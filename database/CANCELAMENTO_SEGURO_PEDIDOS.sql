-- =====================================================
-- MIGRATION: Sistema de Cancelamento Seguro de Pedidos
-- =====================================================
-- Objetivo: Prevenir estoque negativo e garantir que só o cancelado retorna
-- Data: 2026-02-03
-- =====================================================

-- =====================================================
-- 1. TABELA DE HISTÓRICO DE CANCELAMENTO (AUDITORIA)
-- =====================================================
CREATE TABLE IF NOT EXISTS cancelamento_pedidos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pedido_id UUID NOT NULL REFERENCES pedidos(id) ON DELETE CASCADE,
    status_anterior VARCHAR(20) NOT NULL,
    status_novo VARCHAR(20) NOT NULL,
    motivo TEXT,
    cancelado_por UUID NOT NULL REFERENCES users(id),
    pode_reverter BOOLEAN DEFAULT true,
    data_cancelamento TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_cancelamento_pedido_id ON cancelamento_pedidos(pedido_id);
CREATE INDEX IF NOT EXISTS idx_cancelamento_usuario ON cancelamento_pedidos(cancelado_por);
CREATE INDEX IF NOT EXISTS idx_cancelamento_data ON cancelamento_pedidos(data_cancelamento DESC);

-- =====================================================
-- 2. NOVA FUNÇÃO PARA REVERTER MOVIMENTAÇÕES COM SEGURANÇA
-- =====================================================
DROP TRIGGER IF EXISTS trigger_reverter_movimentacoes ON pedidos CASCADE;
DROP FUNCTION IF EXISTS reverter_movimentacoes_pedido() CASCADE;

CREATE OR REPLACE FUNCTION reverter_movimentacoes_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_mov RECORD;
    v_produto RECORD;
    v_estoque_necessario DECIMAL(10,2);
    v_estoque_disponivel DECIMAL(10,2);
    v_movimentacoes_count INT;
    v_já_cancelado BOOLEAN;
