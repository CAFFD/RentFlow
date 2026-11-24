CREATE SCHEMA IF NOT EXISTS producer;
CREATE TABLE IF NOT EXISTS producer.eventos (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, original text NOT NULL
);
CREATE TABLE IF NOT EXISTS producer.tentativas (
    id uuid PRIMARY KEY, event_id uuid NOT NULL REFERENCES producer.eventos,
    estado text NOT NULL, motivo text, iniciada timestamptz NOT NULL DEFAULT clock_timestamp(), concluida timestamptz
);
CREATE INDEX IF NOT EXISTS tentativas_evento ON producer.tentativas(event_id);

CREATE SCHEMA IF NOT EXISTS retirada;
CREATE TABLE IF NOT EXISTS retirada.processed_events (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, ocorrido timestamptz NOT NULL, envelope jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS retirada.efeitos (
    event_id uuid PRIMARY KEY REFERENCES retirada.processed_events,
    reserva_id text NOT NULL UNIQUE ,
    equipamento text NOT NULL ,
    cliente text NOT NULL ,
    inicio timestamptz NOT NULL ,
    fim timestamptz NOT NULL,
    processado timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE SCHEMA IF NOT EXISTS comunicacao;
CREATE TABLE IF NOT EXISTS comunicacao.processed_events (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, ocorrido timestamptz NOT NULL, envelope jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS comunicacao.efeitos (
    event_id uuid PRIMARY KEY REFERENCES comunicacao.processed_events,
    conteudo text NOT NULL ,
    destinatario text ,
    estado text NOT NULL,
    processado timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE SCHEMA IF NOT EXISTS manutencao;
CREATE TABLE IF NOT EXISTS manutencao.processed_events (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, ocorrido timestamptz NOT NULL, envelope jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS manutencao.efeitos (
    event_id uuid PRIMARY KEY REFERENCES manutencao.processed_events,
    equipamento text ,
    resultado text ,
    motivo text ,
    dados jsonb NOT NULL,
    processado timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE TABLE IF NOT EXISTS auditoria.processed_events (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, ocorrido timestamptz NOT NULL, envelope jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS auditoria.efeitos (
    event_id uuid PRIMARY KEY REFERENCES auditoria.processed_events,
    original text NOT NULL,
    processado timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE SCHEMA IF NOT EXISTS preparacao;
CREATE TABLE IF NOT EXISTS preparacao.processed_events (
    event_id uuid PRIMARY KEY, tipo text NOT NULL, ocorrido timestamptz NOT NULL, envelope jsonb NOT NULL
);
CREATE TABLE IF NOT EXISTS preparacao.efeitos (
    event_id uuid PRIMARY KEY REFERENCES preparacao.processed_events,
    reserva_id text NOT NULL ,
    equipamento text NOT NULL ,
    planejado timestamptz NOT NULL ,
    worker_id text NOT NULL,
    processado timestamptz NOT NULL DEFAULT clock_timestamp()
);
