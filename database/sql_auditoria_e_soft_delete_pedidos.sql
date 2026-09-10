-- =====================================================================
-- AUDITORIA GERAL + EXCLUSAO LOGICA (SOFT DELETE) DE PEDIDOS
-- =====================================================================
-- Motivacao: uma venda em RASCUNHO foi excluida fisicamente do banco
-- (via deletePedido()), o que (a) apagou o historico sem deixar rastro
-- de quem fez e quando, e (b) liberou o numero sequencial da venda
-- para ser reaproveitado por um pedido totalmente diferente, causando
-- confusao entre pedidos de clientes diferentes com o mesmo numero.
--
-- Esta migracao:
--   1. Cria uma tabela de auditoria genérica (audit_log), que registra
--      INSERT/UPDATE/DELETE em pedidos, pedido_itens e pre_pedidos —
--      nao so exclusoes.
--   2. Adiciona colunas de exclusao logica (deleted_at/deleted_by) em
--      "pedidos".
--   3. Cria a função excluir_pedido_soft(), que substitui o DELETE
--      fisico por um UPDATE marcando o pedido como excluído, mantendo
--      o registro (e o número) para sempre. O perfil COMERCIAL deixa
--      de poder excluir qualquer pedido (nem os que ele mesmo criou):
--      só ADMIN e o próprio solicitante (que não seja a conta
--      COMERCIAL) podem excluir.
--   4. Bloqueia em definitivo, via trigger, qualquer tentativa de
--      DELETE físico na tabela "pedidos" (mesmo que alguém tente via
--      SQL direto ou um bug futuro no frontend).
--   5. Cria uma view "pedidos_excluidos" para listar o que foi
--      excluído, e uma policy dando ao ADMIN acesso de leitura à
--      audit_log completa.
--
-- Execute este arquivo inteiro no SQL Editor do Supabase.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. TABELA DE AUDITORIA GENÉRICA
-- ---------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.audit_log (
    id uuid DEFAULT uuid_generate_v4() NOT NULL,
    tabela varchar(50) NOT NULL,
    registro_id uuid NULL,
    acao varchar(20) NOT NULL,
    dados_anteriores jsonb NULL,
    dados_novos jsonb NULL,
    usuario_id uuid NULL,
    usuario_nome varchar(255) NULL,
    usuario_role varchar(20) NULL,
    created_at timestamptz DEFAULT now() NOT NULL,
    CONSTRAINT audit_log_pkey PRIMARY KEY (id),
    CONSTRAINT audit_log_acao_check CHECK ((acao)::text = ANY (ARRAY['INSERT','UPDATE','DELETE']::text[]))
);

CREATE INDEX IF NOT EXISTS idx_audit_log_tabela_registro ON public.audit_log (tabela, registro_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_created_at ON public.audit_log (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_usuario ON public.audit_log (usuario_id);

COMMENT ON TABLE public.audit_log IS
'Auditoria genérica de INSERT/UPDATE/DELETE nas tabelas de pedidos. Alimentada automaticamente por triggers, nunca deve ser escrita manualmente pela aplicação.';

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- Só ADMIN pode ler a auditoria. Ninguém (nem ADMIN) pode alterar/apagar
-- pela API — a tabela só recebe INSERTs, feitos pelo trigger (SECURITY
-- DEFINER, portanto ignora RLS na escrita).
DROP POLICY IF EXISTS admin_select_audit_log ON public.audit_log;
CREATE POLICY admin_select_audit_log
ON public.audit_log
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'ADMIN');

REVOKE INSERT, UPDATE, DELETE ON public.audit_log FROM authenticated, anon;
GRANT SELECT ON public.audit_log TO authenticated;

-- ---------------------------------------------------------------------
-- 2. COLUNAS DE EXCLUSAO LOGICA EM "pedidos"
-- ---------------------------------------------------------------------
ALTER TABLE public.pedidos
    ADD COLUMN IF NOT EXISTS deleted_at timestamptz NULL,
    ADD COLUMN IF NOT EXISTS deleted_by uuid NULL;

DO $do$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'pedidos_deleted_by_fkey'
    ) THEN
        ALTER TABLE public.pedidos
            ADD CONSTRAINT pedidos_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES public.users(id);
    END IF;
END;
$do$;

CREATE INDEX IF NOT EXISTS idx_pedidos_deleted_at ON public.pedidos (deleted_at);

