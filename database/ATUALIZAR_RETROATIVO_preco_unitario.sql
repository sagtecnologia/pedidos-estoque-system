-- =====================================================
-- SCRIPT RETROATIVO: ATUALIZAR PREÇO UNITÁRIO DAS MOVIMENTAÇÕES
-- =====================================================
-- Objetivo: Atualizar o preco_unitario das movimentações existentes
--           buscando o preço real do pedido de compra (pedido_itens)
-- Data: 2026-02-03
-- =====================================================

-- PASSO 1: Atualizar com o preço do pedido_itens (PRIMEIRA PRIORIDADE)
-- =====================================================
UPDATE estoque_movimentacoes em
SET preco_unitario = pi.preco_unitario
FROM pedido_itens pi
WHERE em.pedido_id = pi.pedido_id
  AND em.produto_id = pi.produto_id
  AND COALESCE(em.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID) = 
      COALESCE(pi.sabor_id, '00000000-0000-0000-0000-000000000000'::UUID)
  AND em.tipo = 'ENTRADA'
  AND em.preco_unitario IS NULL
  AND pi.preco_unitario IS NOT NULL;

-- PASSO 2: Para movimentações que ainda não têm preço, usar o preço do cadastro do produto
-- =====================================================
UPDATE estoque_movimentacoes em
SET preco_unitario = p.preco_compra
FROM produtos p
WHERE em.produto_id = p.id
  AND em.tipo = 'ENTRADA'
  AND em.pedido_id IS NOT NULL
  AND em.preco_unitario IS NULL
  AND p.preco_compra IS NOT NULL;

-- PASSO 3: Verificar resultado
-- =====================================================
SELECT 'RESUMO DA ATUALIZAÇÃO' as relatorio;
SELECT 
    COUNT(*) as total_movimentacoes_entrada,
    COUNT(CASE WHEN preco_unitario IS NOT NULL THEN 1 END) as com_preco,
    COUNT(CASE WHEN preco_unitario IS NULL THEN 1 END) as sem_preco,
    ROUND(AVG(preco_unitario), 2) as preco_medio,
    ROUND(SUM(valor_total), 2) as valor_total_estoque
FROM estoque_movimentacoes
WHERE tipo = 'ENTRADA';

-- PASSO 4: Verificar movimentações sem preço (se houver)
-- =====================================================
SELECT 'Movimentações de entrada SEM preço:' as info;
SELECT 
    em.id,
    em.produto_id,
    p.codigo,
    p.nome,
    em.quantidade,
    em.pedido_id,
    em.created_at
FROM estoque_movimentacoes em
LEFT JOIN produtos p ON em.produto_id = p.id
WHERE em.tipo = 'ENTRADA'
  AND em.preco_unitario IS NULL
  AND em.pedido_id IS NOT NULL
LIMIT 20;

-- PASSO 5: Informação sobre as atualizações
-- =====================================================
SELECT 'Script executado com sucesso!' as status;
SELECT 'Os preços foram atualizados conforme:' as info;
SELECT '1. Prioridade: Preço do pedido_itens (preco_unitario do item do pedido)' as passo1;
SELECT '2. Fallback: Preço do produto cadastrado (preco_compra)' as passo2;
SELECT '3. Se ainda não tiver, permanece NULL' as passo3;
