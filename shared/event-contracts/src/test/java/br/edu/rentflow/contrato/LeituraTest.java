package br.edu.rentflow.contrato;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class LeituraTest {
    private final ObjectMapper json = new ObjectMapper().findAndRegisterModules();
    private final String original = """
            {"eventId":"5ef5ec28-92b6-487e-a83b-c7ded756444b","eventType":"novo.fato",
            "occurredAt":"2026-11-24T00:00:00Z","schemaVersion":1,"data":{}}
            """;

    @Test void leEnvelopeInteroperavel() throws Exception {
        assertEquals("novo.fato",Evento.ler(json, original,"novo.fato").eventType());
    }
    @Test void rejeitaDoisEnvelopes() {
        assertThrows(Exception.class, () -> Evento.ler(json, original + original,"novo.fato"));
    }
    @Test void rejeitaTimestampNumerico() {
        assertThrows(IllegalArgumentException.class, () -> Evento.ler(json,original.replace("\"2026-11-24T00:00:00Z\"","0"),"novo.fato"));
    }
    @Test void rejeitaVersaoEmTexto() {
        assertThrows(IllegalArgumentException.class, () -> Evento.ler(json,original.replace(":1,",":\"1\","),"novo.fato"));
    }
}
