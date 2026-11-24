package br.edu.rentflow.retirada;

import br.edu.rentflow.contrato.Evento;
import br.edu.rentflow.consumo.EfeitosRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.sql.Timestamp;

@Repository
public class RetiradaRepository extends EfeitosRepository {
    public RetiradaRepository(JdbcTemplate banco) { super(banco, "retirada"); }

    @Override
    public void criarEfeito(Evento e, String original, String worker) {
        String tipo = e.eventType();
        if (!tipo.equals("reserva.confirmada")) throw new IllegalArgumentException("Evento fora da retirada");
        banco.update("INSERT INTO retirada.efeitos(event_id,reserva_id,equipamento,cliente,inicio,fim) VALUES (?,?,?,?,?,?)",
                e.eventId(), e.texto("reservaId"), e.texto("equipamento"), e.texto("cliente"), Timestamp.from(e.instante("retiradaInicio")), Timestamp.from(e.instante("retiradaFim")));
    }
}
