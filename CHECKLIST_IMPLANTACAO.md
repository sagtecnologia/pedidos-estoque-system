# ✅ CHECKLIST DE IMPLANTAÇÃO - DIVIDIR QUANTIDADE DE SABOR

## 📋 Antes de Começar

### Verificações Iniciais
- [ ] Acesso ao Supabase (admin ou developer)
- [ ] Acesso ao repositório/projeto de código
- [ ] Navegador atualizado
- [ ] Backup recente do banco de dados (recomendado)

---

## 🚀 PROCESSO DE IMPLANTAÇÃO

### ETAPA 1: Preparar o Banco de Dados ⏱️ 5 minutos

#### ☑️ Passo 1.1: Acessar Supabase SQL Editor
- [ ] Abra [https://app.supabase.com](https://app.supabase.com)
- [ ] Selecione seu projeto
- [ ] Clique em **"SQL Editor"** no menu esquerdo
- [ ] Clique em **"New Query"**

#### ☑️ Passo 1.2: Copiar e Executar SQL
- [ ] Abra arquivo: `database/sql_dividir_sabor.sql`
- [ ] Copie TODO o conteúdo (Ctrl+A, Ctrl+C)
- [ ] Cole no SQL Editor (Ctrl+V)
- [ ] Clique em **"Run"** (Ctrl+Enter ou botão verde)
- [ ] ✅ Aguarde mensagem de sucesso (não deve ter erros em vermelho)

#### ☑️ Passo 1.3: Validar Instalação
- [ ] Crie nova query
- [ ] Cole:
```sql
SELECT 'Function Instalada ✓' as status 
WHERE EXISTS(
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'dividir_sabor_quantidade'
);
```
- [ ] Execute (Ctrl+Enter)
- [ ] ✅ Deve retornar uma linha com "Function Instalada ✓"

---

### ETAPA 2: Atualizar o Código Front-end ⏱️ Automático

#### ☑️ Passo 2.1: Sincronizar Arquivos
- [ ] Arquivo `pages/estoque.html` - **✅ JÁ ATUALIZADO**
- [ ] Arquivo `database/backup/schema.sql` - **✅ JÁ ATUALIZADO**
- [ ] Arquivo `database/sql_dividir_sabor.sql` - **✅ JÁ CRIADO**

#### ☑️ Passo 2.2: Limpar Cache do Navegador
- [ ] Abra seu aplicativo
- [ ] Pressione **Ctrl + Shift + Delete**
- [ ] Selecione: "Cookies and cached images and files"
- [ ] Clique em **"Clear data"**
- [ ] Recarregue a página (F5)

---

### ETAPA 3: Teste Funcional ⏱️ 10 minutos

#### ☑️ Passo 3.1: Preparar Dados de Teste
- [ ] Acesse **Estoque** no seu app
- [ ] Procure um produto com **sabores** cadastrados
- [ ] Procure um sabor com **quantidade ≥ 2**
- [ ] Anote:
  - Nome do produto: ________________
  - Nome do sabor: ________________
  - Quantidade: ________________

#### ☑️ Passo 3.2: Testar Divisão
- [ ] Clique no botão **"Editar"** (lápis) do sabor
- [ ] ✅ Modal abre com 2 abas: "Alterar Sabor" e "Dividir Quantidade"
- [ ] Clique na aba **"Dividir Quantidade"**
- [ ] Preencha:
  - Quantidade: `1` (metade da disponível)
  - Nome novo: `[Nome Original]-TEST`
  - Observação: `Teste de funcionalidade`
- [ ] Clique em **"Confirmar Divisão"**
- [ ] ✅ Deve aparecer toast verde com sucesso

#### ☑️ Passo 3.3: Verificar Resultado
- [ ] Página atualiza automaticamente
- [ ] Procure na tabela por 2 linhas:
  - Original com quantidade reduzida
  - Nova com quantidade transferida
- [ ] Soma das 2 = quantidade original ✅

#### ☑️ Passo 3.4: Verificar Movimentações
- [ ] Vá para **Estoque** → **Movimentações por Sabor**
- [ ] Procure por tipo **"AJUSTE_QUANTIDADE_SABOR"**
- [ ] Deve haver 2 registros (um para cada sabor)
- [ ] Observação deve conter "dividida" ✅

#### ☑️ Passo 3.5: Desfazer Teste (Consolidar)
- [ ] Volte para **Estoque por Sabor**
- [ ] Clique em **Editar** no sabor "-TEST"
- [ ] Aba: **"Alterar Sabor"**
- [ ] Novo sabor: selecione o **sabor original**
- [ ] Clique: **"Confirmar Alteração"**
- [ ] ✅ Sabores consolidam de volta aos 2 originais
- [ ] Quantidade volta ao original ✅

---

### ETAPA 4: Testes Avançados (Opcional) ⏱️ 15 minutos

#### ☑️ Passo 4.1: Testar Erros Esperados

**Teste 1: Quantidade inválida**
- [ ] Abra modal de divisão
- [ ] Tente digitar: quantidade inválida (negativa, zero)
- [ ] ✅ Sistema valida e avisa

**Teste 2: Quantidade maior que total**
- [ ] Abra modal de divisão
- [ ] Digita quantidade > total disponível
- [ ] ✅ Sistema mostra erro de validação

**Teste 3: Novo sabor igual ao original**
- [ ] Abra modal
- [ ] Aba "Dividir"
- [ ] Coloca mesmo nome do sabor atual
- [ ] Clica em confirmar
- [ ] ✅ Sistema recusa com mensagem

#### ☑️ Passo 4.2: Testar Consolidação Automática
- [ ] Criar 2 linhas: "Morango" e "Morango-V2"
- [ ] Abrir "Morango-V2" e colocar em "Alterar Sabor"
- [ ] Mudar para "Morango"
- [ ] ✅ "Morango-V2" desaparece, "Morango" soma quantidades

#### ☑️ Passo 4.3: Testar com Múltiplo Divisões
- [ ] Sabor com 10 unidades
- [ ] Dividir para 3 (fica: original 7, novo 3)
- [ ] Dividir os 7 para 4 (fica: original 3, novo 4)
- [ ] Agora temos 3 registros: 3, 4, 3
- [ ] ✅ Soma = 10 original

---

## 📊 Checklist de Validação

| Funcionalidade | Esperado | Resultado | ✓ |
|---|---|---|---|
| Modal com 2 abas | Presente | [ ] |
| Campo quantidade | Validado | [ ] |
| Função RPC | Executa | [ ] |
| Movimentações | Registradas | [ ] |
| Consolidação | Funciona | [ ] |
| Erros | Validados | [ ] |
| Toast de sucesso | Aparece | [ ] |
| Refresh automático | Ocorre | [ ] |

---

## 🎯 Checklist de Produção

Antes de liberar para todos:

### Segurança
- [ ] Testou com usuário comum (não admin)
- [ ] Testou com usuário com restrições
- [ ] Verificou se RLS policies funcionam corretamente

### Dados
- [ ] Testou com 100+ registros de sabores
- [ ] Testou com quantidades decimais
- [ ] Testou com caracteres especiais em nomes

### Performance
- [ ] Divisão levou menos de 2 segundos
- [ ] Carregamento da página normal
- [ ] Sem lag visual no modal

### Compatibilidade
- [ ] Chrome ✅
- [ ] Firefox ✅
- [ ] Safari ✅
- [ ] Edge ✅
- [ ] Mobile ✅

### Documentação
- [ ] Informou equipe sobre nova funcionalidade
- [ ] Criou documentação interna
- [ ] Treinou usuários

---

## 🚨 Troubleshooting Rápido

### Problema: "Function does not exist"
```
❌ Erro no modal ao clicar
✅ Solução: Refaça ETAPA 1 (SQL não executou)
```

### Problema: Modal sem as abas
```
❌ Modal abriu mas só mostra versão antiga
✅ Solução: Limpe cache (ETAPA 2.2) e recarregue
```

### Problema: Erro ao dividir
```
❌ Toast vermelho ao clicar "Confirmar Divisão"
✅ Solução: 
   1. F12 → Console → veja o erro
   2. Verifique se a quantidade é válida
   3. Refaça a função SQL
```

### Problema: Dados não atualizam
```
❌ Divide mas tabela não muda
✅ Solução: Recarregue página (F5)
```

---

## 📱 Testes em Produção

Após ETAPA 3 estar OK:

### Semana 1: Monitoramento
- [ ] Dia 1: 1 usuário testa
- [ ] Dia 2-3: 3-5 usuários testam
- [ ] Dia 4-7: Libera para todo time

### Semana 2: Feedback
- [ ] Colete sugestões de melhoria
- [ ] Documente casos de uso reais
- [ ] Atualize treinamento se necessário

### Semana 3+: Manutenção
- [ ] Monitore erros no Supabase
- [ ] Backup regular do banco
- [ ] Suporte aos usuários

---

## 📞 Quando Tudo Está Pronto

✅ **Todos os checklists completados?**

Então:
- ✅ Funcionalidade está 100% operacional
- ✅ Documentação está completa
- ✅ Equipe está treinada
- ✅ Pronto para produção!

---

## 📋 Documentação Criada

Você tem 4 arquivos de documentação:

1. **IMPLEMENTACAO_DIVIDIR_SABOR.md** (geral)
   - O que foi feito
   - Como aplicar mudanças
   - Estrutura da tabela

2. **GUIA_IMPLANTACAO.md** (passo a passo)
   - Instruções detalhadas
   - Copie/cole de SQL
   - Solução de problemas

3. **EXEMPLOS_USO_DIVIDIR_SABOR.md** (prático)
   - Casos reais
   - Fluxo dia a dia
   - FAQ

4. **RESUMO_TECNICO_MUDANCAS.md** (técnico)
   - Funções altaradas
   - Fluxo de execução
   - Tabelas afetadas

---

## 🎉 Status Final

**Implementação**: ✅ **COMPLETA**  
**Testes**: ⏳ Pendentes (execute checklists acima)  
**Produção**: ⏳ Pronto quando testes passarem  

---

**Última atualização**: 12 de fevereiro de 2026  
**Versão**: 1.0 Beta  
**Status**: Pronto para Implantação
