// =====================================================
// SERVIÇO DE CONFERÊNCIA DE ESTOQUE
// =====================================================

// Lista todos os sabores ativos de produtos ativos, já com os dados do
// produto (marca, nome, código) embutidos — usado para montar a árvore
// marca > produto > sabor na tela de contagem.
async function getSaboresParaConferencia() {
    try {
        const { data, error } = await supabase
            .from('produto_sabores')
            .select(`
                id,
                sabor,
                quantidade,
                produto:produtos!inner(id, nome, codigo, marca, categoria, unidade, active)
            `)
            .eq('ativo', true)
            .eq('produto.active', true)
            .order('sabor');

        if (error) throw error;

        return (data || []).filter(item => item.produto);

    } catch (error) {
        handleError(error, 'Erro ao carregar produtos para conferência');
        return [];
    }
}

// Abre (ou retoma) a conferência RASCUNHO do usuário atual.
async function abrirConferencia() {
    const { data, error } = await supabase.rpc('abrir_conferencia_estoque');

    if (error) throw error;

    const resultado = Array.isArray(data) ? data[0] : data;
    if (resultado && resultado.sucesso === false) {
        throw new Error(resultado.mensagem || 'Não foi possível abrir a conferência');
    }

    return resultado;
}

// Salva (autosave) o valor contado de um sabor. Passe estoqueNovo como
// null/undefined para remover o item (campo deixado em branco).
async function salvarItemConferencia(conferenciaId, saborId, estoqueNovo) {
    const { data, error } = await supabase.rpc('salvar_item_conferencia_estoque', {
        p_conferencia_id: conferenciaId,
        p_sabor_id: saborId,
        p_estoque_novo: (estoqueNovo === '' || estoqueNovo === undefined) ? null : estoqueNovo
    });

    if (error) throw error;

    const resultado = Array.isArray(data) ? data[0] : data;
    if (resultado && resultado.sucesso === false) {
        throw new Error(resultado.mensagem || 'Não foi possível salvar o item');
    }

    return resultado;
}

// Busca os itens já salvos de uma conferência (para retomar contagem).
async function getItensConferencia(conferenciaId) {
    try {
        const { data, error } = await supabase
            .from('conferencia_estoque_itens')
            .select(`
                *,
                sabor:produto_sabores(id, sabor, quantidade),
                produto:produtos(id, nome, marca, codigo)
            `)
            .eq('conferencia_id', conferenciaId);

        if (error) throw error;
        return data || [];

    } catch (error) {
        handleError(error, 'Erro ao carregar itens da conferência');
        return [];
    }
}

async function finalizarConferencia(conferenciaId, observacao = '') {
    try {
        if (!await confirmAction('Finalizar a conferência e enviar para aprovação?')) {
            return null;
        }

        showLoading(true);

        const { data, error } = await supabase.rpc('finalizar_conferencia_estoque', {
            p_conferencia_id: conferenciaId,
            p_observacao: observacao || null
        });

        if (error) throw error;

        const resultado = Array.isArray(data) ? data[0] : data;
        if (resultado && resultado.sucesso === false) {
            throw new Error(resultado.mensagem || 'Não foi possível finalizar a conferência');
        }

        showToast('Conferência enviada para aprovação!', 'success');
        return resultado;

    } catch (error) {
        handleError(error, 'Erro ao finalizar conferência');
        return null;
    } finally {
        showLoading(false);
    }
}

async function cancelarConferencia(conferenciaId) {
    try {
        if (!await confirmAction('Descartar esta conferência? Os itens contados serão perdidos.')) {
            return null;
        }

        showLoading(true);

        const { data, error } = await supabase.rpc('cancelar_conferencia_estoque', {
            p_conferencia_id: conferenciaId
        });

        if (error) throw error;

        const resultado = Array.isArray(data) ? data[0] : data;
        if (resultado && resultado.sucesso === false) {
            throw new Error(resultado.mensagem || 'Não foi possível cancelar a conferência');
        }

        showToast('Conferência cancelada.', 'warning');
        return resultado;

    } catch (error) {
        handleError(error, 'Erro ao cancelar conferência');
        return null;
    } finally {
        showLoading(false);
    }
}

// Lista conferências (aprovação/histórico). filters: { status }
async function listConferencias(filters = {}) {
    try {
        let query = supabase
            .from('conferencias_estoque')
            .select(`
                *,
                criado_por_usuario:users!conferencias_estoque_criado_por_fkey(full_name),
                aprovado_por_usuario:users!conferencias_estoque_aprovado_por_fkey(full_name)
            `)
            .order('criado_em', { ascending: false });

        if (filters.status) {
            query = query.eq('status', filters.status);
        }

        const { data, error } = await query;
        if (error) throw error;
        return data || [];

    } catch (error) {
        handleError(error, 'Erro ao listar conferências de estoque');
        return [];
    }
}

async function getConferencia(id) {
    try {
        const { data, error } = await supabase
            .from('conferencias_estoque')
            .select(`
                *,
                criado_por_usuario:users!conferencias_estoque_criado_por_fkey(full_name),
                aprovado_por_usuario:users!conferencias_estoque_aprovado_por_fkey(full_name)
            `)
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;

    } catch (error) {
        handleError(error, 'Erro ao buscar conferência');
        return null;
    }
}

async function aprovarConferencia(conferenciaId) {
    try {
        if (!await confirmAction('Aprovar esta conferência? O estoque será atualizado com os valores contados.')) {
            return null;
        }

        showLoading(true);

        const { data, error } = await supabase.rpc('aprovar_conferencia_estoque', {
            p_conferencia_id: conferenciaId
        });

        if (error) throw error;

        const resultado = Array.isArray(data) ? data[0] : data;
        if (resultado && resultado.sucesso === false) {
            throw new Error(resultado.mensagem || 'Não foi possível aprovar a conferência');
        }

        showToast(
            `Conferência aprovada! ${resultado.itens_atualizados} item(ns) atualizado(s).`,
            'success'
        );
        return resultado;

    } catch (error) {
        handleError(error, 'Erro ao aprovar conferência');
        return null;
    } finally {
        showLoading(false);
    }
}

async function rejeitarConferencia(conferenciaId, motivo) {
    try {
        if (!motivo || motivo.trim() === '') {
            throw new Error('Informe o motivo da rejeição');
        }

        showLoading(true);

        const { data, error } = await supabase.rpc('rejeitar_conferencia_estoque', {
            p_conferencia_id: conferenciaId,
            p_motivo: motivo
        });

        if (error) throw error;

        const resultado = Array.isArray(data) ? data[0] : data;
        if (resultado && resultado.sucesso === false) {
            throw new Error(resultado.mensagem || 'Não foi possível rejeitar a conferência');
        }

        showToast('Conferência rejeitada.', 'warning');
        return resultado;

    } catch (error) {
        handleError(error, 'Erro ao rejeitar conferência');
        return null;
    } finally {
        showLoading(false);
    }
}
