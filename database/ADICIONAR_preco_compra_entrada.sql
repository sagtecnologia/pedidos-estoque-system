-- =====================================================
-- MIGRATION: Adicionar preco_compra_entrada em pedido_itens
-- =====================================================
-- Objetivo: Rastrear o valor de compra original de cada item de pedido
-- para análise de lucro mais precisa
-- =====================================================

-- Adicionar coluna preco_compra_entrada
ALTER TABLE pedido_itens
ADD COLUMN IF NOT EXISTS preco_compra_entrada DECIMAL(10,2) DEFAULT 0;

-- Atualizar registros existentes com o preco_compra do produto
UPDATE pedido_itens pi
SET preco_compra_entrada = p.preco_compra
FROM produtos p
WHERE pi.produto_id = p.id AND pi.preco_compra_entrada = 0;

-- Adicionar constraint para garantir que o valor seja preenchido para novos registros
ALTER TABLE pedido_itens
ALTER COLUMN preco_compra_entrada SET NOT NULL;

-- Criar índice para melhor performance
CREATE INDEX IF NOT EXISTS idx_pedido_itens_preco_compra 
ON pedido_itens(preco_compra_entrada);

-- Adicionar comentário na coluna
COMMENT ON COLUMN pedido_itens.preco_compra_entrada IS 
'Valor de compra unitário no momento do pedido/entrada. Usado para análise de lucro precisa.';

-- Logs de execução
SELECT 
    'MIGRATION EXECUTADA COM SUCESSO' as status,
    'Coluna preco_compra_entrada adicionada à tabela pedido_itens' as mensagem,
    NOW() as data_execucao;
