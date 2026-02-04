/**
 * Serviço de gerenciamento de filtros para listas (Vendas, Pedidos, etc.)
 * Usa sessionStorage para manter os filtros até o recarregamento da página
 */

class FiltroManager {
    constructor(chaveBase) {
        this.chaveBase = chaveBase;
        this.chavePrefix = `filtros_${chaveBase}`;
    }

    /**
     * Salvar estado dos filtros
     * @param {Object} filtros - Objeto com os valores dos filtros
     */
    salvarFiltros(filtros) {
        try {
            sessionStorage.setItem(this.chavePrefix, JSON.stringify(filtros));
        } catch (e) {
            console.error('Erro ao salvar filtros:', e);
        }
    }

    /**
     * Recuperar filtros salvos
     * @returns {Object} Objeto com os filtros ou null se não encontrado
     */
    recuperarFiltros() {
        try {
            const filtros = sessionStorage.getItem(this.chavePrefix);
            return filtros ? JSON.parse(filtros) : null;
        } catch (e) {
            console.error('Erro ao recuperar filtros:', e);
            return null;
        }
    }

    /**
     * Limpar filtros salvos
     */
    limparFiltros() {
        try {
            sessionStorage.removeItem(this.chavePrefix);
        } catch (e) {
            console.error('Erro ao limpar filtros:', e);
        }
    }

    /**
     * Verificar se há filtros salvos
     * @returns {boolean}
     */
    temFiltrosSalvos() {
        return sessionStorage.getItem(this.chavePrefix) !== null;
    }

    /**
     * Aplicar filtros aos elementos do DOM
     * @param {Object} filtros - Objeto com os filtros a aplicar
     * @param {Array<string>} ids - IDs dos elementos a atualizar
     */
    aplicarFiltrosDOM(filtros, ids = {}) {
        Object.keys(filtros).forEach(chave => {
            const id = ids[chave] || chave;
            const elemento = document.getElementById(id);
            if (elemento) {
                elemento.value = filtros[chave];
            }
        });
    }

    /**
     * Extrair valores dos filtros do DOM
     * @param {Array<string>} ids - Array com os IDs dos elementos dos filtros
     * @returns {Object} Objeto com os valores dos filtros
     */
    extrairFiltrosDOM(ids = {}) {
        const filtros = {};
        Object.keys(ids).forEach(chave => {
            const id = ids[chave];
            const elemento = document.getElementById(id);
            if (elemento) {
                filtros[chave] = elemento.value;
            }
        });
        return filtros;
    }
}

/**
 * Criar instância do gerenciador de filtros para Vendas
 */
const filtroVendas = new FiltroManager('vendas');

/**
 * Criar instância do gerenciador de filtros para Pedidos de Compra
 */
const filtroPedidos = new FiltroManager('pedidos');

/**
 * Criar instância do gerenciador de filtros para Pré-Pedidos
 */
const filtroPrePedidos = new FiltroManager('pre-pedidos');
