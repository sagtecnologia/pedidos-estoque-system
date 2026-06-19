-- =====================================================
-- PRECOS PUBLICOS: VAREJO E ATACADO
-- Proposito: adicionar dois novos precos de venda no cadastro do produto
--            e expor esses valores nas views usadas pelos links publicos.
-- Aplique este SQL no Supabase SQL Editor.
-- =====================================================

ALTER TABLE public.produtos
ADD COLUMN IF NOT EXISTS preco_varejo numeric(10, 2) DEFAULT 0;

ALTER TABLE public.produtos
ADD COLUMN IF NOT EXISTS preco_atacado numeric(10, 2) DEFAULT 0;

ALTER TABLE public.pre_pedido_itens
ADD COLUMN IF NOT EXISTS tipo_preco varchar(20);

ALTER TABLE public.pedido_itens
ADD COLUMN IF NOT EXISTS tipo_preco varchar(20);

UPDATE public.pre_pedido_itens
   SET tipo_preco = 'venda'
 WHERE tipo_preco IS NULL;

UPDATE public.pedido_itens
   SET tipo_preco = 'venda'
 WHERE tipo_preco IS NULL;

ALTER TABLE public.pre_pedido_itens
ALTER COLUMN tipo_preco SET DEFAULT 'venda';

ALTER TABLE public.pedido_itens
ALTER COLUMN tipo_preco SET DEFAULT 'venda';

ALTER TABLE public.pre_pedido_itens
ALTER COLUMN tipo_preco SET NOT NULL;

ALTER TABLE public.pedido_itens
ALTER COLUMN tipo_preco SET NOT NULL;

ALTER TABLE public.pre_pedido_itens
DROP CONSTRAINT IF EXISTS pre_pedido_itens_tipo_preco_check;

ALTER TABLE public.pre_pedido_itens
ADD CONSTRAINT pre_pedido_itens_tipo_preco_check
CHECK (tipo_preco IN ('venda', 'varejo', 'atacado'));

ALTER TABLE public.pedido_itens
DROP CONSTRAINT IF EXISTS pedido_itens_tipo_preco_check;

ALTER TABLE public.pedido_itens
ADD CONSTRAINT pedido_itens_tipo_preco_check
CHECK (tipo_preco IN ('venda', 'varejo', 'atacado'));

CREATE OR REPLACE VIEW public.vw_produtos_publicos
AS SELECT id,
    codigo,
    marca,
    nome,
    unidade,
    preco_venda,
    estoque_atual,
    estoque_minimo,
        CASE
            WHEN estoque_atual = 0::numeric THEN 'ZERADO'::text
            WHEN estoque_atual <= estoque_minimo THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS status_estoque,
    COALESCE(preco_varejo, 0::numeric) AS preco_varejo,
    COALESCE(preco_atacado, 0::numeric) AS preco_atacado
   FROM produtos p
  WHERE active = true AND estoque_atual > 0::numeric
  ORDER BY marca, nome;

ALTER TABLE public.vw_produtos_publicos OWNER TO postgres;
GRANT ALL ON TABLE public.vw_produtos_publicos TO postgres;
GRANT ALL ON TABLE public.vw_produtos_publicos TO anon;
GRANT ALL ON TABLE public.vw_produtos_publicos TO authenticated;
GRANT ALL ON TABLE public.vw_produtos_publicos TO service_role;

CREATE OR REPLACE VIEW public.vw_sabores_publicos
AS SELECT s.id,
    s.produto_id,
    s.sabor,
    s.quantidade,
    p.preco_venda,
    p.estoque_minimo,
    p.marca,
    p.nome AS produto_nome,
    p.codigo AS produto_codigo,
        CASE
            WHEN s.quantidade = 0::numeric THEN 'ZERADO'::text
            WHEN s.quantidade <= p.estoque_minimo THEN 'BAIXO'::text
            ELSE 'OK'::text
        END AS status_estoque,
    COALESCE(p.preco_varejo, 0::numeric) AS preco_varejo,
    COALESCE(p.preco_atacado, 0::numeric) AS preco_atacado
   FROM produto_sabores s
     JOIN produtos p ON p.id = s.produto_id
  WHERE s.ativo = true AND p.active = true AND s.quantidade > 0::numeric
  ORDER BY p.marca, p.nome, s.sabor;

ALTER TABLE public.vw_sabores_publicos OWNER TO postgres;
GRANT ALL ON TABLE public.vw_sabores_publicos TO postgres;
GRANT ALL ON TABLE public.vw_sabores_publicos TO anon;
GRANT ALL ON TABLE public.vw_sabores_publicos TO authenticated;
GRANT ALL ON TABLE public.vw_sabores_publicos TO service_role;
