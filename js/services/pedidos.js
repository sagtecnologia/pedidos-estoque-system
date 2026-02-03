// =====================================================
// SERVIÇO DE PEDIDOS
// =====================================================

// Listar pedidos
async function listPedidos(filters = {}) {
    try {
        let query = supabase
            .from('pedidos')
            .select(`
                *,
                solicitante:users!pedidos_solicitante_id_fkey(full_name),
                fornecedor:fornecedores(nome),
                cliente:clientes(nome),
                aprovador:users!pedidos_aprovador_id_fkey(full_name)
            `)
            .order('created_at', { ascending: false });

        if (filters.status) {
            query = query.eq('status', filters.status);
        }

        if (filters.tipo_pedido) {
            query = query.eq('tipo_pedido', filters.tipo_pedido);
        }

        if (filters.solicitante_id) {
            query = query.eq('solicitante_id', filters.solicitante_id);
        }

        if (filters.search) {
            query = query.ilike('numero', `%${filters.search}%`);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar pedidos');
        return [];
    }
}

// Buscar pedido por ID
async function getPedido(id) {
    try {
        const { data, error } = await supabase
            .from('pedidos')
            .select(`
                *,
                solicitante:users!pedidos_solicitante_id_fkey(id, full_name, email),
                fornecedor:fornecedores(id, nome, cnpj, whatsapp),
                cliente:clientes(id, nome, cpf_cnpj, whatsapp),
                aprovador:users!pedidos_aprovador_id_fkey(id, full_name, email, whatsapp)
            `)
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar pedido');
        return null;
    }
}

// Buscar itens do pedido
async function getItensPedido(pedidoId) {
    try {
        const { data, error } = await supabase
            .from('pedido_itens')
            .select(`
                *,
                produto:produtos(codigo, nome, unidade, preco, preco_compra),
                sabor:produto_sabores(id, sabor, quantidade)
            `)
            .eq('pedido_id', pedidoId)
            .order('created_at');

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar itens do pedido');
        return [];
    }
}

// Criar pedido
async function createPedido(pedido) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        const numero = generateOrderNumber(pedido.tipo_pedido || 'COMPRA');

        const pedidoData = {
            numero,
            solicitante_id: user.id,
            tipo_pedido: pedido.tipo_pedido || 'COMPRA',
            observacoes: pedido.observacoes,
            status: 'RASCUNHO'
        };

        // Adicionar fornecedor_id ou cliente_id dependendo do tipo
        if (pedido.tipo_pedido === 'VENDA') {
            pedidoData.cliente_id = pedido.cliente_id;
        } else {
            pedidoData.fornecedor_id = pedido.fornecedor_id;
        }

        const { data, error } = await supabase
            .from('pedidos')
            .insert([pedidoData])
            .select()
            .single();

        if (error) throw error;

        const tipoPedidoTexto = pedido.tipo_pedido === 'VENDA' ? 'Venda' : 'Pedido';
        showToast(`${tipoPedidoTexto} criado com sucesso!`, 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao criar pedido');
        return null;
    } finally {
        showLoading(false);
    }
}

// Adicionar item ao pedido
// Adicionar item ao pedido
async function addItemPedido(pedidoId, item) {
    try {
        // ✅ NÃO mostrar loading aqui - já é mostrado pela função chamadora
        // showLoading(true);

        const itemData = {
            pedido_id: pedidoId,
            produto_id: item.produto_id,
            quantidade: item.quantidade,
            preco_unitario: item.preco_unitario
        };

        // Incluir sabor_id se fornecido
        if (item.sabor_id) {
            itemData.sabor_id = item.sabor_id;
        }

        // Incluir preco_compra_entrada se fornecido (para rastrear custo exato na venda)
        if (item.preco_compra_entrada !== undefined) {
            itemData.preco_compra_entrada = item.preco_compra_entrada;
        }

        const { data, error } = await supabase
            .from('pedido_itens')
            .insert([itemData])
            .select()
            .single();

        if (error) throw error;

        // ✅ NÃO mostrar toast aqui - será mostrado pela função chamadora
        // showToast('Item adicionado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        console.error('Erro ao adicionar item:', error);
        throw error; // ✅ Propagar erro para função chamadora tratar
    } finally {
        // ✅ NÃO remover loading aqui
        // showLoading(false);
    }
}

