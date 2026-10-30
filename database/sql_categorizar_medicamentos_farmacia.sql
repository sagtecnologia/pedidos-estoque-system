-- Padroniza os medicamentos usados no cadastro atual na categoria Farmácia.
-- A lista nominal evita classificar automaticamente produtos não farmacêuticos.

BEGIN;

UPDATE public.produtos
SET
    categoria = 'Farmácia',
    updated_at = NOW()
WHERE
    categoria IS DISTINCT FROM 'Farmácia'
    AND (
        LOWER(TRIM(COALESCE(categoria, ''))) IN ('remedio', 'remédio', 'farmacia', 'farmácia')
        OR nome IN (
            'DECALAND DEPOT 200MG/ML  (LANDERGOLD)',
            'ENANTATO (LANDERGOLD)',
            'MASTERON 100MG/ML  (LANDERGOLD)',
            'PRIMABOLAN 100MG/ML  (MUSCLE-LABS)',
            'TG 15MG  (TIZERPATIDA)',
            'RETATRUTIDE SYNEDICA 40MG - CAIXA VERDE'
        )
    );

COMMIT;
