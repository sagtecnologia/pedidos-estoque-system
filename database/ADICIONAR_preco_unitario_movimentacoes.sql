-- =====================================================
-- ADICIONAR CAMPO preco_unitario EM estoque_movimentacoes
-- =====================================================
-- Objetivo: Registrar o preço unitário real da movimentação
--           vindo do pedido de compra, não do cadastro do produto
-- Data: 2026-02-03
-- =====================================================

-- Passo 1: Adicionar coluna preco_unitario
ALTER TABLE estoque_movimentacoes
ADD COLUMN preco_unitario DECIMAL(10,2) DEFAULT NULL;

-- Passo 2: Adicionar coluna valor_total (quantidade * preco_unitario) para facilitar consultas
ALTER TABLE estoque_movimentacoes
ADD COLUMN valor_total DECIMAL(10,2) GENERATED ALWAYS AS (quantidade * preco_unitario) STORED;

-- Passo 3: Criar índice para melhor performance em consultas de valor
CREATE INDEX IF NOT EXISTS idx_estoque_mov_preco ON estoque_movimentacoes(preco_unitario);
CREATE INDEX IF NOT EXISTS idx_estoque_mov_valor_total ON estoque_movimentacoes(valor_total);

-- Passo 4: Atualizar movimentações existentes com o preço do produto como fallback
-- Apenas para movimentações do tipo ENTRADA (compras) que têm pedido_id
UPDATE estoque_movimentacoes em
SET preco_unitario = p.preco_compra
FROM produtos p
WHERE em.produto_id = p.id
  AND em.tipo = 'ENTRADA'
  AND em.pedido_id IS NOT NULL
  AND em.preco_unitario IS NULL
  AND p.preco_compra IS NOT NULL;

-- Passo 5: Verificar atualização
SELECT COUNT(*) as movimentacoes_com_preco,
       SUM(valor_total) as valor_total_registrado
FROM estoque_movimentacoes
WHERE preco_unitario IS NOT NULL
  AND tipo = 'ENTRADA';

COMMIT;
