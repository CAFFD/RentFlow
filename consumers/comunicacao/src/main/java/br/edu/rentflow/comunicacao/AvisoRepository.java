package br.edu.rentflow.comunicacao;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public class AvisoRepository {
    public record Aviso(UUID eventId, String conteudo, String destinatario, String estado,
                        int tentativasHttp, int bloqueiosCircuito, String ultimoErro,
                        OffsetDateTime ultimaTentativa, OffsetDateTime enviadoEm) {}

    private final JdbcTemplate banco;

    public AvisoRepository(JdbcTemplate banco) {
        this.banco = banco;
    }

    public Optional<Aviso> reivindicar(UUID eventId, UUID token) {
        List<Aviso> avisos = banco.query("""
                UPDATE comunicacao.efeitos
                   SET estado='SENDING', claim_token=?, claim_until=clock_timestamp() + interval '15 seconds'
                 WHERE event_id=?
                   AND (estado='PENDING' OR (estado='SENDING' AND claim_until < clock_timestamp()))
                RETURNING event_id,conteudo,destinatario,estado,tentativas_http,bloqueios_circuito,
                          ultimo_erro,ultima_tentativa,enviado_em
                """, (rs, linha) -> new Aviso(
                        rs.getObject("event_id", UUID.class),
                        rs.getString("conteudo"),
                        rs.getString("destinatario"),
                        rs.getString("estado"),
                        rs.getInt("tentativas_http"),
                        rs.getInt("bloqueios_circuito"),
                        rs.getString("ultimo_erro"),
                        rs.getObject("ultima_tentativa", OffsetDateTime.class),
                        rs.getObject("enviado_em", OffsetDateTime.class)),
                token, eventId);
        return avisos.stream().findFirst();
    }

    public Optional<Aviso> consultar(UUID eventId) {
        List<Aviso> avisos = banco.query("""
                SELECT event_id,conteudo,destinatario,estado,tentativas_http,bloqueios_circuito,
                       ultimo_erro,ultima_tentativa,enviado_em
                  FROM comunicacao.efeitos WHERE event_id=?
                """, (rs, linha) -> new Aviso(
                        rs.getObject("event_id", UUID.class),
                        rs.getString("conteudo"),
                        rs.getString("destinatario"),
                        rs.getString("estado"),
                        rs.getInt("tentativas_http"),
                        rs.getInt("bloqueios_circuito"),
                        rs.getString("ultimo_erro"),
                        rs.getObject("ultima_tentativa", OffsetDateTime.class),
                        rs.getObject("enviado_em", OffsetDateTime.class)),
                eventId);
        return avisos.stream().findFirst();
    }

    public void registrarChamadaHttp(UUID eventId, UUID token) {
        exigirUmaLinha(banco.update("""
                UPDATE comunicacao.efeitos
                   SET tentativas_http=tentativas_http+1, ultima_tentativa=clock_timestamp()
                 WHERE event_id=? AND estado='SENDING' AND claim_token=?
                """, eventId, token), "Aviso perdeu a reivindicacao antes da chamada HTTP");
    }

    public void marcarEnviado(UUID eventId, UUID token) {
        exigirUmaLinha(banco.update("""
                UPDATE comunicacao.efeitos
                   SET estado='SENT', enviado_em=clock_timestamp(), ultimo_erro=NULL,
                       claim_token=NULL, claim_until=NULL
                 WHERE event_id=? AND estado='SENDING' AND claim_token=?
                """, eventId, token), "Aviso perdeu a reivindicacao depois do sucesso HTTP");
    }

    public void marcarFalha(UUID eventId, UUID token, String erro) {
        exigirUmaLinha(banco.update("""
                UPDATE comunicacao.efeitos
                   SET estado='PENDING', ultimo_erro=?, claim_token=NULL, claim_until=NULL
                 WHERE event_id=? AND estado='SENDING' AND claim_token=?
                """, limitar(erro), eventId, token), "Aviso perdeu a reivindicacao depois da falha HTTP");
    }

    public void marcarBloqueio(UUID eventId, UUID token) {
        exigirUmaLinha(banco.update("""
                UPDATE comunicacao.efeitos
                   SET estado='PENDING', bloqueios_circuito=bloqueios_circuito+1,
                       ultimo_erro='CIRCUIT_OPEN', claim_token=NULL, claim_until=NULL
                 WHERE event_id=? AND estado='SENDING' AND claim_token=?
                """, eventId, token), "Aviso perdeu a reivindicacao durante bloqueio do circuito");
    }

    public void liberarSemChamada(UUID eventId, UUID token, String erro) {
        marcarFalha(eventId, token, erro);
    }

    private static String limitar(String erro) {
        if (erro == null) return "Falha sem mensagem";
        return erro.length() <= 500 ? erro : erro.substring(0, 500);
    }

    private static void exigirUmaLinha(int linhas, String mensagem) {
        if (linhas != 1) throw new IllegalStateException(mensagem);
    }
}
