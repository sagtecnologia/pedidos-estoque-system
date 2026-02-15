-- =====================================================
-- FUNÇÃO: dividir_sabor_quantidade
-- Propósito: Divide a quantidade de um sabor em dois
-- =====================================================

CREATE OR REPLACE FUNCTION public.dividir_sabor_quantidade(
    p_sabor_id uuid,
    p_quantidade_dividir numeric,
    p_novo_sabor character varying,
    p_produto_id uuid,
    p_observacao text DEFAULT ''::text,
    p_usuario_id uuid DEFAULT NULL::uuid
)
 RETURNS TABLE(sucesso boolean, mensagem text, sabor_original character varying, novo_sabor_criado character varying, quantidade_dividida numeric, movimentacao_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sabor_original VARCHAR(100);
    v_quantidade_atual DECIMAL(10,2);
    v_novo_sabor_id UUID;
    v_novo_sabor_ja_existe UUID;
    v_movimentacao_id UUID;
    v_usuario_id_atual UUID;
BEGIN
    -- Se não foi fornecido usuário, usar o usuário autenticado
    IF p_usuario_id IS NULL THEN
        v_usuario_id_atual := auth.uid();
    ELSE
        v_usuario_id_atual := p_usuario_id;
    END IF;

    -- Validar se o sabor atual existe
    SELECT sabor, quantidade INTO v_sabor_original, v_quantidade_atual
    FROM produto_sabores
    WHERE id = p_sabor_id AND produto_id = p_produto_id
    LIMIT 1;

    IF v_sabor_original IS NULL THEN
        RETURN QUERY SELECT false, 'Sabor não encontrado para este produto'::TEXT, NULL, NULL, NULL, NULL;
        RETURN;
    END IF;

    -- Validar quantidade a dividir
    IF p_quantidade_dividir <= 0 THEN
        RETURN QUERY SELECT false, 'A quantidade a dividir deve ser maior que zero'::TEXT, v_sabor_original, p_novo_sabor, NULL, NULL;
        RETURN;
    END IF;

    -- Validar se tem quantidade suficiente
    IF p_quantidade_dividir > v_quantidade_atual THEN
        RETURN QUERY SELECT false, 'Quantidade a dividir não pode ser maior que a quantidade atual (' || v_quantidade_atual || ')'::TEXT, v_sabor_original, p_novo_sabor, NULL, NULL;
        RETURN;
    END IF;

    -- Validar se o novo sabor é diferente
    IF LOWER(TRIM(v_sabor_original)) = LOWER(TRIM(p_novo_sabor)) THEN
        RETURN QUERY SELECT false, 'O novo sabor deve ser diferente do sabor original'::TEXT, v_sabor_original, p_novo_sabor, p_quantidade_dividir, NULL;
        RETURN;
    END IF;

    -- Verificar se já existe um sabor com esse nome para o mesmo produto
    SELECT id INTO v_novo_sabor_ja_existe
    FROM produto_sabores
    WHERE produto_id = p_produto_id 
      AND LOWER(TRIM(sabor)) = LOWER(TRIM(p_novo_sabor))
    LIMIT 1;

    BEGIN
        -- Se o novo sabor já existe, adicionar quantidade a ele
        IF v_novo_sabor_ja_existe IS NOT NULL THEN
            UPDATE produto_sabores
            SET quantidade = quantidade + p_quantidade_dividir,
                updated_at = NOW()
            WHERE id = v_novo_sabor_ja_existe;

            v_novo_sabor_id := v_novo_sabor_ja_existe;
        ELSE
            -- Se não existe, criar um novo sabor
            INSERT INTO produto_sabores (produto_id, sabor, quantidade, ativo, created_at, updated_at)
            VALUES (p_produto_id, TRIM(p_novo_sabor), p_quantidade_dividir, true, NOW(), NOW())
            RETURNING id INTO v_novo_sabor_id;
        END IF;

        -- Reduzir quantidade do sabor original
        UPDATE produto_sabores
        SET quantidade = quantidade - p_quantidade_dividir,
            updated_at = NOW()
        WHERE id = p_sabor_id;

        -- Registrar movimentação de divisão para sabor original
        INSERT INTO estoque_movimentacoes (
            produto_id,
            sabor_id,
            tipo,
            quantidade,
            estoque_anterior,
            estoque_novo,
            usuario_id,
            observacao,
            created_at,
            updated_at
        ) VALUES (
            p_produto_id,
            p_sabor_id,
            'AJUSTE_QUANTIDADE_SABOR',
            -p_quantidade_dividir,
            v_quantidade_atual,
            v_quantidade_atual - p_quantidade_dividir,
            v_usuario_id_atual,
            'Quantidade dividida para novo sabor "' || TRIM(p_novo_sabor) || '". ' || COALESCE(p_observacao, ''),
            NOW(),
            NOW()
        )
        RETURNING id INTO v_movimentacao_id;

        -- Registrar movimentação para novo sabor
        INSERT INTO estoque_movimentacoes (
            produto_id,
            sabor_id,
            tipo,
            quantidade,
            estoque_anterior,
            estoque_novo,
            usuario_id,
            observacao,
            created_at,
            updated_at
        ) VALUES (
            p_produto_id,
            v_novo_sabor_id,
            'AJUSTE_QUANTIDADE_SABOR',
            p_quantidade_dividir,
            (SELECT COALESCE(quantidade, 0) FROM produto_sabores WHERE id = v_novo_sabor_id) - p_quantidade_dividir,
            (SELECT COALESCE(quantidade, 0) FROM produto_sabores WHERE id = v_novo_sabor_id),
            v_usuario_id_atual,
            'Quantidade dividida de "' || v_sabor_original || '". ' || COALESCE(p_observacao, ''),
            NOW(),
            NOW()
        );

        -- Retornar resultado
        RETURN QUERY SELECT 
            true,
            'Sabor dividido com sucesso! ' || p_quantidade_dividir || ' ' || (SELECT unidade FROM produtos WHERE id = p_produto_id) || ' transferido(s) para "' || TRIM(p_novo_sabor) || '"'::TEXT,
            v_sabor_original,
            TRIM(p_novo_sabor),
            p_quantidade_dividir,
            v_movimentacao_id;

    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT false, 'Erro ao dividir sabor: ' || SQLERRM, v_sabor_original, p_novo_sabor, NULL, NULL;
    END;

END;
$function$
;

-- =====================================================
-- PERMISSIONS
-- =====================================================

ALTER FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO public;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO postgres;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO anon;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO service_role;

-- =====================================================
-- COMENTÁRIO E DOCUMENTAÇÃO
-- =====================================================

COMMENT ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) IS 
'Divide a quantidade de um sabor, criando um novo sabor com parte da quantidade. 
Mantém o sabor original com a quantidade restante.

Parâmetros:
- p_sabor_id: UUID do sabor a ser dividido
- p_quantidade_dividir: Quantidade a transferir (deve ser > 0 e < quantidade atual)
- p_novo_sabor: Nome do novo sabor
- p_produto_id: UUID do produto
- p_observacao: Observação opcional
- p_usuario_id: UUID do usuário (opcional, usa uid() se não fornecido)

Retorna:
- sucesso: boolean
- mensagem: texto descritivo
- sabor_original: nome do sabor original
- novo_sabor_criado: nome do novo sabor
- quantidade_dividida: quantidade transferida
- movimentacao_id: UUID da movimentação registrada';

-- =====================================================
-- EXEMPLO DE USO
-- =====================================================

/*

-- Dividir 2 unidades de "Morango" para um novo sabor "Morango-pink"
SELECT * FROM dividir_sabor_quantidade(
    p_sabor_id := 'uuid-do-sabor-morango',
    p_quantidade_dividir := 2,
    p_novo_sabor := 'Morango-pink',
    p_produto_id := 'uuid-do-produto',
    p_observacao := 'Separação para lote especial'
);

*/