COMMENT ON COLUMN public.pedidos.deleted_at IS 'Quando preenchido, o pedido foi excluído logicamente (nunca é apagado fisicamente). Use excluir_pedido_soft() para excluir.';
COMMENT ON COLUMN public.pedidos.deleted_by IS 'Usuário que executou a exclusão lógica.';

-- ---------------------------------------------------------------------
-- 3. FUNÇÃO GENÉRICA DE AUDITORIA (usada pelos triggers abaixo)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.fn_audit_log_generico()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_nome varchar(255);
    v_usuario_role varchar(20);
    v_registro_id uuid;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NOT NULL THEN
        SELECT full_name, role
          INTO v_usuario_nome, v_usuario_role
          FROM public.users
         WHERE id = v_usuario_id;
    END IF;

    IF TG_OP = 'DELETE' THEN
        v_registro_id := OLD.id;
        INSERT INTO public.audit_log (tabela, registro_id, acao, dados_anteriores, usuario_id, usuario_nome, usuario_role)
        VALUES (TG_TABLE_NAME, v_registro_id, 'DELETE', to_jsonb(OLD), v_usuario_id, v_usuario_nome, v_usuario_role);
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        v_registro_id := NEW.id;
        INSERT INTO public.audit_log (tabela, registro_id, acao, dados_anteriores, dados_novos, usuario_id, usuario_nome, usuario_role)
        VALUES (TG_TABLE_NAME, v_registro_id, 'UPDATE', to_jsonb(OLD), to_jsonb(NEW), v_usuario_id, v_usuario_nome, v_usuario_role);
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        v_registro_id := NEW.id;
        INSERT INTO public.audit_log (tabela, registro_id, acao, dados_novos, usuario_id, usuario_nome, usuario_role)
        VALUES (TG_TABLE_NAME, v_registro_id, 'INSERT', to_jsonb(NEW), v_usuario_id, v_usuario_nome, v_usuario_role);
        RETURN NEW;
    END IF;

    RETURN NULL;
END;
$function$;

-- Aplica a auditoria nas tabelas do ciclo de vida de pedidos.
-- Cobre criação, edição (inclusive status/cliente/total) e exclusão de
-- itens — não só a exclusão do pedido em si.
DROP TRIGGER IF EXISTS trigger_audit_pedidos ON public.pedidos;
CREATE TRIGGER trigger_audit_pedidos
AFTER INSERT OR UPDATE OR DELETE ON public.pedidos
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

DROP TRIGGER IF EXISTS trigger_audit_pedido_itens ON public.pedido_itens;
CREATE TRIGGER trigger_audit_pedido_itens
AFTER INSERT OR UPDATE OR DELETE ON public.pedido_itens
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

DROP TRIGGER IF EXISTS trigger_audit_pre_pedidos ON public.pre_pedidos;
CREATE TRIGGER trigger_audit_pre_pedidos
AFTER INSERT OR UPDATE OR DELETE ON public.pre_pedidos
FOR EACH ROW EXECUTE FUNCTION public.fn_audit_log_generico();

-- ---------------------------------------------------------------------
-- 4. BLOQUEIO PERMANENTE DE EXCLUSÃO FÍSICA EM "pedidos"
-- ---------------------------------------------------------------------
-- A partir de agora, NENHUM DELETE físico é permitido em "pedidos",
-- nem pela aplicação, nem por SQL manual, nem por um bug futuro.
-- A única forma de "excluir" um pedido é a exclusão lógica, via
-- excluir_pedido_soft() (ou diretamente via UPDATE ... SET deleted_at).
CREATE OR REPLACE FUNCTION public.fn_bloquear_exclusao_fisica_pedidos()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    RAISE EXCEPTION 'Exclusão física de pedidos não é permitida. Use excluir_pedido_soft() para manter o histórico e a auditoria.';
END;
$function$;

DROP TRIGGER IF EXISTS trigger_bloquear_exclusao_pedidos ON public.pedidos;
CREATE TRIGGER trigger_bloquear_exclusao_pedidos
BEFORE DELETE ON public.pedidos
FOR EACH ROW EXECUTE FUNCTION public.fn_bloquear_exclusao_fisica_pedidos();

