-- =====================================================
-- ATUALIZAR FUNÇÃO finalizar_pedido PARA INCLUIR preco_unitario
-- =====================================================
-- Objetivo: Registrar o preço unitário do pedido de compra
--           em cada movimentação de estoque
-- Data: 2026-02-03
-- =====================================================

CREATE OR REPLACE FUNCTION finalizar_pedido(p_pedido_id UUID, p_usuario_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_item RECORD;
    v_status VARCHAR;
    v_tipo_pedido VARCHAR;
    v_ja_finalizado BOOLEAN;
    v_mov_existente BOOLEAN;
BEGIN
    -- 🔒 LOCK no pedido (PRIMEIRA COISA - previne race conditions)
    SELECT status, tipo_pedido INTO v_status, v_tipo_pedido
    FROM pedidos
    WHERE id = p_pedido_id
    FOR UPDATE;
    
    -- PROTEÇÃO 1: Impedir múltiplas finalizações
    IF v_status = 'FINALIZADO' THEN
        RAISE EXCEPTION 'Este pedido já foi finalizado anteriormente';
    END IF;
    
    -- PROTEÇÃO 2: Verificar se pedido foi cancelado
    IF v_status = 'CANCELADO' THEN
        RAISE EXCEPTION 'Este pedido foi cancelado e não pode ser finalizado';
    END IF;
    
    -- PROTEÇÃO 3: Verificar status válido (permite RASCUNHO ou APROVADO)
    IF v_status NOT IN ('RASCUNHO', 'APROVADO') THEN
        RAISE EXCEPTION 'Pedido não pode ser finalizado neste status: %', v_status;
    END IF;
    
    -- PROTEÇÃO 4: Verificar se já existem movimentações de finalização
    SELECT EXISTS(
        SELECT 1 
        FROM estoque_movimentacoes 
        WHERE pedido_id = p_pedido_id 
        AND (observacao LIKE '%Finalização%' OR observacao LIKE '%finalização%')
    ) INTO v_ja_finalizado;
    
    IF v_ja_finalizado THEN
        RAISE EXCEPTION 'Este pedido já tem movimentações de finalização registradas';
    END IF;

    -- Processar itens do pedido
    FOR v_item IN 
        SELECT 
            pi.id as item_id,
            pi.produto_id, 
            pi.sabor_id, 
            pi.quantidade,
            pi.preco_unitario,
            p.codigo as produto_codigo,
            ps.sabor as sabor_nome
        FROM pedido_itens pi
        LEFT JOIN produtos p ON p.id = pi.produto_id
        LEFT JOIN produto_sabores ps ON ps.id = pi.sabor_id
        WHERE pi.pedido_id = p_pedido_id
    LOOP
        -- 🛡️ PROTEÇÃO ADICIONAL: Verificar se movimentação já existe
        v_mov_existente := verificar_movimentacao_existente(
            p_pedido_id, 
            v_item.produto_id, 
            v_item.sabor_id
        );
        
        IF v_mov_existente THEN
            RAISE EXCEPTION 'Já existe movimentação para o produto % no pedido especificado', 
                v_item.produto_codigo;
        END IF;
        
        -- Processar movimentação de sabor (se aplicável)
        IF v_item.sabor_id IS NOT NULL THEN
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
                v_preco_unitario DECIMAL;
            BEGIN
                -- Buscar estoque atual COM LOCK
                SELECT quantidade INTO v_estoque_anterior
                FROM produto_sabores
                WHERE id = v_item.sabor_id
                FOR UPDATE;
                
                -- Usar o preço do pedido, não do cadastro do produto
                v_preco_unitario := v_item.preco_unitario;
                
                -- Calcular ajuste baseado no tipo
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    -- Validação de estoque para venda
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para % (%). Necessário: %, Disponível: %',
                            v_item.produto_codigo, 
                            v_item.sabor_nome,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                ELSE
                    RAISE EXCEPTION 'Tipo de pedido inválido: %', v_tipo_pedido;
                END IF;
                
                -- Atualizar estoque do sabor
                UPDATE produto_sabores
                SET quantidade = quantidade + v_quantidade_ajuste
                WHERE id = v_item.sabor_id
                RETURNING quantidade INTO v_estoque_novo;
                
                -- 📝 Registrar movimentação COM PREÇO (constraint única garante não duplicar)
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    sabor_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    preco_unitario,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    v_item.sabor_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    v_preco_unitario,
                    CASE 
                        WHEN v_tipo_pedido = 'COMPRA' THEN 'Entrada - Finalização pedido compra'
                        ELSE 'Saída - Finalização pedido venda'
                    END
                );
            END;
        ELSE
            -- Processar produto sem sabor (lógica similar)
            DECLARE
                v_estoque_anterior DECIMAL;
                v_estoque_novo DECIMAL;
                v_quantidade_ajuste DECIMAL;
                v_preco_unitario DECIMAL;
            BEGIN
                SELECT estoque_atual INTO v_estoque_anterior
                FROM produtos
                WHERE id = v_item.produto_id
                FOR UPDATE;
                
                -- Usar o preço do pedido
                v_preco_unitario := v_item.preco_unitario;
                
                IF v_tipo_pedido = 'COMPRA' THEN
                    v_quantidade_ajuste := v_item.quantidade;
                ELSIF v_tipo_pedido = 'VENDA' THEN
                    v_quantidade_ajuste := -v_item.quantidade;
                    
                    IF v_estoque_anterior < v_item.quantidade THEN
                        RAISE EXCEPTION 'Estoque insuficiente para %. Necessário: %, Disponível: %',
                            v_item.produto_codigo,
                            v_item.quantidade,
                            v_estoque_anterior;
                    END IF;
                END IF;
                
                UPDATE produtos
                SET estoque_atual = estoque_atual + v_quantidade_ajuste
                WHERE id = v_item.produto_id
                RETURNING estoque_atual INTO v_estoque_novo;
                
                INSERT INTO estoque_movimentacoes (
                    produto_id,
                    tipo,
                    quantidade,
                    estoque_anterior,
                    estoque_novo,
                    usuario_id,
                    pedido_id,
                    preco_unitario,
                    observacao
                ) VALUES (
                    v_item.produto_id,
                    CASE WHEN v_tipo_pedido = 'COMPRA' THEN 'ENTRADA' ELSE 'SAIDA' END,
                    v_item.quantidade,
                    v_estoque_anterior,
                    v_estoque_novo,
                    p_usuario_id,
                    p_pedido_id,
                    v_preco_unitario,
                    CASE 
                        WHEN v_tipo_pedido = 'COMPRA' THEN 'Entrada - Finalização pedido compra'
                        ELSE 'Saída - Finalização pedido venda'
                    END
                );
            END;
        END IF;
    END LOOP;

    -- Atualizar status do pedido
    UPDATE pedidos 
    SET 
        status = 'FINALIZADO',
        data_finalizacao = NOW(),
        aprovador_id = p_usuario_id
    WHERE id = p_pedido_id;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VERIFICAÇÃO
-- =====================================================
SELECT 'Função finalizar_pedido atualizada com sucesso!' as status;
