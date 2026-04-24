// =====================================================
// SERVIÇO DE PRODUTOS
// =====================================================

// Listar produtos
async function listProdutos(filters = {}) {
    try {
        let query = supabase
            .from('produtos')
            .select('*')
            .eq('active', true)
            .order('nome');

        if (filters.categoria) {
            query = query.eq('categoria', filters.categoria);
        }

        if (filters.search) {
            query = query.or(`nome.ilike.%${filters.search}%,codigo.ilike.%${filters.search}%`);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar produtos');
        return [];
    }
}

// Buscar produto por ID
async function getProduto(id) {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produto');
        return null;
    }
}

// Criar produto
async function createProduto(produto) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        
        const { data, error } = await supabase
            .from('produtos')
            .insert([{
                ...produto,
                created_by: user.id
            }])
            .select()
            .single();

        if (error) throw error;

        showToast('Produto criado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao criar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Atualizar produto
async function updateProduto(id, produto) {
    try {
        showLoading(true);

        const { data, error } = await supabase
            .from('produtos')
            .update(produto)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        showToast('Produto atualizado com sucesso!', 'success');
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Deletar produto (soft delete)
async function deleteProduto(id) {
    try {
        if (!await confirmAction('Deseja realmente excluir este produto?')) {
            return false;
        }

        showLoading(true);

        const { error } = await supabase
            .from('produtos')
            .update({ active: false })
            .eq('id', id);

        if (error) throw error;

        showToast('Produto excluído com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao excluir produto');
        return false;
    } finally {
        showLoading(false);
    }
}

// Listar produtos com estoque baixo
async function getProdutosEstoqueBaixo() {
    try {
        // Usar rpc ou filtrar no cliente, pois Supabase não permite comparar colunas diretamente
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('active', true)
            .order('estoque_atual');

        if (error) throw error;
        
        // Filtrar no cliente produtos onde estoque_atual <= estoque_minimo
        return data.filter(p => p.estoque_atual <= p.estoque_minimo);
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produtos com estoque baixo');
        return [];
    }
}

// Listar categorias
async function getCategorias() {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('categoria')
            .eq('active', true)
            .not('categoria', 'is', null);

        if (error) throw error;

        // Remover duplicatas
        const categorias = [...new Set(data.map(p => p.categoria))];
        return categorias.sort();
        
    } catch (error) {
        handleError(error, 'Erro ao buscar categorias');
        return [];
    }
}

// =====================================================
// FUNÇÕES DE GERAÇÃO DE CÓDIGO
// =====================================================

// Gerar código automático do produto
async function generateProductCode(marca) {
    try {
        // Buscar último código da marca
        const prefixo = marca ? marca.substring(0, 3).toUpperCase() : 'PRD';
        
        const { data, error } = await supabase
            .from('produtos')
            .select('codigo')
            .like('codigo', `${prefixo}-%`)
            .order('codigo', { ascending: false })
            .limit(1);

        if (error) throw error;

        let nextNumber = 1;
        
        if (data && data.length > 0) {
            // Extrair número do último código (formato: XXX-0001)
            const lastCode = data[0].codigo;
            const match = lastCode.match(/-(\d+)$/);
            if (match) {
                nextNumber = parseInt(match[1]) + 1;
            }
        }

        // Formatar com 4 dígitos: IGN-0001, IGN-0002, etc.
        const codigo = `${prefixo}-${String(nextNumber).padStart(4, '0')}`;
        return codigo;
        
    } catch (error) {
        console.error('Erro ao gerar código:', error);
        // Fallback: usar timestamp
        return `PRD-${Date.now()}`;
    }
}

// =====================================================
// FUNÇÕES DE SABORES
// =====================================================

function normalizarSabores(sabores = []) {
    const saboresMap = new Map();

    sabores.forEach(sabor => {
        const nome = (sabor?.sabor || '').trim().toUpperCase();
        if (!nome) return;

        const quantidade = Number(sabor.quantidade) || 0;
        const codigoBarras = (sabor.codigo_barras || '').trim() || null;
        const existente = saboresMap.get(nome);

        if (existente) {
            existente.quantidade += quantidade;
            if (!existente.id && sabor.id) {
                existente.id = sabor.id;
            }
            if (!existente.codigo_barras && codigoBarras) {
                existente.codigo_barras = codigoBarras;
            }
            return;
        }

        saboresMap.set(nome, {
            id: sabor.id || null,
            sabor: nome,
            quantidade,
            codigo_barras: codigoBarras
        });
    });

    return Array.from(saboresMap.values());
}

// Buscar sabores de um produto
async function getSaboresProduto(produtoId, options = {}) {
    try {
        const { includeInactive = false } = options;
        const { data, error } = await supabase
            .from('produto_sabores')
            .select('*')
            .eq('produto_id', produtoId)
            .order('sabor');

        if (error) throw error;

        const sabores = data || [];
        return includeInactive ? sabores : sabores.filter(s => s.ativo === true);
        
    } catch (error) {
        handleError(error, 'Erro ao buscar sabores');
        return [];
    }
}

async function getProdutoInativoPorNomeEMarca(nome, marca) {
    const { data, error } = await supabase
        .from('produtos')
        .select('*')
        .eq('nome', nome)
        .eq('marca', marca)
        .eq('active', false)
        .order('updated_at', { ascending: false })
        .limit(1);

    if (error) throw error;
    return data?.[0] || null;
}

async function removerSaborProduto(saborId, produtoId) {
    const { data, error } = await supabase.rpc('remover_sabor_produto', {
        p_sabor_id: saborId,
        p_produto_id: produtoId
    });

    if (error) throw error;

    const resultado = Array.isArray(data) ? data[0] : data;
    if (resultado && resultado.sucesso === false) {
        throw new Error(resultado.mensagem || 'Não foi possível remover o sabor');
    }

    return resultado;
}

async function salvarSaborProduto(produtoId, sabor) {
    const { data, error } = await supabase.rpc('salvar_produto_sabor', {
        p_produto_id: produtoId,
        p_sabor_id: sabor.id || null,
        p_sabor: sabor.sabor,
        p_quantidade: sabor.quantidade || 0,
        p_codigo_barras: sabor.codigo_barras || null
    });

    if (error) throw error;

    const resultado = Array.isArray(data) ? data[0] : data;
    if (resultado && resultado.sucesso === false) {
        throw new Error(resultado.mensagem || 'Nao foi possivel salvar o sabor');
    }

    return resultado;
}

async function buscarSaborPorCodigoBarras(codigoBarras) {
    const codigo = (codigoBarras || '').trim();
    if (!codigo) return null;

    const { data, error } = await supabase
        .from('produto_sabores')
        .select(`
            id,
            produto_id,
            sabor,
            quantidade,
            codigo_barras,
            ativo,
            produto:produtos (
                id,
                codigo,
                nome,
                marca,
                preco,
                preco_venda,
                preco_compra,
                active
            )
        `)
        .eq('codigo_barras', codigo)
        .eq('ativo', true)
        .limit(1)
        .maybeSingle();

    if (error) throw error;
    if (!data || data.produto?.active === false) return null;

    return data;
}

// Criar produto com sabores
async function createProdutoComSabores(produto, sabores) {
    try {
        showLoading(true);
        
        const user = await getCurrentUser();
        const saboresNormalizados = normalizarSabores(sabores);
        const produtoInativo = await getProdutoInativoPorNomeEMarca(produto.nome, produto.marca);

        if (produtoInativo) {
            return await updateProdutoComSabores(produtoInativo.id, {
                ...produto,
                active: true
            }, saboresNormalizados);
        }
        
        // Gerar código automático baseado na marca
        const codigo = await generateProductCode(produto.marca);
        
        // 1. Criar produto
        const { data: produtoData, error: produtoError } = await supabase
            .from('produtos')
            .insert([{
                ...produto,
                codigo: codigo, // Código gerado automaticamente
                estoque_atual: 0, // Será calculado automaticamente pelo trigger
                created_by: user.id
            }])
            .select()
            .single();

        if (produtoError) throw produtoError;

        // 2. Criar sabores
        if (saboresNormalizados.length > 0) {
            const saboresInsert = saboresNormalizados.map(s => ({
                produto_id: produtoData.id,
                sabor: s.sabor,
                quantidade: s.quantidade || 0,
                ativo: true
            }));

            const { error: saboresError } = await supabase
                .from('produto_sabores')
                .insert(saboresInsert);

            if (saboresError) throw saboresError;
        }

        showToast('Produto criado com sucesso!', 'success');
        return produtoData;
        
    } catch (error) {
        handleError(error, 'Erro ao criar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Atualizar produto com sabores
async function updateProdutoComSabores(id, produto, sabores) {
    try {
        showLoading(true);
        const saboresNormalizados = normalizarSabores(sabores);

        // 1. Atualizar produto
        const { data: produtoData, error: produtoError } = await supabase
            .from('produtos')
            .update(produto)
            .eq('id', id)
            .select()
            .single();

        if (produtoError) throw produtoError;

        // 2. Buscar sabores existentes
        const saboresExistentes = await getSaboresProduto(id, { includeInactive: true });
        const saboresAtivos = saboresExistentes.filter(s => s.ativo === true);
        const saboresExistentesPorNome = new Map(
            saboresExistentes.map(s => [s.sabor.trim().toUpperCase(), s])
        );
        const saboresPreparados = saboresNormalizados.map(sabor => {
            const saborExistente = saboresExistentesPorNome.get(sabor.sabor);
            return saborExistente
                ? { ...sabor, id: saborExistente.id }
                : sabor;
        });
        const idsExistentes = saboresAtivos.map(s => s.id);
        const idsRecebidos = saboresPreparados.filter(s => s.id).map(s => s.id);

        // 3. Desativar sabores removidos
        const idsRemovidos = idsExistentes.filter(id => !idsRecebidos.includes(id));
        if (idsRemovidos.length > 0) {
            for (const saborId of idsRemovidos) {
                await removerSaborProduto(saborId, id);
            }
        }

        // 4. Atualizar e inserir sabores
        for (const sabor of saboresPreparados) {
            await salvarSaborProduto(id, sabor);
        }

        showToast('Produto atualizado com sucesso!', 'success');
        return produtoData;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar produto');
        return null;
    } finally {
        showLoading(false);
    }
}

// Listar marcas
async function getMarcas() {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('marca')
            .eq('active', true)
            .not('marca', 'is', null);

        if (error) throw error;

        // Remover duplicatas
        const marcas = [...new Set(data.map(p => p.marca))];
        return marcas.sort();
        
    } catch (error) {
        handleError(error, 'Erro ao buscar marcas');
        return [];
    }
}

// Listar produtos por marca
async function getProdutosPorMarca(marca) {
    try {
        const { data, error } = await supabase
            .from('produtos')
            .select('*')
            .eq('marca', marca)
            .eq('active', true)
            .order('nome');

        if (error) throw error;
        return data || [];
        
    } catch (error) {
        handleError(error, 'Erro ao buscar produtos');
        return [];
    }
}
