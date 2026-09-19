-- =====================================================================
-- COMISSAO DE VENDEDOR
-- =====================================================================
-- Aplique este SQL no Supabase SQL Editor (uma unica vez).
-- O script e idempotente: pode ser reaplicado sem efeito colateral.
--
-- O QUE ELE FAZ
--   1. Cadastro da comissao no usuario (users.comissao_tipo / comissao_valor).
--   2. Trava de banco: SOMENTE ADMIN altera comissao. Nao depende do
--      frontend — hoje as tabelas public.* nao tem RLS ligada e qualquer
--      usuario autenticado consegue dar UPDATE em public.users pela API.
--   3. Congelamento da comissao no pedido de venda no momento em que ele e
--      FINALIZADO (pedidos.comissao_tipo / comissao_valor / comissao_total).
--      Mesma filosofia ja usada em pedido_itens.preco_compra_entrada: mudar a
--      comissao do vendedor hoje NAO pode reescrever o lucro de meses passados.
--
-- REGRA DE CALCULO (definida com o cliente)
--   PERCENTUAL -> comissao = total da venda * valor / 100
--   UNIDADE    -> comissao = soma das quantidades dos itens * valor
--   Em ambos os casos a comissao e rateavel item a item de forma exata,
--   o que permite a analise financeira filtrar por marca/produto/sabor
--   sem distorcer o numero.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. CADASTRO DA COMISSAO NO USUARIO
-- ---------------------------------------------------------------------

ALTER TABLE public.users
    ADD COLUMN IF NOT EXISTS comissao_tipo  varchar(12)    NOT NULL DEFAULT 'PERCENTUAL',
    ADD COLUMN IF NOT EXISTS comissao_valor numeric(12, 4) NOT NULL DEFAULT 0;

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_comissao_tipo_check;

ALTER TABLE public.users
    ADD CONSTRAINT users_comissao_tipo_check
    CHECK (comissao_tipo IN ('PERCENTUAL', 'UNIDADE'));

ALTER TABLE public.users
    DROP CONSTRAINT IF EXISTS users_comissao_valor_check;

-- Percentual acima de 100% quase sempre e erro de digitacao (ex.: digitar 500
-- pensando em R$ 5,00 por unidade). Valor nunca pode ser negativo.
ALTER TABLE public.users
    ADD CONSTRAINT users_comissao_valor_check
    CHECK (
        comissao_valor >= 0
        AND (comissao_tipo <> 'PERCENTUAL' OR comissao_valor <= 100)
    );

COMMENT ON COLUMN public.users.comissao_tipo IS
'Como a comissao do vendedor e calculada: PERCENTUAL (% sobre o valor da venda) ou UNIDADE (R$ fixo por unidade vendida). Somente ADMIN altera.';

COMMENT ON COLUMN public.users.comissao_valor IS
'Valor da comissao. Se comissao_tipo = PERCENTUAL, e o percentual (ex.: 5 = 5%). Se UNIDADE, e o valor em R$ por unidade vendida. Zero = sem comissao. Somente ADMIN altera.';


-- ---------------------------------------------------------------------
-- 2. TRAVA: SOMENTE ADMIN ALTERA COMISSAO
-- ---------------------------------------------------------------------
-- current_app_user_role() ja existe (criada em sql_rls_perfil_comercial.sql).
-- Recriada aqui com CREATE OR REPLACE para que este script seja autonomo.

CREATE OR REPLACE FUNCTION public.current_app_user_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT u.role
    FROM public.users u
    WHERE u.id = auth.uid()
    LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.current_app_user_role() TO authenticated;


CREATE OR REPLACE FUNCTION public.users_proteger_comissao()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
    v_role text;
