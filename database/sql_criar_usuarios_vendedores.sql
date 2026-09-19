-- =====================================================================
-- CRIACAO DOS USUARIOS VENDEDORES (sem validacao de email)
-- =====================================================================
-- Aplique no Supabase SQL Editor DEPOIS de:
--   1. sql_comissao_vendedor.sql
--   2. sql_admin_criar_usuario.sql
--
-- Este script apenas CHAMA public.admin_criar_usuario() — toda a logica de
-- criar em auth.users com email ja confirmado vive la, em um lugar so.
-- Cadastrar novos usuarios daqui pra frente nao precisa mais de SQL: a tela
-- Usuarios > Novo Usuario usa exatamente a mesma funcao.
--
-- USUARIOS CRIADOS
--   renata@gmail.com    senha: Renata@2026     perfil VENDEDOR
--   pequipod@gmail.com  senha: Pequipod@2026   perfil VENDEDOR
--
--   >>> Peca para os dois trocarem a senha apos o primeiro login. <<<
--   (Usuarios > Editar > Nova Senha, por um ADMIN.)
--
-- Comissao comeca zerada de proposito: quem define o valor de cada vendedor
-- e o ADMIN, pela tela de Usuarios.
--
-- Idempotente: se o email ja existir, apenas reaplica a senha e garante que
-- o perfil esta VENDEDOR/ativo com o email confirmado.
-- =====================================================================

DO $$
DECLARE
    v_conta   RECORD;
    v_user_id uuid;
BEGIN
    FOR v_conta IN
        SELECT *
        FROM (VALUES
            ('renata@gmail.com',   'Renata@2026',   'Renata'),
            ('pequipod@gmail.com', 'Pequipod@2026', 'Pequipod')
        ) AS t(email, senha, nome)
    LOOP
        SELECT id INTO v_user_id
          FROM auth.users
         WHERE lower(email) = lower(v_conta.email);

        IF v_user_id IS NULL THEN
            v_user_id := public.admin_criar_usuario(
                p_email          => v_conta.email,
                p_senha          => v_conta.senha,
                p_nome           => v_conta.nome,
                p_role           => 'VENDEDOR',
                p_whatsapp       => NULL,
                p_ativo          => true,
                p_comissao_tipo  => 'PERCENTUAL',
                p_comissao_valor => 0
            );
            RAISE NOTICE 'Usuario criado: % (%)', v_conta.email, v_user_id;
        ELSE
            -- Ja existia (ex.: tentativa anterior pela tela antiga, que podia
            -- deixar o usuario preso esperando confirmacao de email).
            UPDATE auth.users
               SET encrypted_password       = extensions.crypt(v_conta.senha, extensions.gen_salt('bf')),
                   email_confirmed_at       = COALESCE(email_confirmed_at, now()),
                   updated_at               = now(),
                   recovery_token           = '',
                   recovery_sent_at         = NULL,
                   reauthentication_token   = '',
                   reauthentication_sent_at = NULL
             WHERE id = v_user_id;

            -- Garante a identity: sem ela o login falha com
            -- "Invalid login credentials" mesmo com a senha correta.
            INSERT INTO auth.identities (
                id, user_id, provider_id, identity_data, provider,
                last_sign_in_at, created_at, updated_at
            )
            SELECT gen_random_uuid(), v_user_id, v_user_id::text,
                   jsonb_build_object(
                       'sub', v_user_id::text,
                       'email', lower(v_conta.email),
                       'email_verified', true,
                       'phone_verified', false
                   ),
                   'email', now(), now(), now()
             WHERE NOT EXISTS (
                SELECT 1 FROM auth.identities
                 WHERE user_id = v_user_id AND provider = 'email'
             );

            INSERT INTO public.users (id, email, full_name, role, active)
            VALUES (v_user_id, lower(v_conta.email), v_conta.nome, 'VENDEDOR', true)
            ON CONFLICT (id) DO UPDATE
               SET role   = 'VENDEDOR',
                   active = true;

            RAISE NOTICE 'Usuario ja existia, senha e acesso redefinidos: % (%)', v_conta.email, v_user_id;
        END IF;
    END LOOP;
END;
$$;


-- ---------------------------------------------------------------------
-- CONFERENCIA
-- ---------------------------------------------------------------------
SELECT u.email,
       u.full_name,
       u.role,
       u.active,
       u.comissao_tipo,
       u.comissao_valor,
       au.email_confirmed_at IS NOT NULL AS email_confirmado,
       (SELECT count(*) FROM auth.identities i WHERE i.user_id = u.id) AS identities
  FROM public.users u
  JOIN auth.users au ON au.id = u.id
 WHERE u.email IN ('renata@gmail.com', 'pequipod@gmail.com');
