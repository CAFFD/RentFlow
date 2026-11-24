package br.edu.rentflow.consumo;

import br.edu.rentflow.contrato.Evento;
import org.springframework.jdbc.core.JdbcTemplate;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.*;

public abstract class EfeitosRepository {
    protected final JdbcTemplate banco;
    private final String schema;
    protected EfeitosRepository(JdbcTemplate banco, String schema) {
        this.banco = banco; this.schema = schema; // Constante fornecida pelo modulo.
    }

    public boolean registrar(Evento e, String original) {
        int novos = banco.update("INSERT INTO " + schema + ".processed_events(event_id,tipo,ocorrido,envelope) VALUES (?,?,?,?::jsonb) ON CONFLICT(event_id) DO NOTHING",
                e.eventId(), e.eventType(), Timestamp.from(e.occurredAt()), original);
        if (novos == 1) return true;
        Boolean igual = banco.queryForObject("SELECT envelope = ?::jsonb FROM " + schema + ".processed_events WHERE event_id=?", Boolean.class, original,e.eventId());
        if (!Boolean.TRUE.equals(igual)) throw new ColisaoDeEvento();
        return false;
    }

    public abstract void criarEfeito(Evento evento, String original, String worker);

    public List<String> consultar(UUID id, String tipo, Instant inicio, Instant fim) {
        StringBuilder sql = new StringBuilder("SELECT (to_jsonb(e) || jsonb_build_object('tipo',p.tipo,'ocorrido',p.ocorrido))::text FROM "
                + schema + ".efeitos e JOIN " + schema + ".processed_events p USING(event_id) WHERE true");
        List<Object> args = new ArrayList<>();
        if (id != null) { sql.append(" AND p.event_id=?"); args.add(id); }
        if (tipo != null) { sql.append(" AND p.tipo=?"); args.add(tipo); }
        if (inicio != null) { sql.append(" AND p.ocorrido>=?"); args.add(Timestamp.from(inicio)); }
        if (fim != null) { sql.append(" AND p.ocorrido<=?"); args.add(Timestamp.from(fim)); }
        sql.append(" ORDER BY p.ocorrido,p.event_id LIMIT 500");
        return banco.queryForList(sql.toString(), String.class, args.toArray());
    }
}
