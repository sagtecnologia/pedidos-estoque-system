-- =====================================================================
-- CORREÇÃO DA DIVERGÊNCIA DE ESTOQUE
-- =====================================================================
-- Contexto: 53 de 60 produtos movimentados não fecham com o histórico.
--
-- Causa raiz: em finalizar_pedido() e reabrir_pedido_para_rascunho(),
-- o UPDATE do saldo executa SEMPRE, mas o INSERT da movimentação usa
-- ON CONFLICT DO NOTHING sobre um índice único por PEDIDO (e não por
-- EVENTO). Ao reabrir e refinalizar o mesmo pedido, a segunda baixa
-- altera o saldo e o registro é descartado em silêncio.
--
-- Esta migração faz três coisas:
--   PARTE 1  identifica o evento e o ciclo de cada movimentação
--   PARTE 2  inverte a ordem: grava o histórico ANTES de mexer no saldo
--   PARTE 3  entrega uma RPC atômica para o inventário
--
-- ORDEM DE EXECUÇÃO: rodar esta migração ANTES do inventário físico.
-- Inventário sem esta correção volta a divergir na primeira reabertura.
--
-- Rodar em transação única. Recomendado: backup antes.
-- =====================================================================

BEGIN;

-- =====================================================================
-- PARTE 1 — Identificar evento e ciclo
-- =====================================================================
-- Hoje o tipo de evento só existe como texto livre em `observacao`, e o
-- índice único não distingue a 1ª da 2ª finalização do mesmo pedido.
-- Passamos a gravar isso em colunas próprias.

ALTER TABLE public.estoque_movimentacoes
    ADD COLUMN IF NOT EXISTS evento VARCHAR(20),
    ADD COLUMN IF NOT EXISTS ciclo  INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.estoque_movimentacoes.evento IS
    'FINALIZACAO | REABERTURA | CANCELAMENTO | AJUSTE | OUTRO';
COMMENT ON COLUMN public.estoque_movimentacoes.ciclo IS
    'Rodada de finalização do pedido. Incrementa a cada reabertura. '
    'Permite que a 2ª finalização do mesmo pedido grave sua própria movimentação.';

ALTER TABLE public.pedidos
    ADD COLUMN IF NOT EXISTS ciclo_estoque INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.pedidos.ciclo_estoque IS
    'Quantas vezes este pedido já foi reaberto. Usado como chave de idempotência por evento.';

-- --- Backfill do evento a partir da observação existente -------------
UPDATE public.estoque_movimentacoes
SET evento = CASE
        WHEN observacao ILIKE '%cancelamento%'  THEN 'CANCELAMENTO'
        WHEN observacao ILIKE '%reabertura%'    THEN 'REABERTURA'
        WHEN observacao ILIKE '%ajuste%'        THEN 'AJUSTE'
        WHEN observacao ILIKE '%finaliza%'      THEN 'FINALIZACAO'
        ELSE 'OUTRO'
    END
WHERE evento IS NULL;

-- --- Backfill do ciclo -----------------------------------------------
-- As duplicatas históricas (ex.: 3 devoluções para 1 saída) impediriam a
-- criação do índice único. Numeramos cada repetição em ordem cronológica,
-- preservando TODAS as linhas — nada é apagado.
WITH numerado AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY pedido_id, produto_id,
                            COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid),
                            evento
               ORDER BY created_at, id
           ) - 1 AS seq
    FROM public.estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
)
UPDATE public.estoque_movimentacoes m
SET ciclo = n.seq
FROM numerado n
WHERE m.id = n.id
  AND n.seq > 0;

-- Alinha o contador do pedido ao maior ciclo já gravado, para que as
-- próximas operações não colidam com o histórico remendado acima.
UPDATE public.pedidos p
SET ciclo_estoque = sub.max_ciclo + 1
FROM (
    SELECT pedido_id, MAX(ciclo) AS max_ciclo
    FROM public.estoque_movimentacoes
    WHERE pedido_id IS NOT NULL
    GROUP BY pedido_id
) sub
WHERE p.id = sub.pedido_id
  AND sub.max_ciclo >= p.ciclo_estoque;

