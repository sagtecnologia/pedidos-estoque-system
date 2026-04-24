-- =====================================================
-- FUNCAO: adicionar_item_venda_codigo_barras
-- Proposito: adicionar item em venda lendo codigo de barras cadastrado no sabor
-- =====================================================

ALTER TABLE public.produto_sabores
ADD COLUMN IF NOT EXISTS codigo_barras varchar(50);

CREATE UNIQUE INDEX IF NOT EXISTS produto_sabores_codigo_barras_key
ON public.produto_sabores (codigo_barras)
WHERE codigo_barras IS NOT NULL AND codigo_barras <> '';

DROP FUNCTION IF EXISTS public.adicionar_item_venda_codigo_barras(uuid, character varying, numeric);

CREATE OR REPLACE FUNCTION public.adicionar_item_venda_codigo_barras(
    p_pedido_id uuid,
    p_codigo_barras character varying,
    p_quantidade numeric DEFAULT 1
)
RETURNS TABLE(
    item_id uuid,
    produto_id uuid,
    sabor_id uuid,
    produto_nome character varying,
    sabor_nome character varying,
    quantidade_adicionada numeric,
    preco_unitario_adicionado numeric,
    total_pedido numeric
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_ativo boolean;
    v_usuario_role text;
    v_pedido record;
    v_sabor record;
    v_quantidade_usada numeric;
    v_estoque_disponivel numeric;
    v_item_id uuid;
    v_total numeric;
    v_item_existente record;
BEGIN
    v_usuario_id := auth.uid();

    IF v_usuario_id IS NULL THEN
        RAISE EXCEPTION 'Usuario nao autenticado';
    END IF;

    SELECT active, role
      INTO v_usuario_ativo, v_usuario_role
      FROM public.users
     WHERE id = v_usuario_id
     LIMIT 1;

    IF COALESCE(v_usuario_ativo, false) = false THEN
        RAISE EXCEPTION 'Usuario sem permissao para adicionar itens';
    END IF;

    IF COALESCE(p_quantidade, 0) <= 0 THEN
        RAISE EXCEPTION 'Quantidade invalida';
    END IF;

    SELECT *
      INTO v_pedido
      FROM public.pedidos
     WHERE id = p_pedido_id
       AND tipo_pedido = 'VENDA'
     LIMIT 1;

    IF v_pedido.id IS NULL THEN
        RAISE EXCEPTION 'Venda nao encontrada';
    END IF;

    IF v_pedido.status <> 'RASCUNHO' THEN
        RAISE EXCEPTION 'Apenas vendas em rascunho permitem adicionar itens';
    END IF;

    IF v_usuario_role NOT IN ('ADMIN', 'VENDEDOR', 'COMERCIAL') THEN
        RAISE EXCEPTION 'Perfil sem permissao para adicionar itens em vendas';
    END IF;

    IF v_usuario_role <> 'ADMIN' AND v_pedido.solicitante_id <> v_usuario_id THEN
        RAISE EXCEPTION 'Apenas o vendedor responsavel pode adicionar itens nesta venda';
    END IF;

    SELECT
        ps.id AS sabor_id,
        ps.produto_id,
        ps.sabor,
        COALESCE(ps.quantidade, 0) AS estoque_sabor,
        p.nome AS produto_nome,
        COALESCE(p.preco_venda, p.preco, 0) AS preco_venda,
        COALESCE(p.preco_compra, 0) AS preco_compra
      INTO v_sabor
      FROM public.produto_sabores ps
      JOIN public.produtos p ON p.id = ps.produto_id
     WHERE ps.codigo_barras = TRIM(COALESCE(p_codigo_barras, ''))
       AND ps.ativo = true
       AND p.active = true
     LIMIT 1;

    IF v_sabor.sabor_id IS NULL THEN
        RAISE EXCEPTION 'Codigo de barras nao encontrado em nenhum sabor ativo';
    END IF;

    SELECT COALESCE(SUM(pi.quantidade), 0)
      INTO v_quantidade_usada
      FROM public.pedido_itens pi
     WHERE pi.pedido_id = p_pedido_id
       AND pi.sabor_id = v_sabor.sabor_id;

    v_estoque_disponivel := GREATEST(0, v_sabor.estoque_sabor - v_quantidade_usada);

    IF p_quantidade > v_estoque_disponivel THEN
        RAISE EXCEPTION 'Estoque insuficiente para % - %. Disponivel: % UN',
            v_sabor.produto_nome,
            v_sabor.sabor,
            v_estoque_disponivel;
    END IF;

    IF COALESCE(v_sabor.preco_venda, 0) <= 0 THEN
        RAISE EXCEPTION 'Produto encontrado, mas sem preco de venda cadastrado';
    END IF;

    SELECT pi.id, pi.quantidade
      INTO v_item_existente
      FROM public.pedido_itens pi
     WHERE pi.pedido_id = p_pedido_id
       AND pi.produto_id = v_sabor.produto_id
       AND pi.sabor_id = v_sabor.sabor_id
     ORDER BY pi.created_at ASC
     LIMIT 1;

    IF v_item_existente.id IS NOT NULL THEN
        UPDATE public.pedido_itens
           SET quantidade = COALESCE(v_item_existente.quantidade, 0) + p_quantidade,
               preco_unitario = v_sabor.preco_venda,
               preco_compra_entrada = v_sabor.preco_compra
         WHERE public.pedido_itens.id = v_item_existente.id
         RETURNING public.pedido_itens.id INTO v_item_id;
    ELSE
        INSERT INTO public.pedido_itens (
            pedido_id,
            produto_id,
            sabor_id,
            quantidade,
            preco_unitario,
            preco_compra_entrada
        ) VALUES (
            p_pedido_id,
            v_sabor.produto_id,
            v_sabor.sabor_id,
            p_quantidade,
            v_sabor.preco_venda,
            v_sabor.preco_compra
        )
        RETURNING id INTO v_item_id;
    END IF;

    SELECT COALESCE(SUM(pi.subtotal), 0)
      INTO v_total
      FROM public.pedido_itens pi
     WHERE pi.pedido_id = p_pedido_id;

    UPDATE public.pedidos
       SET total = v_total
     WHERE public.pedidos.id = p_pedido_id;

    RETURN QUERY SELECT
        v_item_id,
        v_sabor.produto_id,
        v_sabor.sabor_id,
        v_sabor.produto_nome,
        v_sabor.sabor,
        p_quantidade,
        v_sabor.preco_venda,
        v_total;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.adicionar_item_venda_codigo_barras(uuid, character varying, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adicionar_item_venda_codigo_barras(uuid, character varying, numeric) TO service_role;

-- =====================================================
-- POLICIES: permitir que o fluxo normal e o fluxo por codigo adicionem itens
-- em vendas em rascunho do proprio vendedor/comercial, ou qualquer rascunho
-- para ADMIN.
-- =====================================================

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

GRANT EXECUTE ON FUNCTION public.current_app_user_role() TO authenticated;

DROP POLICY IF EXISTS app_insert_itens_venda_rascunho ON public.pedido_itens;
CREATE POLICY app_insert_itens_venda_rascunho
ON public.pedido_itens
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'VENDA'
          AND p.status = 'RASCUNHO'
          AND (
              public.current_app_user_role() = 'ADMIN'
              OR p.solicitante_id = auth.uid()
          )
    )
);

