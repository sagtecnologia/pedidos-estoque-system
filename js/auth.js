// =====================================================
// AUTENTICAÇÃO
// =====================================================

// Fazer login
async function login(email, password) {
    try {
        showLoading(true);
        
        const { data, error } = await supabase.auth.signInWithPassword({
            email,
            password
        });

        if (error) throw error;

        // Verificar se o email foi confirmado
        if (!data.user.email_confirmed_at) {
            await supabase.auth.signOut();
            showToast('❌ Você precisa confirmar seu email antes de fazer login! Verifique sua caixa de entrada.', 'error', 6000);
            return;
        }

        // Buscar dados do usuário
        const { data: userData, error: userError } = await supabase
            .from('users')
            .select('*')
            .eq('id', data.user.id)
            .single();

        if (userError) throw userError;

        if (!userData.active) {
            await supabase.auth.signOut();
            showToast('⏳ Sua conta está aguardando aprovação do administrador. Você receberá um email quando for aprovada.', 'warning', 6000);
            return;
        }

        showToast('Login realizado com sucesso!', 'success');
        redirect(getDefaultRouteForUser(userData));
        
    } catch (error) {
        handleError(error, 'Erro ao fazer login');
    } finally {
        showLoading(false);
    }
}

// Fazer cadastro
async function register(email, password, fullName, role = 'COMPRADOR', whatsapp = null) {
    try {
        showLoading(true);

        // Criar usuário no auth do Supabase
        const { data: authData, error: authError } = await supabase.auth.signUp({
            email,
            password
        });

        if (authError) {
            // Tratar erro específico de email já registrado no Supabase Auth
            if (authError.message.includes('already registered') || 
                authError.message.includes('User already registered')) {
                throw new Error('Este email já está cadastrado. Se você já confirmou o email, faça login. Caso contrário, verifique sua caixa de entrada.');
            }
            throw authError;
        }

        // Criar registro na tabela users (PENDENTE DE APROVAÇÃO)
        const { error: userError } = await supabase
            .from('users')
            .insert([{
                id: authData.user.id,
                email,
                full_name: fullName,
                role: role,
                whatsapp: whatsapp,
                active: false
            }]);

        if (userError) {
            // Se o usuário já existe na tabela (tentativa de recadastro)
            if (userError.message.includes('duplicate key') || 
                userError.message.includes('users_email_key') ||
                userError.message.includes('users_pkey')) {
                // Usuário já está cadastrado, apenas mostrar o modal de confirmação
                console.log('Usuário já existe na tabela users, mostrando modal de confirmação');
            } else {
                // Outro erro, lançar exceção
                throw userError;
            }
        }

        // Mostrar modal de confirmação de email
        showEmailConfirmationModal(email);
        
    } catch (error) {
        // Se for erro customizado (mensagem em português), mostrar direto
        if (error.message.includes('já está cadastrado')) {
            showToast(error.message, 'error');
        } else {
            handleError(error, 'Erro ao fazer cadastro');
        }
    } finally {
        showLoading(false);
    }
}

// Mostrar modal de confirmação de email
function showEmailConfirmationModal(email) {
    const modal = document.createElement('div');
    modal.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    modal.innerHTML = `
        <div class="bg-white rounded-lg shadow-2xl max-w-md w-full mx-4 p-8">
            <div class="text-center">
                <div class="w-16 h-16 bg-green-100 rounded-full mx-auto mb-4 flex items-center justify-center">
                    <svg class="w-8 h-8 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 8l7.89 5.26a2 2 0 002.22 0L21 8M5 19h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"></path>
                    </svg>
                </div>
                <h2 class="text-2xl font-bold text-gray-900 mb-4">📧 Verifique seu Email AGORA!</h2>
                
                <div class="bg-green-100 border-l-4 border-green-600 p-4 mb-6 text-left">
                    <p class="text-sm text-green-900 mb-3">
                        <strong class="text-lg">✅ PASSO 1: CONFIRME SEU EMAIL</strong>
                    </p>
                    <p class="text-sm text-green-800 mb-2">
                        Enviamos um email de confirmação para:
                    </p>
                    <p class="text-green-900 font-bold break-all">${email}</p>
                </div>

                <div class="space-y-3 text-left mb-6 bg-white border-2 border-green-500 p-4 rounded-lg">
                    <p class="text-gray-800 font-semibold mb-3">
                        ⚡ Ações imediatas:
                    </p>
                    <p class="text-gray-700">
                        <strong class="text-green-600">1.</strong> Abra sua caixa de entrada <strong>AGORA</strong>
                    </p>
                    <p class="text-gray-700">
                        <strong class="text-green-600">2.</strong> Procure por um email com assunto <em>"Confirme seu cadastro"</em>
                    </p>
                    <p class="text-gray-700">
                        <strong class="text-green-600">3.</strong> Clique no link <strong>"Confirmar Email"</strong>
                    </p>
                    <p class="text-sm text-gray-600 italic mt-2">
                        💡 Verifique a pasta <strong>SPAM</strong> se não encontrar
                    </p>
                </div>

                <div class="bg-blue-50 border-l-4 border-blue-500 p-4 mb-6 text-left">
                    <p class="text-sm text-blue-900 mb-2">
                        <strong class="text-lg">⏳ PASSO 2: AGUARDE APROVAÇÃO</strong>
                    </p>
                    <p class="text-sm text-blue-800">
                        Após confirmar seu email, sua conta ficará <strong>pendente de aprovação</strong> do administrador. Você receberá uma notificação quando for aprovado.
                    </p>
                </div>

                <div class="bg-yellow-50 border-l-4 border-yellow-500 p-4 mb-6 text-left">
                    <p class="text-sm text-yellow-800">
                        <strong>⚠️ Atenção:</strong> O link de confirmação expira em 24 horas. Se não confirmar, será necessário fazer um novo cadastro.
                    </p>
                </div>
                <button onclick="window.location.href='/index.html'" class="w-full bg-purple-600 text-white py-3 px-4 rounded-lg font-semibold hover:bg-purple-700 transition">
                    Ir para Login
                </button>
            </div>
        </div>
    `;
    document.body.appendChild(modal);
}

// Fazer logout
async function logout() {
    try {
        // Verificar se há sessão ativa antes de tentar logout
        const { data: { session } } = await supabase.auth.getSession();
        
        if (session) {
            const { error } = await supabase.auth.signOut();
            if (error) throw error;
        }
        
        showToast('Logout realizado com sucesso!', 'success');
        redirect('/index.html');
        
    } catch (error) {
        // Se for erro de sessão, apenas redirecionar
        if (error.message?.includes('session') || error.message?.includes('Session')) {
            redirect('/index.html');
        } else {
            handleError(error, 'Erro ao fazer logout');
        }
    }
}

// Alterar senha
async function changePassword(newPassword) {
    try {
        showLoading(true);

        const { error } = await supabase.auth.updateUser({
            password: newPassword
        });

        if (error) throw error;

        showToast('Senha alterada com sucesso!', 'success');
        
    } catch (error) {
        handleError(error, 'Erro ao alterar senha');
    } finally {
        showLoading(false);
    }
}

// Recuperar senha
async function resetPassword(email) {
    try {
        showLoading(true);

        const { error } = await supabase.auth.resetPasswordForEmail(email, {
            redirectTo: window.location.origin + '/pages/reset-password.html'
        });

        if (error) throw error;

        showToast('Email de recuperação enviado!', 'success');
        
    } catch (error) {
        handleError(error, 'Erro ao enviar email de recuperação');
    } finally {
        showLoading(false);
    }
}
