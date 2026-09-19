-- =====================================================================
-- ESTOQUE RESERVA (transferência de produtos/sabores para outro estoque)
-- =====================================================================
-- Motivação: hoje só existe UM estoque (produtos.estoque_atual /
-- produto_sabores.quantidade). Esta migração permite criar outros
-- "estoques" nomeados (ex: "Depósito B", "Consignação Loja X") e mover
-- quantidade de um produto/sabor do estoque PRINCIPAL para um desses
-- estoques, com a opção de devolver depois. O estoque PRINCIPAL nunca
-- vira uma linha em "estoques": ele continua sendo exatamente o que já
-- é hoje (produtos.estoque_atual / produto_sabores.quantidade), então
-- nenhum código existente (vendas, compras, conferência, relatórios)
-- precisa mudar — para o resto do sistema, estoque em reserva é
-- simplesmente estoque que "saiu" (SAIDA) e pode "voltar" (ENTRADA).
--
-- Como funciona por baixo dos panos:
--   - mover_estoque_para_reserva(): dá baixa no principal (mesma trigger
--     de bloqueio de estoque negativo que já protege o resto do
--     sistema) e credita em estoque_saldos, registrando tanto em
--     estoque_movimentacoes (ENTRADA/SAIDA — para aparecer no
--     histórico do produto normalmente) quanto em estoque_transferencias
--     (auditoria dedicada, com saldo antes/depois dos dois lados).
--   - retornar_estoque_reserva() faz o caminho inverso.
--   - As duas funções sempre travam (FOR UPDATE) primeiro a linha do
--     PRINCIPAL (produtos ou produto_sabores) e só depois a linha de
--     estoque_saldos, nessa ordem fixa nas duas direções — isso evita
--     deadlock caso alguém mova para a reserva e outra pessoa devolva
--     do mesmo produto/sabor ao mesmo tempo.
--
-- Limitação conhecida (ver comentário completo antes da seção 5):
-- reprocessar_estoque_completo() e reprocessar_estoque_produto() são
-- ferramentas de emergência que recalculam o estoque olhando só para
-- pedidos finalizados — elas não sabem que uma parte do saldo pode
-- estar em um estoque reserva. Não foram alteradas aqui (são
-- destrutivas e de altíssimo risco para mexer sem poder testar ao
-- vivo); o procedimento seguro está documentado na seção 5.
--
-- Execute este arquivo inteiro no SQL Editor do Supabase. Depois rode
-- sql_estoque_reserva_testes.sql (ele mesmo desfaz tudo com ROLLBACK)
-- para validar antes de usar em produção.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELAS
-- ---------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.estoques (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    nome varchar(100) NOT NULL,
    descricao text NULL,
    ativo boolean NOT NULL DEFAULT true,
    created_by uuid NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT estoques_pkey PRIMARY KEY (id),
    CONSTRAINT estoques_nome_key UNIQUE (nome),
    CONSTRAINT estoques_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(id)
);

COMMENT ON TABLE public.estoques IS 'Estoques adicionais além do principal (ex: "Depósito B"). O estoque principal NUNCA tem linha aqui: ele continua sendo produtos.estoque_atual / produto_sabores.quantidade.';

CREATE TRIGGER update_estoques_updated_at
BEFORE UPDATE ON public.estoques
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS trigger_audit_estoques ON public.estoques;
CREATE TRIGGER trigger_audit_estoques
AFTER INSERT OR UPDATE OR DELETE ON public.estoques
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

CREATE TABLE IF NOT EXISTS public.estoque_saldos (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    estoque_id uuid NOT NULL,
    produto_id uuid NOT NULL,
    sabor_id uuid NULL,
    quantidade numeric(10,2) NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT estoque_saldos_pkey PRIMARY KEY (id),
    CONSTRAINT estoque_saldos_quantidade_check CHECK (quantidade >= 0),
    CONSTRAINT estoque_saldos_estoque_id_fkey FOREIGN KEY (estoque_id) REFERENCES public.estoques(id),
    CONSTRAINT estoque_saldos_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id),
    CONSTRAINT estoque_saldos_sabor_id_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id)
);