-- --- Índices únicos por EVENTO (não mais por pedido) -----------------
DROP INDEX IF EXISTS public."idx_movimentacao_finalização_unica";
DROP INDEX IF EXISTS public.idx_movimentacao_cancelamento_unica;

CREATE UNIQUE INDEX idx_mov_evento_unica
    ON public.estoque_movimentacoes (
        pedido_id,
        produto_id,
        COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid),
        evento,
        ciclo
    )
    WHERE pedido_id IS NOT NULL;

COMMENT ON INDEX public.idx_mov_evento_unica IS
    'Idempotência por EVENTO: protege contra duplo clique e retry de rede, '
    'mas permite que cada nova rodada (ciclo) do mesmo pedido grave sua própria '
    'movimentação. Cobre também a REABERTURA, que antes não tinha proteção alguma.';


-- =====================================================================
-- PARTE 2 — Gravar o histórico ANTES de mexer no saldo
-- =====================================================================
-- Regra nova, válida para todas as funções: o INSERT é a trava. Se ele
-- não gravar (conflito = operação repetida), o saldo NÃO é tocado.
-- Assim é impossível o saldo mudar sem deixar registro.

CREATE OR REPLACE FUNCTION public.finalizar_pedido(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item        RECORD;
    v_status      VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ciclo       INT;
BEGIN
    SELECT status, tipo_pedido, ciclo_estoque
      INTO v_status, v_tipo_pedido, v_ciclo
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado: %', p_pedido_id;
    END IF;

    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado';
    END IF;

    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Pedido foi cancelado e não pode ser finalizado';
    END IF;

    FOR v_item IN
        SELECT pi.produto_id,
               pi.sabor_id,
               pi.quantidade,
               pi.preco_unitario,
               p.codigo  AS produto_codigo,
               ps.sabor  AS sabor_nome
        FROM pedido_itens pi
        JOIN produtos p ON p.id = pi.produto_id
        LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
        WHERE pi.pedido_id = p_pedido_id
    LOOP
        DECLARE
            v_est_ant  DECIMAL;
            v_est_novo DECIMAL;
            v_ajuste   DECIMAL;
            v_mov_id   UUID;
        BEGIN
            -- Lock da linha de saldo antes de qualquer leitura de valor
            IF v_item.sabor_id IS NOT NULL THEN
                SELECT quantidade INTO v_est_ant
                FROM produto_sabores WHERE id = v_item.sabor_id FOR UPDATE;
            ELSE
                SELECT estoque_atual INTO v_est_ant
                FROM produtos WHERE id = v_item.produto_id FOR UPDATE;
            END IF;

            IF v_tipo_pedido = 'COMPRA' THEN
                v_ajuste := v_item.quantidade;
            ELSIF v_tipo_pedido = 'VENDA' THEN
                v_ajuste := -v_item.quantidade;
                IF v_est_ant < v_item.quantidade THEN
                    RAISE EXCEPTION
                        'ESTOQUE INSUFICIENTE: % (%) - Disponível: %, Solicitado: %',
                        v_item.produto_codigo, COALESCE(v_item.sabor_nome, '-'),
                        v_est_ant, v_item.quantidade;
                END IF;
            ELSE
                RAISE EXCEPTION 'Tipo de pedido inválido: %', v_tipo_pedido;
            END IF;

            v_est_novo := v_est_ant + v_ajuste;

            -- 🔒 O INSERT É A TRAVA. Se conflitar, a operação já foi
            -- processada nesta rodada e o saldo não pode ser tocado.
            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao, preco_unitario,
                evento, ciclo
            ) VALUES (
                v_item.produto_id, v_item.sabor_id,
                CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                v_item.quantidade, v_est_ant, v_est_novo,
                p_usuario_id, p_pedido_id,
                'Finalização pedido ' || v_tipo_pedido, v_item.preco_unitario,
                'FINALIZACAO', v_ciclo
            )
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_mov_id;

            IF v_mov_id IS NULL THEN
                CONTINUE;  -- já processado; saldo intocado
            END IF;

            IF v_item.sabor_id IS NOT NULL THEN
                UPDATE produto_sabores SET quantidade = v_est_novo
                WHERE id = v_item.sabor_id;
            ELSE
                UPDATE produtos SET estoque_atual = v_est_novo
                WHERE id = v_item.produto_id;
            END IF;
        END;
    END LOOP;

    UPDATE pedidos
    SET status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id,
        updated_at = NOW()
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$function$;


