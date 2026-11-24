package br.edu.rentflow.comunicacao;

import br.edu.rentflow.contrato.Evento;
import br.edu.rentflow.consumo.EfeitosRepository;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class ComunicacaoRepository extends EfeitosRepository {
    public ComunicacaoRepository(JdbcTemplate banco) { super(banco, "comunicacao"); }

    @Override
    public void criarEfeito(Evento e, String original, String worker) {
        String tipo = e.eventType();
        String conteudo = switch (tipo) {
            case "reserva.confirmada" -> "Reserva confirmada: " + e.texto("reservaId");
            case "reserva.cancelada" -> "Reserva cancelada: " + e.texto("reservaId");
            case "inspecao.reprovada" -> "Inspecao reprovada: " + e.texto("motivo");
            default -> throw new IllegalArgumentException("Evento fora da comunicacao");
        };
        String destino = e.texto("destinatario");
        banco.update("INSERT INTO comunicacao.efeitos(event_id,conteudo,destinatario,estado) VALUES (?,?,?,'PENDING')",
                e.eventId(), conteudo, destino != null ? destino : e.texto("cliente"));
    }
}