DROP POLICY IF EXISTS app_select_itens_venda_permitida ON public.pedido_itens;
CREATE POLICY app_select_itens_venda_permitida
ON public.pedido_itens
FOR SELECT
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'VENDA'
          AND (
              public.current_app_user_role() = 'ADMIN'
              OR p.solicitante_id = auth.uid()
          )
    )
);

DROP POLICY IF EXISTS app_update_itens_venda_rascunho ON public.pedido_itens;
CREATE POLICY app_update_itens_venda_rascunho
ON public.pedido_itens
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'VENDA'
          AND p.status = 'RASCUNHO'
          AND (
              public.current_app_user_role() = 'ADMIN'
              OR p.solicitante_id = auth.uid()
          )
    )
)
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'VENDA'
          AND p.status = 'RASCUNHO'
          AND (
              public.current_app_user_role() = 'ADMIN'
              OR p.solicitante_id = auth.uid()
          )
    )
);

DROP POLICY IF EXISTS app_delete_itens_venda_rascunho ON public.pedido_itens;
CREATE POLICY app_delete_itens_venda_rascunho
ON public.pedido_itens
FOR DELETE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND EXISTS (
        SELECT 1
        FROM public.pedidos p
        WHERE p.id = pedido_id
          AND p.tipo_pedido = 'VENDA'
          AND p.status = 'RASCUNHO'
          AND (
              public.current_app_user_role() = 'ADMIN'
              OR p.solicitante_id = auth.uid()
          )
    )
);

DROP POLICY IF EXISTS app_update_total_venda_rascunho ON public.pedidos;
CREATE POLICY app_update_total_venda_rascunho
ON public.pedidos
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND tipo_pedido = 'VENDA'
    AND status = 'RASCUNHO'
    AND (
        public.current_app_user_role() = 'ADMIN'
        OR solicitante_id = auth.uid()
    )
)
WITH CHECK (
    public.current_app_user_role() IN ('ADMIN', 'VENDEDOR', 'COMERCIAL')
    AND tipo_pedido = 'VENDA'
    AND status = 'RASCUNHO'
    AND (
        public.current_app_user_role() = 'ADMIN'
        OR solicitante_id = auth.uid()
    )
);