BEGIN
    -- PROTEÇÃO 1: Verificar se já foi cancelado antes
    SELECT EXISTS(
        SELECT 1 FROM cancelamento_pedidos 
        WHERE pedido_id = OLD.id 
        AND status_novo = 'CANCELADO'
    ) INTO v_já_cancelado;
    
    IF v_já_cancelado THEN
        RAISE EXCEPTION 'BLOQUEIO: Este pedido já foi cancelado anteriormente! Não é possível cancelar novamente.';
    END IF;
    
    -- PROTEÇÃO 2: Só reverter se mudança for FINALIZADO → CANCELADO/RASCUNHO
    IF NOT (OLD.status = 'FINALIZADO' AND NEW.status IN ('RASCUNHO', 'CANCELADO')) THEN
        RETURN NEW;
    END IF;
    
    RAISE NOTICE '🔐 INÍCIO DO CANCELAMENTO SEGURO - Pedido: % (% → %)', 
        OLD.numero, OLD.status, NEW.status;
    
    -- =====================================================
    -- VALIDAÇÃO PARA CANCELAMENTOS DE COMPRA
    -- =====================================================
    IF OLD.tipo_pedido = 'COMPRA' THEN
        RAISE NOTICE '📦 CANCELAMENTO DE COMPRA - Validando estoque';
        
        -- Verificar se há estoque suficiente para reverter TODAS as entradas
        FOR v_mov IN 
            SELECT m.*, p.codigo as produto_codigo, ps.sabor as sabor_nome,
                   COALESCE(ps.quantidade, 0) as estoque_sabor,
                   p.estoque_atual as estoque_geral
            FROM estoque_movimentacoes m
            JOIN produtos p ON m.produto_id = p.id
            LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
            WHERE m.pedido_id = OLD.id 
            AND m.tipo = 'ENTRADA'
            ORDER BY m.created_at DESC
        LOOP
            -- Validar estoque por sabor
            IF v_mov.sabor_id IS NOT NULL THEN
                IF v_mov.estoque_sabor < v_mov.quantidade THEN
                    RAISE EXCEPTION 'BLOQUEIO: Não é possível reverter! O produto % (Sabor: %) foi parcialmente vendido. '
                        'Estoque do sabor: %, tentando remover: %, faltariam: % unidades. '
                        'Cancele primeiro as vendas relacionadas.',
                        v_mov.produto_codigo,
                        COALESCE(v_mov.sabor_nome, 'geral'),
                        v_mov.estoque_sabor,
                        v_mov.quantidade,
                        (v_mov.quantidade - v_mov.estoque_sabor);
                END IF;
            ELSE
                -- Validar estoque geral
                IF v_mov.estoque_geral < v_mov.quantidade THEN
                    RAISE EXCEPTION 'BLOQUEIO: Não é possível reverter! O produto % foi parcialmente vendido. '
                        'Estoque: %, tentando remover: %, faltariam: % unidades. '
                        'Cancele primeiro as vendas relacionadas.',
                        v_mov.produto_codigo,
                        v_mov.estoque_geral,
                        v_mov.quantidade,
                        (v_mov.quantidade - v_mov.estoque_geral);
                END IF;
            END IF;
        END LOOP;
    END IF;
    
    -- =====================================================
    -- VALIDAÇÃO PARA CANCELAMENTOS DE VENDA
    -- =====================================================
    IF OLD.tipo_pedido = 'VENDA' THEN
        RAISE NOTICE '🛍️ CANCELAMENTO DE VENDA - Validando se há estoque para devolver';
        
        -- Para vendas, verificar se existe estoque para devolver
        FOR v_mov IN 
            SELECT m.*, p.codigo as produto_codigo, ps.sabor as sabor_nome
            FROM estoque_movimentacoes m
            JOIN produtos p ON m.produto_id = p.id
            LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
            WHERE m.pedido_id = OLD.id 
            AND m.tipo = 'SAIDA'
            ORDER BY m.created_at DESC
        LOOP
            -- Apenas aviso para venda (não bloqueia, pois está devolvendo)
            RAISE NOTICE '↩️ Devolvendo %un do produto % (Sabor: %)',
                v_mov.quantidade,
                v_mov.produto_codigo,
                COALESCE(v_mov.sabor_nome, 'geral');
        END LOOP;
    END IF;
    
    -- =====================================================
    -- EXECUÇÃO: Reverter as movimentações
    -- =====================================================
    RAISE NOTICE '⚙️ Iniciando reversão de movimentações';
    
    FOR v_mov IN 
        SELECT id, tipo, quantidade, produto_id, sabor_id
        FROM estoque_movimentacoes
        WHERE pedido_id = OLD.id
        ORDER BY created_at DESC
    LOOP
        -- REVERSÃO: Inverter a movimentação
        -- Se foi ENTRADA, remove (quantidade negativa)
        -- Se foi SAÍDA, adiciona (quantidade positiva)
        
        -- Atualizar estoque do sabor
        IF v_mov.sabor_id IS NOT NULL THEN
            IF v_mov.tipo = 'ENTRADA' THEN
                -- Remover quantidade da ENTRADA
                UPDATE produto_sabores
                SET quantidade = quantidade - v_mov.quantidade
                WHERE id = v_mov.sabor_id;
                RAISE NOTICE '  ↓ Removendo %un do sabor (ENTRADA revertida)', v_mov.quantidade;
            ELSIF v_mov.tipo = 'SAIDA' THEN
                -- Adicionar quantidade da SAÍDA
                UPDATE produto_sabores
                SET quantidade = quantidade + v_mov.quantidade
                WHERE id = v_mov.sabor_id;
                RAISE NOTICE '  ↑ Adicionando %un ao sabor (SAÍDA revertida)', v_mov.quantidade;
            END IF;
        END IF;
        
        -- Atualizar estoque geral
        IF v_mov.tipo = 'ENTRADA' THEN
            UPDATE produtos
            SET estoque_atual = estoque_atual - v_mov.quantidade
            WHERE id = v_mov.produto_id;
            RAISE NOTICE '  ↓ Removendo %un do estoque geral (ENTRADA revertida)', v_mov.quantidade;
        ELSIF v_mov.tipo = 'SAIDA' THEN
            UPDATE produtos
            SET estoque_atual = estoque_atual + v_mov.quantidade
            WHERE id = v_mov.produto_id;
            RAISE NOTICE '  ↑ Adicionando %un ao estoque geral (SAÍDA revertida)', v_mov.quantidade;
        END IF;
        
        -- Deletar a movimentação original
        DELETE FROM estoque_movimentacoes WHERE id = v_mov.id;
    END LOOP;
    
    -- =====================================================
    -- AUDITORIA: Registrar cancelamento
    -- =====================================================
    INSERT INTO cancelamento_pedidos (
        pedido_id,
        status_anterior,
        status_novo,
        cancelado_por,
        motivo,
        pode_reverter
    ) VALUES (
        OLD.id,
        OLD.status,
        NEW.status,
        COALESCE(NEW.aprovador_id, (SELECT id FROM users LIMIT 1)), -- Sistema como fallback
        'Cancelamento automático',
        FALSE -- Não permite reverter cancellamento duplo
    );
    
    RAISE NOTICE '✅ Cancelamento de pedido % finalizado com SUCESSO', OLD.numero;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger
