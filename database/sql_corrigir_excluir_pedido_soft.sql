-- =====================================================================
-- CORRECAO: excluir_pedido_soft() quebrava ao excluir qualquer pedido
-- =====================================================================
-- Aplique no Supabase SQL Editor. Idempotente.
--
-- ERRO
--   "structure of query does not match function result type"
--   ao clicar em excluir um pedido/venda em RASCUNHO.
--
-- CAUSA
--   A funcao declara  RETURNS TABLE(..., numero text)
--   mas devolve       v_pedido.numero, que e varchar(50).
--   PL/pgSQL compara o descritor da tupla por tipo exato: varchar nao e
--   text, entao todo RETURN QUERY que usa v_pedido.numero estoura. Como
--   quatro dos cinco RETURN QUERY usam esse campo — inclusive o de
--   sucesso — a exclusao falhava sempre.
--
-- IMPACTO NO ESTOQUE: NENHUM
--   O erro ocorre no RETURN QUERY, depois do UPDATE, entao o Postgres
--   desfaz a transacao inteira: o pedido NAO chega a ser marcado como
--   excluido. Alem disso a funcao so aceita pedidos em RASCUNHO, que por
--   definicao nunca movimentaram estoque (estoque so se move em
--   finalizar_pedido). Conferido no banco: nenhum pedido com deleted_at,
--   nenhuma movimentacao orfa, nenhuma divergencia de saldo com
--   movimentacao do dia.
--
-- CORRECAO
--   Um cast ::text em cada retorno. Nenhuma mudanca de regra de negocio:
--   a permissao abaixo e exatamente a que ja esta em producao hoje.
--
-- ATENCAO — DIVERGENCIA QUE NAO FOI TOCADA AQUI
--   O arquivo database/sql_auditoria_e_soft_delete_pedidos.sql (commit
--   "auditoria") contem uma versao DIFERENTE desta funcao, que proibe o
--   perfil COMERCIAL de excluir qualquer pedido. Essa versao nunca chegou
--   a producao: o banco ainda permite COMERCIAL excluir rascunhos de
--   VENDA. Esta correcao preserva o comportamento ATUAL de producao de
--   proposito, para nao mudar regra de permissao junto com um bugfix.
--   Se a intencao era mesmo bloquear o COMERCIAL, avise: e trocar o
--   bloco IF NOT (...) por essa outra regra.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.excluir_pedido_soft(p_pedido_id uuid)
RETURNS TABLE(sucesso boolean, mensagem text, numero text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
    v_usuario_id   uuid;
    v_usuario_role text;
    v_pedido       record;
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
        RETURN QUERY SELECT false, 'Este pedido já havia sido excluído anteriormente'::text, v_pedido.numero::text;
        RETURN;
    END IF;

    IF v_pedido.status <> 'RASCUNHO' THEN
        RETURN QUERY SELECT false, 'Apenas pedidos em RASCUNHO podem ser excluídos'::text, v_pedido.numero::text;
        RETURN;
    END IF;

    -- Regra de permissão IDÊNTICA à que já está em produção:
    -- ADMIN exclui qualquer rascunho; COMERCIAL exclui rascunhos de VENDA;
    -- qualquer usuário exclui os próprios rascunhos.
    IF NOT (
        v_usuario_role = 'ADMIN'
        OR (v_usuario_role = 'COMERCIAL' AND v_pedido.tipo_pedido = 'VENDA')
        OR v_pedido.solicitante_id = v_usuario_id
    ) THEN
        RETURN QUERY SELECT false, 'Você não tem permissão para excluir este pedido'::text, v_pedido.numero::text;
        RETURN;
    END IF;

    UPDATE public.pedidos
       SET deleted_at = now(),
           deleted_by = v_usuario_id
     WHERE id = p_pedido_id;

    -- Se este pedido veio de um pré-pedido, devolve o pré-pedido para
    -- EM_ANALISE, para ele voltar a aparecer na tela de Pré-Pedidos.
    UPDATE public.pre_pedidos
       SET status               = 'EM_ANALISE',
           analisado_por        = NULL,
           data_analise         = NULL,
           cliente_vinculado_id = NULL,
           pedido_gerado_id     = NULL
     WHERE pedido_gerado_id = p_pedido_id;

    RETURN QUERY SELECT true, 'Pedido excluído com sucesso'::text, v_pedido.numero::text;
END;
$function$;

COMMENT ON FUNCTION public.excluir_pedido_soft(uuid) IS
'Exclusao logica de pedido em RASCUNHO. O campo numero e devolvido com cast ::text: sem ele o PL/pgSQL recusa varchar(50) onde a assinatura declara text.';


-- ---------------------------------------------------------------------
-- CONFERENCIA
-- ---------------------------------------------------------------------
-- Depois de aplicar, exclua um rascunho pela tela. Para auditar:
--
--   SELECT numero, status, deleted_at, deleted_by
--     FROM public.pedidos
--    WHERE deleted_at IS NOT NULL
--    ORDER BY deleted_at DESC;
--
-- O pedido continua na base (nunca e apagado fisicamente) e aparece na
-- tela Pedidos Excluidos.
