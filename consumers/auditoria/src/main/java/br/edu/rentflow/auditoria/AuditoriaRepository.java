package br.edu.rentflow.auditoria;

import br.edu.rentflow.contrato.Evento;
import br.edu.rentflow.consumo.EfeitosRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class AuditoriaRepository extends EfeitosRepository {
    public AuditoriaRepository(JdbcTemplate banco) { super(banco, "auditoria"); }

    @Override
    public void criarEfeito(Evento e, String original, String worker) {
        banco.update("INSERT INTO auditoria.efeitos(event_id,original) VALUES (?,?)", e.eventId(), original);
    }
}