-- sabor_id é opcional (produto sem sabores) — usa o mesmo truque de
-- COALESCE com uuid fixo já usado em idx_movimentacao_cancelamento_unica
-- para tratar NULL como um valor único em vez de "sempre diferente".
CREATE UNIQUE INDEX IF NOT EXISTS idx_estoque_saldos_unico
ON public.estoque_saldos (estoque_id, produto_id, (COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)));

CREATE INDEX IF NOT EXISTS idx_estoque_saldos_produto ON public.estoque_saldos (produto_id);
CREATE INDEX IF NOT EXISTS idx_estoque_saldos_estoque ON public.estoque_saldos (estoque_id);

COMMENT ON TABLE public.estoque_saldos IS 'Quanto de cada produto/sabor está guardado em cada estoque (não-principal). Só é alterada pelas funções mover_estoque_para_reserva/retornar_estoque_reserva.';

CREATE TRIGGER update_estoque_saldos_updated_at
BEFORE UPDATE ON public.estoque_saldos
FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TABLE IF NOT EXISTS public.estoque_transferencias (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    produto_id uuid NOT NULL,
    sabor_id uuid NULL,
    estoque_origem_id uuid NULL,   -- NULL = estoque principal
    estoque_destino_id uuid NULL,  -- NULL = estoque principal
    tipo varchar(20) NOT NULL,
    quantidade numeric(10,2) NOT NULL,
    saldo_origem_anterior numeric(10,2) NOT NULL,
    saldo_origem_novo numeric(10,2) NOT NULL,
    saldo_destino_anterior numeric(10,2) NOT NULL,
    saldo_destino_novo numeric(10,2) NOT NULL,
    movimentacao_id uuid NULL,
    usuario_id uuid NULL,
    observacao text NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT estoque_transferencias_pkey PRIMARY KEY (id),
    CONSTRAINT estoque_transferencias_tipo_check CHECK (tipo IN ('ENVIO','RETORNO')),
    CONSTRAINT estoque_transferencias_quantidade_check CHECK (quantidade > 0),
    CONSTRAINT estoque_transferencias_origem_destino_diff CHECK (estoque_origem_id IS DISTINCT FROM estoque_destino_id),
    CONSTRAINT estoque_transferencias_produto_id_fkey FOREIGN KEY (produto_id) REFERENCES public.produtos(id),
    CONSTRAINT estoque_transferencias_sabor_id_fkey FOREIGN KEY (sabor_id) REFERENCES public.produto_sabores(id),
    CONSTRAINT estoque_transferencias_estoque_origem_id_fkey FOREIGN KEY (estoque_origem_id) REFERENCES public.estoques(id),
    CONSTRAINT estoque_transferencias_estoque_destino_id_fkey FOREIGN KEY (estoque_destino_id) REFERENCES public.estoques(id),
    CONSTRAINT estoque_transferencias_movimentacao_id_fkey FOREIGN KEY (movimentacao_id) REFERENCES public.estoque_movimentacoes(id),
    CONSTRAINT estoque_transferencias_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES public.users(id)
);

CREATE INDEX IF NOT EXISTS idx_estoque_transferencias_produto ON public.estoque_transferencias (produto_id);
CREATE INDEX IF NOT EXISTS idx_estoque_transferencias_created_at ON public.estoque_transferencias (created_at DESC);

COMMENT ON TABLE public.estoque_transferencias IS 'Histórico completo (imutável) de cada movimentação entre o estoque principal e um estoque reserva, nos dois sentidos. Nunca é editada, só recebe INSERT.';

-- ---------------------------------------------------------------------
-- 2. RLS — leitura liberada para autenticados, escrita só via função
--    SECURITY DEFINER (mesmo padrão de conferencias_estoque).
-- ---------------------------------------------------------------------
ALTER TABLE public.estoques ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoque_saldos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.estoque_transferencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS select_estoques ON public.estoques;
CREATE POLICY select_estoques ON public.estoques FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS select_estoque_saldos ON public.estoque_saldos;
CREATE POLICY select_estoque_saldos ON public.estoque_saldos FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS select_estoque_transferencias ON public.estoque_transferencias;
CREATE POLICY select_estoque_transferencias ON public.estoque_transferencias FOR SELECT TO authenticated USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.estoques FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.estoque_saldos FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.estoque_transferencias FROM authenticated, anon;
GRANT SELECT ON public.estoques TO authenticated;
GRANT SELECT ON public.estoque_saldos TO authenticated;
GRANT SELECT ON public.estoque_transferencias TO authenticated;