-- ---------------------------------------------------------------------
-- 5. FUNÇÃO DE EXCLUSÃO LÓGICA (substitui o DELETE físico)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.excluir_pedido_soft(p_pedido_id uuid)
RETURNS TABLE(sucesso boolean, mensagem text, numero text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_role text;
    v_pedido record;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuário não autenticado'::text, NULL::text;
        RETURN;
    END IF;

    SELECT role INTO v_usuario_role FROM public.users WHERE id = v_usuario_id;

    SELECT * INTO v_pedido FROM public.pedidos WHERE id = p_pedido_id FOR UPDATE;

    IF v_pedido.id IS NULL THEN
        RETURN QUERY SELECT false, 'Pedido não encontrado'::text, NULL::text;
        RETURN;
    END IF;

    IF v_pedido.deleted_at IS NOT NULL THEN
        RETURN QUERY SELECT false, 'Este pedido já havia sido excluído anteriormente'::text, v_pedido.numero;
        RETURN;
    END IF;

    IF v_pedido.status <> 'RASCUNHO' THEN
        RETURN QUERY SELECT false, 'Apenas pedidos em RASCUNHO podem ser excluídos'::text, v_pedido.numero;
        RETURN;
    END IF;

    -- Regra de permissão: ADMIN pode excluir qualquer rascunho; o
    -- próprio solicitante pode excluir os rascunhos que ele criou.
    -- O perfil COMERCIAL NÃO pode mais excluir nenhum pedido (nem os
    -- que ele mesmo criou) — foi essa permissão ampla, combinada com
    -- o login compartilhado da conta COMERCIAL, que causou o incidente
    -- que motivou esta migração (exclusão de rascunho reaproveitando o
    -- número do pedido para outro cliente).
    IF v_usuario_role = 'COMERCIAL' THEN
        RETURN QUERY SELECT false, 'O perfil COMERCIAL não tem permissão para excluir pedidos. Peça para um ADMIN excluir, se necessário.'::text, v_pedido.numero;
        RETURN;
    END IF;

    IF NOT (
        v_usuario_role = 'ADMIN'
        OR v_pedido.solicitante_id = v_usuario_id
    ) THEN
        RETURN QUERY SELECT false, 'Você não tem permissão para excluir este pedido'::text, v_pedido.numero;
        RETURN;
    END IF;

    UPDATE public.pedidos
       SET deleted_at = now(),
           deleted_by = v_usuario_id
     WHERE id = p_pedido_id;

    -- Se este pedido foi gerado a partir de um pré-pedido, devolve o
    -- pré-pedido para EM_ANALISE automaticamente — assim ele volta a
    -- aparecer na tela de Pré-Pedidos para ser reprocessado, sem exigir
    -- nenhum ajuste manual (como precisou ser feito manualmente no
    -- incidente que motivou esta migração).
    UPDATE public.pre_pedidos
       SET status = 'EM_ANALISE',
           analisado_por = NULL,
           data_analise = NULL,
           cliente_vinculado_id = NULL,
           pedido_gerado_id = NULL
     WHERE pedido_gerado_id = p_pedido_id;

    RETURN QUERY SELECT true, 'Pedido excluído com sucesso'::text, v_pedido.numero;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.excluir_pedido_soft(uuid) TO authenticated;

-- ---------------------------------------------------------------------
-- 6. VIEW DE PEDIDOS EXCLUÍDOS (para a tela "Pedidos Excluídos")
-- ---------------------------------------------------------------------
-- IMPORTANTE: security_invoker faz a view rodar com as permissões de
-- quem consulta (e respeitar as policies de RLS de "pedidos"), em vez
-- de rodar com o dono da view — sem isso, a view poderia vazar pedidos
-- excluídos de outras pessoas para qualquer usuário autenticado.
CREATE OR REPLACE VIEW public.pedidos_excluidos
WITH (security_invoker = true) AS
SELECT
    p.id,
    p.numero,
    p.tipo_pedido,
    p.status,
    p.total,
    p.cliente_id,
    p.fornecedor_id,
    p.solicitante_id,
    p.created_at,
    p.deleted_at,
    p.deleted_by,
    ub.full_name AS excluido_por_nome
FROM public.pedidos p
LEFT JOIN public.users ub ON ub.id = p.deleted_by
WHERE p.deleted_at IS NOT NULL;

GRANT SELECT ON public.pedidos_excluidos TO authenticated;

COMMENT ON VIEW public.pedidos_excluidos IS 'Pedidos excluídos logicamente (nunca removidos fisicamente). Roda com security_invoker=true para respeitar a RLS de "pedidos" de quem consulta.';

-- =====================================================================
-- FIM DA MIGRAÇÃO
-- =====================================================================
