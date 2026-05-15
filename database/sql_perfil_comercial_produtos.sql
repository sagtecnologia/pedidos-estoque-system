-- Libera cadastro e edicao de produtos para o perfil COMERCIAL.
-- Mantem a exclusao fora do escopo e o bloqueio de preco de compra no frontend.
-- Aplique este SQL no Supabase SQL Editor.

DROP POLICY IF EXISTS comercial_insert_produtos ON public.produtos;
CREATE POLICY comercial_insert_produtos
ON public.produtos
FOR INSERT
TO authenticated
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
);

DROP POLICY IF EXISTS comercial_update_produtos ON public.produtos;
CREATE POLICY comercial_update_produtos
ON public.produtos
FOR UPDATE
TO authenticated
USING (
    public.current_app_user_role() = 'COMERCIAL'
)
WITH CHECK (
    public.current_app_user_role() = 'COMERCIAL'
);
