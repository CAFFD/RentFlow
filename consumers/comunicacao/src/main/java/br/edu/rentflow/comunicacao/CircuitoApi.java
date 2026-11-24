package br.edu.rentflow.comunicacao;

import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import org.springframework.web.bind.annotation.*;

import java.util.LinkedHashMap;
import java.util.Map;

@RestController
@RequestMapping("/circuit-breaker")
public class CircuitoApi {
    private final CircuitBreaker circuito;
    private final CircuitoEventos eventos;

    public CircuitoApi(CircuitBreaker notificationProvider, CircuitoEventos eventos) {
        this.circuito = notificationProvider;
        this.eventos = eventos;
    }

    @GetMapping
    public Map<String, Object> consultar() {
        var metrics = circuito.getMetrics();
        Map<String, Object> resposta = new LinkedHashMap<>();
        resposta.put("name", circuito.getName());
        resposta.put("state", circuito.getState().name());
        resposta.put("failureRate", metrics.getFailureRate());
        resposta.put("bufferedCalls", metrics.getNumberOfBufferedCalls());
        resposta.put("successfulCalls", metrics.getNumberOfSuccessfulCalls());
        resposta.put("failedCalls", metrics.getNumberOfFailedCalls());
        resposta.put("notPermittedCalls", metrics.getNumberOfNotPermittedCalls());
        resposta.put("transitions", eventos.consultar());
        return resposta;
    }

    @PostMapping("/reset")
    public Map<String, Object> reset() {
        circuito.reset();
        eventos.limpar();
        return consultar();
    }
}