// Remover item do pedido
async function removeItemPedido(itemId) {
    try {
        if (!await confirmAction('Deseja realmente remover este item?')) {
            return false;
        }

        showLoading(true);

        const { error } = await supabase
            .from('pedido_itens')
            .delete()
            .eq('id', itemId);

        if (error) throw error;

        showToast('Item removido com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao remover item');
        return false;
    } finally {
        showLoading(false);
    }
}

// Enviar pedido para aprovação
async function enviarPedido(pedidoId) {
    try {
        if (!await confirmAction('Deseja enviar este pedido para aprovação?')) {
            return false;
        }

        showLoading(true);

        // Verificar se há itens
        const itens = await getItensPedido(pedidoId);
        if (itens.length === 0) {
            throw new Error('Adicione pelo menos um item ao pedido');
        }

        const { data, error } = await supabase
            .from('pedidos')
            .update({ status: 'ENVIADO' })
            .eq('id', pedidoId)
            .select()
            .single();

        if (error) throw error;

        showToast('Pedido enviado para aprovação!', 'success');
        
        // Gerar link WhatsApp
        await enviarWhatsAppAprovacao(pedidoId);
        
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao enviar pedido');
        return null;
    } finally {
        showLoading(false);
    }
}

// Aprovar pedido
async function aprovarPedido(pedidoId) {
    try {
        if (!await confirmAction('Deseja aprovar este pedido?')) {
            return false;
        }

        showLoading(true);
        
        const user = await getCurrentUser();

        const { data, error } = await supabase
            .from('pedidos')
            .update({ 
                status: 'APROVADO',
                aprovador_id: user.id,
                data_aprovacao: new Date().toISOString()
            })
            .eq('id', pedidoId)
            .select()
            .single();

        if (error) throw error;

        showToast('Pedido aprovado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao aprovar pedido');
        return null;
    } finally {
        showLoading(false);
    }
}

// Rejeitar pedido
async function rejeitarPedido(pedidoId, motivo) {
    try {
        if (!motivo || motivo.trim() === '') {
            throw new Error('Informe o motivo da rejeição');
        }

        showLoading(true);
        
        const user = await getCurrentUser();

        const { data, error } = await supabase
            .from('pedidos')
            .update({ 
                status: 'REJEITADO',
                aprovador_id: user.id,
                motivo_rejeicao: motivo,
                data_aprovacao: new Date().toISOString()
            })
            .eq('id', pedidoId)
            .select()
            .single();

        if (error) throw error;

        showToast('Pedido rejeitado!', 'warning');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao rejeitar pedido');
        return null;
    } finally {
        showLoading(false);
    }
}

// Variável para controle de finalização em progresso
let finalizacaoEmProgresso = false;

