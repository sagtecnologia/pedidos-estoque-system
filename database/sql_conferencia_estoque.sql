-- =====================================================================
-- CONFERÊNCIA DE ESTOQUE (contagem física + aprovação)
-- =====================================================================
-- Motivação: o único jeito de corrigir estoque manualmente hoje é a tela
-- "Ajuste de Estoque" (ajuste-estoque.html), exclusiva de ADMIN, que
-- escreve direto em produto_sabores/estoque_movimentacoes sem nenhuma
-- aprovação. Esta migração cria um fluxo de duas etapas: qualquer
-- usuário confere fisicamente o estoque de todos os produtos/sabores
-- cadastrados e informa o que contou; só ADMIN aprova, e é somente na
-- aprovação que o estoque real muda.
--
-- Regra central (pedida explicitamente): um sabor que o usuário NÃO
-- tocou durante a contagem jamais pode ser zerado ou alterado. Isso é
-- garantido no próprio modelo de dados: só existe uma linha em
-- conferencia_estoque_itens para um sabor quando o usuário de fato
-- informou um valor para ele (ver salvar_item_conferencia_estoque).
--
-- Tudo passa por funções SECURITY DEFINER (igual a salvar_produto_sabor
-- e excluir_pedido_soft) — a escrita direta nas tabelas novas é
-- bloqueada (REVOKE), então não depende de policies de RLS abertas.
--
-- HISTÓRICO DE CORREÇÕES (aplicadas nesta versão do arquivo):
--   1) abrir_conferencia_estoque(): "column reference numero is
--      ambiguous" — o RETURNS TABLE(..., numero integer) cria uma
--      variável de saída chamada "numero", que colidia com a coluna
--      conferencias_estoque.numero em referências não qualificadas.
--      Corrigido qualificando com alias de tabela.
--   2) aprovar_conferencia_estoque(): a leitura de produto_sabores no
--      loop de aprovação não filtrava "ativo = true". Se um sabor fosse
--      desativado (remover_sabor_produto) depois da contagem e antes da
--      aprovação, a função ainda sobrescrevia a quantidade dele (mesmo
--      inativo), inconsistente com o recálculo de produtos.estoque_atual
--      (que só soma sabores ativos). Corrigido para tratar sabor
--      inativo do mesmo jeito que sabor excluído: pula o item.
--      Também passou a contar e retornar itens_ignorados, para o
--      admin saber se algo foi pulado nessa situação.
--
-- Execute este arquivo inteiro no SQL Editor do Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELAS
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.conferencias_estoque_numero_seq;

CREATE TABLE IF NOT EXISTS public.conferencias_estoque (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    numero integer NOT NULL DEFAULT nextval('public.conferencias_estoque_numero_seq'),
    status varchar(20) NOT NULL DEFAULT 'RASCUNHO',
    criado_por uuid NOT NULL,
    criado_em timestamptz NOT NULL DEFAULT now(),
    enviado_em timestamptz NULL,
    aprovado_por uuid NULL,
    aprovado_em timestamptz NULL,
    motivo_rejeicao text NULL,
    observacao text NULL,
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT conferencias_estoque_pkey PRIMARY KEY (id),
    CONSTRAINT conferencias_estoque_status_check CHECK (status IN ('RASCUNHO','PENDENTE','APROVADA','REJEITADA','CANCELADA')),
    CONSTRAINT conferencias_estoque_criado_por_fkey FOREIGN KEY (criado_por) REFERENCES public.users(id),
    CONSTRAINT conferencias_estoque_aprovado_por_fkey FOREIGN KEY (aprovado_por) REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS idx_conferencias_estoque_status ON public.conferencias_estoque (status);
CREATE INDEX IF NOT EXISTS idx_conferencias_estoque_criado_por ON public.conferencias_estoque (criado_por);

-- Garante no máximo um RASCUNHO por usuário (o próprio abrir_conferencia_estoque
-- já retoma o existente em vez de criar outro, mas esse índice impede duplicidade
-- mesmo em caso de corrida de duas chamadas simultâneas).
CREATE UNIQUE INDEX IF NOT EXISTS idx_conferencias_estoque_um_rascunho_por_usuario
    ON public.conferencias_estoque (criado_por)
    WHERE status = 'RASCUNHO';

CREATE TABLE IF NOT EXISTS public.conferencia_estoque_itens (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    conferencia_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    sabor_id uuid NOT NULL,
    estoque_anterior numeric(10,2) NOT NULL,
    estoque_novo numeric(10,2) NOT NULL,
    estoque_no_momento_aprovacao numeric(10,2) NULL,
    contado_em timestamptz NOT NULL DEFAULT now(),
    contado_por uuid NOT NULL,
    processado boolean NOT NULL DEFAULT false,
    CONSTRAINT conferencia_estoque_itens_pkey PRIMARY KEY (id),
    CONSTRAINT conferencia_estoque_itens_conferencia_fkey FOREIGN KEY (conferencia_id) REFERENCES public.conferencias_estoque(id) ON DELETE CASCADE,
    CONSTRAINT conferencia_estoque_itens_produto_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id),
    CONSTRAINT conferencia_estoque_itens_sabor_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id),
    CONSTRAINT conferencia_estoque_itens_contado_por_fkey FOREIGN KEY (contado_por) REFERENCES public.users(id),
    CONSTRAINT conferencia_estoque_itens_unica UNIQUE (conferencia_id, sabor_id)
);

