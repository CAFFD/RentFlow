package br.edu.rentflow.comunicacao;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.util.UUID;
import java.util.concurrent.TimeUnit;

@Service
public class DespachoService {
    public record Resultado(String resultado, String circuito, AvisoRepository.Aviso aviso) {}

    private final AvisoRepository repositorio;
    private final ProvedorNotificacaoClient provedor;
    private final CircuitBreaker circuito;
    private final boolean habilitado;

    public DespachoService(AvisoRepository repositorio,
                           ProvedorNotificacaoClient provedor,
                           CircuitBreaker notificationProvider,
                           @Value("${rentflow.notification.enabled:false}") boolean habilitado) {
        this.repositorio = repositorio;
        this.provedor = provedor;
        this.circuito = notificationProvider;
        this.habilitado = habilitado;
    }

    public Resultado despachar(UUID eventId) {
        if (!habilitado) return resultado("DISABLED", eventId);

        UUID token = UUID.randomUUID();
        var aviso = repositorio.reivindicar(eventId, token);
        if (aviso.isEmpty()) {
            var atual = repositorio.consultar(eventId);
            if (atual.isEmpty()) return new Resultado("NOT_FOUND", circuito.getState().name(), null);
            String estado = "SENT".equals(atual.get().estado()) ? "ALREADY_SENT" : "BUSY";
            return new Resultado(estado, circuito.getState().name(), atual.get());
        }

        if (!circuito.tryAcquirePermission()) {
            repositorio.marcarBloqueio(eventId, token);
            return resultado("BLOCKED", eventId);
        }

        try {
            repositorio.registrarChamadaHttp(eventId, token);
        } catch (RuntimeException erroBanco) {
            circuito.releasePermission();
            tentarLiberar(eventId, token, erroBanco);
            throw erroBanco;
        }

        long inicio = System.nanoTime();
        try {
            provedor.enviar(eventId, aviso.get().conteudo(), aviso.get().destinatario());
            circuito.onSuccess(System.nanoTime() - inicio, TimeUnit.NANOSECONDS);
            repositorio.marcarEnviado(eventId, token);
            return resultado("SENT", eventId);
        } catch (RuntimeException erroHttp) {
            circuito.onError(System.nanoTime() - inicio, TimeUnit.NANOSECONDS, erroHttp);
            repositorio.marcarFalha(eventId, token, erroHttp.getClass().getSimpleName() + ": " + erroHttp.getMessage());
            return resultado("HTTP_FAILED", eventId);
        }
    }

    private Resultado resultado(String nome, UUID eventId) {
        return new Resultado(nome, circuito.getState().name(), repositorio.consultar(eventId).orElse(null));
    }

    private void tentarLiberar(UUID eventId, UUID token, RuntimeException erro) {
        try {
            repositorio.liberarSemChamada(eventId, token,
                    "Falha local antes do HTTP: " + erro.getClass().getSimpleName());
        } catch (RuntimeException ignorada) {
            erro.addSuppressed(ignorada);
        }
    }
}
