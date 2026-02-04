-- =====================================================
-- SCRIPT COMPLETO: CORRIGIR PREÇO DE COMPRA POR SABOR
-- =====================================================
-- Objetivo: Fazer a aba "Estoque Sabor" usar o preço real 
--           das movimentações de entrada (pedido de compra)
-- Data: 2026-02-03
-- =====================================================

-- PASSO 1: Adicionar coluna preco_unitario em estoque_movimentacoes (se não existir)
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'estoque_movimentacoes' AND column_name = 'preco_unitario'
    ) THEN
        ALTER TABLE estoque_movimentacoes
        ADD COLUMN preco_unitario DECIMAL(10,2) DEFAULT NULL;
        
        RAISE NOTICE 'Coluna preco_unitario adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna preco_unitario já existe';
    END IF;
END $$;

-- PASSO 2: Adicionar coluna valor_total (se não existir)
-- =====================================================
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'estoque_movimentacoes' AND column_name = 'valor_total'
    ) THEN
        ALTER TABLE estoque_movimentacoes
        ADD COLUMN valor_total DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED;
        
        RAISE NOTICE 'Coluna valor_total adicionada com sucesso';
    ELSE
        RAISE NOTICE 'Coluna valor_total já existe';
    END IF;
END $$;

-- PASSO 3: Criar índices se não existirem
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_estoque_mov_preco ON estoque_movimentacoes(preco_unitario);
CREATE INDEX IF NOT EXISTS idx_estoque_mov_valor_total ON estoque_movimentacoes(valor_total);

-- PASSO 4: Atualizar a VIEW vw_estoque_sabores para usar o preço real das movimentações
-- =====================================================
-- Droppar a view antiga para recriar sem conflito de nomes
DROP VIEW IF EXISTS vw_estoque_sabores CASCADE;

CREATE VIEW vw_estoque_sabores AS
SELECT 
    p.id as produto_id,
    p.marca,
    p.nome as produto_nome,
    p.nome as produto,
    p.codigo,
    ps.id as sabor_id,
    ps.sabor,
    ps.quantidade,
    p.estoque_minimo,
    -- Preço de compra: usar a ÚLTIMA entrada (movimentação mais recente)
    -- Se não tiver movimentação, usar o preço do cadastro do produto
    COALESCE(
        (SELECT em.preco_unitario
         FROM estoque_movimentacoes em 
         WHERE em.produto_id = p.id 
           AND em.sabor_id = ps.id 
           AND em.tipo = 'ENTRADA'
           AND em.preco_unitario IS NOT NULL
         ORDER BY em.created_at DESC
         LIMIT 1
        ),
        p.preco_compra
    ) as preco_compra,
    p.preco_venda,
    CASE 
        WHEN ps.quantidade = 0 THEN 'ZERADO'
        WHEN ps.quantidade <= p.estoque_minimo THEN 'BAIXO'
        ELSE 'OK'
    END as status_estoque
FROM produtos p
LEFT JOIN produto_sabores ps ON p.id = ps.produto_id
WHERE p.active = true AND ps.ativo = true
ORDER BY p.marca, p.nome, ps.sabor;

-- PASSO 5: Verificar dados atualizados
-- =====================================================
SELECT 'Verificação dos dados' as operacao;
SELECT COUNT(*) as total_movimentacoes,
       COUNT(CASE WHEN preco_unitario IS NOT NULL THEN 1 END) as movimentacoes_com_preco,
       COUNT(CASE WHEN tipo = 'ENTRADA' THEN 1 END) as entradas_total
FROM estoque_movimentacoes;

SELECT 'View vw_estoque_sabores atualizada com sucesso!' as status;

-- =====================================================
-- RESUMO DO QUE FOI FEITO:
-- =====================================================
-- 1. Adicionadas colunas preco_unitario e valor_total em estoque_movimentacoes
-- 2. Atualizadas a VIEW para buscar o preço da ÚLTIMA movimentação de entrada
-- 3. Se não tiver movimentação, usa o preço cadastrado do produto como fallback
-- 4. Isso garante que a aba "Estoque Sabor" mostre o preço real pago na última compra
-- =====================================================
