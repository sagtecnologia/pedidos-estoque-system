# 📋 Exemplos Práticos - Dividir Quantidade de Sabor

## Cenários de Uso

---

## Exemplo 1: Separar Morangos para Lotes

### Situação Inicial
```
Produto: Berries Premium
Sabor: Morango
Quantidade: 3 un
```

### Ação
1. Abrir **Estoque** → **Estoque por Sabor**
2. Encontrar a linha "Morango" (berries)
3. Clique em **Editar** ✏️
4. Aba: **Dividir Quantidade**
5. Preencha:
   - Quantidade: `2`
   - Nome novo: `Morango-Premium`
   - Observação: `Separação para lote exportação`
6. Clique: **"Confirmar Divisão"** ✓

### Resultado
```
Produto: Berries Premium
├── Morango: 1 un
└── Morango-Premium: 2 un
```

### Movimentações Registradas
```
Tipo: AJUSTE_QUANTIDADE_SABOR
├── Morango: -2 un (de 3 para 1)
└── Morango-Premium: +2 un (novo)
```

---

## Exemplo 2: Consolidar Sabores

### Situação Inicial
```
Produto: Iogurte Natural
├── Morango: 2 un
└── Morango-Pink: 3 un (foi ao longo do tempo)
```

### Problema
Você quer consolidar "Morango-Pink" de volta em "Morango"

### Solução: Usar a Aba "Alterar Sabor"
1. Clique em **Editar** para "Morango-Pink"
2. Aba: **Alterar Sabor**
3. Novo Sabor: `Morango`
4. Clique: **"Confirmar Alteração"** ✓

### Resultado
```
Produto: Iogurte Natural
└── Morango: 5 un (2 + 3)
```

---

## Exemplo 3: Corrigir Separação Errada

### Situação Inicial
```
Produto: Sorvete
Sabor: Chocolate
Quantidade: 10 un
(Errado! Deveria ser 8 chocolate e 2 chocolate-amargo)
```

### Ação
1. Clique em **Editar** para "Chocolate"
2. Aba: **Dividir Quantidade**
3. Quantid: `2`
4. Nome novo: `Chocolate-Amargo`
5. Observação: `Correção de separação de lote`
6. **Confirmar Divisão** ✓

### Resultado
```
Produto: Sorvete
├── Chocolate: 8 un
└── Chocolate-Amargo: 2 un
```

---

## Exemplo 4: Criar Sabor Personalizado (Divisão)

### Situação Inicial
```
Produto: Bolacha Amanteigada
Sabor: Vanilla
Quantidade: 12 un
(Comprou genérica, quer separar premium)
```

### Ação
1. Clique em **Editar** para "Vanilla"
2. Aba: **Dividir Quantidade**
3. Quantid: `5`
4. Nome novo: `Vanilla-Premium`
5. **Confirmar Divisão** ✓

### Resultado
```
Produto: Bolacha Amanteigada
├── Vanilla: 7 un
└── Vanilla-Premium: 5 un
```

---

## Exemplo 5: Rastreabilidade - Verificar Movimentações

Após dividir um sabor, você pode verificar o histórico:

1. Vá para **Estoque** → **Movimentações por Sabor**
2. Filtre por **Produto** ou **Sabor**
3. Procure por tipo `AJUSTE_QUANTIDADE_SABOR`

### O que você verá
```
Data: 12/02/2026 14:30:45
Tipo: AJUSTE_QUANTIDADE_SABOR
Produto: Berries Premium
Sabor: Morango
Quantidade: -2
Observação: Quantidade dividida para novo sabor "Morango-Premium"
Usuario: Você

---

Data: 12/02/2026 14:30:45 (mesmo tempo)
Tipo: AJUSTE_QUANTIDADE_SABOR
Produto: Berries Premium
Sabor: Morango-Premium
Quantidade: +2
Observação: Quantidade dividida de "Morango"
Usuario: Você
```

---

## Situações Que NÃO São Possíveis ❌

### 1. Dividir quantidade = 0
```
❌ Erro: Sabor com quantidade zerada não pode ser dividido
```

### 2. Dividir quantidade maior que o total
```
Original: 3 un
Tentar dividir: 5 un
❌ Erro: Não pode transferir 5 quando só tem 3
```

