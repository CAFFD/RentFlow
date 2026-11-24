package br.edu.rentflow.producer;

import br.edu.rentflow.contrato.Evento;
import com.fasterxml.jackson.databind.*;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import java.time.Instant;
import java.util.*;

@RestController
@RequestMapping("/events")
public class EventosApi {
    private final JdbcTemplate banco;
    private final ObjectMapper json;
    private final Publicador publicador;

    public EventosApi(JdbcTemplate banco, ObjectMapper json, Publicador publicador) {
        this.banco = banco; this.json = json; this.publicador = publicador;
    }

    @PostMapping("/{tipo}")
    public ResponseEntity<?> criar(@PathVariable String tipo, @RequestBody JsonNode data) throws Exception {
        Evento e = new Evento(UUID.randomUUID(), tipo, Instant.now(), 1, data);
        try { e.validar(tipo); }
        catch (IllegalArgumentException erro) { throw new ResponseStatusException(HttpStatus.BAD_REQUEST, erro.getMessage()); }
        String original = json.writeValueAsString(e);
        banco.update("INSERT INTO producer.eventos(event_id,tipo,original) VALUES (?,?,?)", e.eventId(), tipo, original);
        return resposta(publicador.publicar(e.eventId(), tipo, original));
    }

    private Map<String,Object> fato(UUID id) {
        return banco.queryForList("SELECT tipo,original FROM producer.eventos WHERE event_id=?", id).stream()
                .findFirst().orElseThrow(() -> new ResponseStatusException(HttpStatus.NOT_FOUND));
    }

    @PostMapping("/{id}/replay")
    public ResponseEntity<?> repetir(@PathVariable UUID id) {
        var fato = fato(id);
        return resposta(publicador.publicar(id, (String) fato.get("tipo"), (String) fato.get("original")));
    }

    private ResponseEntity<?> resposta(Map<String,Object> resultado) {
        return ResponseEntity.status("PUBLICADO".equals(resultado.get("estado")) ? 200 : 503).body(resultado);
    }

    @GetMapping("/{id}")
    public Map<String,Object> consultar(@PathVariable UUID id) throws Exception {
        var fato = fato(id);
        var tentativas = banco.queryForList("SELECT id,estado,motivo,iniciada,concluida FROM producer.tentativas WHERE event_id=? ORDER BY iniciada,id", id);
        String estado = "PENDENTE";
        if (!tentativas.isEmpty()) estado = "FALHA";
        if (tentativas.stream().anyMatch(t -> "INDETERMINADO".equals(t.get("estado")))) estado = "INDETERMINADO";
        if (tentativas.stream().anyMatch(t -> "PUBLICADO".equals(t.get("estado")))) estado = "PUBLICADO";

        return Map.of("envelope",json.readTree((String) fato.get("original")), "original",fato.get("original"), "estado",estado,"tentativas",tentativas);
    }
}
