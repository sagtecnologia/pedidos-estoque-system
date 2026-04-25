-- Permite edicao compartilhada de pedidos de COMPRA em RASCUNHO
-- para os perfis operacionais do fluxo de compra.
--
-- Objetivo:
-- 1. Permitir que ADMIN, COMPRADOR e COMERCIAL editem pedidos de compra
--    em RASCUNHO mesmo quando nao forem os solicitantes.
-- 2. Alinhar as permissoes do banco com a regra da interface.

DROP POLICY IF EXISTS app_select_itens_compra_permitida ON public.pedido_itens;
CREATE POLICY app_select_itens_compra_permitida
ON public.pedido_itens
FOR SELECT
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'COMPRA'
    )
);

DROP POLICY IF EXISTS app_insert_itens_compra_rascunho ON public.pedido_itens;
CREATE POLICY app_insert_itens_compra_rascunho
ON public.pedido_itens
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'COMPRA'
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS app_update_itens_compra_rascunho ON public.pedido_itens;
CREATE POLICY app_update_itens_compra_rascunho
ON public.pedido_itens
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'COMPRA'
          AND p.status = 'RASCUNHO'
    )
)
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'COMPRA'
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS app_delete_itens_compra_rascunho ON public.pedido_itens;
CREATE POLICY app_delete_itens_compra_rascunho
ON public.pedido_itens
FOR DELETE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'COMPRA'
          AND p.status = 'RASCUNHO'
    )
);

DROP POLICY IF EXISTS app_update_pedido_compra_rascunho_compartilhado ON public.pedidos;
CREATE POLICY app_update_pedido_compra_rascunho_compartilhado
ON public.pedidos
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND tipo_pedido = 'COMPRA'
    AND status = 'RASCUNHO'
)
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'COMPRADOR', 'COMERCIAL')
    AND tipo_pedido = 'COMPRA'
    AND status = 'RASCUNHO'
);