CREATE OR REPLACE FUNCTION public.reabrir_pedido_para_rascunho(p_pedido_id uuid, p_usuario_id uuid)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_item        RECORD;
    v_status      VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ciclo       INT;
BEGIN
    SELECT status, tipo_pedido, ciclo_estoque
      INTO v_status, v_tipo_pedido, v_ciclo
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado: %', p_pedido_id;
    END IF;

    IF v_status <> 'FINALIZADO' THEN
        RAISE EXCEPTION 'Apenas pedidos FINALIZADOS podem ser reabertos. Status atual: %', v_status;
    END IF;

    FOR v_item IN
        SELECT pi.produto_id, pi.sabor_id, pi.quantidade, pi.preco_unitario
        FROM pedido_itens pi
        WHERE pi.pedido_id = p_pedido_id
          AND pi.sabor_id IS NOT NULL
    LOOP
        DECLARE
            v_est_ant  DECIMAL;
            v_est_novo DECIMAL;
            v_ajuste   DECIMAL;
            v_mov_id   UUID;
        BEGIN
            SELECT quantidade INTO v_est_ant
            FROM produto_sabores WHERE id = v_item.sabor_id FOR UPDATE;

            -- COMPRA: remove a entrada. VENDA: devolve a saída.
            v_ajuste   := CASE WHEN v_tipo_pedido = 'COMPRA'
                               THEN -v_item.quantidade ELSE v_item.quantidade END;
            v_est_novo := v_est_ant + v_ajuste;

            INSERT INTO estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, pedido_id, observacao, preco_unitario,
                evento, ciclo
            ) VALUES (
                v_item.produto_id, v_item.sabor_id,
                CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'SAIDA' ELSE 'ENTRADA' END,
                v_item.quantidade, v_est_ant, v_est_novo,
                p_usuario_id, p_pedido_id,
                CASE WHEN v_tipo_pedido = 'COMPRA'
                     THEN 'Reabertura - Reversão de entrada de compra'
                     ELSE 'Reabertura - Devolução de venda' END,
                v_item.preco_unitario,
                'REABERTURA', v_ciclo
            )
            ON CONFLICT DO NOTHING
            RETURNING id INTO v_mov_id;

            IF v_mov_id IS NULL THEN
                CONTINUE;
            END IF;

            UPDATE produto_sabores SET quantidade = v_est_novo
            WHERE id = v_item.sabor_id;
        END;
    END LOOP;

    -- Abre a próxima rodada: a refinalização terá sua própria movimentação.
    UPDATE pedidos
    SET status = 'RASCUNHO',
        data_finalizacao = NULL,
        ciclo_estoque = ciclo_estoque + 1,
        updated_at = NOW()
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$function$;


-- =====================================================================
-- PARTE 3 — RPC atômica para o inventário
-- =====================================================================
-- A tela pages/ajuste-estoque.html hoje grava o saldo em VALOR ABSOLUTO
-- calculado no navegador, em três chamadas separadas e sem transação.
-- Se uma venda acontecer entre abrir a tela e salvar a contagem, a venda
-- é sobrescrita (lost update) — justamente o risco de um inventário feito
-- durante o expediente.
--
-- Esta função lê o saldo NO BANCO com lock, grava a movimentação primeiro
-- e só então aplica a contagem. Tudo em uma transação.

CREATE OR REPLACE FUNCTION public.registrar_contagem_inventario(
    p_sabor_id   uuid,
    p_contagem   numeric,
    p_usuario_id uuid,
    p_motivo     text DEFAULT 'Inventário'
)
 RETURNS TABLE(saldo_anterior numeric, saldo_novo numeric, diferenca numeric)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_produto_id UUID;
    v_est_ant    DECIMAL;
    v_dif        DECIMAL;
