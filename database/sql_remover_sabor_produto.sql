-- =====================================================
-- FUNCAO: remover_sabor_produto
-- Proposito: desativar um sabor de produto com bypass controlado de RLS
-- Regra: nao permite remover sabor com estoque maior que zero
-- =====================================================

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

    UPDATE public.produto_sabores
       SET ativo = false,
           updated_at = now()
     WHERE id = p_sabor_id;

    RETURN QUERY SELECT true, 'Sabor removido com sucesso'::text;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.remover_sabor_produto(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remover_sabor_produto(uuid, uuid) TO service_role;
