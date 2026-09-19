-- =====================================================================
-- TESTES DE sql_estoque_reserva.sql
-- =====================================================================
-- Rode isto DEPOIS de aplicar sql_estoque_reserva.sql, inteiro, de uma
-- vez, no SQL Editor do Supabase. Tudo aqui roda dentro de uma única
-- transação que termina em ROLLBACK — ou seja, nenhum dado de teste
-- fica gravado, mesmo se todos os testes passarem. Se algum teste
-- falhar, a mensagem de erro aparece no resultado e a transação também
-- é desfeita automaticamente (erro em transação = rollback).
--
-- Não precisa editar nada: o script pega um usuário ADMIN existente
-- para simular a sessão autenticada (via request.jwt.claim.sub, que é
-- o que auth.uid() lê) e cria produtos/sabores/estoque de teste com
-- nomes óbvios ("TESTE-RESERVA-...") só para a duração da transação.
--
-- O que é validado:
--   1. Caminho feliz: mover para reserva e devolver, produto com sabor.
--   2. Caminho feliz: mover e devolver, produto SEM sabor.
--   3. Bloqueio: produto com sabor exige p_sabor_id.
--   4. Bloqueio: não deixa mover mais do que o disponível.
--   5. Bloqueio: não deixa devolver mais do que está na reserva.
--   6. Bloqueio: não autenticado / não-admin não conseguem executar.
--   7. Saldo final bate exatamente com o saldo inicial após ida e volta.
--   8. remover_sabor_produto() passa a bloquear remoção com saldo em reserva.
-- =====================================================================

BEGIN;

DO $teste$
DECLARE
    v_admin_id uuid;
    v_produto_sabor_id uuid;
    v_sabor_id uuid;
    v_produto_simples_id uuid;
    v_estoque_id uuid;
    v_resultado record;
    v_estoque_atual_check numeric;
