package br.edu.rentflow.producer;

import jakarta.annotation.PreDestroy;
import org.springframework.amqp.AmqpConnectException;
import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.concurrent.*;

@Service
public class Publicador {
    private record Resultado(String estado, String motivo) {}
    private final JdbcTemplate banco;
    private final RabbitTemplate rabbit;
    // Limita inclusive uma escrita bloqueada por alarme de recursos do broker.
    private final ExecutorService envios = new ThreadPoolExecutor(2, 2, 0, TimeUnit.SECONDS,
            new ArrayBlockingQueue<>(8), Thread.ofPlatform().daemon().name("publicacao-", 0).factory());

    public Publicador(JdbcTemplate banco, RabbitTemplate rabbit) {
        this.banco = banco;
        this.rabbit = rabbit;
    }

    public Map<String,Object> publicar(UUID evento, String tipo, String json) {
        UUID tentativa = UUID.randomUUID();
        banco.update("INSERT INTO producer.tentativas(id,event_id,estado) VALUES (?,?,'INDETERMINADO')", tentativa, evento);
        Resultado resultado = aguardar(evento, tipo, json, tentativa);
        banco.update("UPDATE producer.tentativas SET estado=?,motivo=?,concluida=now() WHERE id=?",
                resultado.estado(), resultado.motivo(), tentativa);
        return Map.of("eventId", evento, "attemptId", tentativa, "estado", resultado.estado(), "motivo", resultado.motivo());
    }

    private Resultado aguardar(UUID evento, String tipo, String json, UUID tentativa) {
        Future<Resultado> envio;
        try {
            envio = envios.submit(() -> enviar(evento, tipo, json, tentativa));
        } catch (RejectedExecutionException cheio) {
            return new Resultado("FALHA", "Limite de envios locais atingido antes da publicacao");
        }
        try {
            return envio.get(8, TimeUnit.SECONDS);
        } catch (InterruptedException erro) {
            envio.cancel(true);
            Thread.currentThread().interrupt();
            return new Resultado("INDETERMINADO", "Espera interrompida");
        } catch (TimeoutException erro) {
            envio.cancel(true);
            return new Resultado("INDETERMINADO", "Prazo da tentativa excedido");
        } catch (ExecutionException erro) {
            if (erro.getCause() instanceof AmqpConnectException)
                return new Resultado("FALHA", "Conexao recusada antes do envio");
            return new Resultado("INDETERMINADO", erro.getCause().getClass().getSimpleName());
        }
    }

    private Resultado enviar(UUID evento, String tipo, String json, UUID tentativa) throws Exception {
        var correlacao = new CorrelationData(tentativa.toString());
        var mensagem = MessageBuilder.withBody(json.getBytes(StandardCharsets.UTF_8))
                .setContentType("application/json").setContentEncoding("UTF-8")
                .setMessageId(evento.toString()).setDeliveryMode(MessageDeliveryMode.PERSISTENT).build();
        rabbit.send("rentflow.events", tipo, mensagem, correlacao);
        var confirm = correlacao.getFuture().get(5, TimeUnit.SECONDS);
        if (correlacao.getReturned() != null)
            return new Resultado("FALHA", "RETURN " + correlacao.getReturned().getReplyCode());
        if (confirm.isAck()) return new Resultado("PUBLICADO", "ACK do broker, sem return");
        if (confirm.getReason() == null) return new Resultado("FALHA", "NACK do broker");
        return new Resultado("INDETERMINADO", "Canal fechado sem confirm do broker");
    }

    @PreDestroy
    public void encerrar() { envios.shutdownNow(); }
}
