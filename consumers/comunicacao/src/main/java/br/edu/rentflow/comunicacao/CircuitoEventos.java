package br.edu.rentflow.comunicacao;

import io.github.resilience4j.circuitbreaker.event.CircuitBreakerOnStateTransitionEvent;
import org.springframework.stereotype.Component;

import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ConcurrentLinkedDeque;

@Component
public class CircuitoEventos {
    public record Transicao(Instant instante, String origem, String destino) {}

    private final ConcurrentLinkedDeque<Transicao> transicoes = new ConcurrentLinkedDeque<>();

    public void registrar(CircuitBreakerOnStateTransitionEvent evento) {
        var transicao = evento.getStateTransition();
        transicoes.addLast(new Transicao(Instant.now(),
                transicao.getFromState().name(), transicao.getToState().name()));
        while (transicoes.size() > 30) {
            transicoes.pollFirst();
        }
    }

    public List<Transicao> consultar() {
        return new ArrayList<>(transicoes);
    }

    public void limpar() {
        transicoes.clear();
    }
}