// Finalizar pedido (baixar estoque)
async function finalizarPedido(pedidoId) {
    try {
        // PROTEÇÃO: Impedir múltiplas finalizações simultâneas
        if (finalizacaoEmProgresso) {
            showToast('⏳ Aguarde... O pedido já está sendo finalizado!', 'warning');
            return false;
        }

        // 🔒 VALIDAÇÃO DE SESSÃO ATIVA
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        if (sessionError || !session) {
            showToast('❌ Sua sessão expirou! Faça login novamente.', 'error', 5000);
            setTimeout(() => {
                window.location.href = '/index.html';
            }, 2000);
            return false;
        }

        // Verificar se o token ainda é válido
        const tokenExpiresAt = session.expires_at * 1000;
        const now = Date.now();
        if (tokenExpiresAt <= now) {
            showToast('❌ Sua sessão expirou! Faça login novamente.', 'error', 5000);
            await supabase.auth.signOut();
            setTimeout(() => {
                window.location.href = '/index.html';
            }, 2000);
            return false;
        }

        // Verificar se o pedido já está finalizado
        const { data: pedidoAtual } = await supabase
            .from('pedidos')
            .select('status, numero')
            .eq('id', pedidoId)
            .single();

        if (pedidoAtual && pedidoAtual.status === 'FINALIZADO') {
            showToast('⚠️ Este pedido já foi finalizado anteriormente!', 'error');
            return false;
        }

        if (pedidoAtual && pedidoAtual.status === 'CANCELADO') {
            showToast('⚠️ Este pedido está cancelado e não pode ser finalizado!', 'error');
            return false;
        }

        if (!await confirmAction('Deseja finalizar este pedido? O estoque será baixado automaticamente.')) {
            return false;
        }

        finalizacaoEmProgresso = true;
        showLoading(true);
        
        const user = await getCurrentUser();

        // Chamar função do banco
        const { data, error } = await supabase
            .rpc('finalizar_pedido', {
                p_pedido_id: pedidoId,
                p_usuario_id: user.id
            });

        if (error) {
            // Tratar erros de validação de estoque de forma mais amigável
            if (error.message && error.message.includes('Estoque insuficiente')) {
                // Extrair informações do erro (formato: "Estoque insuficiente para CODIGO (SABOR). Necessário: X, Disponível: Y")
                const match = error.message.match(/para (.+?) \((.+?)\)\. Necessário: ([\d.]+), Disponível: ([\d.]+)/);
                
                if (match) {
                    const [_, codigo, sabor, necessario, disponivel] = match;
                    const faltam = (parseFloat(necessario) - parseFloat(disponivel)).toFixed(2);
                    
                    throw new Error(
                        `❌ ESTOQUE INSUFICIENTE!\n\n` +
                        `📦 Produto: ${codigo}\n` +
                        `🎨 Sabor: ${sabor}\n` +
                        `📊 Necessário: ${necessario} unidades\n` +
                        `📉 Disponível: ${disponivel} unidades\n` +
                        `⚠️  Faltam: ${faltam} unidades\n\n` +
                        `Por favor, reduza a quantidade ou abasteça o estoque antes de finalizar.`
                    );
                } else {
                    // Se não conseguir extrair, mostrar mensagem original melhorada
                    throw new Error(`❌ Erro de estoque:\n${error.message}`);
                }
            }
            
            throw error;
        }

        showToast('Pedido finalizado e estoque atualizado!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao finalizar pedido');
        return false;
    } finally {
        finalizacaoEmProgresso = false;
        showLoading(false);
    }
}

