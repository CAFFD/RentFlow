package br.edu.rentflow.contrato;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Instant;
import java.util.UUID;

public record Evento(UUID eventId, String eventType, Instant occurredAt, int schemaVersion, JsonNode data) {
    public static Evento ler(ObjectMapper mapper, String original, String chave) throws JsonProcessingException {
        JsonNode raiz = mapper.reader().with(DeserializationFeature.FAIL_ON_READING_DUP_TREE_KEY,
                DeserializationFeature.FAIL_ON_TRAILING_TOKENS).readTree(original);
        if (raiz == null || !raiz.isObject() || !raiz.path("eventId").isTextual() ||
                !raiz.path("eventType").isTextual() || !raiz.path("occurredAt").isTextual() ||
                !raiz.path("occurredAt").textValue().endsWith("Z") || !raiz.path("schemaVersion").isInt())
            throw new IllegalArgumentException("Formato do envelope invalido");
        Evento evento = mapper.treeToValue(raiz, Evento.class);
        if (!evento.eventId().toString().equalsIgnoreCase(raiz.path("eventId").textValue()))
            throw new IllegalArgumentException("UUID fora do formato canonico");
        evento.validar(chave);
        return evento;
    }

    public void validar(String chave) {
        if (eventId == null || occurredAt == null || schemaVersion != 1 || data == null || !data.isObject())
            throw new IllegalArgumentException("Envelope incompleto ou versao invalida");
        if (eventType == null || !eventType.equals(chave) || eventType.length() > 255 ||
                !eventType.matches("[a-z0-9_-]+(\\.[a-z0-9_-]+)*"))
            throw new IllegalArgumentException("Tipo ou chave de roteamento invalida");
        switch (eventType) {
            case "reserva.confirmada" -> {
                exigir("reservaId", "equipamentoId", "equipamento", "cliente");
                if (!instante("retiradaInicio").isBefore(instante("retiradaFim")))
                    throw new IllegalArgumentException("Janela de retirada invalida");
            }
            case "reserva.cancelada" -> exigir("reservaId", "equipamentoId", "cliente");
            case "inspecao.aprovada" -> exigir("inspecaoId", "equipamentoId", "equipamento");
            case "inspecao.reprovada" -> exigir("inspecaoId", "equipamentoId", "equipamento", "motivo", "destinatario");
            case "inspecao.agendada" -> { exigir("inspecaoId", "equipamentoId"); instante("agendadaPara"); }
            case "equipamento.cadastrado" -> exigir("equipamentoId", "equipamento");
            default -> { /* Tipos novos preservam dados e envelope. */ }
        }
    }

    private void exigir(String... campos) {
        for (String campo : campos) {
            JsonNode valor = data.path(campo);
            if (!valor.isTextual() || valor.textValue().isBlank()) throw new IllegalArgumentException("Campo obrigatorio: " + campo);
        }
    }

    public Instant instante(String campo) {
        exigir(campo);
        try { return Instant.parse(texto(campo)); }
        catch (java.time.DateTimeException erro) { throw new IllegalArgumentException("Instante invalido: " + campo, erro); }
    }

    public String texto(String campo) { return data.path(campo).asText(null); }
}
