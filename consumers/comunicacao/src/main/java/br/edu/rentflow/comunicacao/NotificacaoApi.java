package br.edu.rentflow.comunicacao;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

@RestController
@RequestMapping("/notifications")
public class NotificacaoApi {
    private final DespachoService despacho;
    private final AvisoRepository repositorio;

    public NotificacaoApi(DespachoService despacho, AvisoRepository repositorio) {
        this.despacho = despacho;
        this.repositorio = repositorio;
    }

    @PostMapping("/{eventId}/dispatch")
    public ResponseEntity<?> despachar(@PathVariable UUID eventId) {
        var resultado = despacho.despachar(eventId);
        int status = switch (resultado.resultado()) {
            case "SENT", "ALREADY_SENT" -> 200;
            case "NOT_FOUND" -> 404;
            case "BUSY", "DISABLED" -> 409;
            case "BLOCKED" -> 503;
            default -> 502;
        };
        return ResponseEntity.status(status).body(resultado);
    }

    @GetMapping("/{eventId}")
    public ResponseEntity<?> consultar(@PathVariable UUID eventId) {
        return repositorio.consultar(eventId)
                .<ResponseEntity<?>>map(ResponseEntity::ok)
                .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
