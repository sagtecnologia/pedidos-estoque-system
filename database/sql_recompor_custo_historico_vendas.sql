-- Recompõe o custo histórico de itens de VENDA que ainda estão sem custo.
-- Regra: última ENTRADA originada de uma COMPRA finalizada, anterior à SAÍDA
-- da própria venda. O preço usado é o preco_unitario do item dessa COMPRA.
-- Não usa o preço atual do cadastro e não altera itens que já têm custo > 0.

CREATE OR REPLACE FUNCTION public.auditar_custos_historicos_vendas()
RETURNS TABLE (
    pedido_id uuid,
    numero_pedido text,
    item_id uuid,
    data_venda timestamptz,
    produto_id uuid,
    produto text,
    sabor_id uuid,
    sabor text,
    quantidade numeric,
    custo_gravado numeric,
    compra_origem_id uuid,
    data_entrada timestamptz,
    custo_reconstruido numeric,
    situacao text
)
LANGUAGE sql
STABLE
AS $$
WITH itens_venda AS (
    SELECT
        p.id AS pedido_id,
        p.numero::text AS numero_pedido,
        pi.id AS item_id,
        pi.produto_id,
        pi.sabor_id,
        pi.quantidade,
        pi.preco_compra_entrada AS custo_gravado,
        COALESCE(
            (
                SELECT MAX(ms.created_at)
                FROM public.estoque_movimentacoes ms
                WHERE ms.pedido_id = p.id
                  AND ms.tipo = 'SAIDA'
                  AND ms.produto_id = pi.produto_id
                  AND ms.sabor_id IS NOT DISTINCT FROM pi.sabor_id
            ),
            p.created_at
        ) AS data_venda
    FROM public.pedidos p
    JOIN public.pedido_itens pi ON pi.pedido_id = p.id
    WHERE p.tipo_pedido = 'VENDA'
      AND p.status = 'FINALIZADO'
      AND COALESCE(pi.preco_compra_entrada, 0) <= 0
), custos_candidatos AS (
    SELECT
        iv.*,
        c.pedido_id AS compra_origem_id,
        c.created_at AS data_entrada,
        ci.preco_unitario AS custo_reconstruido,
        ROW_NUMBER() OVER (
            PARTITION BY iv.item_id
            ORDER BY c.created_at DESC, c.id DESC
        ) AS ordem
    FROM itens_venda iv
    JOIN public.estoque_movimentacoes c
      ON c.tipo = 'ENTRADA'
     AND c.produto_id = iv.produto_id
     AND c.sabor_id IS NOT DISTINCT FROM iv.sabor_id
     AND c.created_at <= iv.data_venda
    JOIN public.pedidos pc
      ON pc.id = c.pedido_id
     AND pc.tipo_pedido = 'COMPRA'
     AND pc.status = 'FINALIZADO'
    JOIN public.pedido_itens ci
      ON ci.pedido_id = pc.id
     AND ci.produto_id = iv.produto_id
     AND ci.sabor_id IS NOT DISTINCT FROM iv.sabor_id
     AND ci.preco_unitario > 0
)
SELECT
    iv.pedido_id,
    iv.numero_pedido,
    iv.item_id,
    iv.data_venda,
    iv.produto_id,
    pr.nome::text AS produto,
    iv.sabor_id,
    ps.sabor::text AS sabor,
    iv.quantidade,
    iv.custo_gravado,
    cc.compra_origem_id,
    cc.data_entrada,
    cc.custo_reconstruido,
    CASE
        WHEN cc.item_id IS NULL THEN 'SEM_ENTRADA_DE_COMPRA_ANTERIOR'
        ELSE 'PRONTO_PARA_RECONSTRUIR'
    END AS situacao
FROM itens_venda iv
LEFT JOIN custos_candidatos cc ON cc.item_id = iv.item_id AND cc.ordem = 1
JOIN public.produtos pr ON pr.id = iv.produto_id
LEFT JOIN public.produto_sabores ps ON ps.id = iv.sabor_id
ORDER BY iv.data_venda, iv.numero_pedido, produto, sabor;
$$;

CREATE OR REPLACE FUNCTION public.recompor_custos_historicos_vendas()
RETURNS TABLE (
    itens_atualizados bigint,
    itens_sem_entrada_anterior bigint,
    custo_total_gravado numeric
)
LANGUAGE plpgsql
AS $$
BEGIN
    WITH auditoria AS (
        SELECT * FROM public.auditar_custos_historicos_vendas()
    ), atualizados AS (
        UPDATE public.pedido_itens pi
           SET preco_compra_entrada = a.custo_reconstruido
          FROM auditoria a
         WHERE pi.id = a.item_id
           AND a.situacao = 'PRONTO_PARA_RECONSTRUIR'
           AND COALESCE(pi.preco_compra_entrada, 0) <= 0
         RETURNING pi.id, pi.preco_compra_entrada
    )
    SELECT
        (SELECT COUNT(*) FROM atualizados),
        (SELECT COUNT(*) FROM auditoria WHERE situacao = 'SEM_ENTRADA_DE_COMPRA_ANTERIOR'),
        COALESCE((SELECT SUM(preco_compra_entrada) FROM atualizados), 0)
    INTO itens_atualizados, itens_sem_entrada_anterior, custo_total_gravado;

    RETURN NEXT;
END;
$$;

-- ETAPA 1 — execute e valide a amostra e os itens sem entrada anterior:
-- SELECT * FROM public.auditar_custos_historicos_vendas();
--
-- ETAPA 2 — somente após validar a etapa 1, grave os custos reconstruídos:
-- SELECT * FROM public.recompor_custos_historicos_vendas();
