# 🚀 GUIA DE IMPLANTAÇÃO - Dividir Quantidade de Sabor

## Status: ✅ Pronto para Implantação

Todos os arquivos foram atualizados. Agora você precisa executar a função SQL no seu banco de dados.

---

## 📝 Passo a Passo

### PASSO 1: Acessar o Supabase

1. Abra [https://app.supabase.com](https://app.supabase.com)
2. Selecione seu projeto
3. Clique no menu lateral → **SQL Editor**

### PASSO 2: Executar a Função SQL

**OPÇÃO A: Copiar do arquivo (Recomendado)**

1. Abra o arquivo `database/sql_dividir_sabor.sql`
2. **Copie TODO o conteúdo** (Ctrl+A, Ctrl+C)
3. No Supabase SQL Editor, **Cole** (Ctrl+V)
4. Clique em **"Run"** (Ctrl+Enter ou botão verde)

**OPÇÃO B: Copiar trechos (se preferir)**

1. No Supabase SQL Editor, clique em **"New Query"**
2. Cole este trecho:

```sql
CREATE OR REPLACE FUNCTION public.dividir_sabor_quantidade(
    p_sabor_id uuid,
    p_quantidade_dividir numeric,
    p_novo_sabor character varying,
    p_produto_id uuid,
    p_observacao text DEFAULT ''::text,
    p_usuario_id uuid DEFAULT NULL::uuid
)
 RETURNS TABLE(sucesso boolean, mensagem text, sabor_original character varying, novo_sabor_criado character varying, quantidade_dividida numeric, movimentacao_id uuid)
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_sabor_original VARCHAR(100);
    v_quantidade_atual DECIMAL(10,2);
    v_novo_sabor_id UUID;
    v_novo_sabor_ja_existe UUID;
    v_movimentacao_id UUID;
    v_usuario_id_atual UUID;
BEGIN
    IF p_usuario_id IS NULL THEN
        v_usuario_id_atual := auth.uid();
    ELSE
        v_usuario_id_atual := p_usuario_id;
    END IF;

    SELECT sabor, quantidade INTO v_sabor_original, v_quantidade_atual
    FROM produto_sabores
    WHERE id = p_sabor_id AND produto_id = p_produto_id
    LIMIT 1;

    IF v_sabor_original IS NULL THEN
        RETURN QUERY SELECT false, 'Sabor não encontrado para este produto'::TEXT, NULL, NULL, NULL, NULL;
        RETURN;
    END IF;

    IF p_quantidade_dividir <= 0 THEN
        RETURN QUERY SELECT false, 'A quantidade a dividir deve ser maior que zero'::TEXT, v_sabor_original, p_novo_sabor, NULL, NULL;
        RETURN;
    END IF;

    IF p_quantidade_dividir > v_quantidade_atual THEN
        RETURN QUERY SELECT false, 'Quantidade a dividir não pode ser maior que a quantidade atual (' || v_quantidade_atual || ')'::TEXT, v_sabor_original, p_novo_sabor, NULL, NULL;
        RETURN;
    END IF;

    IF LOWER(TRIM(v_sabor_original)) = LOWER(TRIM(p_novo_sabor)) THEN
        RETURN QUERY SELECT false, 'O novo sabor deve ser diferente do sabor original'::TEXT, v_sabor_original, p_novo_sabor, p_quantidade_dividir, NULL;
        RETURN;
    END IF;

    SELECT id INTO v_novo_sabor_ja_existe
    FROM produto_sabores
    WHERE produto_id = p_produto_id 
      AND LOWER(TRIM(sabor)) = LOWER(TRIM(p_novo_sabor))
    LIMIT 1;

    BEGIN
        IF v_novo_sabor_ja_existe IS NOT NULL THEN
            UPDATE produto_sabores
            SET quantidade = quantidade + p_quantidade_dividir,
                updated_at = NOW()
            WHERE id = v_novo_sabor_ja_existe;

            v_novo_sabor_id := v_novo_sabor_ja_existe;
        ELSE
            INSERT INTO produto_sabores (produto_id, sabor, quantidade, ativo, created_at, updated_at)
            VALUES (p_produto_id, TRIM(p_novo_sabor), p_quantidade_dividir, true, NOW(), NOW())
            RETURNING id INTO v_novo_sabor_id;
        END IF;

        UPDATE produto_sabores
        SET quantidade = quantidade - p_quantidade_dividir,
            updated_at = NOW()
        WHERE id = p_sabor_id;

        INSERT INTO estoque_movimentacoes (
            produto_id, sabor_id, tipo, quantidade, estoque_anterior, estoque_novo,
            usuario_id, observacao, created_at, updated_at
        ) VALUES (
            p_produto_id, p_sabor_id, 'AJUSTE_QUANTIDADE_SABOR', -p_quantidade_dividir,
            v_quantidade_atual, v_quantidade_atual - p_quantidade_dividir,
            v_usuario_id_atual,
            'Quantidade dividida para novo sabor "' || TRIM(p_novo_sabor) || '". ' || COALESCE(p_observacao, ''),
            NOW(), NOW()
        ) RETURNING id INTO v_movimentacao_id;

        INSERT INTO estoque_movimentacoes (
            produto_id, sabor_id, tipo, quantidade, estoque_anterior, estoque_novo,
            usuario_id, observacao, created_at, updated_at
        ) VALUES (
            p_produto_id, v_novo_sabor_id, 'AJUSTE_QUANTIDADE_SABOR', p_quantidade_dividir,
            (SELECT COALESCE(quantidade, 0) FROM produto_sabores WHERE id = v_novo_sabor_id) - p_quantidade_dividir,
            (SELECT COALESCE(quantidade, 0) FROM produto_sabores WHERE id = v_novo_sabor_id),
            v_usuario_id_atual,
            'Quantidade dividida de "' || v_sabor_original || '". ' || COALESCE(p_observacao, ''),
            NOW(), NOW()
        );

        RETURN QUERY SELECT 
            true,
            'Sabor dividido com sucesso! ' || p_quantidade_dividir || ' ' || (SELECT unidade FROM produtos WHERE id = p_produto_id) || ' transferido(s) para "' || TRIM(p_novo_sabor) || '"'::TEXT,
            v_sabor_original, TRIM(p_novo_sabor), p_quantidade_dividir, v_movimentacao_id;

    EXCEPTION WHEN OTHERS THEN
        RETURN QUERY SELECT false, 'Erro ao dividir sabor: ' || SQLERRM, v_sabor_original, p_novo_sabor, NULL, NULL;
    END;

END;
$function$ ;

ALTER FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) OWNER TO postgres;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO public;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO postgres;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO anon;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO authenticated;
GRANT ALL ON FUNCTION public.dividir_sabor_quantidade(uuid, numeric, varchar, uuid, text, uuid) TO service_role;
```

3. Clique em **"Run"**

### PASSO 3: Validar a Instalação

No **SQL Editor**, execute este comando de verificação:

```sql
SELECT exists(
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'dividir_sabor_quantidade'
) as funcao_instalada;
```

✅ Se retornar `true`, a função foi instalada com sucesso!

### PASSO 4: Testar no Navegador

1. Abra seu aplicativo → **Estoque** → **Estoque por Sabor**
2. Procure um produto com sabores (ex: com 3+ unidades)
3. Clique em **Editar** (botão de lápis)
4. Na janela que abre, clique na aba **"Dividir Quantidade"**
5. Preencha:
   - Quantidade: `2`
   - Nome do novo sabor: `[Nome] - Pink` (ou qualquer outro)
6. Clique em **"Confirmar Divisão"**

### PASSO 5: Verificar o Resultado

Após confirmar:
- ✓ A página deve atualizar automaticamente
- ✓ Você verá 2 registros do sabor (original + novo)
- ✓ A soma das quantidades deve ser igual ao original

---

## 🐛 Solução de Problemas

### Erro: "Function dividir_sabor_quantidade does not exist"
- **Solução**: Execute os passos 2 e 3 novamente
- Verifique se não há erros de sintaxe ao executar

### Erro: "Unauthorized"
- **Solução**: Verifique se sua conta tem permissão no Supabase
- Tente fazer logout e login novamente

### Modal não aparece com as abas
- **Solução**: Limpe o cache do navegador (Ctrl+Shift+Del)
- Ou acesse em modo privado/anônimo

### Erro: "Sabor não encontrado"
- **Solução**: Recarregue a página (F5)
- Verifique se o sabor ainda existe

---

## 📊 Rastreamento da Implantação

| Item | Status |
|------|--------|
| Função SQL criada | ✅ Pronto |
| Modal HTML atualizado | ✅ Pronto |
| JavaScript atualizado | ✅ Pronto |
| Documentação completa | ✅ Pronto |
| Pronto para produção | ✅ Sim |

---

## 📚 Arquivos Alterados

```
pedidos-estoque-system/
├── database/
│   ├── backup/schema.sql (linhas 955-1070 adicionadas)
│   └── sql_dividir_sabor.sql (NOVO - função isolada)
├── pages/
│   └── estoque.html (modal + javascript atualizados)
└── IMPLEMENTACAO_DIVIDIR_SABOR.md (NOVO - documentação)
```

---

## ✅ Checklist Final

Antes de considerar a implementação completa:

- [ ] Função SQL foi executada no Supabase
- [ ] Validação retornou `true`
- [ ] Testou dividir um sabor
- [ ] Verificou se aparece corretamente na tabela
- [ ] Verificou se as movimentações foram registradas
- [ ] Testou com múltiplos sabores

---

## 💡 Dicas de Uso

1. **Para consolidar sabores**: Use a aba "Alterar Sabor"
2. **Para dividir**: Use a aba "Dividir Quantidade"
3. **Rastreabilidade**: Todas as operações ficam registradas em "Movimentações por Sabor"
4. **Desfazer**: Se cometeu um erro, contact seu suporte (não há botão desfazer automático)

---

## 📞 Próximos Passos

Se tudo funcionou:
1. ✅ Documentar o procedimento
2. ✅ Treinar usuários
3. ✅ Monitorar uso nas próximas semanas
4. ✅ Coletar feedback para melhorias

---

**Data de Implantação**: 12/02/2026  
**Versão**: 1.0  
**Status**: Pronto para Produção ✅