BEGIN
    -- -------------------------------------------------------------
    -- SETUP
    -- -------------------------------------------------------------
    SELECT id INTO v_admin_id FROM public.users WHERE role = 'ADMIN' LIMIT 1;
    IF v_admin_id IS NULL THEN
        RAISE EXCEPTION 'TESTE ABORTADO: nenhum usuário com role=ADMIN encontrado em public.users.';
    END IF;

    -- Faz auth.uid() devolver este ADMIN pelo resto da transação.
    PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);

    INSERT INTO public.produtos (codigo, nome, unidade, estoque_atual, active)
    VALUES ('TESTE-RESERVA-SABOR', 'Produto Teste Com Sabor', 'UN', 0, true)
    RETURNING id INTO v_produto_sabor_id;

    INSERT INTO public.produto_sabores (produto_id, sabor, quantidade, ativo)
    VALUES (v_produto_sabor_id, 'Sabor Teste', 100, true)
    RETURNING id INTO v_sabor_id;

    INSERT INTO public.produtos (codigo, nome, unidade, estoque_atual, active)
    VALUES ('TESTE-RESERVA-SIMPLES', 'Produto Teste Sem Sabor', 'UN', 50, true)
    RETURNING id INTO v_produto_simples_id;

    SELECT estoque_atual INTO v_estoque_atual_check FROM public.produtos WHERE id = v_produto_sabor_id;
    IF v_estoque_atual_check <> 100 THEN
        RAISE EXCEPTION 'SETUP FALHOU: trigger atualizar_estoque_produto não somou o sabor (esperado 100, veio %)', v_estoque_atual_check;
    END IF;

    SELECT * INTO v_resultado FROM public.criar_estoque_reserva('TESTE-RESERVA-Depósito', 'Estoque de teste') AS t;
    IF NOT v_resultado.sucesso THEN
        RAISE EXCEPTION 'SETUP FALHOU: criar_estoque_reserva() retornou sucesso=false: %', v_resultado.mensagem;
    END IF;
    v_estoque_id := v_resultado.estoque_id;

    RAISE NOTICE '✓ Setup ok. produto_sabor=% sabor=% produto_simples=% estoque=%', v_produto_sabor_id, v_sabor_id, v_produto_simples_id, v_estoque_id;

    -- -------------------------------------------------------------
    -- TESTE 3: produto com sabor exige p_sabor_id
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 10, NULL, 'sem sabor') AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 3 FALHOU: deveria exigir sabor_id e não exigiu';
    END IF;
    RAISE NOTICE '✓ TESTE 3 ok: % ', v_resultado.mensagem;

    -- -------------------------------------------------------------
    -- TESTE 4: não deixa mover mais do que o disponível
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 999, v_sabor_id, 'excede') AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 4 FALHOU: deveria bloquear quantidade maior que o disponível';
    END IF;
    RAISE NOTICE '✓ TESTE 4 ok: %', v_resultado.mensagem;

    -- -------------------------------------------------------------
    -- TESTE 1a: caminho feliz - mover 30 do sabor para a reserva
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 30, v_sabor_id, 'teste 1a') AS t;
    IF NOT v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 1a FALHOU: %', v_resultado.mensagem;
    END IF;
    IF v_resultado.saldo_principal_novo <> 70 OR v_resultado.saldo_reserva_novo <> 30 THEN
        RAISE EXCEPTION 'TESTE 1a FALHOU: esperado principal=70/reserva=30, veio principal=%/reserva=%', v_resultado.saldo_principal_novo, v_resultado.saldo_reserva_novo;
    END IF;
    IF (SELECT quantidade FROM public.produto_sabores WHERE id = v_sabor_id) <> 70 THEN
        RAISE EXCEPTION 'TESTE 1a FALHOU: produto_sabores.quantidade não ficou em 70';
    END IF;
    IF (SELECT estoque_atual FROM public.produtos WHERE id = v_produto_sabor_id) <> 70 THEN
        RAISE EXCEPTION 'TESTE 1a FALHOU: produtos.estoque_atual não foi recalculado para 70';
    END IF;
    RAISE NOTICE '✓ TESTE 1a ok: %', v_resultado.mensagem;

    -- -------------------------------------------------------------
    -- TESTE 5: não deixa devolver mais do que está na reserva
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.retornar_estoque_reserva(v_produto_sabor_id, v_estoque_id, 999, v_sabor_id, 'excede retorno') AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 5 FALHOU: deveria bloquear devolução maior que o saldo em reserva';
    END IF;
    RAISE NOTICE '✓ TESTE 5 ok: %', v_resultado.mensagem;

    -- -------------------------------------------------------------
    -- TESTE 1b: caminho feliz - devolve os 30 de volta ao principal
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.retornar_estoque_reserva(v_produto_sabor_id, v_estoque_id, 30, v_sabor_id, 'teste 1b') AS t;
    IF NOT v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 1b FALHOU: %', v_resultado.mensagem;
    END IF;
    IF v_resultado.saldo_principal_novo <> 100 OR v_resultado.saldo_reserva_novo <> 0 THEN
        RAISE EXCEPTION 'TESTE 1b FALHOU: esperado principal=100/reserva=0, veio principal=%/reserva=%', v_resultado.saldo_principal_novo, v_resultado.saldo_reserva_novo;
    END IF;
    RAISE NOTICE '✓ TESTE 1b ok: saldo voltou exatamente ao valor original (100)';

    -- -------------------------------------------------------------
    -- TESTE 2: caminho feliz completo com produto SEM sabor
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_simples_id, v_estoque_id, 20, NULL, 'teste 2 ida') AS t;
    IF NOT v_resultado.sucesso OR v_resultado.saldo_principal_novo <> 30 OR v_resultado.saldo_reserva_novo <> 20 THEN
        RAISE EXCEPTION 'TESTE 2 (ida) FALHOU: sucesso=% principal=% reserva=% mensagem=%', v_resultado.sucesso, v_resultado.saldo_principal_novo, v_resultado.saldo_reserva_novo, v_resultado.mensagem;
    END IF;

    SELECT * INTO v_resultado FROM public.retornar_estoque_reserva(v_produto_simples_id, v_estoque_id, 20, NULL, 'teste 2 volta') AS t;
    IF NOT v_resultado.sucesso OR v_resultado.saldo_principal_novo <> 50 OR v_resultado.saldo_reserva_novo <> 0 THEN
        RAISE EXCEPTION 'TESTE 2 (volta) FALHOU: sucesso=% principal=% reserva=% mensagem=%', v_resultado.sucesso, v_resultado.saldo_principal_novo, v_resultado.saldo_reserva_novo, v_resultado.mensagem;
    END IF;
    RAISE NOTICE '✓ TESTE 2 ok: produto sem sabor foi e voltou corretamente (50 -> 30/20 -> 50/0)';

    -- -------------------------------------------------------------
    -- TESTE 8: remover_sabor_produto() bloqueia com saldo em reserva
    -- -------------------------------------------------------------
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 100, v_sabor_id, 'teste 8: move tudo') AS t;
    IF NOT v_resultado.sucesso OR v_resultado.saldo_principal_novo <> 0 THEN
        RAISE EXCEPTION 'TESTE 8 (setup) FALHOU: %', v_resultado.mensagem;
    END IF;
    -- Agora produto_sabores.quantidade = 0, mas há 100 em estoque_saldos.
    SELECT * INTO v_resultado FROM public.remover_sabor_produto(v_sabor_id, v_produto_sabor_id) AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 8 FALHOU: remover_sabor_produto() deixou remover um sabor com saldo em estoque reserva!';
    END IF;
    RAISE NOTICE '✓ TESTE 8 ok: remoção corretamente bloqueada (%)', v_resultado.mensagem;

    -- devolve para não deixar pendência (embora tudo será desfeito no ROLLBACK)
    PERFORM public.retornar_estoque_reserva(v_produto_sabor_id, v_estoque_id, 100, v_sabor_id, 'teste 8: devolve tudo');

    -- -------------------------------------------------------------
    -- TESTE 6: bloqueio de permissão
    -- -------------------------------------------------------------
    PERFORM set_config('request.jwt.claim.sub', '', true); -- simula não autenticado
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 1, v_sabor_id, 'sem sessao') AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 6a FALHOU: função executou sem usuário autenticado';
    END IF;
    RAISE NOTICE '✓ TESTE 6a ok: bloqueado sem autenticação (%)', v_resultado.mensagem;

    PERFORM set_config('request.jwt.claim.sub', gen_random_uuid()::text, true); -- uuid aleatório, não existe em users
    SELECT * INTO v_resultado FROM public.mover_estoque_para_reserva(v_produto_sabor_id, v_estoque_id, 1, v_sabor_id, 'usuario inexistente') AS t;
    IF v_resultado.sucesso THEN
        RAISE EXCEPTION 'TESTE 6b FALHOU: função executou para um usuário sem role (deveria negar por padrão)';
    END IF;
    RAISE NOTICE '✓ TESTE 6b ok: usuário sem registro em public.users foi negado por padrão (%)', v_resultado.mensagem;

    -- Restaura sessão ADMIN antes de sair (não é obrigatório já que vamos dar ROLLBACK, mas deixa claro).
    PERFORM set_config('request.jwt.claim.sub', v_admin_id::text, true);

    RAISE NOTICE '';
    RAISE NOTICE '════════════════════════════════════════';
    RAISE NOTICE '✅ TODOS OS TESTES PASSARAM';
    RAISE NOTICE '════════════════════════════════════════';
END;
$teste$;

-- Nada do que este script fez fica gravado.
ROLLBACK;
