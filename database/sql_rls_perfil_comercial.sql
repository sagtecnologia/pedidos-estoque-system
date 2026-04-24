-- Corrige o acesso do perfil COMERCIAL nas consultas do sistema.
-- Aplique este SQL no Supabase SQL Editor.
--
-- Diagnóstico:
-- Se ADMIN enxerga pedidos/vendas e COMERCIAL recebe lista vazia,
-- o problema está nas regras de acesso do banco (RLS/policies),
-- não no filtro do frontend.

CREATE OR REPLACE FUNCTION public.current_app_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT u.role
    FROM public.users u
    WHERE u.id = auth.uid()
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.current_app_user_role() IS
'Retorna o papel do usuário autenticado na tabela public.users. Usada para policies do app.';

GRANT EXECUTE ON FUNCTION public.current_app_user_role() TO authenticated;

DROP POLICY IF EXISTS comercial_select_users ON public.users;
CREATE POLICY comercial_select_users
ON public.users
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_clientes ON public.clientes;
CREATE POLICY comercial_select_clientes
ON public.clientes
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_fornecedores ON public.fornecedores;
CREATE POLICY comercial_select_fornecedores
ON public.fornecedores
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_produtos ON public.produtos;
CREATE POLICY comercial_select_produtos
ON public.produtos
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_produto_sabores ON public.produto_sabores;
CREATE POLICY comercial_select_produto_sabores
ON public.produto_sabores
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_pedidos ON public.pedidos;
CREATE POLICY comercial_select_pedidos
ON public.pedidos
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_insert_pedidos ON public.pedidos;
CREATE POLICY comercial_insert_pedidos
ON public.pedidos
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
    AND solicitante_id = auth.uid()
    AND tipo_pedido IN ('COMPRA', 'VENDA')
);

DROP POLICY IF EXISTS comercial_update_pedidos ON public.pedidos;
CREATE POLICY comercial_update_pedidos
ON public.pedidos
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() = 'COMERCIAL'
    AND solicitante_id = auth.uid()
)
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
    AND solicitante_id = auth.uid()
);

DROP POLICY IF EXISTS comercial_delete_pedidos ON public.pedidos;
CREATE POLICY comercial_delete_pedidos
ON public.pedidos
FOR DELETE
TO authenticated
USING (
    public.current_app_user_role() = 'COMERCIAL'
    AND solicitante_id = auth.uid()
    AND status = 'RASCUNHO'
);

DROP POLICY IF EXISTS comercial_select_pedido_itens ON public.pedido_itens;
CREATE POLICY comercial_select_pedido_itens
ON public.pedido_itens
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_insert_pedido_itens ON public.pedido_itens;
CREATE POLICY comercial_insert_pedido_itens
ON public.pedido_itens
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.solicitante_id = auth.uid()
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS comercial_update_pedido_itens ON public.pedido_itens;
CREATE POLICY comercial_update_pedido_itens
ON public.pedido_itens
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() = 'COMERCIAL'
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.solicitante_id = auth.uid()
          AND p.status = 'RASCUNHO'
    )
)
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.solicitante_id = auth.uid()
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS comercial_delete_pedido_itens ON public.pedido_itens;
CREATE POLICY comercial_delete_pedido_itens
ON public.pedido_itens
FOR DELETE
TO authenticated
USING (
    public.current_app_user_role() = 'COMERCIAL'
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.solicitante_id = auth.uid()
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS comercial_select_pagamentos ON public.pagamentos;
CREATE POLICY comercial_select_pagamentos
ON public.pagamentos
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_insert_pagamentos ON public.pagamentos;
CREATE POLICY comercial_insert_pagamentos
ON public.pagamentos
FOR INSERT
TO authenticated
WITH CHECK (public.current_app_user_role() = 'COMERCIAL');

DROP POLICY IF EXISTS comercial_select_pre_pedidos ON public.pre_pedidos;
CREATE POLICY comercial_select_pre_pedidos
ON public.pre_pedidos
FOR SELECT
TO authenticated
USING (public.current_app_user_role() = 'COMERCIAL');
