-- =====================================================================
-- PERFIL VENDEDOR: PERMISSAO PARA CRIAR VENDA
-- =====================================================================
-- Aplique no Supabase SQL Editor. Idempotente.
--
-- PROBLEMA
--   Ao clicar em "Criar Venda", o usuario VENDEDOR recebia
--   "Voce nao tem permissao para realizar esta acao".
--
-- DIAGNOSTICO
--   public.pedidos tem RLS ativa, e as unicas policies de INSERT eram:
--     - "COMPRADOR pode criar pedidos"  -> COMPRADOR e ADMIN
--     - "comercial_insert_pedidos"      -> COMERCIAL
--   O perfil VENDEDOR nao aparecia em nenhuma. Como ate agora nao existia
--   nenhum usuario VENDEDOR no banco (so ADMIN e COMERCIAL), a lacuna nunca
--   tinha sido exercitada.
--
--   Observe que o restante do fluxo JA contemplava VENDEDOR
--   (app_insert_itens_venda_rascunho, app_update_total_venda_rascunho,
--   "Vendedor pode atualizar seus pedidos em rascunho", pagamentos...).
--   Faltava apenas o cabecalho da venda.
--
-- ESCOPO DESTA CORRECAO
--   Da ao VENDEDOR o direito de criar APENAS pedidos de VENDA, e apenas
--   em seu proprio nome (solicitante_id = auth.uid()). Ele continua sem
--   poder criar pedidos de COMPRA.
-- =====================================================================

DROP POLICY IF EXISTS vendedor_insert_vendas ON public.pedidos;

CREATE POLICY vendedor_insert_vendas
ON public.pedidos
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() = 'VENDEDOR'
    AND solicitante_id = auth.uid()
    AND tipo_pedido = 'VENDA'
);

COMMENT ON POLICY vendedor_insert_vendas ON public.pedidos IS
'VENDEDOR pode abrir pedidos de VENDA em seu proprio nome. Nao permite criar pedidos de COMPRA.';


-- ---------------------------------------------------------------------
-- CONFERENCIA
-- ---------------------------------------------------------------------
-- Lista quem pode inserir em public.pedidos depois desta correcao:
--
--   SELECT polname, pg_get_expr(polwithcheck, polrelid) AS regra
--     FROM pg_policy
--    WHERE polrelid = 'public.pedidos'::regclass AND polcmd = 'a'
--    ORDER BY polname;
