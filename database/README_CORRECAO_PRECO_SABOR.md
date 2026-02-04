# Correção: Preço de Compra por Sabor no Estoque

## Problema
A aba "Estoque Sabor" estava mostrando o **preço cadastrado no produto** em vez do **preço real da entrada do pedido de compra**.

## Solução
Implementação de um sistema que registra e utiliza o preço unitário real de cada movimentação de estoque.

## Arquivos criados

### 1. `CORRIGIR_COMPLETO_preco_estoque_sabor.sql`
Script SQL completo que:
- Adiciona coluna `preco_unitario` em `estoque_movimentacoes` (se não existir)
- Adiciona coluna `valor_total` calculada automaticamente
- Cria índices para performance
- **Atualiza a view `vw_estoque_sabores`** para usar o preço real das movimentações

### 2. `ATUALIZAR_finalizar_pedido_com_preco.sql`
Atualiza a função SQL `finalizar_pedido()` para:
- Registrar o `preco_unitario` do item do pedido em cada movimentação
- Usar o preço real da compra, não do cadastro do produto

## Como executar

### Passo 1: Executar o script de correção completa
```sql
-- Abrir SQL Editor no Supabase
-- Copiar e executar o arquivo: CORRIGIR_COMPLETO_preco_estoque_sabor.sql
```

Este script irá:
1. Adicionar as colunas necessárias (se não existirem)
2. Criar os índices
3. **Atualizar a view para usar o preço das movimentações**

### Passo 2: Atualizar a função finalizar_pedido (RECOMENDADO)
```sql
-- Copiar e executar o arquivo: ATUALIZAR_finalizar_pedido_com_preco.sql
```

Esta atualização garante que **novos pedidos de compra** registrem o preço correto.

## Resultado esperado

### Antes da correção:
- Aba "Estoque Sabor" mostra preço: **R$ 10,00** (preço cadastrado no produto)
- Mesmo que a última compra foi por **R$ 8,50**

### Depois da correção:
- Aba "Estoque Sabor" mostra preço: **R$ 8,50** (preço da última entrada)
- Valores de estoque refletem o preço real pago

## Comportamento da View

A view `vw_estoque_sabores` agora funciona assim:

1. **Busca a ÚLTIMA movimentação de ENTRADA** (pedido de compra) do sabor
2. **Extrai o `preco_unitario`** dessa movimentação
3. **Se não tiver movimentação**, usa o preço cadastrado do produto como fallback

```sql
-- Exemplo de lógica:
SELECT COALESCE(
    (SELECT preco_unitario 
     FROM estoque_movimentacoes 
     WHERE produto_id = X AND sabor_id = Y 
     AND tipo = 'ENTRADA'
     ORDER BY created_at DESC LIMIT 1),
    produto.preco_compra
) as preco_compra
```

## Impacto

✅ A aba "Estoque Sabor" agora mostra o preço real das compras  
✅ Totais de investimento em estoque ficam precisos  
✅ Margem de lucro é calculada corretamente  
✅ Histórico de preços é preservado em `estoque_movimentacoes`

## Notas importantes

- Os pedidos **já finalizados** precisam de ajuste manual se o preço estava errado
- Pedidos **novos** usarão a função atualizada e registrarão o preço correto
- A view busca apenas a **última movimentação** para simplificar (pode ser ajustado para média se necessário)

## Suporte

Se houver dúvidas:
1. Verificar se as colunas foram adicionadas: `SELECT * FROM estoque_movimentacoes LIMIT 1`
2. Verificar a view: `SELECT * FROM vw_estoque_sabores LIMIT 5`
3. Verificar movimentações: `SELECT preco_unitario, quantidade FROM estoque_movimentacoes WHERE tipo = 'ENTRADA' LIMIT 10`
