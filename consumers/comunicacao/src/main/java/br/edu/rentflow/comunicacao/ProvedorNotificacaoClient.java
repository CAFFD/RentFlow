package br.edu.rentflow.comunicacao;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

import java.util.Map;
import java.util.UUID;

@Component
public class ProvedorNotificacaoClient {
    private final RestClient http;

    public ProvedorNotificacaoClient(RestClient notificationRestClient) {
        this.http = notificationRestClient;
    }

    public void enviar(UUID avisoId, String conteudo, String destinatario) {
        http.post()
                .uri("/provider/messages")
                .header("Idempotency-Key", avisoId.toString())
                .body(Map.of(
                        "notificationId", avisoId,
                        "content", conteudo,
                        "recipient", destinatario == null ? "nao-informado" : destinatario))
                .retrieve()
                .toBodilessEntity();
    }
}
