package br.edu.rentflow.consumo;

import br.edu.rentflow.contrato.Evento;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.JdbcTemplate;
import java.time.Instant;
import java.util.UUID;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class ProcessamentoTest {
    private final Evento evento = new Evento(UUID.randomUUID(),"novo.fato", Instant.EPOCH,1,new ObjectMapper().createObjectNode());

    @Test void duplicataNaoRepeteEfeito() {
        var repo = mock(EfeitosRepository.class);
        when(repo.registrar(evento,"original")).thenReturn(false);
        assertFalse(new Processamento(repo).aplicar(evento,"original","A"));
        verify(repo,never()).criarEfeito(any(),anyString(),anyString());
    }

    @Test void conflitoDeUuidComJsonDiferenteEhPermanente() {
        var banco = mock(JdbcTemplate.class);
        var repo = new EfeitosRepository(banco,"auditoria") {
            public void criarEfeito(Evento e, String original, String worker) { fail("Colisao nao pode gravar efeito"); }
        };
        // O INSERT encontrou a chave e o banco avaliou a igualdade jsonb como falsa.
        when(banco.queryForObject(anyString(),eq(Boolean.class),eq("alterado"),eq(evento.eventId()))).thenReturn(false);
        assertThrows(ColisaoDeEvento.class, () -> new Processamento(repo).aplicar(evento,"alterado","A"));
    }
}
