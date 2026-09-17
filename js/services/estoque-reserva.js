// =====================================================
// SERVIÇO DE ESTOQUE RESERVA
// =====================================================
// Move estoque de produtos/sabores do estoque principal para um
// estoque reserva nomeado (ex: "Depósito B"), com opção de devolver.
// Todas as escritas passam pelas funções RPC do banco (mover_estoque_para_reserva
// / retornar_estoque_reserva / criar_estoque_reserva / atualizar_estoque_reserva_status),
// que fazem toda a validação (permissão, saldo disponível, travas de
// concorrência). Este arquivo só chama essas funções e normaliza o retorno.

function normalizarResultadoRpc(data, mensagemPadraoErro) {
    const resultado = Array.isArray(data) ? data[0] : data;
    if (resultado && resultado.sucesso === false) {
        throw new Error(resultado.mensagem || mensagemPadraoErro);
    }
    return resultado;
}

// Lista todos os estoques reserva cadastrados (ativos e inativos)
async function listEstoquesReserva() {
    try {
        const { data, error } = await supabase
            .from('estoques')
            .select('*')
            .order('nome');

        if (error) throw error;
        return data || [];

    } catch (error) {
        handleError(error, 'Erro ao listar estoques');
        return [];
    }
}

async function criarEstoqueReserva(nome, descricao = null) {
    const { data, error } = await supabase.rpc('criar_estoque_reserva', {
        p_nome: nome,
        p_descricao: descricao
    });

    if (error) throw error;
    return normalizarResultadoRpc(data, 'Não foi possível criar o estoque');
}

async function atualizarEstoqueReservaStatus(estoqueId, ativo) {
    const { data, error } = await supabase.rpc('atualizar_estoque_reserva_status', {
        p_estoque_id: estoqueId,
        p_ativo: ativo
    });

    if (error) throw error;
    return normalizarResultadoRpc(data, 'Não foi possível alterar o estoque');
}

// Move quantidade do estoque principal para um estoque reserva.
// params: { produtoId, saborId (opcional), estoqueDestinoId, quantidade, observacao }
async function moverEstoqueParaReserva({ produtoId, saborId = null, estoqueDestinoId, quantidade, observacao = null }) {
    const { data, error } = await supabase.rpc('mover_estoque_para_reserva', {
        p_produto_id: produtoId,
        p_estoque_destino_id: estoqueDestinoId,
        p_quantidade: quantidade,
        p_sabor_id: saborId,
        p_observacao: observacao
    });

    if (error) throw error;
    return normalizarResultadoRpc(data, 'Não foi possível mover o estoque');
}

// Devolve quantidade de um estoque reserva para o estoque principal.
// params: { produtoId, saborId (opcional), estoqueOrigemId, quantidade, observacao }
async function retornarEstoqueReserva({ produtoId, saborId = null, estoqueOrigemId, quantidade, observacao = null }) {
    const { data, error } = await supabase.rpc('retornar_estoque_reserva', {
        p_produto_id: produtoId,
        p_estoque_origem_id: estoqueOrigemId,
        p_quantidade: quantidade,
        p_sabor_id: saborId,
        p_observacao: observacao
    });

    if (error) throw error;
    return normalizarResultadoRpc(data, 'Não foi possível devolver o estoque');
}

// Saldos atuais em estoque(s) reserva (só linhas com quantidade > 0)
async function listSaldosReserva(estoqueId = null) {
    try {
        let query = supabase
            .from('estoque_saldos_detalhado')
            .select('*')
            .order('produto_nome');

        if (estoqueId) {
            query = query.eq('estoque_id', estoqueId);
        }

        const { data, error } = await query;
        if (error) throw error;
        return data || [];

    } catch (error) {
        handleError(error, 'Erro ao listar saldos em estoque reserva');
        return [];
    }
}

// Histórico de transferências (envios e retornos)
async function listTransferenciasReserva(filters = {}) {
    try {
        let query = supabase
            .from('estoque_transferencias_detalhado')
            .select('*');

        if (filters.produtoId) {
            query = query.eq('produto_id', filters.produtoId);
        }
        if (filters.estoqueId) {
            query = query.or(`estoque_origem_id.eq.${filters.estoqueId},estoque_destino_id.eq.${filters.estoqueId}`);
        }
        if (filters.limit) {
            query = query.limit(filters.limit);
        }

        const { data, error } = await query;
        if (error) throw error;
        return data || [];

    } catch (error) {
        handleError(error, 'Erro ao listar histórico de transferências');
        return [];
    }
}

// Catálogo para a tela de "mover para reserva": produtos com sabor
// (uma linha por sabor ativo) + produtos sem nenhum sabor cadastrado
// (uma linha por produto, usando o estoque do próprio produto).
async function listCatalogoParaMovimentacao() {
    try {
        const { data: comSabor, error: erroSabor } = await supabase
            .from('produto_sabores')
            .select(`
                id,
                sabor,
                quantidade,
                ativo,
                produto:produtos!inner(id, codigo, nome, unidade, active)
            `)
            .eq('ativo', true)
            .eq('produto.active', true)
            .order('sabor');

        if (erroSabor) throw erroSabor;

        const produtosComSaborIds = new Set((comSabor || []).map(s => s.produto.id));

        const { data: todosProdutos, error: erroProdutos } = await supabase
            .from('produtos')
            .select('id, codigo, nome, unidade, estoque_atual, active')
            .eq('active', true)
            .order('nome');

        if (erroProdutos) throw erroProdutos;

        const semSabor = (todosProdutos || []).filter(p => !produtosComSaborIds.has(p.id));

        const itensComSabor = (comSabor || []).map(s => ({
            produtoId: s.produto.id,
            produtoCodigo: s.produto.codigo,
            produtoNome: s.produto.nome,
            unidade: s.produto.unidade,
            saborId: s.id,
            saborNome: s.sabor,
            disponivel: Number(s.quantidade) || 0
        }));

        const itensSemSabor = semSabor.map(p => ({
            produtoId: p.id,
            produtoCodigo: p.codigo,
            produtoNome: p.nome,
            unidade: p.unidade,
            saborId: null,
            saborNome: null,
            disponivel: Number(p.estoque_atual) || 0
        }));

        return [...itensComSabor, ...itensSemSabor].sort((a, b) =>
            a.produtoNome.localeCompare(b.produtoNome) || (a.saborNome || '').localeCompare(b.saborNome || '')
        );

    } catch (error) {
        handleError(error, 'Erro ao carregar produtos para movimentação');
        return [];
    }
}