BEGIN
    IF p_contagem < 0 THEN
        RAISE EXCEPTION 'Contagem não pode ser negativa: %', p_contagem;
    END IF;

    SELECT produto_id, quantidade INTO v_produto_id, v_est_ant
    FROM produto_sabores
    WHERE id = p_sabor_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sabor não encontrado: %', p_sabor_id;
    END IF;

    v_dif := p_contagem - v_est_ant;

    IF v_dif = 0 THEN
        RETURN QUERY SELECT v_est_ant, v_est_ant, 0::numeric;
        RETURN;
    END IF;

    INSERT INTO estoque_movimentacoes (
        produto_id, sabor_id, tipo, quantidade,
        estoque_anterior, estoque_novo,
        usuario_id, observacao, evento, ciclo
    ) VALUES (
        v_produto_id, p_sabor_id,
        CASE WHEN v_dif > 0 THEN 'ENTRADA' ELSE 'SAIDA' END,
        ABS(v_dif), v_est_ant, p_contagem,
        p_usuario_id, 'Ajuste de Estoque - ' || p_motivo, 'AJUSTE', 0
    );

    UPDATE produto_sabores
    SET quantidade = p_contagem, updated_at = NOW()
    WHERE id = p_sabor_id;

    RETURN QUERY SELECT v_est_ant, p_contagem, v_dif;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.registrar_contagem_inventario(uuid, numeric, uuid, text) TO authenticated;


-- =====================================================================
-- PARTE 4 — Conferência permanente
-- =====================================================================
-- Depois do inventário, esta view deve voltar ZERO linhas para todo
-- movimento posterior à data de corte. Se voltar a aparecer linha,
-- surgiu um caminho de escrita novo que burla a regra.

CREATE OR REPLACE VIEW public.vw_conferencia_estoque AS
SELECT p.codigo,
       p.nome,
       p.estoque_atual                                   AS saldo_sistema,
       COALESCE(SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.quantidade
                         ELSE -m.quantidade END), 0)     AS saldo_historico,
       p.estoque_atual
         - COALESCE(SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.quantidade
                             ELSE -m.quantidade END), 0) AS diferenca
FROM produtos p
LEFT JOIN estoque_movimentacoes m ON m.produto_id = p.id
GROUP BY p.id, p.codigo, p.nome, p.estoque_atual
HAVING p.estoque_atual
       - COALESCE(SUM(CASE WHEN m.tipo = 'ENTRADA' THEN m.quantidade
                           ELSE -m.quantidade END), 0) <> 0;

COMMENT ON VIEW public.vw_conferencia_estoque IS
    'Produtos cujo saldo não é reproduzido pela soma das movimentações. '
    'Enquanto o histórico anterior ao inventário não for zerado por ajuste, '
    'esta view continuará listando as divergências antigas — o que importa '
    'é ela não GANHAR linhas novas depois da data de corte.';

COMMIT;

-- =====================================================================
-- PENDÊNCIAS NÃO COBERTAS POR ESTA MIGRAÇÃO
-- =====================================================================
-- 1. cancelar_pedido_definitivo() usa o mesmo padrão UPDATE-antes-INSERT.
--    Hoje ela é protegida por uma checagem explícita que levanta exceção
--    (PROTEÇÃO 3), então o risco é baixo — mas vale aplicar a mesma
--    inversão de ordem por consistência.
-- 2. pages/ajuste-estoque.html precisa passar a chamar
--    registrar_contagem_inventario() em vez de fazer UPDATE direto.
-- 3. atualizar_estoque_produto() soma apenas sabores com ativo = true.
--    559 unidades estão presas em sabores desativados e não aparecem no
--    total do produto. Decidir por sabor: reativar ou zerar com ajuste.
-- 4. NÃO rodar reprocessar_estoque_completo() — ela reescreve o saldo a
--    partir do histórico, que está comprovadamente incompleto.
