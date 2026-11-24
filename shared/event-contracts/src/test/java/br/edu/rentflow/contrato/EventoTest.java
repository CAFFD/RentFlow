package br.edu.rentflow.contrato;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import java.time.Instant;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;

class EventoTest {
    private final ObjectMapper mapper = new ObjectMapper();
    private Evento evento(String tipo, String data) throws Exception {
        return new Evento(UUID.fromString("00000000-0000-0000-0000-000000000001"),tipo,Instant.EPOCH,1,mapper.readTree(data));
    }
    @Test void aceitaFamiliaNova() throws Exception {
        evento("inspecao.reaberta","{}").validar("inspecao.reaberta");
    }
    @Test void rejeitaChaveDivergente() {
        assertThrows(IllegalArgumentException.class, () -> evento("novo.fato","{}").validar("outro.fato"));
    }
    @Test void exigeMotivoEDestinatario() {
        assertThrows(IllegalArgumentException.class, () -> evento("inspecao.reprovada","{}").validar("inspecao.reprovada"));
    }
    @Test void exigeJanelaCrescente() throws Exception {
        var e = evento("reserva.confirmada", """
                {"reservaId":"R","equipamentoId":"E","equipamento":"Gerador","cliente":"A",
                 "retiradaInicio":"2026-11-25T15:00:00Z","retiradaFim":"2026-11-25T14:00:00Z"}
                """);
        assertThrows(IllegalArgumentException.class, () -> e.validar(e.eventType()));
    }
}