-- ---------------------------------------------------------------------
-- 3. VIEWS DE LEITURA (com nomes já resolvidos, para a tela)
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW public.estoque_saldos_detalhado
WITH (security_invoker = true) AS
SELECT
    es.id,
    es.estoque_id,
    e.nome AS estoque_nome,
    es.produto_id,
    p.codigo AS produto_codigo,
    p.nome AS produto_nome,
    p.unidade AS produto_unidade,
    es.sabor_id,
    ps.sabor AS sabor_nome,
    es.quantidade,
    es.updated_at
FROM public.estoque_saldos es
JOIN public.estoques e ON e.id = es.estoque_id
JOIN public.produtos p ON p.id = es.produto_id
LEFT JOIN public.produto_sabores ps ON ps.id = es.sabor_id
WHERE es.quantidade > 0;

GRANT SELECT ON public.estoque_saldos_detalhado TO authenticated;
COMMENT ON VIEW public.estoque_saldos_detalhado IS 'Saldos de estoque reserva com nomes já resolvidos, só linhas com quantidade > 0. security_invoker=true respeita a RLS das tabelas de origem.';

CREATE OR REPLACE VIEW public.estoque_transferencias_detalhado
WITH (security_invoker = true) AS
SELECT
    t.id,
    t.tipo,
    t.produto_id,
    p.codigo AS produto_codigo,
    p.nome AS produto_nome,
    t.sabor_id,
    ps.sabor AS sabor_nome,
    t.estoque_origem_id,
    eo.nome AS estoque_origem_nome,
    t.estoque_destino_id,
    ed.nome AS estoque_destino_nome,
    t.quantidade,
    t.saldo_origem_anterior,
    t.saldo_origem_novo,
    t.saldo_destino_anterior,
    t.saldo_destino_novo,
    t.usuario_id,
    u.full_name AS usuario_nome,
    t.observacao,
    t.created_at
FROM public.estoque_transferencias t
JOIN public.produtos p ON p.id = t.produto_id
LEFT JOIN public.produto_sabores ps ON ps.id = t.sabor_id
LEFT JOIN public.estoques eo ON eo.id = t.estoque_origem_id
LEFT JOIN public.estoques ed ON ed.id = t.estoque_destino_id
LEFT JOIN public.users u ON u.id = t.usuario_id
ORDER BY t.created_at DESC;

GRANT SELECT ON public.estoque_transferencias_detalhado TO authenticated;
COMMENT ON VIEW public.estoque_transferencias_detalhado IS 'Histórico de transferências com nomes já resolvidos, mais recente primeiro.';