BEGIN
    -- auth.uid() nulo = service_role, SQL Editor ou rotina interna.
    -- Nesses contextos a alteracao e permitida (e como o ADMIN opera fora do app).
    IF auth.uid() IS NULL THEN
        RETURN NEW;
    END IF;

    v_role := public.current_app_user_role();

    IF TG_OP = 'INSERT' THEN
        -- O auto-cadastro (register.html) insere a propria linha em public.users.
        -- Quem nao e ADMIN nunca define a propria comissao: cai no padrao.
        IF v_role IS DISTINCT FROM 'ADMIN' THEN
            NEW.comissao_tipo  := 'PERCENTUAL';
            NEW.comissao_valor := 0;
        END IF;
        RETURN NEW;
    END IF;

    IF (NEW.comissao_tipo, NEW.comissao_valor) IS DISTINCT FROM (OLD.comissao_tipo, OLD.comissao_valor)
       AND v_role IS DISTINCT FROM 'ADMIN' THEN
        RAISE EXCEPTION 'Apenas administradores podem alterar a comissao do vendedor.'
            USING ERRCODE = '42501';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.users_proteger_comissao() IS
'Impede que usuarios nao-ADMIN alterem users.comissao_tipo / users.comissao_valor, inclusive por chamada direta na API (as tabelas public.* nao tem RLS ligada).';

DROP TRIGGER IF EXISTS trg_users_proteger_comissao ON public.users;
CREATE TRIGGER trg_users_proteger_comissao
    BEFORE INSERT OR UPDATE ON public.users
    FOR EACH ROW
    EXECUTE FUNCTION public.users_proteger_comissao();


-- ---------------------------------------------------------------------
-- 3. COMISSAO CONGELADA NO PEDIDO DE VENDA
-- ---------------------------------------------------------------------