// Gerar mensagem WhatsApp para aprovação
async function enviarWhatsAppAprovacao(pedidoId) {
    try {
        const pedido = await getPedido(pedidoId);
        const itens = await getItensPedido(pedidoId);

        // PRIMEIRO: Gerar e abrir o PDF para impressão/download
        showToast('Gerando PDF do pedido...', 'info');
        
        if (pedido.tipo_pedido === 'VENDA') {
            await gerarPDFParaEnvio(pedidoId, 'VENDA');
        } else {
            await gerarPDFParaEnvio(pedidoId, 'COMPRA');
        }

        // Aguardar um pouco para o PDF abrir
        await new Promise(resolve => setTimeout(resolve, 1000));

        // Buscar TODOS os aprovadores ativos com WhatsApp
        const { data: aprovadores, error: errorAprovadores } = await supabase
            .from('users')
            .select('id, full_name, whatsapp')
            .eq('role', 'APROVADOR')
            .eq('active', true)
            .not('whatsapp', 'is', null);

        if (errorAprovadores) throw errorAprovadores;

        if (!aprovadores || aprovadores.length === 0) {
            showToast('Nenhum aprovador com WhatsApp cadastrado no sistema', 'warning');
            return;
        }

        // Montar mensagem
        const tipoPedido = pedido.tipo_pedido === 'VENDA' ? 'Venda' : 'Compra';
        let mensagem = `🔔 *Novo Pedido de ${tipoPedido} para Aprovação*\n\n`;
        mensagem += `📋 *Pedido:* ${pedido.numero}\n`;
        mensagem += `👤 *Solicitante:* ${pedido.solicitante.full_name}\n`;
        
        if (pedido.fornecedor) {
            mensagem += `🏢 *Fornecedor:* ${pedido.fornecedor.nome}\n`;
        }
        if (pedido.cliente) {
            mensagem += `👥 *Cliente:* ${pedido.cliente.nome}\n`;
        }
        
        mensagem += `💰 *Total:* ${formatCurrency(pedido.total)}\n\n`;
        
        mensagem += `📄 *PDF do pedido foi gerado!*\n`;
        mensagem += `_Anexe o PDF que foi aberto ao enviar esta mensagem_\n\n`;
        
        mensagem += `📱 Acesse o sistema para aprovar ou rejeitar:\n`;
        mensagem += `${window.location.origin}/pages/aprovacao.html?id=${pedidoId}`;

        // Se houver mais de um aprovador, mostrar seleção
        if (aprovadores.length === 1) {
            const link = generateWhatsAppLink(aprovadores[0].whatsapp, mensagem);
            window.open(link, '_blank');
        } else {
            // Mostrar modal para selecionar aprovador
            mostrarSelecaoAprovador(aprovadores, mensagem);
        }
        
    } catch (error) {
        handleError(error, 'Erro ao gerar mensagem WhatsApp');
    }
}

// Gerar PDF para envio (abre em nova janela para impressão/download)
async function gerarPDFParaEnvio(pedidoId, tipoPedido) {
    try {
        // Buscar dados completos do pedido
        const { data: pedido, error: pedidoError } = await supabase
            .from('pedidos')
            .select(`
                *,
                solicitante:users!pedidos_solicitante_id_fkey(full_name),
                aprovador:users!pedidos_aprovador_id_fkey(full_name),
                ${tipoPedido === 'VENDA' ? 
                    'cliente:clientes(nome, cpf_cnpj, tipo, contato, whatsapp, endereco, cidade, estado)' : 
                    'fornecedor:fornecedores(nome, cnpj, whatsapp, endereco)'}
            `)
            .eq('id', pedidoId)
            .single();

        if (pedidoError) throw pedidoError;

        // Buscar itens
        const { data: itens, error: itensError } = await supabase
            .from('pedido_itens')
            .select('*, produto:produtos(codigo, nome, unidade)')
            .eq('pedido_id', pedidoId)
            .order('created_at', { ascending: true });

        if (itensError) throw itensError;

        // Buscar configurações da empresa
        const empresaConfig = await getEmpresaConfig();

        // Gerar HTML apropriado
        const html = tipoPedido === 'VENDA' ? 
            gerarHTMLPedidoVenda(pedido, itens, empresaConfig) : 
            gerarHTMLPedidoCompra(pedido, itens, empresaConfig);

        // Abrir em nova janela
        const printWindow = window.open('', '_blank', 'width=800,height=600');
        printWindow.document.write(html);
        printWindow.document.close();
        printWindow.focus();
        
        // Aguardar carregar e abrir diálogo de impressão
        setTimeout(() => {
            printWindow.print();
        }, 500);

    } catch (error) {
        console.error('Erro ao gerar PDF:', error);
        throw error;
    }
}