-- ---------------------------------------------------------------------
-- 4. FUNÇÕES DE GESTÃO DOS ESTOQUES (criar / ativar / desativar)
--    Restrito a ADMIN, mesmo padrão de pages/ajuste-estoque.html.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.criar_estoque_reserva(
    p_nome varchar,
    p_descricao text DEFAULT NULL
)
RETURNS TABLE(sucesso boolean, mensagem text, estoque_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_nome varchar(100);
    v_estoque_id uuid;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuário não autenticado'::text, NULL::uuid;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    -- IS DISTINCT FROM (não <>): se o usuário não existir mais em public.users,
    -- v_usuario_role vem NULL, e "NULL <> 'ADMIN'" é NULL (nem true nem false em
    -- SQL), o que faria o IF ser pulado e liberaria a ação por engano.
    IF v_usuario_role IS DISTINCT FROM 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem criar estoques'::text, NULL::uuid;
        RETURN;
    END IF;

    v_nome := TRIM(COALESCE(p_nome, ''));

    IF v_nome = '' THEN
        RETURN QUERY SELECT false, 'Informe um nome para o estoque'::text, NULL::uuid;
        RETURN;
    END IF;

    IF EXISTS (SELECT 1 FROM public.estoques WHERE LOWER(nome) = LOWER(v_nome)) THEN
        RETURN QUERY SELECT false, ('Já existe um estoque chamado "' || v_nome || '"')::text, NULL::uuid;
        RETURN;
    END IF;

    BEGIN
        INSERT INTO public.estoques (nome, descricao, created_by)
        VALUES (v_nome, NULLIF(TRIM(COALESCE(p_descricao, '')), ''), v_usuario_id)
        RETURNING id INTO v_estoque_id;
    EXCEPTION WHEN unique_violation THEN
        RETURN QUERY SELECT false, ('Já existe um estoque chamado "' || v_nome || '"')::text, NULL::uuid;
        RETURN;
    END;

    RETURN QUERY SELECT true, 'Estoque criado com sucesso'::text, v_estoque_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.atualizar_estoque_reserva_status(
    p_estoque_id uuid,
    p_ativo boolean
)
RETURNS TABLE(sucesso boolean, mensagem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_estoque record;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuário não autenticado'::text;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    IF v_usuario_role IS DISTINCT FROM 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem alterar estoques'::text;
        RETURN;
    END IF;

    SELECT * INTO v_estoque FROM public.estoques WHERE id = p_estoque_id;

    IF v_estoque.id IS NULL THEN
        RETURN QUERY SELECT false, 'Estoque não encontrado'::text;
        RETURN;
    END IF;

    -- Desativar só impede NOVAS transferências para lá (mover_estoque_para_reserva
    -- exige destino ativo). Um estoque desativado que ainda tenha saldo continua
    -- podendo ser devolvido normalmente por retornar_estoque_reserva — assim
    -- nenhum saldo fica "preso" mesmo que alguém desative por engano.
    UPDATE public.estoques
       SET ativo = p_ativo,
           updated_at = now()
     WHERE id = p_estoque_id;

    RETURN QUERY SELECT true,
        CASE WHEN p_ativo THEN 'Estoque reativado' ELSE 'Estoque desativado' END::text;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.criar_estoque_reserva(varchar, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.atualizar_estoque_reserva_status(uuid, boolean) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 5. mover_estoque_para_reserva() — Principal -> Reserva
-- ---------------------------------------------------------------------
-- IMPORTANTE (ler antes de rodar reprocessar_estoque_completo/produto ou
-- reconstruir_historico_produto em produção, se algum dia precisar):
--
-- 1) reprocessar_estoque_completo() e reprocessar_estoque_produto()
--    APAGAM estoque_movimentacoes e recalculam o saldo olhando só para
--    pedidos FINALIZADOS. Elas não sabem nada sobre estoque_saldos.
--    Se houver quantidade em algum estoque reserva quando essas funções
--    forem rodadas, o saldo do principal recalculado vai "esquecer" que
--    parte do estoque foi transferida, e a mercadoria vai parecer
--    disponível em dois lugares ao mesmo tempo (no principal recalculado
--    E no estoque reserva). ESSA LIMITAÇÃO JÁ EXISTE HOJE para qualquer
--    ajuste manual sem pedido (ex: Ajuste de Estoque) — não é algo novo
--    introduzido por este arquivo, mas passa a valer também para
--    transferências. Procedimento seguro: antes de rodar qualquer uma
--    dessas duas funções, devolva todo o saldo reservado ao principal
--    (retornar_estoque_reserva) e só então reprocesse; mova de volta
--    para a reserva depois, se precisar.
-- 2) reconstruir_historico_produto() NÃO altera saldo nenhum (só reescreve
--    o histórico exibido em "Histórico do produto"), então não corrompe
--    quantidade — mas como ela preserva apenas linhas tipo='AJUSTE' sem
--    pedido, os registros de transferência (tipo ENTRADA/SAIDA) somem
--    dessa tela específica após rodá-la. O saldo real e a tabela
--    estoque_transferencias (fonte de verdade da transferência) não são
--    afetados.
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.mover_estoque_para_reserva(
    p_produto_id uuid,
    p_estoque_destino_id uuid,
    p_quantidade numeric,
    p_sabor_id uuid DEFAULT NULL,
    p_observacao text DEFAULT NULL
)
RETURNS TABLE(
    sucesso boolean,
    mensagem text,
    transferencia_id uuid,
    saldo_principal_anterior numeric,
    saldo_principal_novo numeric,
    saldo_reserva_anterior numeric,
    saldo_reserva_novo numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_produto record;
    v_sabor record;
    v_tem_sabores boolean;
    v_estoque_destino record;
    v_saldo_anterior numeric;
    v_saldo_novo numeric;
    v_saldo_reserva_anterior numeric;
    v_saldo_reserva_novo numeric;
    v_saldo_id uuid;
    v_movimentacao_id uuid;
    v_transferencia_id uuid;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuário não autenticado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    IF v_usuario_role IS DISTINCT FROM 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem movimentar estoque para reserva'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RETURN QUERY SELECT false, 'A quantidade a mover deve ser maior que zero'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT id, codigo, nome, unidade INTO v_produto FROM public.produtos WHERE id = p_produto_id;

    IF v_produto.id IS NULL THEN
        RETURN QUERY SELECT false, 'Produto não encontrado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT * INTO v_estoque_destino FROM public.estoques WHERE id = p_estoque_destino_id;

    IF v_estoque_destino.id IS NULL THEN
        RETURN QUERY SELECT false, 'Estoque de destino não encontrado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    IF NOT v_estoque_destino.ativo THEN
        RETURN QUERY SELECT false, ('Estoque "' || v_estoque_destino.nome || '" está inativo e não pode receber transferências')::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.produto_sabores WHERE produto_id = p_produto_id AND ativo = true
    ) INTO v_tem_sabores;

    IF p_sabor_id IS NULL AND v_tem_sabores THEN
        RETURN QUERY SELECT false, 'Este produto possui sabores cadastrados; selecione o sabor a movimentar'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    -- Trava a linha do PRINCIPAL primeiro (mesma ordem em mover/retornar,
    -- para nunca haver deadlock entre as duas funções rodando ao mesmo tempo
    -- para o mesmo produto/sabor).
    IF p_sabor_id IS NOT NULL THEN
        SELECT id, sabor, quantidade INTO v_sabor
          FROM public.produto_sabores
         WHERE id = p_sabor_id AND produto_id = p_produto_id AND ativo = true
         FOR UPDATE;

        IF v_sabor.id IS NULL THEN
            RETURN QUERY SELECT false, 'Sabor não encontrado para este produto'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
            RETURN;
        END IF;

        v_saldo_anterior := COALESCE(v_sabor.quantidade, 0);
    ELSE
        SELECT estoque_atual INTO v_saldo_anterior
          FROM public.produtos WHERE id = p_produto_id
          FOR UPDATE;

        v_saldo_anterior := COALESCE(v_saldo_anterior, 0);
    END IF;

    -- COALESCE acima é o que garante que esta comparação nunca vire NULL
    -- (o que faria o IF ser silenciosamente pulado e liberar a transferência
    -- mesmo sem saldo real).
    IF v_saldo_anterior < p_quantidade THEN
        RETURN QUERY SELECT false,
            ('Estoque insuficiente. Disponível: ' || v_saldo_anterior || ', solicitado: ' || p_quantidade)::text,
            NULL::uuid, v_saldo_anterior, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    BEGIN
        v_saldo_novo := v_saldo_anterior - p_quantidade;

        IF p_sabor_id IS NOT NULL THEN
            UPDATE public.produto_sabores
               SET quantidade = quantidade - p_quantidade,
                   updated_at = now()
             WHERE id = p_sabor_id;
        ELSE
            UPDATE public.produtos
               SET estoque_atual = estoque_atual - p_quantidade
             WHERE id = p_produto_id;
        END IF;

        INSERT INTO public.estoque_movimentacoes (
            produto_id, sabor_id, tipo, quantidade,
            estoque_anterior, estoque_novo, usuario_id, observacao
        ) VALUES (
            p_produto_id, p_sabor_id, 'SAIDA', p_quantidade,
            v_saldo_anterior, v_saldo_novo, v_usuario_id,
            'Transferência para estoque reserva "' || v_estoque_destino.nome || '". ' || COALESCE(p_observacao, '')
        ) RETURNING id INTO v_movimentacao_id;

        -- Garante que a linha de saldo exista (0 se for a primeira vez),
        -- trava ela e só então soma — evita condição de corrida na criação.
        INSERT INTO public.estoque_saldos (estoque_id, produto_id, sabor_id, quantidade)
        VALUES (p_estoque_destino_id, p_produto_id, p_sabor_id, 0)
        ON CONFLICT (estoque_id, produto_id, (COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)))
        DO NOTHING;

        SELECT id, quantidade INTO v_saldo_id, v_saldo_reserva_anterior
          FROM public.estoque_saldos
         WHERE estoque_id = p_estoque_destino_id
           AND produto_id = p_produto_id
           AND COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(p_sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)
         FOR UPDATE;

        UPDATE public.estoque_saldos
           SET quantidade = quantidade + p_quantidade,
               updated_at = now()
         WHERE id = v_saldo_id
        RETURNING quantidade INTO v_saldo_reserva_novo;

        INSERT INTO public.estoque_transferencias (
            produto_id, sabor_id, estoque_origem_id, estoque_destino_id, tipo, quantidade,
            saldo_origem_anterior, saldo_origem_novo, saldo_destino_anterior, saldo_destino_novo,
            movimentacao_id, usuario_id, observacao
        ) VALUES (
            p_produto_id, p_sabor_id, NULL, p_estoque_destino_id, 'ENVIO', p_quantidade,
            v_saldo_anterior, v_saldo_novo, v_saldo_reserva_anterior, v_saldo_reserva_novo,
            v_movimentacao_id, v_usuario_id, NULLIF(TRIM(COALESCE(p_observacao, '')), '')
        ) RETURNING id INTO v_transferencia_id;

        RETURN QUERY SELECT true,
            ('Movido ' || p_quantidade || ' ' || v_produto.unidade || ' para o estoque "' || v_estoque_destino.nome || '"')::text,
            v_transferencia_id, v_saldo_anterior, v_saldo_novo, v_saldo_reserva_anterior, v_saldo_reserva_novo;

    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT false, ('Erro ao mover estoque: ' || SQLERRM)::text, NULL::uuid, v_saldo_anterior, NULL::numeric, NULL::numeric, NULL::numeric;
    END;
