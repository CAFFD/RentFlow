ALTER TABLE comunicacao.efeitos
    ADD COLUMN IF NOT EXISTS tentativas_http integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS bloqueios_circuito integer NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS ultimo_erro text,
    ADD COLUMN IF NOT EXISTS ultima_tentativa timestamptz,
    ADD COLUMN IF NOT EXISTS enviado_em timestamptz,
    ADD COLUMN IF NOT EXISTS claim_token uuid,
    ADD COLUMN IF NOT EXISTS claim_until timestamptz;

CREATE INDEX IF NOT EXISTS comunicacao_efeitos_estado
    ON comunicacao.efeitos (estado, processado);