ALTER TABLE public.pedidos
    ADD COLUMN IF NOT EXISTS comissao_tipo         varchar(12)    NULL,
    ADD COLUMN IF NOT EXISTS comissao_valor        numeric(12, 4) NULL,
    ADD COLUMN IF NOT EXISTS comissao_total        numeric(12, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS comissao_vendedor_id  uuid           NULL,
    ADD COLUMN IF NOT EXISTS comissao_calculada_em timestamptz    NULL;

ALTER TABLE public.pedidos
    DROP CONSTRAINT IF EXISTS pedidos_comissao_tipo_check;

ALTER TABLE public.pedidos
    ADD CONSTRAINT pedidos_comissao_tipo_check
    CHECK (comissao_tipo IS NULL OR comissao_tipo IN ('PERCENTUAL', 'UNIDADE'));

ALTER TABLE public.pedidos
    DROP CONSTRAINT IF EXISTS pedidos_comissao_vendedor_id_fkey;

ALTER TABLE public.pedidos
    ADD CONSTRAINT pedidos_comissao_vendedor_id_fkey
    FOREIGN KEY (comissao_vendedor_id) REFERENCES public.users(id);

CREATE INDEX IF NOT EXISTS idx_pedidos_comissao_vendedor
    ON public.pedidos (comissao_vendedor_id);

COMMENT ON COLUMN public.pedidos.comissao_tipo IS
'Copia congelada de users.comissao_tipo no momento em que a venda foi FINALIZADA. NULL = venda anterior ao recurso de comissao.';

COMMENT ON COLUMN public.pedidos.comissao_valor IS
'Copia congelada de users.comissao_valor no momento em que a venda foi FINALIZADA. Alterar a comissao do vendedor depois NAO muda este valor.';

COMMENT ON COLUMN public.pedidos.comissao_total IS
'Comissao em R$ devida ao vendedor por esta venda. Entra como custo na analise financeira.';

COMMENT ON COLUMN public.pedidos.comissao_vendedor_id IS
'Vendedor que recebe a comissao (copia de solicitante_id no momento da finalizacao).';


-- Calculo puro da comissao. Isolado para que frontend e banco nunca divirjam.
CREATE OR REPLACE FUNCTION public.calcular_comissao(
    p_tipo        text,
    p_valor       numeric,
    p_total_venda numeric,
    p_quantidade  numeric
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_tipo IS NULL OR COALESCE(p_valor, 0) <= 0 THEN 0::numeric
        WHEN p_tipo = 'PERCENTUAL' THEN ROUND(COALESCE(p_total_venda, 0) * p_valor / 100, 2)
        WHEN p_tipo = 'UNIDADE'    THEN ROUND(COALESCE(p_quantidade, 0)  * p_valor, 2)
        ELSE 0::numeric
    END;
$$;

COMMENT ON FUNCTION public.calcular_comissao(text, numeric, numeric, numeric) IS
'Calculo unico da comissao. PERCENTUAL incide sobre o valor da venda; UNIDADE multiplica a quantidade vendida.';


CREATE OR REPLACE FUNCTION public.pedidos_aplicar_comissao()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_quantidade    numeric;
    v_ja_finalizado boolean := false;
BEGIN
    -- Comissao so existe em VENDA. Compra nunca gera comissao.
    IF NEW.tipo_pedido IS DISTINCT FROM 'VENDA' THEN
        NEW.comissao_total := 0;
        RETURN NEW;
    END IF;

    -- Venda que deixa de estar FINALIZADA (cancelamento, reabertura) nao gera
    -- custo de comissao. O snapshot da regra e mantido para auditoria.
    IF NEW.status IS DISTINCT FROM 'FINALIZADO' THEN
        NEW.comissao_total := 0;
        RETURN NEW;
    END IF;

    -- OLD nao existe em INSERT, por isso o teste do TG_OP vem isolado:
    -- PL/pgSQL nao garante curto-circuito dentro de uma mesma expressao.
    IF TG_OP = 'UPDATE' AND OLD.status = 'FINALIZADO' THEN
        v_ja_finalizado := true;
    END IF;

    -- Transicao para FINALIZADO: congela a regra vigente do vendedor.
    IF NOT v_ja_finalizado THEN
        SELECT u.comissao_tipo, u.comissao_valor, u.id
          INTO NEW.comissao_tipo, NEW.comissao_valor, NEW.comissao_vendedor_id
          FROM public.users u
         WHERE u.id = NEW.solicitante_id;

        NEW.comissao_calculada_em := now();
    END IF;

    -- Se a venda ja estava FINALIZADA, a regra congelada acima e reaproveitada
    -- e o valor e apenas recalculado. O recalculo acontece em todo UPDATE, e
    -- nao so quando pedidos.total muda: no tipo UNIDADE a comissao depende da
    -- quantidade de itens, que pode mudar sem alterar o total da venda.
    -- O recalculo e idempotente e so consulta pedido_itens no tipo UNIDADE.

    IF NEW.comissao_tipo = 'UNIDADE' THEN
        SELECT COALESCE(SUM(pi.quantidade), 0)
          INTO v_quantidade
          FROM public.pedido_itens pi
         WHERE pi.pedido_id = NEW.id;
    ELSE
        v_quantidade := 0;
    END IF;

    NEW.comissao_total := public.calcular_comissao(
        NEW.comissao_tipo,
        NEW.comissao_valor,
        NEW.total,
        v_quantidade
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.pedidos_aplicar_comissao() IS
'Congela a regra de comissao do vendedor quando a venda e FINALIZADA e mantem pedidos.comissao_total coerente com o total da venda.';

DROP TRIGGER IF EXISTS trg_pedidos_aplicar_comissao ON public.pedidos;
CREATE TRIGGER trg_pedidos_aplicar_comissao
    BEFORE INSERT OR UPDATE ON public.pedidos
    FOR EACH ROW
    EXECUTE FUNCTION public.pedidos_aplicar_comissao();


-- ---------------------------------------------------------------------
-- 4. CONFERENCIA
-- ---------------------------------------------------------------------
-- Rode depois de aplicar, para ver a comissao configurada por vendedor:
--
--   SELECT full_name, role, comissao_tipo, comissao_valor
--     FROM public.users
--    WHERE role IN ('VENDEDOR', 'COMERCIAL', 'ADMIN')
--    ORDER BY full_name;
--
-- E para conferir as comissoes ja congeladas nas vendas finalizadas:
--
--   SELECT p.numero, u.full_name AS vendedor, p.total,
--          p.comissao_tipo, p.comissao_valor, p.comissao_total
--     FROM public.pedidos p
--     LEFT JOIN public.users u ON u.id = p.comissao_vendedor_id
--    WHERE p.tipo_pedido = 'VENDA'
--      AND p.status = 'FINALIZADO'
--    ORDER BY p.created_at DESC
--    LIMIT 50;
--
-- Vendas ja finalizadas antes desta migracao ficam com comissao_total = 0
-- (decisao do cliente: comissao vale so daqui pra frente).
