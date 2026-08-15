-- Resumo mensal de vendas: receita, custo, lucro e margem por mês.
-- SOMENTE LEITURA: não altera nem remove nada.
-- Rodar no SQL Editor do Supabase e copiar o resultado.
--
-- Lucro = receita (preco_unitario) - custo congelado no item
-- (preco_compra_entrada). Mesma regra do obterCustoHistorico() da analise.html,
-- então os números batem com o que o cliente vê na tela.

SELECT
    to_char(p.created_at AT TIME ZONE 'America/Sao_Paulo', 'MM/YYYY')      AS mes,
    SUM(pi.quantidade * pi.preco_unitario)                                 AS receita_total,
    SUM(pi.quantidade * COALESCE(pi.preco_compra_entrada, 0))              AS custo_total,
    SUM(pi.quantidade * (pi.preco_unitario - COALESCE(pi.preco_compra_entrada, 0))) AS lucro_total,
    ROUND(
        100 * SUM(pi.quantidade * (pi.preco_unitario - COALESCE(pi.preco_compra_entrada, 0)))
            / NULLIF(SUM(pi.quantidade * pi.preco_unitario), 0)
    , 1)                                                                   AS margem_media_pct
FROM public.pedidos p
JOIN public.pedido_itens pi ON pi.pedido_id = p.id
WHERE p.tipo_pedido = 'VENDA'
  AND p.status = 'FINALIZADO'
  AND p.created_at < '2026-09-01'   -- até o mês 08
GROUP BY 1, date_trunc('month', p.created_at AT TIME ZONE 'America/Sao_Paulo')
ORDER BY date_trunc('month', p.created_at AT TIME ZONE 'America/Sao_Paulo');
