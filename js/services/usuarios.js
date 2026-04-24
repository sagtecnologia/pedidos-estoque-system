// =====================================================
// SERVIÇO DE USUÁRIOS
// =====================================================

// Listar usuários
async function listUsuarios(filters = {}) {
    try {
        let query = supabase
            .from('users')
            .select('*')
            .order('full_name');

        if (filters.role) {
            query = query.eq('role', filters.role);
        }

        if (filters.active !== undefined) {
            query = query.eq('active', filters.active);
        }

        if (filters.search) {
            query = query.or(`full_name.ilike.%${filters.search}%,email.ilike.%${filters.search}%`);
        }

        const { data, error } = await query;

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao listar usuários');
        return [];
    }
}

// Buscar usuário por ID
async function getUsuario(id) {
    try {
        const { data, error } = await supabase
            .from('users')
            .select('*')
            .eq('id', id)
            .single();

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar usuário');
        return null;
    }
}

// Atualizar usuário
async function updateUsuario(id, usuario, novaSenha = null) {
    try {
        showLoading(true);

        const { data, error } = await supabase
            .from('users')
            .update(usuario)
            .eq('id', id)
            .select()
            .single();

        if (error) throw error;

        if (novaSenha) {
            const { error: senhaError } = await supabase.rpc('admin_update_user_password', {
                p_user_id: id,
                p_new_password: novaSenha
            });

            if (senhaError) throw senhaError;
        }

        showToast(
            novaSenha ? 'Usuário e senha atualizados com sucesso!' : 'Usuário atualizado com sucesso!',
            'success'
        );
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao atualizar usuário');
        return null;
    } finally {
        showLoading(false);
    }
}

// Desativar usuário
async function deactivateUsuario(id) {
    try {
        if (!await confirmAction('Deseja realmente desativar este usuário?')) {
            return false;
        }

        showLoading(true);

        const { error } = await supabase
            .from('users')
            .update({ active: false })
            .eq('id', id);

        if (error) throw error;

        showToast('Usuário desativado com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao desativar usuário');
        return false;
    } finally {
        showLoading(false);
    }
}

// Ativar usuário
async function activateUsuario(id) {
    try {
        showLoading(true);

        const { error } = await supabase
            .from('users')
            .update({ active: true })
            .eq('id', id);

        if (error) throw error;

        showToast('Usuário ativado com sucesso!', 'success');
        return true;
        
    } catch (error) {
        handleError(error, 'Erro ao ativar usuário');
        return false;
    } finally {
        showLoading(false);
    }
}

// Listar aprovadores
async function getAprovadores() {
    try {
        const { data, error } = await supabase
            .from('users')
            .select('*')
            .eq('role', 'APROVADOR')
            .eq('active', true)
            .order('full_name');

        if (error) throw error;
        return data;
        
    } catch (error) {
        handleError(error, 'Erro ao buscar aprovadores');
        return [];
    }
}