// Mostrar modal para selecionar aprovador
function mostrarSelecaoAprovador(aprovadores, mensagem) {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    
    modal.innerHTML = `
        <div class="bg-white rounded-lg p-6 max-w-md w-full mx-4">
            <h3 class="text-lg font-semibold mb-4">Selecione o Aprovador</h3>
            <div class="space-y-2 mb-6">
                ${aprovadores.map(aprov => `
                    <button onclick="enviarParaAprovadorSelecionado('${aprov.whatsapp}', '${encodeURIComponent(mensagem)}')" 
                            class="w-full text-left px-4 py-3 border rounded-lg hover:bg-gray-50 flex items-center justify-between">
                        <div>
                            <div class="font-medium">${aprov.full_name}</div>
                            <div class="text-sm text-gray-600">${aprov.whatsapp}</div>
                        </div>
                        <svg class="w-5 h-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path>
                        </svg>
                    </button>
                `).join('')}
            </div>
            <button onclick="this.closest('.fixed').remove()" 
                    class="w-full px-4 py-2 bg-gray-200 text-gray-800 rounded-lg hover:bg-gray-300">
                Cancelar
            </button>
        </div>
    `;
    
    document.body.appendChild(modal);
}

// Enviar para aprovador selecionado
function enviarParaAprovadorSelecionado(whatsapp, mensagemEncoded) {
    const mensagem = decodeURIComponent(mensagemEncoded);
    const link = generateWhatsAppLink(whatsapp, mensagem);
    window.open(link, '_blank');
    document.querySelector('.fixed.inset-0').remove();
}

// Alias para compatibilidade
const enviarPedidoParaAprovacao = enviarPedido;

// Estatísticas de pedidos
async function getEstatisticasPedidos() {
    try {
        const { data, error } = await supabase
            .from('pedidos')
            .select('status, total');

        if (error) throw error;

        const stats = {
            total: data.length,
            rascunho: 0,
            enviado: 0,
            aprovado: 0,
            rejeitado: 0,
            finalizado: 0,
            valor_total: 0
        };

        data.forEach(p => {
            stats[p.status.toLowerCase()]++;
            stats.valor_total += parseFloat(p.total || 0);
        });

        return stats;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar estatísticas');
        return null;
    }
}

// Excluir pedido (apenas RASCUNHO)
async function deletePedido(pedidoId) {
    try {
        console.log('🗑️ Iniciando exclusão do pedido:', pedidoId);
        
        // Verificar se o pedido está em RASCUNHO
        const { data: pedido, error: errorPedido } = await supabase
            .from('pedidos')
            .select('status, numero, tipo_pedido')
            .eq('id', pedidoId)
            .single();
            
        if (errorPedido) {
            console.error('❌ Erro ao buscar pedido:', errorPedido);
            throw errorPedido;
        }
        
        console.log('📋 Pedido encontrado:', pedido);
        
        if (pedido.status !== 'RASCUNHO') {
            throw new Error('Apenas pedidos em RASCUNHO podem ser excluídos');
        }
        
        // Primeiro, excluir os itens do pedido
        console.log('🗑️ Excluindo itens do pedido...');
        const { error: errorItens } = await supabase
            .from('pedido_itens')
            .delete()
            .eq('pedido_id', pedidoId);
            
        if (errorItens) {
            console.error('❌ Erro ao excluir itens:', errorItens);
            throw errorItens;
        }
        console.log('✅ Itens excluídos com sucesso');
        
        // Depois, excluir o pedido
        console.log('🗑️ Excluindo pedido...');
        const { data: deleteData, error: errorDelete } = await supabase
            .from('pedidos')
            .delete()
            .eq('id', pedidoId)
            .select(); // Adicionar select() para confirmar exclusão
            
        if (errorDelete) {
            console.error('❌ Erro ao excluir pedido:', errorDelete);
            throw errorDelete;
        }
        
        console.log('✅ Resposta da exclusão:', deleteData);
        
        // Verificar se realmente excluiu
        if (!deleteData || deleteData.length === 0) {
            console.warn('⚠️ Nenhum registro foi excluído. Possível problema de RLS.');
            throw new Error('Falha ao excluir o pedido. Verifique suas permissões.');
        }
        
        console.log('✅ Pedido excluído com sucesso!');
        showToast(`${pedido.tipo_pedido === 'COMPRA' ? 'Pedido de compra' : 'Venda'} ${pedido.numero} excluído com sucesso!`, 'success');
        return true;
        
    } catch (error) {
        console.error('❌ Erro completo na exclusão:', error);
        handleError(error, 'Erro ao excluir pedido');
        return false;
    }
}

