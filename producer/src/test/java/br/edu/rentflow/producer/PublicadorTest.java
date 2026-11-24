package br.edu.rentflow.producer;

import org.junit.jupiter.api.Test;
import org.springframework.amqp.AmqpConnectException;
import org.springframework.amqp.core.*;
import org.springframework.amqp.rabbit.connection.CorrelationData;
import org.springframework.amqp.rabbit.core.RabbitTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import java.net.ConnectException;
import java.util.UUID;
import java.util.function.Consumer;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

class PublicadorTest {
    private final RabbitTemplate template = mock(RabbitTemplate.class);
    private final Publicador publicador = new Publicador(mock(JdbcTemplate.class), template);
    private final UUID evento = UUID.randomUUID();

    @org.junit.jupiter.api.AfterEach void encerrar() { publicador.encerrar(); }

    private String enviar(Consumer<CorrelationData> resposta) {
        doAnswer(invocacao -> {
            Message mensagem = invocacao.getArgument(2);
            assertEquals(MessageDeliveryMode.PERSISTENT, mensagem.getMessageProperties().getDeliveryMode());
            assertEquals(evento.toString(), mensagem.getMessageProperties().getMessageId());
            assertFalse(mensagem.getMessageProperties().getHeaders().containsKey("__TypeId__"));
            CorrelationData tentativa = invocacao.getArgument(3);
            assertNotEquals(evento.toString(),tentativa.getId());
            resposta.accept(tentativa);
            return null;
        }).when(template).send(eq("rentflow.events"),eq("novo.fato"),any(Message.class),any(CorrelationData.class));
        return publicador.publicar(evento,"novo.fato","{}").get("estado").toString();
    }

    @Test void ackSemRetorno() {
        assertEquals("PUBLICADO",enviar(c -> c.getFuture().complete(new CorrelationData.Confirm(true,null))));
    }
    @Test void ackComReturnFalha() {
        assertEquals("FALHA",enviar(c -> {
            c.setReturned(new ReturnedMessage(new Message(new byte[0]),312,"NO_ROUTE","rentflow.events","novo.fato"));
            c.getFuture().complete(new CorrelationData.Confirm(true,null));
        }));
    }
    @Test void nackDoBrokerFalha() {
        assertEquals("FALHA",enviar(c -> c.getFuture().complete(new CorrelationData.Confirm(false,null))));
    }
    @Test void fechamentoSemConfirmIndeterminado() {
        assertEquals("INDETERMINADO",enviar(c -> c.getFuture().complete(new CorrelationData.Confirm(false,"channel closed"))));
    }
    @Test void timeoutIndeterminado() {
        assertEquals("INDETERMINADO",enviar(c -> { /* Sem resposta do broker. */ }));
    }
    @Test void conexaoRecusadaFalha() {
        assertEquals("FALHA",enviar(c -> { throw new AmqpConnectException(new ConnectException()); }));
    }
}
