-- =====================================================
-- FUNCAO: salvar_produto_sabor
-- Proposito: criar, atualizar ou reativar sabor de produto com bypass controlado de RLS
-- =====================================================

ALTER TABLE public.produto_sabores
ADD COLUMN IF NOT EXISTS codigo_barras varchar(50);

CREATE UNIQUE INDEX IF NOT EXISTS produto_sabores_codigo_barras_key
ON public.produto_sabores (codigo_barras)
WHERE codigo_barras IS NOT NULL AND codigo_barras <> '';

DROP FUNCTION IF EXISTS public.salvar_produto_sabor(uuid, uuid, character varying, numeric);

CREATE OR REPLACE FUNCTION public.salvar_produto_sabor(
    p_produto_id uuid,
    p_sabor_id uuid DEFAULT NULL,
    p_sabor character varying DEFAULT NULL,
    p_quantidade numeric DEFAULT 0,
    p_codigo_barras character varying DEFAULT NULL
)
RETURNS TABLE(sucesso boolean, mensagem text, sabor_id uuid)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
    v_usuario_id uuid;
    v_usuario_ativo boolean;
    v_sabor_normalizado varchar(100);
    v_sabor_existente_id uuid;
BEGIN
    v_usuario_id := auth.uid();
    v_sabor_normalizado := UPPER(TRIM(COALESCE(p_sabor, '')));

    IF v_usuario_id IS NULL THEN
        RETURN QUERY SELECT false, 'Usuario nao autenticado'::text, NULL::uuid;
        RETURN;
    END IF;

    SELECT active
      INTO v_usuario_ativo
      FROM public.users
     WHERE id = v_usuario_id
     LIMIT 1;

    IF COALESCE(v_usuario_ativo, false) = false THEN
        RETURN QUERY SELECT false, 'Usuario sem permissao para salvar sabores'::text, NULL::uuid;
        RETURN;
    END IF;

    IF v_sabor_normalizado = '' THEN
        RETURN QUERY SELECT false, 'Nome do sabor obrigatorio'::text, NULL::uuid;
        RETURN;
    END IF;

    IF p_sabor_id IS NOT NULL THEN
        UPDATE public.produto_sabores
           SET sabor = v_sabor_normalizado,
               quantidade = COALESCE(p_quantidade, 0),
               codigo_barras = NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
               ativo = true,
               updated_at = now()
         WHERE id = p_sabor_id
           AND produto_id = p_produto_id;

        RETURN QUERY SELECT true, 'Sabor atualizado com sucesso'::text, p_sabor_id;
        RETURN;
    END IF;

    SELECT id
      INTO v_sabor_existente_id
      FROM public.produto_sabores
     WHERE produto_id = p_produto_id
       AND UPPER(TRIM(sabor)) = v_sabor_normalizado
     LIMIT 1;

    IF v_sabor_existente_id IS NOT NULL THEN
        UPDATE public.produto_sabores
           SET sabor = v_sabor_normalizado,
               quantidade = COALESCE(p_quantidade, 0),
               codigo_barras = NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
               ativo = true,
               updated_at = now()
         WHERE id = v_sabor_existente_id;

        RETURN QUERY SELECT true, 'Sabor reativado com sucesso'::text, v_sabor_existente_id;
        RETURN;
    END IF;

    INSERT INTO public.produto_sabores (
        produto_id,
        sabor,
        quantidade,
        codigo_barras,
        ativo,
        created_at,
        updated_at
    ) VALUES (
        p_produto_id,
        v_sabor_normalizado,
        COALESCE(p_quantidade, 0),
        NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
        true,
        now(),
        now()
    )
    RETURNING id INTO v_sabor_existente_id;

    RETURN QUERY SELECT true, 'Sabor criado com sucesso'::text, v_sabor_existente_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.salvar_produto_sabor(uuid, uuid, character varying, numeric, character varying) TO authenticated;
GRANT EXECUTE ON FUNCTION public.salvar_produto_sabor(uuid, uuid, character varying, numeric, character varying) TO service_role;