// Excluir item do pedido
async function deleteItemPedido(itemId) {
    try {
        console.log('🗑️ Iniciando exclusão do item:', itemId);
        
        // Buscar informações do item antes de excluir
        const { data: item, error: errorItem } = await supabase
            .from('pedido_itens')
            .select('pedido_id, pedido:pedidos(status)')
            .eq('id', itemId)
            .single();
            
        if (errorItem) {
            console.error('❌ Erro ao buscar item:', errorItem);
            throw errorItem;
        }
        
        console.log('📋 Item encontrado:', item);
        
        // Verificar se o pedido está em RASCUNHO
        if (item.pedido.status !== 'RASCUNHO') {
            throw new Error('Apenas itens de pedidos em RASCUNHO podem ser removidos');
        }
        
        // Excluir o item
        console.log('🗑️ Excluindo item...');
        const { data: deleteData, error: errorDelete } = await supabase
            .from('pedido_itens')
            .delete()
            .eq('id', itemId)
            .select(); // Adicionar select() para confirmar exclusão
            
        if (errorDelete) {
            console.error('❌ Erro ao excluir item:', errorDelete);
            throw errorDelete;
        }
        
        console.log('✅ Resposta da exclusão:', deleteData);
        
        // Verificar se realmente excluiu
        if (!deleteData || deleteData.length === 0) {
            console.warn('⚠️ Nenhum registro foi excluído. Possível problema de RLS.');
            throw new Error('Falha ao excluir o item. Verifique suas permissões.');
        }
        
        console.log('✅ Item excluído com sucesso!');
        
        // ✅ RECALCULAR O TOTAL DO PEDIDO
        console.log('🔄 Recalculando total do pedido...');
        await recalcularTotalPedido(item.pedido_id);
        
        showToast('Item removido com sucesso!', 'success');
        return true;
        
    } catch (error) {
        console.error('❌ Erro completo na exclusão do item:', error);
        handleError(error, 'Erro ao remover item');
        return false;
    }
}

// Recalcular total do pedido
async function recalcularTotalPedido(pedidoId) {
    try {
        console.log('📊 Recalculando total do pedido:', pedidoId);
        
        // Buscar todos os itens do pedido
        const { data: itens, error: itensError } = await supabase
            .from('pedido_itens')
            .select('subtotal')
            .eq('pedido_id', pedidoId);
        
        if (itensError) {
            console.error('❌ Erro ao buscar itens:', itensError);
            throw itensError;
        }
        
        // Calcular total
        const total = itens.reduce((sum, item) => sum + (parseFloat(item.subtotal) || 0), 0);
        console.log(`💰 Novo total calculado: R$ ${total.toFixed(2)} (${itens.length} itens)`);
        
        // Atualizar total no pedido
        const { error: updateError } = await supabase
            .from('pedidos')
            .update({ total: total })
            .eq('id', pedidoId);
        
        if (updateError) {
            console.error('❌ Erro ao atualizar total:', updateError);
            throw updateError;
        }
        
        console.log('✅ Total do pedido atualizado com sucesso!');
        return total;
        
    } catch (error) {
        console.error('❌ Erro ao recalcular total do pedido:', error);
        // Não lançar erro para não interromper o fluxo principal
        return null;
    }
}
