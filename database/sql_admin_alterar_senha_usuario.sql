-- Permite que ADMIN altere a senha de outro usuário pelo painel.
-- Aplique este SQL no Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.admin_update_user_password(
    p_user_id uuid,
    p_new_password text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_admin_role text;
BEGIN
    SELECT role
    INTO v_admin_role
    FROM public.users
    WHERE id = auth.uid()
    LIMIT 1;

    IF v_admin_role IS DISTINCT FROM 'ADMIN' THEN
        RAISE EXCEPTION 'Apenas administradores podem alterar senhas de usuários.';
    END IF;

    IF p_user_id IS NULL THEN
        RAISE EXCEPTION 'Usuário alvo é obrigatório.';
    END IF;

    IF p_new_password IS NULL OR length(trim(p_new_password)) < 6 THEN
        RAISE EXCEPTION 'A nova senha deve ter pelo menos 6 caracteres.';
    END IF;

    UPDATE auth.users
    SET
        encrypted_password = extensions.crypt(p_new_password, extensions.gen_salt('bf')),
        updated_at = now(),
        recovery_token = '',
        recovery_sent_at = NULL,
        reauthentication_token = '',
        reauthentication_sent_at = NULL
    WHERE id = p_user_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuário não encontrado no Auth.';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.admin_update_user_password(uuid, text) IS
'Permite que ADMIN altere a senha de um usuário diretamente no auth.users.';

GRANT EXECUTE ON FUNCTION public.admin_update_user_password(uuid, text) TO authenticated;
