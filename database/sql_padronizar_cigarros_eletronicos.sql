-- Consolida pods, essências e dispositivos na categoria exibida no catálogo público.

BEGIN;

UPDATE public.produtos
SET
    categoria = 'Cigarros eletrônicos',
    updated_at = NOW()
WHERE
    categoria IS DISTINCT FROM 'Cigarros eletrônicos'
    AND (
        LOWER(TRIM(COALESCE(categoria, ''))) IN (
            'cigarro eletronico',
            'cigarro eletrônico',
            'cigarros eletronicos',
            'cigarros eletrônicos',
            'pod',
            'pods',
            'essencia',
            'essência'
        )
        OR nome IN (
            'DINNER LADY LUMA 40K (LANÇAMENTO)',
            'HALLÚ 2.0',
            'IGNITE FROZEN 20K (LANÇAMENTO)',
            'NASTY SALT LIQUIDO 35MG / 30ML',
            'NASTY SALT LIQUIDO 50MG / 30ML',
            'NIKIBAR 30K',
            'V300',
            'V50 NEW  EDITION BLACK',
            'V80 NEW EDTION',
            'VAPORESSO XROS 5'
        )
    );

COMMIT;
