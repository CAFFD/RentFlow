package br.edu.rentflow.comunicacao;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.junit.jupiter.api.Test;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class DespachoServiceTest {
    @Test
    void abreDepoisDeQuatroFalhasEBloqueiaSemExecutarHttp() {
        AvisoRepository repositorio = mock(AvisoRepository.class);
        ProvedorNotificacaoClient provedor = mock(ProvedorNotificacaoClient.class);
        CircuitoEventos eventos = new CircuitoEventos();
        CircuitBreaker circuito = new CircuitoConfig().notificationProvider(eventos);
        var servico = new DespachoService(repositorio, provedor, circuito, true);

        when(repositorio.reivindicar(any(), any())).thenAnswer(invocacao -> {
            UUID id = invocacao.getArgument(0);
            return Optional.of(aviso(id, "SENDING"));
        });
        when(repositorio.consultar(any())).thenAnswer(invocacao ->
                Optional.of(aviso(invocacao.getArgument(0), "PENDING")));
        doThrow(new IllegalStateException("HTTP 503")).when(provedor)
                .enviar(any(), anyString(), anyString());

        for (int i = 0; i < 4; i++) {
            assertEquals("HTTP_FAILED", servico.despachar(UUID.randomUUID()).resultado());
        }
        assertEquals(CircuitBreaker.State.OPEN, circuito.getState());

        var bloqueada = servico.despachar(UUID.randomUUID());
        assertEquals("BLOCKED", bloqueada.resultado());
        verify(provedor, times(4)).enviar(any(), anyString(), anyString());
        verify(repositorio, times(4)).registrarChamadaHttp(any(), any());
        verify(repositorio).marcarBloqueio(any(), any());
    }

    @Test
    void configuracaoEhExatamenteADemonstrada() {
        CircuitBreaker circuito = new CircuitoConfig().notificationProvider(new CircuitoEventos());
        var config = circuito.getCircuitBreakerConfig();
        assertEquals(4, config.getSlidingWindowSize());
        assertEquals(4, config.getMinimumNumberOfCalls());
        assertEquals(50, config.getFailureRateThreshold());
        assertEquals(2, config.getPermittedNumberOfCallsInHalfOpenState());
        assertFalse(config.isAutomaticTransitionFromOpenToHalfOpenEnabled());
        assertEquals(10_000, config.getWaitIntervalFunctionInOpenState().apply(1));
    }

    private static AvisoRepository.Aviso aviso(UUID id, String estado) {
        return new AvisoRepository.Aviso(id, "Aviso", "destino", estado,
                0, 0, null, null, null);
    }
}
