package br.edu.rentflow.consumo;

import com.fasterxml.jackson.databind.*;
import org.springframework.web.bind.annotation.*;
import java.time.Instant;
import java.util.*;

@RestController
public class ConsultaApi {
    private final EfeitosRepository repositorio;
    private final ObjectMapper mapper;
    public ConsultaApi(EfeitosRepository repositorio, ObjectMapper mapper) { this.repositorio = repositorio; this.mapper = mapper; }

    @GetMapping("/effects")
    public List<JsonNode> consultar(@RequestParam(required=false) UUID eventId, @RequestParam(required=false) String eventType,
            @RequestParam(required=false) Instant inicio, @RequestParam(required=false) Instant fim) throws Exception {
        List<JsonNode> itens = new ArrayList<>();
        for (String linha : repositorio.consultar(eventId,eventType,inicio,fim)) itens.add(mapper.readTree(linha));
        return itens;
    }
}