END;
$function$;

-- ---------------------------------------------------------------------
-- 6. retornar_estoque_reserva() — Reserva -> Principal
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.retornar_estoque_reserva(
    p_produto_id uuid,
    p_estoque_origem_id uuid,
    p_quantidade numeric,
    p_sabor_id uuid DEFAULT NULL,
    p_observacao text DEFAULT NULL
)
RETURNS TABLE(
    sucesso boolean,
    mensagem text,
    transferencia_id uuid,
    saldo_principal_anterior numeric,
    saldo_principal_novo numeric,
    saldo_reserva_anterior numeric,
    saldo_reserva_novo numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_produto record;
    v_sabor record;
    v_tem_sabores boolean;
    v_estoque_origem record;
    v_saldo_anterior numeric;
    v_saldo_novo numeric;
    v_saldo_reserva_anterior numeric;
    v_saldo_reserva_novo numeric;
    v_saldo_id uuid;
    v_movimentacao_id uuid;
    v_transferencia_id uuid;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuário não autenticado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    IF v_usuario_role IS DISTINCT FROM 'ADMIN' THEN
        RETURN QUERY SELECT false, 'Somente administradores podem retornar estoque da reserva'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    IF p_quantidade IS NULL OR p_quantidade <= 0 THEN
        RETURN QUERY SELECT false, 'A quantidade a retornar deve ser maior que zero'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT id, codigo, nome, unidade INTO v_produto FROM public.produtos WHERE id = p_produto_id;

    IF v_produto.id IS NULL THEN
        RETURN QUERY SELECT false, 'Produto não encontrado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    -- Propositalmente não exige estoque_origem.ativo = true: um estoque
    -- desativado ainda pode devolver o saldo que restou nele (ver
    -- atualizar_estoque_reserva_status).
    SELECT * INTO v_estoque_origem FROM public.estoques WHERE id = p_estoque_origem_id;

    IF v_estoque_origem.id IS NULL THEN
        RETURN QUERY SELECT false, 'Estoque de origem não encontrado'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    SELECT EXISTS(
        SELECT 1 FROM public.produto_sabores WHERE produto_id = p_produto_id AND ativo = true
    ) INTO v_tem_sabores;

    IF p_sabor_id IS NULL AND v_tem_sabores THEN
        RETURN QUERY SELECT false, 'Este produto possui sabores cadastrados; selecione o sabor a retornar'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
        RETURN;
    END IF;

    -- Mesma ordem de travamento de mover_estoque_para_reserva: PRINCIPAL
    -- primeiro, depois estoque_saldos — mesmo aqui sendo o saldo que
    -- efetivamente valida a operação. Isso é o que garante que as duas
    -- funções nunca causem deadlock uma com a outra.
    IF p_sabor_id IS NOT NULL THEN
        SELECT id, sabor, quantidade INTO v_sabor
          FROM public.produto_sabores
         WHERE id = p_sabor_id AND produto_id = p_produto_id AND ativo = true
         FOR UPDATE;

        IF v_sabor.id IS NULL THEN
            RETURN QUERY SELECT false, 'Sabor não encontrado para este produto'::text, NULL::uuid, NULL::numeric, NULL::numeric, NULL::numeric, NULL::numeric;
            RETURN;
        END IF;

        v_saldo_anterior := COALESCE(v_sabor.quantidade, 0);
    ELSE
        SELECT estoque_atual INTO v_saldo_anterior
          FROM public.produtos WHERE id = p_produto_id
          FOR UPDATE;

        v_saldo_anterior := COALESCE(v_saldo_anterior, 0);
    END IF;

    SELECT id, quantidade INTO v_saldo_id, v_saldo_reserva_anterior
      FROM public.estoque_saldos
     WHERE estoque_id = p_estoque_origem_id
       AND produto_id = p_produto_id
       AND COALESCE(sabor_id, '00000000-0000-0000-0000-000000000000'::uuid) = COALESCE(p_sabor_id, '00000000-0000-0000-0000-000000000000'::uuid)
     FOR UPDATE;

    IF v_saldo_id IS NULL OR v_saldo_reserva_anterior <= 0 THEN
        RETURN QUERY SELECT false,
            ('Não há saldo no estoque "' || v_estoque_origem.nome || '" para este produto/sabor')::text,
            NULL::uuid, v_saldo_anterior, NULL::numeric, COALESCE(v_saldo_reserva_anterior, 0), NULL::numeric;
        RETURN;
    END IF;

    IF v_saldo_reserva_anterior < p_quantidade THEN
        RETURN QUERY SELECT false,
            ('Quantidade maior que o saldo disponível na reserva. Disponível: ' || v_saldo_reserva_anterior || ', solicitado: ' || p_quantidade)::text,
            NULL::uuid, v_saldo_anterior, NULL::numeric, v_saldo_reserva_anterior, NULL::numeric;
        RETURN;
    END IF;

    BEGIN
        v_saldo_novo := v_saldo_anterior + p_quantidade;

        IF p_sabor_id IS NOT NULL THEN
            UPDATE public.produto_sabores
               SET quantidade = quantidade + p_quantidade,
                   updated_at = now()
             WHERE id = p_sabor_id;
        ELSE
            UPDATE public.produtos
               SET estoque_atual = estoque_atual + p_quantidade
             WHERE id = p_produto_id;
        END IF;

        UPDATE public.estoque_saldos
           SET quantidade = quantidade - p_quantidade,
               updated_at = now()
         WHERE id = v_saldo_id
        RETURNING quantidade INTO v_saldo_reserva_novo;

        INSERT INTO public.estoque_movimentacoes (
            produto_id, sabor_id, tipo, quantidade,
            estoque_anterior, estoque_novo, usuario_id, observacao
        ) VALUES (
            p_produto_id, p_sabor_id, 'ENTRADA', p_quantidade,
            v_saldo_anterior, v_saldo_novo, v_usuario_id,
            'Retorno do estoque reserva "' || v_estoque_origem.nome || '". ' || COALESCE(p_observacao, '')
        ) RETURNING id INTO v_movimentacao_id;

        INSERT INTO public.estoque_transferencias (
            produto_id, sabor_id, estoque_origem_id, estoque_destino_id, tipo, quantidade,
            saldo_origem_anterior, saldo_origem_novo, saldo_destino_anterior, saldo_destino_novo,
            movimentacao_id, usuario_id, observacao
        ) VALUES (
            p_produto_id, p_sabor_id, p_estoque_origem_id, NULL, 'RETORNO', p_quantidade,
            v_saldo_reserva_anterior, v_saldo_reserva_novo, v_saldo_anterior, v_saldo_novo,
            v_movimentacao_id, v_usuario_id, NULLIF(TRIM(COALESCE(p_observacao, '')), '')
        ) RETURNING id INTO v_transferencia_id;

        RETURN QUERY SELECT true,
            ('Retornado ' || p_quantidade || ' ' || v_produto.unidade || ' do estoque "' || v_estoque_origem.nome || '" para o principal')::text,
            v_transferencia_id, v_saldo_anterior, v_saldo_novo, v_saldo_reserva_anterior, v_saldo_reserva_novo;

    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT false, ('Erro ao retornar estoque: ' || SQLERRM)::text, NULL::uuid, v_saldo_anterior, NULL::numeric, v_saldo_reserva_anterior, NULL::numeric;
    END;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.mover_estoque_para_reserva(uuid, uuid, numeric, uuid, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.retornar_estoque_reserva(uuid, uuid, numeric, uuid, text) TO authenticated, service_role;

-- ---------------------------------------------------------------------
-- 7. FECHA UMA BRECHA EM remover_sabor_produto()
-- ---------------------------------------------------------------------
-- remover_sabor_produto() já bloqueava remover um sabor com
-- produto_sabores.quantidade > 0 (estoque principal). Mas com estoque
-- reserva, um sabor pode estar com quantidade = 0 no principal e ainda
-- assim ter unidades guardadas em algum estoque reserva (porque foram
-- movidas para lá). Sem este ajuste, seria possível desativar esse sabor
-- e o saldo em reserva ficaria "preso": retornar_estoque_reserva exige
-- que o sabor esteja ativo, então a devolução passaria a falhar e a
-- mercadoria nunca mais voltaria a aparecer em lugar nenhum do sistema.
-- Esta função é recriada só para adicionar essa verificação extra —
-- todo o resto do comportamento original é mantido.
CREATE OR REPLACE FUNCTION public.remover_sabor_produto(
    p_sabor_id uuid,
    p_produto_id uuid
)
RETURNS TABLE(sucesso boolean, mensagem text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_ativo boolean;
    v_sabor_id uuid;
    v_quantidade numeric(10, 2);
    v_quantidade_reserva numeric(10, 2);
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text;
        RETURN;
    END IF;

    SELECT active
      INTO v_usuario_ativo
      FROM public.users
     WHERE id = v_usuario_id
     LIMIT 1;

    IF COALESCE(v_usuario_ativo, false) = false THEN
        RETURN QUERY SELECT false, 'Usuario sem permissao para remover sabores'::text;
        RETURN;
    END IF;

    SELECT id, COALESCE(quantidade, 0)
      INTO v_sabor_id, v_quantidade
      FROM public.produto_sabores
     WHERE id = p_sabor_id
       AND produto_id = p_produto_id
       AND ativo = true
     LIMIT 1;

    IF v_sabor_id IS NULL THEN
        RETURN QUERY SELECT false, 'Sabor nao encontrado ou ja removido'::text;
        RETURN;
    END IF;

    IF v_quantidade > 0 THEN
        RETURN QUERY SELECT false, 'Nao e possivel remover um sabor com estoque maior que zero'::text;
        RETURN;
    END IF;

    SELECT COALESCE(SUM(quantidade), 0) INTO v_quantidade_reserva
      FROM public.estoque_saldos
     WHERE sabor_id = p_sabor_id;

    IF v_quantidade_reserva > 0 THEN
        RETURN QUERY SELECT false,
            ('Nao e possivel remover: ha ' || v_quantidade_reserva || ' unidade(s) deste sabor em estoque reserva. Devolva ao principal antes de remover.')::text;
        RETURN;
    END IF;

    UPDATE public.produto_sabores
       SET ativo = false,
           updated_at = now()
     WHERE id = p_sabor_id;

    RETURN QUERY SELECT true, 'Sabor removido com sucesso'::text;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.remover_sabor_produto(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remover_sabor_produto(uuid, uuid) TO service_role;

-- =====================================================================
-- FIM DA MIGRAÇÃO
-- =====================================================================