CREATE TRIGGER trigger_reverter_movimentacoes
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION reverter_movimentacoes_pedido();

-- =====================================================
-- 3. ATUALIZAR FUNÇÃO DE VALIDAÇÃO DE STATUS
-- =====================================================
DROP TRIGGER IF EXISTS trigger_validar_mudanca_status ON pedidos CASCADE;
DROP FUNCTION IF EXISTS validar_mudanca_status_pedido() CASCADE;

CREATE OR REPLACE FUNCTION validar_mudanca_status_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_cancelado_antes BOOLEAN;
BEGIN
    -- PROTEÇÃO 1: Bloquear qualquer mudança em pedido já cancelado
    IF OLD.status = 'CANCELADO' THEN
        RAISE EXCEPTION 'BLOQUEIO PERMANENTE: Não é possível alterar um pedido já cancelado. '
            'Status atual: CANCELADO. Esta operação é irreversível.';
    END IF;
    
    -- PROTEÇÃO 2: Bloquear cancelamento duplo
    IF NEW.status = 'CANCELADO' THEN
        SELECT EXISTS(
            SELECT 1 FROM cancelamento_pedidos 
            WHERE pedido_id = NEW.id 
            AND status_novo = 'CANCELADO'
        ) INTO v_cancelado_antes;
        
        IF v_cancelado_antes THEN
            RAISE EXCEPTION 'BLOQUEIO: Este pedido foi cancelado anteriormente! Não é possível cancelar novamente.';
        END IF;
    END IF;
    
    -- PROTEÇÃO 3: Permitir cancelamento apenas de status específicos
    IF NEW.status = 'CANCELADO' AND OLD.status NOT IN ('FINALIZADO', 'APROVADO', 'ENVIADO', 'REJEITADO') THEN
        RAISE EXCEPTION 'RESTRIÇÃO: Só é possível cancelar pedidos nos status: '
            'FINALIZADO, APROVADO, ENVIADO ou REJEITADO. '
            'Status atual: %. Para cancelar, o pedido deve estar em um destes status.', OLD.status;
    END IF;
    
    -- PROTEÇÃO 4: Bloquear re-abertura múltipla como rascunho
    IF NEW.status = 'RASCUNHO' AND OLD.status = 'FINALIZADO' THEN
        SELECT COUNT(*) FROM cancelamento_pedidos 
        WHERE pedido_id = NEW.id 
        INTO v_cancelado_antes;
        
        IF v_cancelado_antes > 0 THEN
            RAISE EXCEPTION 'RESTRIÇÃO: Este pedido já foi cancelado e reaberto. '
                'Não é possível fazer múltiplas reabertura. Cancele definitivamente ou exclua.';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Criar trigger de validação
CREATE TRIGGER trigger_validar_mudanca_status
    BEFORE UPDATE OF status ON pedidos
    FOR EACH ROW
    WHEN (OLD.status IS DISTINCT FROM NEW.status)
    EXECUTE FUNCTION validar_mudanca_status_pedido();

-- =====================================================
-- 4. CONSTRAINT PARA EVITAR ESTOQUE NEGATIVO
-- =====================================================
CREATE OR REPLACE FUNCTION validar_estoque_nao_negativo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estoque_atual < 0 THEN
        RAISE EXCEPTION 'BLOQUEIO: Estoque não pode ser negativo! Produto: %, Estoque resultante: %',
            NEW.codigo, NEW.estoque_atual;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_estoque_nao_negativo ON produtos;
CREATE TRIGGER trigger_validar_estoque_nao_negativo
    BEFORE UPDATE ON produtos
    FOR EACH ROW
    EXECUTE FUNCTION validar_estoque_nao_negativo();

-- =====================================================
-- 5. VALIDAÇÃO DE ESTOQUE POR SABOR
-- =====================================================
CREATE OR REPLACE FUNCTION validar_estoque_sabor_nao_negativo()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.quantidade < 0 THEN
        RAISE EXCEPTION 'BLOQUEIO: Estoque de sabor não pode ser negativo! Sabor: %, Estoque resultante: %',
            NEW.sabor, NEW.quantidade;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_validar_estoque_sabor ON produto_sabores;