CREATE INDEX IF NOT EXISTS idx_conferencia_estoque_itens_conferencia ON public.conferencia_estoque_itens (conferencia_id);
CREATE INDEX IF NOT EXISTS idx_conferencia_estoque_itens_sabor ON public.conferencia_estoque_itens (sabor_id);

COMMENT ON TABLE public.conferencias_estoque IS 'Cabeçalho de uma conferência (contagem física) de estoque: RASCUNHO enquanto o usuário conta, PENDENTE após finalizar, APROVADA/REJEITADA/CANCELADA no fim do fluxo.';
COMMENT ON TABLE public.conferencia_estoque_itens IS 'Um item só existe aqui quando o usuário efetivamente informou um novo estoque para aquele sabor durante a contagem. Sabores não tocados nunca geram linha, e portanto nunca são alterados na aprovação.';

-- ---------------------------------------------------------------------
-- 2. RLS — toda escrita passa pelas funções abaixo (SECURITY DEFINER);
--    a API só recebe SELECT.
-- ---------------------------------------------------------------------
ALTER TABLE public.conferencias_estoque ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conferencia_estoque_itens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS select_own_or_admin_conferencias_estoque ON public.conferencias_estoque;
CREATE POLICY select_own_or_admin_conferencias_estoque
ON public.conferencias_estoque
FOR SELECT
TO authenticated
USING (criado_por = auth.uid() OR public.current_app_user_role() = 'ADMIN');

DROP POLICY IF EXISTS select_own_or_admin_conferencia_itens ON public.conferencia_estoque_itens;
CREATE POLICY select_own_or_admin_conferencia_itens
ON public.conferencia_estoque_itens
FOR SELECT
TO authenticated
USING (
    public.current_app_user_role() = 'ADMIN'
    OR EXISTS (
        SELECT 1 FROM public.conferencias_estoque c
         WHERE c.id = conferencia_estoque_itens.conferencia_id
           AND c.criado_por = auth.uid()
    )
);

REVOKE INSERT, UPDATE, DELETE ON public.conferencias_estoque FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.conferencia_estoque_itens FROM authenticated, anon;
GRANT SELECT ON public.conferencias_estoque TO authenticated;
GRANT SELECT ON public.conferencia_estoque_itens TO authenticated;

-- ---------------------------------------------------------------------
-- 3. AUDITORIA — reaproveita a função genérica já usada em pedidos
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trigger_audit_conferencias_estoque ON public.conferencias_estoque;
CREATE TRIGGER trigger_audit_conferencias_estoque
AFTER INSERT OR UPDATE OR DELETE ON public.conferencias_estoque
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

