package br.edu.rentflow.preparacao;

import br.edu.rentflow.contrato.Evento;
import br.edu.rentflow.consumo.EfeitosRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;
import java.sql.Timestamp;

@Repository
public class PreparacaoRepository extends EfeitosRepository {
    public PreparacaoRepository(JdbcTemplate banco) { super(banco, "preparacao"); }

    @Override
    public void criarEfeito(Evento e, String original, String worker) {
        String tipo = e.eventType();
        if (!tipo.equals("reserva.confirmada")) throw new IllegalArgumentException("Evento fora da preparacao");
        banco.update("INSERT INTO preparacao.efeitos(event_id,reserva_id,equipamento,planejado,worker_id) VALUES (?,?,?,?,?)",
                e.eventId(), e.texto("reservaId"), e.texto("equipamento"), Timestamp.from(e.instante("retiradaInicio").minusSeconds(1800)), worker);
    }
}
