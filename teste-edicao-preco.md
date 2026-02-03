# Teste da Funcionalidade de Edição de Preço de Compra

## Funcionalidade Implementada

Foi adicionada a capacidade de alterar o valor de compra de produtos específicos quando o pedido estiver no status FINALIZADO (pendente).

### Como funciona

1. **Pré-requisitos**:
   - Pedido deve estar no status `FINALIZADO`
   - Usuário deve ter permissão de ADMIN
   
2. **Interface**:
   - Na tabela de itens do pedido, aparece um ícone 💰 (dollar-sign) na coluna de ações
   - Um indicador visual aparece no cabeçalho informando sobre a funcionalidade
   
3. **Modal de Edição**:
   - Mostra o produto/sabor selecionado
   - Exibe a quantidade (somente leitura)
   - Mostra o preço atual (somente leitura)
   - Campo para inserir o novo preço unitário
   - Cálculo automático do novo subtotal
   - Aviso sobre o recálculo do total do pedido

### Fluxo de Teste

1. Faça login como ADMIN
2. Acesse um pedido no status FINALIZADO
3. Verifique se o indicador laranja aparece no cabeçalho dos itens
4. Clique no ícone 💰 de qualquer item
5. Altere o preço no modal
6. Confirme a alteração
7. Verifique se:
   - O preço do item foi atualizado
   - O total do pedido foi recalculado
   - As alterações foram persistidas no banco

### Segurança

- Apenas usuários com role ADMIN podem alterar preços
- Funcionalidade disponível apenas para pedidos FINALIZADOS
- Confirmação obrigatória antes da alteração
- Validação de preço > 0
- Recálculo automático e seguro do total

### Arquivos Modificados

- `pages/pedido-detalhe.html`: Interface e funcionalidade principal
- Utiliza função existente `recalcularTotalPedido()` do arquivo `js/services/pedidos.js`

### Observações Técnicas

- O subtotal é calculado automaticamente pelo banco de dados (coluna GENERATED)
- A função recalcularTotalPedido() já existia e foi reutilizada
- Implementação segura com validações no frontend e backend