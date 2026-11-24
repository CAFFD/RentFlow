package br.edu.rentflow.consumo;

import br.edu.rentflow.contrato.Evento;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.rabbitmq.client.Channel;
import org.slf4j.*;
import org.springframework.amqp.core.Message;
import org.springframework.amqp.rabbit.annotation.RabbitListener;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.*;
import org.springframework.jdbc.CannotGetJdbcConnectionException;
import org.springframework.transaction.CannotCreateTransactionException;
import java.nio.charset.StandardCharsets;
import java.io.IOException;

public class EntregaListener {
    private static final Logger log = LoggerFactory.getLogger(EntregaListener.class);
    private final Processamento servico;
    private final ObjectMapper mapper;
    private final String worker;
    private final boolean falhaAposCommit;
    public EntregaListener(Processamento servico, ObjectMapper mapper, @Value("${rentflow.consumer-id}") String worker,
            @Value("${rentflow.teste-falha:false}") boolean falhaAposCommit) {
        this.servico = servico; this.mapper = mapper; this.worker = worker; this.falhaAposCommit = falhaAposCommit;
    }

    @RabbitListener(queues="${rentflow.queue}")
    public void receber(Message mensagem, Channel canal) throws IOException, InterruptedException {
        var props = mensagem.getMessageProperties();
        long tag = props.getDeliveryTag();
        String original = new String(mensagem.getBody(), StandardCharsets.UTF_8);
        String tipo = props.getReceivedRoutingKey();
        String id = props.getMessageId();
        for (int tentativa = 1; tentativa <= 3; tentativa++) {
            try {
                Evento evento = Evento.ler(mapper, original, tipo);
                id = evento.eventId().toString();
                log.info("eventId={} eventType={} consumerId={} outcome=RECEBIDO redelivered={}", id,tipo,worker,props.getRedelivered());
                boolean novo = servico.aplicar(evento, original, worker);
                if (novo && falhaAposCommit && evento.data().path("testeFalhaAposCommit").asBoolean(false)) {
                    log.info("eventId={} eventType={} consumerId={} outcome=FALHA_SIMULADA_APOS_COMMIT",id,tipo,worker);
                    canal.abort(); // Teste local: entrega ainda sem ACK volta ao broker.
                    return;
                }
                canal.basicAck(tag,false);
                log.info("eventId={} eventType={} consumerId={} outcome={}",id,tipo,worker,novo ? "ACK_COMMIT" : "ACK_DUPLICATA");
                return;
            } catch (TransientDataAccessException | RecoverableDataAccessException | CannotCreateTransactionException | CannotGetJdbcConnectionException erro) {
                log.warn("eventId={} eventType={} consumerId={} outcome=TRANSITORIO tentativa={} erro={}",id,tipo,worker,tentativa,erro.getClass().getSimpleName());
                if (tentativa < 3) { Thread.sleep(250L * tentativa); continue; }
            } catch (JsonProcessingException | RuntimeException erro) {
                log.error("eventId={} eventType={} consumerId={} outcome=PERMANENTE erro={}",id,tipo,worker,erro.getClass().getSimpleName());
            }
            canal.basicReject(tag,false);
            return;
        }
    }
}
