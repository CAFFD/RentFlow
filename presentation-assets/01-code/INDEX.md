# Índice dos recortes

| Recurso | Origem | Linhas | O que mostra |
|---|---|---:|---|
| `01-publicador-amqp.java.txt` | `producer/src/main/java/br/edu/rentflow/producer/Publicador.java` | 60–71 | mensagem persistente, RabbitTemplate, correlation data, confirm e return |
| `02-definitions-exchange.json.txt` | `infra/rabbitmq/definitions.json` | 7–16 | exchange topic durável |
| `03-definitions-binding-confirmada.json.txt` | `infra/rabbitmq/definitions.json` | 65–80 | cópias de reserva confirmada para retirada e comunicação |
| `04-definitions-bindings-comunicacao.json.txt` | `infra/rabbitmq/definitions.json` | 82–96 | reserva cancelada e inspeção reprovada para comunicação |
| `05-definitions-bindings-topic.json.txt` | `infra/rabbitmq/definitions.json` | 98–120 | padrões `inspecao.#`, `#` e preparação |
| `06-entrega-listener-ack.java.txt` | `shared/event-contracts/src/main/java/br/edu/rentflow/consumo/EntregaListener.java` | 28–48 | RabbitListener, commit antes do ACK e log de duplicata |
| `07-preparacao-repository-worker.java.txt` | `consumers/preparacao/src/main/java/br/edu/rentflow/preparacao/PreparacaoRepository.java` | 9–19 | tarefa planejada e worker responsável |
| `08-processamento-transacao.java.txt` | `shared/event-contracts/src/main/java/br/edu/rentflow/consumo/Processamento.java` | 6–15 | transação envolvendo dedupe e efeito |
| `09-efeitos-repository-idempotencia.java.txt` | `shared/event-contracts/src/main/java/br/edu/rentflow/consumo/EfeitosRepository.java` | 12–23 | ON CONFLICT e detecção de colisão |
| `10-v001-retirada-constraints.sql.txt` | `infra/sql/V001__nucleo.sql` | 11–23 | unicidade por eventId e reservaId |
| `11-v001-preparacao-constraints.sql.txt` | `infra/sql/V001__nucleo.sql` | 60–71 | efeito único e worker persistido |
| `12-circuito-config.java.txt` | `consumers/comunicacao/src/main/java/br/edu/rentflow/comunicacao/CircuitoConfig.java` | 14–29 | configuração Resilience4j e transições |
| `13-despacho-service.java.txt` | `consumers/comunicacao/src/main/java/br/edu/rentflow/comunicacao/DespachoService.java` | 41–63 | permissão, chamada protegida, sucesso e falha |