DROP TRIGGER IF EXISTS trigger_audit_conferencia_estoque_itens ON public.conferencia_estoque_itens;
CREATE TRIGGER trigger_audit_conferencia_estoque_itens
AFTER INSERT OR UPDATE OR DELETE ON public.conferencia_estoque_itens
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

-- ---------------------------------------------------------------------
-- 4. abrir_conferencia_estoque() — retoma o rascunho do usuário ou cria um novo
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.abrir_conferencia_estoque()
RETURNS TABLE(sucesso boolean, mensagem text, conferencia_id uuid, numero integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_ativo boolean;
    v_conferencia_id uuid;
    v_numero integer;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text, NULL::uuid, NULL::integer;
        RETURN;
    END IF;

    SELECT active INTO v_usuario_ativo FROM public.users WHERE id = v_usuario_id;

    IF COALESCE(v_usuario_ativo, false) = false THEN
        RETURN QUERY SELECT false, 'Usuario sem permissao para realizar conferencia de estoque'::text, NULL::uuid, NULL::integer;
        RETURN;
    END IF;

    SELECT c.id, c.numero INTO v_conferencia_id, v_numero
      FROM public.conferencias_estoque c
     WHERE c.criado_por = v_usuario_id
       AND c.status = 'RASCUNHO'
     ORDER BY c.criado_em DESC
     LIMIT 1;

    IF v_conferencia_id IS NOT NULL THEN
        RETURN QUERY SELECT true, 'Conferencia em andamento retomada'::text, v_conferencia_id, v_numero;
        RETURN;
    END IF;

    INSERT INTO public.conferencias_estoque AS c (criado_por)
    VALUES (v_usuario_id)
    RETURNING c.id, c.numero INTO v_conferencia_id, v_numero;

    RETURN QUERY SELECT true, 'Conferencia iniciada'::text, v_conferencia_id, v_numero;
END;
$function$;

-- ---------------------------------------------------------------------
-- 5. salvar_item_conferencia_estoque() — autosave de UM sabor contado
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.salvar_item_conferencia_estoque(
    p_conferencia_id uuid,
    p_sabor_id uuid,
    p_estoque_novo numeric DEFAULT NULL
)
RETURNS TABLE(sucesso boolean, mensagem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_conferencia record;
    v_produto_id uuid;
    v_quantidade_atual numeric;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text;
        RETURN;
    END IF;

    SELECT * INTO v_conferencia
      FROM public.conferencias_estoque
     WHERE id = p_conferencia_id
     FOR UPDATE;

    IF v_conferencia.id IS NULL THEN
        RETURN QUERY SELECT false, 'Conferencia nao encontrada'::text;
        RETURN;
    END IF;

    IF v_conferencia.criado_por <> v_usuario_id THEN
        RETURN QUERY SELECT false, 'Voce nao tem permissao para editar esta conferencia'::text;
        RETURN;
    END IF;

    IF v_conferencia.status <> 'RASCUNHO' THEN
        RETURN QUERY SELECT false, 'Esta conferencia ja foi enviada e nao pode mais ser editada'::text;
        RETURN;
    END IF;

    -- estoque_anterior é sempre lido aqui no servidor, nunca confiado do cliente
    SELECT produto_id, quantidade INTO v_produto_id, v_quantidade_atual
      FROM public.produto_sabores
     WHERE id = p_sabor_id
       AND ativo = true;

    IF v_produto_id IS NULL THEN
        RETURN QUERY SELECT false, 'Sabor nao encontrado ou inativo'::text;
        RETURN;
    END IF;

    -- Campo vazio (NULL) = usuario nao contou esse sabor: remove o item,
    -- se existir, e o sabor fica de fora da conferencia (nunca zerado).
    IF p_estoque_novo IS NULL THEN
        DELETE FROM public.conferencia_estoque_itens
         WHERE conferencia_id = p_conferencia_id
           AND sabor_id = p_sabor_id;

        RETURN QUERY SELECT true, 'Item removido da conferencia'::text;
        RETURN;
    END IF;

    IF p_estoque_novo < 0 THEN
        RETURN QUERY SELECT false, 'Estoque nao pode ser negativo'::text;
        RETURN;
    END IF;

    INSERT INTO public.conferencia_estoque_itens (
        conferencia_id, produto_id, sabor_id,
        estoque_anterior, estoque_novo, contado_por
    ) VALUES (
        p_conferencia_id, v_produto_id, p_sabor_id,
        COALESCE(v_quantidade_atual, 0), p_estoque_novo, v_usuario_id
    )
    ON CONFLICT (conferencia_id, sabor_id) DO UPDATE
        SET estoque_anterior = EXCLUDED.estoque_anterior,
            estoque_novo = EXCLUDED.estoque_novo,
            contado_em = now();

    RETURN QUERY SELECT true, 'Item salvo'::text;
END;
$function$;

-- ---------------------------------------------------------------------
-- 6. finalizar_conferencia_estoque() — RASCUNHO -> PENDENTE
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.finalizar_conferencia_estoque(
    p_conferencia_id uuid,
    p_observacao text DEFAULT NULL
)
RETURNS TABLE(sucesso boolean, mensagem text, total_itens integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_conferencia record;
    v_total_itens integer;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text, 0;
        RETURN;
    END IF;

    SELECT * INTO v_conferencia
      FROM public.conferencias_estoque
     WHERE id = p_conferencia_id
     FOR UPDATE;

    IF v_conferencia.id IS NULL THEN
        RETURN QUERY SELECT false, 'Conferencia nao encontrada'::text, 0;
        RETURN;
    END IF;

    IF v_conferencia.criado_por <> v_usuario_id THEN
        RETURN QUERY SELECT false, 'Voce nao tem permissao para finalizar esta conferencia'::text, 0;
        RETURN;
    END IF;

    IF v_conferencia.status <> 'RASCUNHO' THEN
        RETURN QUERY SELECT false, 'Esta conferencia ja foi finalizada'::text, 0;
        RETURN;
    END IF;

    SELECT count(*) INTO v_total_itens
      FROM public.conferencia_estoque_itens
     WHERE conferencia_id = p_conferencia_id;

    IF v_total_itens = 0 THEN
        RETURN QUERY SELECT false, 'Informe ao menos um item contado antes de finalizar'::text, 0;
        RETURN;
    END IF;

    UPDATE public.conferencias_estoque
       SET status = 'PENDENTE',
           enviado_em = now(),
           observacao = NULLIF(TRIM(COALESCE(p_observacao, '')), ''),
           updated_at = now()
     WHERE id = p_conferencia_id;

    RETURN QUERY SELECT true, 'Conferencia enviada para aprovacao'::text, v_total_itens;
END;
$function$;

-- ---------------------------------------------------------------------
-- 7. cancelar_conferencia_estoque() — desiste da propria conferencia
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.cancelar_conferencia_estoque(p_conferencia_id uuid)
RETURNS TABLE(sucesso boolean, mensagem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_conferencia record;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text;
        RETURN;
    END IF;

    SELECT * INTO v_conferencia
      FROM public.conferencias_estoque
     WHERE id = p_conferencia_id
     FOR UPDATE;

    IF v_conferencia.id IS NULL THEN
        RETURN QUERY SELECT false, 'Conferencia nao encontrada'::text;
        RETURN;
    END IF;

    IF v_conferencia.criado_por <> v_usuario_id THEN
        RETURN QUERY SELECT false, 'Voce nao tem permissao para cancelar esta conferencia'::text;
        RETURN;
    END IF;

    IF v_conferencia.status NOT IN ('RASCUNHO', 'PENDENTE') THEN
        RETURN QUERY SELECT false, 'Somente conferencias em rascunho ou pendentes podem ser canceladas'::text;
        RETURN;
    END IF;

    UPDATE public.conferencias_estoque
       SET status = 'CANCELADA',
           updated_at = now()
     WHERE id = p_conferencia_id;

    RETURN QUERY SELECT true, 'Conferencia cancelada'::text;
END;
$function$;

-- ---------------------------------------------------------------------
-- 8. aprovar_conferencia_estoque() — só ADMIN. Único ponto que altera
--    o estoque real. Sempre diferenca-e-loga (nunca sobrescreve calado),
--    e usa a quantidade AO VIVO no momento da aprovacao (nao o snapshot
--    salvo na contagem) para calcular a diferenca registrada em
--    estoque_movimentacoes — mas o valor final gravado em
--    produto_sabores.quantidade e SEMPRE o que foi contado
--    (estoque_novo), porque essa e a contagem fisica real. Se algo
--    mudou o estoque entre a contagem e a aprovacao (venda, compra),
--    a tela de aprovacao avisa o ADMIN (compara estoque_anterior
--    salvo na contagem com o estoque ao vivo) para ele decidir se
--    aprova assim mesmo ou rejeita e pede recontagem.
-- ---------------------------------------------------------------------
-- DROP necessário: a versão anterior desta função retornava uma coluna
-- a menos (sem itens_ignorados), e o Postgres não permite que
-- CREATE OR REPLACE mude o tipo de retorno de uma função existente.
DROP FUNCTION IF EXISTS public.aprovar_conferencia_estoque(uuid);

CREATE OR REPLACE FUNCTION public.aprovar_conferencia_estoque(p_conferencia_id uuid)
RETURNS TABLE(sucesso boolean, mensagem text, itens_atualizados integer, itens_sem_alteracao integer, itens_ignorados integer)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_aprovador_nome text;
    v_contador_nome text;
    v_conferencia record;
    v_item record;
    v_quantidade_atual numeric;
    v_produto_id uuid;
    v_diferenca numeric;
    v_itens_atualizados integer := 0;
    v_itens_sem_alteracao integer := 0;
    v_itens_ignorados integer := 0;
    v_produtos_tocados uuid[] := ARRAY[]::uuid[];
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text, 0, 0, 0;
        RETURN;
    END IF;

    SELECT role, full_name INTO v_usuario_role, v_aprovador_nome
      FROM public.users WHERE id = v_usuario_id;

    IF v_usuario_role <> 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem aprovar conferencias de estoque'::text, 0, 0, 0;
        RETURN;
    END IF;

    SELECT * INTO v_conferencia
      FROM public.conferencias_estoque
     WHERE id = p_conferencia_id
     FOR UPDATE;

    IF v_conferencia.id IS NULL THEN
        RETURN QUERY SELECT false, 'Conferencia nao encontrada'::text, 0, 0, 0;
        RETURN;
    END IF;

    IF v_conferencia.status <> 'PENDENTE' THEN
        RETURN QUERY SELECT false, 'Esta conferencia nao esta pendente de aprovacao'::text, 0, 0, 0;
        RETURN;
    END IF;

    SELECT full_name INTO v_contador_nome FROM public.users WHERE id = v_conferencia.criado_por;

    FOR v_item IN
        SELECT * FROM public.conferencia_estoque_itens
         WHERE conferencia_id = p_conferencia_id
         ORDER BY id
    LOOP
        -- Mesmo filtro "ativo = true" usado na contagem: se o sabor foi
        -- desativado entre a contagem e a aprovacao, trata como removido
        -- e pula o item (nao reativa quantidade em sabor inativo).
        SELECT quantidade, produto_id INTO v_quantidade_atual, v_produto_id
          FROM public.produto_sabores
         WHERE id = v_item.sabor_id
           AND ativo = true
         FOR UPDATE;

        IF v_quantidade_atual IS NULL THEN
            v_itens_ignorados := v_itens_ignorados + 1;
            CONTINUE;
        END IF;

        v_diferenca := v_item.estoque_novo - v_quantidade_atual;

        UPDATE public.conferencia_estoque_itens
           SET estoque_no_momento_aprovacao = v_quantidade_atual,
               processado = true
         WHERE id = v_item.id;

        IF v_diferenca <> 0 THEN
            UPDATE public.produto_sabores
               SET quantidade = v_item.estoque_novo,
                   updated_at = now()
             WHERE id = v_item.sabor_id;

            INSERT INTO public.estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo, usuario_id, observacao
            ) VALUES (
                v_produto_id, v_item.sabor_id,
                CASE WHEN v_diferenca > 0 THEN 'ENTRADA' ELSE 'SAIDA' END,
                ABS(v_diferenca), v_quantidade_atual, v_item.estoque_novo, v_usuario_id,
                'Conferencia de Estoque #' || v_conferencia.numero
                    || ' - contado por ' || COALESCE(v_contador_nome, 'usuario')
                    || ' - aprovado por ' || COALESCE(v_aprovador_nome, 'admin')
            );

            v_itens_atualizados := v_itens_atualizados + 1;

            IF NOT (v_produto_id = ANY(v_produtos_tocados)) THEN
                v_produtos_tocados := array_append(v_produtos_tocados, v_produto_id);
            END IF;
        ELSE
            v_itens_sem_alteracao := v_itens_sem_alteracao + 1;
        END IF;
    END LOOP;

    -- Recalcula produtos.estoque_atual (soma dos sabores ativos), uma vez
    -- por produto tocado — mesma logica ja usada em ajuste-estoque.html.
    UPDATE public.produtos p
       SET estoque_atual = sub.total,
           updated_at = now()
      FROM (
            SELECT produto_id, COALESCE(SUM(quantidade), 0) AS total
              FROM public.produto_sabores
             WHERE produto_id = ANY(v_produtos_tocados)
               AND ativo = true
             GROUP BY produto_id
      ) sub
     WHERE p.id = sub.produto_id;

    UPDATE public.conferencias_estoque
       SET status = 'APROVADA',
           aprovado_por = v_usuario_id,
           aprovado_em = now(),
           updated_at = now()
     WHERE id = p_conferencia_id;

    RETURN QUERY SELECT true, 'Conferencia aprovada com sucesso'::text, v_itens_atualizados, v_itens_sem_alteracao, v_itens_ignorados;
END;
$function$;

-- ---------------------------------------------------------------------
-- 9. rejeitar_conferencia_estoque() — só ADMIN. Nenhuma mudanca de estoque.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.rejeitar_conferencia_estoque(
    p_conferencia_id uuid,
    p_motivo text
)
RETURNS TABLE(sucesso boolean, mensagem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_conferencia record;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    IF v_usuario_role <> 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem rejeitar conferencias de estoque'::text;
        RETURN;
    END IF;

    IF TRIM(COALESCE(p_motivo, '')) = '' THEN
        RETURN QUERY SELECT false, 'Informe o motivo da rejeicao'::text;
        RETURN;
    END IF;

    SELECT * INTO v_conferencia
      FROM public.conferencias_estoque
     WHERE id = p_conferencia_id
     FOR UPDATE;

    IF v_conferencia.id IS NULL THEN
        RETURN QUERY SELECT false, 'Conferencia nao encontrada'::text;
        RETURN;
    END IF;

    IF v_conferencia.status <> 'PENDENTE' THEN
        RETURN QUERY SELECT false, 'Esta conferencia nao esta pendente de aprovacao'::text;
        RETURN;
    END IF;

    UPDATE public.conferencias_estoque
       SET status = 'REJEITADA',
           aprovado_por = v_usuario_id,
           aprovado_em = now(),
           motivo_rejeicao = p_motivo,
           updated_at = now()
     WHERE id = p_conferencia_id;

    RETURN QUERY SELECT true, 'Conferencia rejeitada'::text;
END;
$function$;

-- ---------------------------------------------------------------------
-- 10. GRANTS
-- ---------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.abrir_conferencia_estoque() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.salvar_item_conferencia_estoque(uuid, uuid, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.finalizar_conferencia_estoque(uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancelar_conferencia_estoque(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.aprovar_conferencia_estoque(uuid) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rejeitar_conferencia_estoque(uuid, text) TO authenticated, service_role;

-- =====================================================================
-- FIM DA MIGRAÇÃO
-- =====================================================================