### 3. Novo sabor igual ao original
```
Original: Morango
Novo: Morango
❌ Erro: Novo sabor deve ser diferente
```

### 4. Dividir para sabor vazio
```
Novo sabor: (vazio)
❌ Erro: Digite um nome para o novo sabor
```

---

## Dicas de Ouro 💡

### 1. Nomeação Consistente
Use padrões para nomear:
- `[Nome]-Premium` (versão melhor)
- `[Nome]-Standard` (versão normal)
- `[Nome]-Exportação` (para exportar)
- `[Nome]-Promo` (promoção)

### 2. Observações Detalhadas
Sempre adicione observações!
```
✓ "Separação para pedido #123"
✓ "Correção de inventário"
✓ "Lote especial cliente XYZ"
✓ "Descarte de amostra"
```

### 3. Agrupar Operações
Se vai dividi vários sabores, faça tudo de uma vez:
```
Antes:
- Chocolate: 20 un
- Morango: 15 un
- Baunilha: 18 un

Ação:
- Divide chocolate 10/10
- Divide morango 8/7
- Divide baunilha 12/6

Depois: Todos têm suas variações
```

### 4. Verificar Antes de Dividir
Vejo aqui:
- Quantidade atual (mostrada no modal)
- Unidade de medida (mostrada)
- Produtos relacionados (no filtro)

---

## Integrações com Outras Áreas 🔗

### Impacto no Relatório de Estoque
```
Antes:
- Total: 3 morangos
- 1 sabor envolvido

Depois:
- Total: 3 morangos (mantém-se)
- 2 sabores (morango + morango-pink)
```

### Impacto em Movimentações
```
Fica registrado automaticamente como:
tipo: AJUSTE_QUANTIDADE_SABOR
Cria crédito para um e débito para outro
```

### Impacto em Análises
```
Pode afetar análises de:
- Histórico de sabor individual
- Lucratividade por sabor
- Volume de saída
```

---

## Quando Usar Cada Aba 🎯

### Use "Alterar Sabor" quando:
- ✓ Quer mudar o **nome** do sabor (digitação errada)
- ✓ Quer **consolidar** sabores similares
- ✓ Quer **renomear** permanentemente

### Use "Dividir Quantidade" quando:
- ✓ Quer **separar** em lotes
- ✓ Quer **rastrear** quantidades diferentes
- ✓ Quer **manter histórico** de ambos

---

## Exemplo Real de Fluxo Dia a Dia 📅

### Segunda-feira: Chegou Compra
```
400 unidades de Morango compradas
Criado automaticamente: Morango - 400 un
```

### Terça-feira: Separa para Clientes
```
Cliente A pediu: 150 morango premium
Client B pediu: 200 morango standard

Ação: Divide 150 para "Morango-Premium"

Resultado:
├── Morango: 250 un (standard)
└── Morango-Premium: 150 un (cliente A)
```

### Quarta-feira: Separação Final
```
Da da stock padrão separa mais:
100 para promoção Black Friday

Ação: Divide 100 do "Morango" para "Morango-BlackFriday"

Resultado:
├── Morango: 150 un
├── Morango-Premium: 150 un
└── Morango-BlackFriday: 100 un
```

### Quinta-feira: Verificar Estoque
```
Vai para Estoque → Estoque por Sabor
Filtra: Marca = XYZ, Produto = Morango

Vê todos em 3 registros diferentes
Que somados = 400 original ✓
```

---

## FAQ - Perguntas Frequentes ❓

**P: Posso desfazer uma divisão?**  
R: Sim, usando "Alterar Sabor" para consolidar de volta.

**P: Se dividir duas vezes, fica com 3 sabores?**  
R: Sim! Você pode dividir quantas vezes quiser.

**P: O estoque total muda?**  
R: Não! O total de unidades do produto mantém-se igual.

**P: Afeta o preço?**  
R: Não, cada sabor tem seu próprio preço (se quiser mudar depois).

**P: Posso dividir para um sabor que já existe?**  
R: Sim! As quantidades são automaticamente somadas.

**P: Fica registrado no histórico?**  
R: Sim! Em "Movimentações por Sabor" com tipo "AJUSTE_QUANTIDADE_SABOR".

---

**Dúvidas?** Consulte o arquivo `IMPLEMENTACAO_DIVIDIR_SABOR.md` para mais detalhes técnicos!
