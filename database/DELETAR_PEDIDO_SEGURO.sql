-- ============================================================================
-- DELETAR PEDIDO DE FORMA SEGURA
-- ============================================================================
-- PROBLEMA: Foreign Keys com RESTRICT impedem deletar pedidos que têm
--           movimentações de estoque, itens, etc
--
-- SOLUÇÃO: Função que deleta em ordem CORRETA:
--          1. estoque_movimentacoes
--          2. pedido_itens
--          3. cancelamento_pedidos
--          4. pedidos (por último)

DROP FUNCTION IF EXISTS deletar_pedido_seguro(UUID, UUID);

CREATE FUNCTION deletar_pedido_seguro(
    p_pedido_id uuid,
    p_usuario_id uuid
)
RETURNS BOOLEAN AS $$
DECLARE
    v_pedido_num VARCHAR;
    v_status VARCHAR;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA)
    SELECT numero, status INTO v_pedido_num, v_status
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido não encontrado';
    END IF;
    
    -- Proteção: Não deletar pedidos FINALIZADOS ou CANCELADOS (apenas RASCUNHO)
    IF v_status != 'RASCUNHO' THEN
        RAISE EXCEPTION 'Apenas pedidos em RASCUNHO podem ser deletados';
    END IF;
    
    -- ============================================================================
    -- PASSO 1: Deletar estoque_movimentacoes
    -- ============================================================================
    DELETE FROM estoque_movimentacoes
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 2: Deletar pedido_itens
    -- ============================================================================
    DELETE FROM pedido_itens
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 3: Deletar cancelamento_pedidos
    -- ============================================================================
    DELETE FROM cancelamento_pedidos
    WHERE pedido_id = p_pedido_id;
    
    -- ============================================================================
    -- PASSO 4: Deletar o pedido (por último!)
    -- ============================================================================
    DELETE FROM pedidos
    WHERE id = p_pedido_id;
    
    RETURN TRUE;
    
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao deletar pedido: %', SQLERRM;
END;
$$ LANGUAGE plpgsql;