CREATE TRIGGER trigger_validar_estoque_sabor
    BEFORE UPDATE ON produto_sabores
    FOR EACH ROW
    EXECUTE FUNCTION validar_estoque_sabor_nao_negativo();

-- =====================================================
-- 6. VIEW PARA AUDITORIA DE CANCELAMENTOS
-- =====================================================
CREATE OR REPLACE VIEW v_cancelamentos_auditoria AS
SELECT 
    cp.id as cancelamento_id,
    cp.pedido_id,
    p.numero as pedido_numero,
    p.tipo_pedido,
    cp.status_anterior,
    cp.status_novo,
    cp.motivo,
    u.full_name as cancelado_por_usuario,
    cp.pode_reverter,
    cp.data_cancelamento,
    CASE 
        WHEN cp.status_novo = 'CANCELADO' THEN '❌ Cancelado Definitivamente'
        WHEN cp.status_novo = 'RASCUNHO' THEN '🔄 Reaberto como Rascunho'
        ELSE cp.status_novo
    END as tipo_cancelamento
FROM cancelamento_pedidos cp
JOIN pedidos p ON cp.pedido_id = p.id
JOIN users u ON cp.cancelado_por = u.id
ORDER BY cp.data_cancelamento DESC;

-- =====================================================
-- 7. FUNÇÃO PARA VERIFICAR SE PEDIDO PODE SER CANCELADO
-- =====================================================
CREATE OR REPLACE FUNCTION pode_cancelar_pedido(p_pedido_id UUID)
RETURNS TABLE (
    pode_cancelar BOOLEAN,
    motivo TEXT,
    conflitos TEXT[]
) AS $$
DECLARE
    v_pedido RECORD;
    v_conflitos TEXT[];
    v_mov RECORD;
    v_estoque_sabor DECIMAL(10,2);
    v_estoque_geral DECIMAL(10,2);
BEGIN
    -- Buscar pedido
    SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT false, 'Pedido não encontrado'::TEXT, ARRAY[]::TEXT[];
        RETURN;
    END IF;
    
    -- Verificar se já foi cancelado
    IF v_pedido.status = 'CANCELADO' THEN
        RETURN QUERY SELECT false, 'Pedido já foi cancelado'::TEXT, ARRAY['Cancelamento anterior detectado']::TEXT[];
        RETURN;
    END IF;
    
    -- Verificar se está em status cancellável
    IF v_pedido.status NOT IN ('FINALIZADO', 'APROVADO', 'ENVIADO', 'REJEITADO') THEN
        RETURN QUERY SELECT false, 
            'Pedido não está em status cancellável. Status: ' || v_pedido.status::TEXT,
            ARRAY['Status: ' || v_pedido.status]::TEXT[];
        RETURN;
    END IF;
    
    -- Se é COMPRA, validar estoque
    IF v_pedido.tipo_pedido = 'COMPRA' THEN
        v_conflitos := ARRAY[]::TEXT[];
        
        FOR v_mov IN 
            SELECT m.*, p.codigo, ps.sabor,
                   COALESCE(ps.quantidade, 0) as est_sabor,
                   p.estoque_atual as est_geral
            FROM estoque_movimentacoes m
            JOIN produtos p ON m.produto_id = p.id
            LEFT JOIN produto_sabores ps ON m.sabor_id = ps.id
            WHERE m.pedido_id = p_pedido_id AND m.tipo = 'ENTRADA'
        LOOP
            IF v_mov.sabor_id IS NOT NULL AND v_mov.est_sabor < v_mov.quantidade THEN
                v_conflitos := array_append(v_conflitos, 
                    'Produto: ' || v_mov.codigo || ' (Sabor: ' || COALESCE(v_mov.sabor, 'geral') || 
                    ') - Estoque: ' || v_mov.est_sabor || ', Tentando remover: ' || v_mov.quantidade);
            END IF;
        END LOOP;
        
        IF array_length(v_conflitos, 1) > 0 THEN
            RETURN QUERY SELECT false, 
                'Não é possível cancelar - produtos já foram vendidos',
                v_conflitos;
            RETURN;
        END IF;
    END IF;
    
    -- Se passou em todas validações
    RETURN QUERY SELECT true, 'Pedido pode ser cancelado com segurança'::TEXT, ARRAY[]::TEXT[];
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. LOG DE EXECUÇÃO
-- =====================================================
SELECT 
    '✅ MIGRATION EXECUTADA COM SUCESSO' as status,
    'Sistema de Cancelamento Seguro instalado' as mensagem,
    NOW() as data_execucao,
    'Tabelas, funções, triggers e validações criadas' as detalhes;
