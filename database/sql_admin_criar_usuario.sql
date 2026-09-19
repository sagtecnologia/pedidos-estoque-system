-- =====================================================================
-- ADMIN CRIA USUARIO JA LIBERADO (sem confirmacao de email)
-- =====================================================================
-- Aplique no Supabase SQL Editor DEPOIS de sql_comissao_vendedor.sql.
-- Idempotente (CREATE OR REPLACE).
--
-- PROBLEMA QUE ESTA FUNCAO RESOLVE
--   A tela /pages/usuarios.html criava o usuario via supabase.auth.signUp(),
--   que respeita a opcao "Confirm email" do projeto. Como os emails usados
--   aqui sao apenas credencial de login (nao sao caixas reais), o usuario
--   nascia travado esperando um email que nunca seria aberto.
--
--   Esta funcao cria o usuario direto em auth.users com email_confirmed_at
--   preenchido: ele ja entra no sistema com email e senha, sem confirmacao.
--
-- SEGURANCA
--   SECURITY DEFINER, mas so executa se quem chamou for ADMIN em
--   public.users. Mesmo padrao ja usado em admin_update_user_password().
--   O cadastro publico (register.html) NAO passa por aqui e continua
--   exigindo confirmacao e aprovacao normalmente.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.admin_criar_usuario(
    p_email          text,
    p_senha          text,
    p_nome           text,
    p_role           text,
    p_whatsapp       text    DEFAULT NULL,
    p_ativo          boolean DEFAULT true,
    p_comissao_tipo  text    DEFAULT 'PERCENTUAL',
    p_comissao_valor numeric DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_email   text := lower(trim(p_email));
    v_user_id uuid;
BEGIN
    -- ---------------- validacao de quem chamou ----------------
    -- auth.uid() nulo = SQL Editor / service_role, que ja pode tudo no banco.
    -- Vindo do app (JWT presente), so ADMIN passa.
    IF auth.uid() IS NOT NULL
       AND public.current_app_user_role() IS DISTINCT FROM 'ADMIN' THEN
        RAISE EXCEPTION 'Apenas administradores podem cadastrar usuarios.'
            USING ERRCODE = '42501';
    END IF;

    -- ---------------- validacao dos dados ----------------
    IF v_email IS NULL OR v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' THEN
        RAISE EXCEPTION 'Email invalido: %', p_email;
    END IF;

    IF p_senha IS NULL OR length(p_senha) < 6 THEN
        RAISE EXCEPTION 'A senha deve ter pelo menos 6 caracteres.';
    END IF;

    IF p_nome IS NULL OR length(trim(p_nome)) = 0 THEN
        RAISE EXCEPTION 'O nome e obrigatorio.';
    END IF;

    IF p_role NOT IN ('ADMIN', 'COMPRADOR', 'APROVADOR', 'VENDEDOR', 'COMERCIAL') THEN
        RAISE EXCEPTION 'Perfil invalido: %', p_role;
    END IF;

    IF EXISTS (SELECT 1 FROM auth.users WHERE lower(email) = v_email)
       OR EXISTS (SELECT 1 FROM public.users WHERE lower(email) = v_email) THEN
        RAISE EXCEPTION 'Ja existe um usuario com o email %.', v_email;
    END IF;

    -- ---------------- auth.users (email ja confirmado) ----------------
    v_user_id := gen_random_uuid();

    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password,
        email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
        created_at, updated_at,
        confirmation_token, recovery_token,
        email_change_token_new, email_change_token_current, email_change
    ) VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        v_email,
        extensions.crypt(p_senha, extensions.gen_salt('bf')),
        now(),                                   -- <<< sem confirmacao de email
        '{"provider":"email","providers":["email"]}'::jsonb,
        jsonb_build_object('full_name', trim(p_nome), 'role', p_role),
        now(), now(),
        '', '', '', '', ''
    );

    -- Sem a identity o GoTrue nao associa o provedor "email" e o login
    -- falha com "Invalid login credentials".
    INSERT INTO auth.identities (
        id, user_id, provider_id, identity_data, provider,
        last_sign_in_at, created_at, updated_at
    ) VALUES (
        gen_random_uuid(),
        v_user_id,
        v_user_id::text,
        jsonb_build_object(
            'sub', v_user_id::text,
            'email', v_email,
            'email_verified', true,
            'phone_verified', false
        ),
        'email',
        now(), now(), now()
    );

    -- ---------------- perfil da aplicacao ----------------
    -- A comissao passa pelo trigger trg_users_proteger_comissao; como quem
    -- chamou e ADMIN, o valor informado e aceito.
    INSERT INTO public.users (
        id, email, full_name, role, whatsapp, active,
        comissao_tipo, comissao_valor
    ) VALUES (
        v_user_id, v_email, trim(p_nome), p_role, p_whatsapp, coalesce(p_ativo, true),
        coalesce(p_comissao_tipo, 'PERCENTUAL'), coalesce(p_comissao_valor, 0)
    );

    RETURN v_user_id;
END;
$$;

COMMENT ON FUNCTION public.admin_criar_usuario(text, text, text, text, text, boolean, text, numeric) IS
'ADMIN cadastra um usuario ja com email confirmado e pronto para login. Usada pela tela de Usuarios no lugar de auth.signUp().';

REVOKE ALL ON FUNCTION public.admin_criar_usuario(text, text, text, text, text, boolean, text, numeric) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.admin_criar_usuario(text, text, text, text, text, boolean, text, numeric) TO authenticated;


-- ---------------------------------------------------------------------
-- CONFERENCIA
-- ---------------------------------------------------------------------
-- Depois de cadastrar alguem pela tela, confirme que ele nasceu liberado:
--
--   SELECT u.email, u.role, u.active,
--          au.email_confirmed_at IS NOT NULL AS email_confirmado,
--          (SELECT count(*) FROM auth.identities i WHERE i.user_id = u.id) AS identities
--     FROM public.users u
--     JOIN auth.users au ON au.id = u.id
--    ORDER BY u.created_at DESC
--    LIMIT 5;
