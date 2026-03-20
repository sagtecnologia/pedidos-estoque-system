// =====================================================
// CONFIGURAÇÃO DO SUPABASE
// =====================================================

// IMPORTANTE: Substitua com suas credenciais do Supabase
const SUPABASE_URL = 'https://hkrasdxmhkvoaclslvrr.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_kOxVylRe6zLoxst1uKrM5w_ln_4xKB2';

// Inicializar cliente Supabase e exportar para uso global
// A biblioteca Supabase CDN expõe o namespace em window.supabase
const { createClient } = window.supabase;
window.supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true
    }
});

// Listener global de mudança de estado de autenticação
// ESSENCIAL: sem isso o Supabase não faz refresh automático do token
window.supabase.auth.onAuthStateChange((event, session) => {
    console.log(`🔐 Auth state changed: ${event}`);
    
    if (event === 'TOKEN_REFRESHED') {
        console.log('🔄 Token renovado automaticamente');
    }
    
    if (event === 'SIGNED_OUT') {
        console.log('🚪 Usuário deslogado');
        // Só redireciona se não estiver já na página de login
        if (!window.location.pathname.includes('index.html') && 
            window.location.pathname !== '/' &&
            !window.location.pathname.includes('register.html') &&
            !window.location.pathname.includes('pedido-publico.html') &&
            !window.location.pathname.includes('auth-callback.html')) {
            window.location.href = '/index.html';
        }
    }
});
