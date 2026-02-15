# 📋 Implementação: Dividir Quantidade de Sabor

## Resumo das Mudanças

Você agora pode **dividir a quantidade de um sabor** mantendo o sabor original com a quantidade restante!

### Exemplo Prático:
- **Antes**: 3 morangos (um único registro)
- **Depois**: 1 morango + 2 morangos-pink (dois registros)

---

## 🔧 O que foi implementado

### 1. **Nova Função SQL (RPC)** - `dividir_sabor_quantidade`
- **Arquivo**: `database/backup/schema.sql`
- **Localização**: Linhas 955-1070
- **Função**: Divide a quantidade de um sabor criando um novo sabor ou agregando a um existente

### 2. **Modal Atualizado**
- **Arquivo**: `pages/estoque.html`
- **Mudanças**:
  - Adicionadas 2 abas: "Alterar Sabor" e "Dividir Quantidade"
  - Campo para quantidade a dividir
  - Validação em tempo real da quantidade

### 3. **Funções JavaScript Novas**
- `mudarTabGerenciarSabor()` - Alterna entre as abas
- `confirmarDividirSaborAba()` - Processa a divisão
- Atualizada: `abrirModalAlterarSabor()` - Mostra quantidade disponível

---

## 📦 Como Aplicar as Mudanças

### Passo 1: Atualizar o Banco de Dados

Faça uma das opções:

#### Opção A: Via SQL Editor do Supabase
1. Vá para **Supabase Dashboard** → **SQL Editor**
2. Copie o conteúdo completo de `database/backup/schema.sql` linhas 955-1070
3. Cole e execute

#### Opção B: Via arquivo SQL
```bash
# Se tiver acesso ao banco via terminal
psql -h seu_host -U seu_usuario -d sua_database -f database/backup/schema.sql
```

### Passo 2: Verificar Instalação

No Supabase, vá para:
- **Supabase Dashboard** → **SQL Editor**
- Execute:
```sql
SELECT EXISTS(
    SELECT 1 FROM information_schema.routines 
    WHERE routine_name = 'dividir_sabor_quantidade'
);
```
- Deve retornar `true`

---

## 💻 Como Usar

### Dividir um Sabor:

1. Vá para **Estoque** → **Estoque por Sabor**
2. Clique no botão **Editar** do sabor desejado
3. Clique na aba **"Dividir Quantidade"** 
4. Preencha:
   - **Quantidade para Novo Sabor**: Ex: `2` (se tivermos 3 morangos)
   - **Nome do Novo Sabor**: Ex: `Morango-pink`
   - **Observação** (opcional): Motivo da divisão
5. Clique em **"Confirmar Divisão"** ✓

### Resultado:
- Morango: **1 unidade**
- Morango-pink: **2 unidades**

---

## 🔍 O Que Acontece nos Bastidores

### 1. **Validações**
- ✓ Quantidade deve ser > 0
- ✓ Quantidade deve ser < quantidade atual
- ✓ Novo sabor não pode ser igual ao anterior
- ✓ Registra 2 movimentações (uma para cada sabor)

### 2. **Movimentações Registradas**
Tipo: `AJUSTE_QUANTIDADE_SABOR`

**Sabor Original**: -2 (saída)
**Novo Sabor**: +2 (entrada)

Você pode ver isso em **Movimentações por Sabor**

### 3. **Consolidação Automática**
Se o novo sabor já existir para o produto, a quantidade é **automaticamente somada**.

---

## ⚠️ Notas Importantes

1. **Não é possível dividir sabores com quantidade zerada**
2. A quantidade deve ser **menor** que a quantidade atual
3. Todas as operações são **registradas** nas movimentações
4. Você pode **desfazer** via movimentações se necessário

---

## 🧪 Testes Recomendados

1. Dividir um sabor com 10 unidades em 3 e 7
2. Dividir e consolidar com sabor existente
3. Verificar se as movimentações foram registradas corretamente
4. Verificar relatórios e totalizações

---

## 📊 Estrutura da Tabela `produto_sabores`

```
CREATE TABLE produto_sabores (
    id uuid PRIMARY KEY,
    produto_id uuid,
    sabor varchar(100),
    quantidade numeric(10,2),
    ativo boolean,
    created_at timestamptz,
    updated_at timestamptz
)
```

---

## 🚀 Próximas Melhorias Possíveis

- [ ] Opção para dividir por lote/data
- [ ] Relatório de rastreabilidade de divisões
- [ ] Automation de divisão por movimentações
- [ ] Template de divisões frequentes

---

## 📞 Suporte

Se encontrar erros:
1. Verifique se a função foi criada com sucesso
2. Verifique os logs do browser (F12 → Console)
3. Verifique os erros do Supabase (Logs)

Status da implementação: ✅ **COMPLETO**
