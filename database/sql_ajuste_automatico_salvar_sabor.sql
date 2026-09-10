-- =====================================================================
-- AJUSTE AUTOMÁTICO DE ESTOQUE AO SALVAR SABOR (tela "Editar Produto")
-- =====================================================================
-- Motivação: salvar_produto_sabor() fazia UPDATE ... SET quantidade =
-- COALESCE(p_quantidade, 0) diretamente, sem nunca registrar nada em
-- estoque_movimentacoes. Como o formulário de "Editar Produto" sempre
-- envia a quantidade (mesmo quando o usuário só mudou nome/preço), se
-- o valor exibido no formulário estivesse desatualizado (modal aberto
-- por um tempo, cache, etc.), salvar o produto sobrescrevia
-- silenciosamente a quantidade real de cada sabor, apagando vendas e
-- compras que aconteceram nesse meio-tempo sem deixar nenhum rastro.
-- Isso foi identificado como a causa raiz de grandes divergências de
-- estoque por sabor no produto IGN-0017 (até +293 unidades sem
-- explicação em um único sabor).
--
-- Esta migração NÃO impede a sobrescrita (isso exigiria tirar o campo
-- de quantidade do formulário de edição de produto, uma mudança maior
-- de UX) — ela faz a função gerar automaticamente uma movimentação de
-- AJUSTE (ENTRADA ou SAIDA, conforme o sinal da diferença) sempre que
-- a quantidade do sabor mudar, com estoque_anterior/estoque_novo
-- corretos. Isso:
--   1. Fecha a lacuna no histórico (a cadeia de movimentações deixa de
--      ter "saltos" inexplicados nesses pontos).
--   2. Aparece automaticamente na Auditoria (trigger_audit_pedidos e
--      afins não cobrem esta tabela, mas o próprio registro em
--      estoque_movimentacoes já serve de auditoria para estoque).
--   3. Fica visível no histórico de movimentações do produto/sabor,
--      com a observação "Ajuste automático - Edição de produto".
--
-- Execute este arquivo inteiro no SQL Editor do Supabase (depois de já
-- ter rodado database/sql_salvar_produto_sabor.sql alguma vez).
-- =====================================================================

DROP FUNCTION IF EXISTS public.salvar_produto_sabor(uuid, uuid, character varying, numeric, character varying);

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
    v_quantidade_anterior numeric;
    v_quantidade_nova numeric;
    v_diferenca numeric;
BEGIN
    v_usuario_id := auth.uid();
    v_sabor_normalizado := UPPER(TRIM(COALESCE(p_sabor, '')));
    v_quantidade_nova := COALESCE(p_quantidade, 0);

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

    -- -------------------------------------------------------------
    -- CASO 1: edição de um sabor existente (p_sabor_id informado)
    -- -------------------------------------------------------------
    IF p_sabor_id IS NOT NULL THEN
        SELECT quantidade
          INTO v_quantidade_anterior
          FROM public.produto_sabores
         WHERE id = p_sabor_id
           AND produto_id = p_produto_id
         FOR UPDATE;

        IF NOT FOUND THEN
            RETURN QUERY SELECT false, 'Sabor não encontrado'::text, NULL::uuid;
            RETURN;
        END IF;

        UPDATE public.produto_sabores
           SET sabor = v_sabor_normalizado,
               quantidade = v_quantidade_nova,
               codigo_barras = NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
               ativo = true,
               updated_at = now()
         WHERE id = p_sabor_id
           AND produto_id = p_produto_id;

        v_diferenca := v_quantidade_nova - COALESCE(v_quantidade_anterior, 0);

        IF v_diferenca <> 0 THEN
            INSERT INTO public.estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, observacao
            ) VALUES (
                p_produto_id,
                p_sabor_id,
                CASE WHEN v_diferenca > 0 THEN 'ENTRADA' ELSE 'SAIDA' END,
                ABS(v_diferenca),
                COALESCE(v_quantidade_anterior, 0),
                v_quantidade_nova,
                v_usuario_id,
                'Ajuste automático - Edição de produto (tela Editar Produto)'
            );
        END IF;

        RETURN QUERY SELECT true, 'Sabor atualizado com sucesso'::text, p_sabor_id;
        RETURN;
    END IF;

    -- -------------------------------------------------------------
    -- CASO 2: sem sabor_id — reativar sabor existente com mesmo nome,
    -- ou criar um sabor novo
    -- -------------------------------------------------------------
    SELECT id
      INTO v_sabor_existente_id
      FROM public.produto_sabores
     WHERE produto_id = p_produto_id
       AND UPPER(TRIM(sabor)) = v_sabor_normalizado
     LIMIT 1;

    IF v_sabor_existente_id IS NOT NULL THEN
        SELECT quantidade
          INTO v_quantidade_anterior
          FROM public.produto_sabores
         WHERE id = v_sabor_existente_id
         FOR UPDATE;

        UPDATE public.produto_sabores
           SET sabor = v_sabor_normalizado,
               quantidade = v_quantidade_nova,
               codigo_barras = NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
               ativo = true,
               updated_at = now()
         WHERE id = v_sabor_existente_id;

        v_diferenca := v_quantidade_nova - COALESCE(v_quantidade_anterior, 0);

        IF v_diferenca <> 0 THEN
            INSERT INTO public.estoque_movimentacoes (
                produto_id, sabor_id, tipo, quantidade,
                estoque_anterior, estoque_novo,
                usuario_id, observacao
            ) VALUES (
                p_produto_id,
                v_sabor_existente_id,
                CASE WHEN v_diferenca > 0 THEN 'ENTRADA' ELSE 'SAIDA' END,
                ABS(v_diferenca),
                COALESCE(v_quantidade_anterior, 0),
                v_quantidade_nova,
                v_usuario_id,
                'Ajuste automático - Edição de produto (reativação de sabor)'
            );
        END IF;

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
        v_quantidade_nova,
        NULLIF(TRIM(COALESCE(p_codigo_barras, '')), ''),
        true,
        now(),
        now()
    )
    RETURNING id INTO v_sabor_existente_id;

    -- Sabor novo criado já com quantidade inicial: registra a ENTRADA
    -- correspondente (partindo de 0) para manter o histórico completo.
    IF v_quantidade_nova <> 0 THEN
        INSERT INTO public.estoque_movimentacoes (
            produto_id, sabor_id, tipo, quantidade,
            estoque_anterior, estoque_novo,
            usuario_id, observacao
        ) VALUES (
            p_produto_id,
            v_sabor_existente_id,
            CASE WHEN v_quantidade_nova > 0 THEN 'ENTRADA' ELSE 'SAIDA' END,
            ABS(v_quantidade_nova),
            0,
            v_quantidade_nova,
            v_usuario_id,
            'Ajuste automático - Criação de sabor (tela Editar Produto)'
        );
    END IF;

    RETURN QUERY SELECT true, 'Sabor criado com sucesso'::text, v_sabor_existente_id;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.salvar_produto_sabor(uuid, uuid, character varying, numeric, character varying) TO authenticated;
GRANT EXECUTE ON FUNCTION public.salvar_produto_sabor(uuid, uuid, character varying, numeric, character varying) TO service_role;

-- =====================================================================
-- FIM DA MIGRAÇÃO
-- =====================================================================
