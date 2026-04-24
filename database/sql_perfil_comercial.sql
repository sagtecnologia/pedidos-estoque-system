ALTER TABLE public.users
DROP CONSTRAINT IF EXISTS users_role_check;

ALTER TABLE public.users
ADD CONSTRAINT users_role_check
CHECK (
    (role)::text = ANY (
        (
            ARRAY[
                'ADMIN'::character varying,
                'COMPRADOR'::character varying,
                'APROVADOR'::character varying,
                'VENDEDOR'::character varying,
                'COMERCIAL'::character varying
            ]
        )::text[]
    )
);

COMMENT ON COLUMN public.users."role" IS
'Perfil do usuario: ADMIN (acesso total), COMPRADOR (pedidos), VENDEDOR (vendas), APROVADOR (aprovar pedidos), COMERCIAL (clientes, produtos, pedidos de compra, vendas e pre-pedidos sem custo/lucro).';
