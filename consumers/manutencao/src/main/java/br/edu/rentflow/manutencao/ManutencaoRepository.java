package br.edu.rentflow.manutencao;

import br.edu.rentflow.contrato.Evento;
import br.edu.rentflow.consumo.EfeitosRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ManutencaoRepository extends EfeitosRepository {
    public ManutencaoRepository(JdbcTemplate banco) { super(banco, "manutencao"); }

    @Override
    public void criarEfeito(Evento e, String original, String worker) {
        String tipo = e.eventType();
        if (!tipo.startsWith("inspecao.") && !tipo.equals("inspecao")) throw new IllegalArgumentException("Evento fora da manutencao");
        String resultado = switch (tipo) {
            case "inspecao.aprovada" -> "APROVADA";
            case "inspecao.reprovada" -> "REPROVADA";
            default -> null;
        };
        String equipamento = e.texto("equipamento");
        banco.update("INSERT INTO manutencao.efeitos(event_id,equipamento,resultado,motivo,dados) VALUES (?,?,?,?,?::jsonb)",
                e.eventId(), equipamento != null ? equipamento : e.texto("equipamentoId"), resultado, e.texto("motivo"), e.data().toString());
    }
}
