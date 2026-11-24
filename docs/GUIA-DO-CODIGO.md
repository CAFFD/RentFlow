# Guia de leitura do núcleo RENTFLOW

Comece com uma reserva confirmada. O objetivo é seguir um único UUID desde o HTTP até a autorização de retirada e explicar onde uma repetição pode acontecer.

## 1. Como um processo ganha vida

Abra `producer/src/main/java/br/edu/rentflow/producer/ProducerApplication.java` e `consumers/retirada/src/main/java/br/edu/rentflow/retirada/RetiradaApplication.java`. Cada método main chama SpringApplication.run. O Spring cria o contexto da aplicação, lê application.properties e configura o servidor HTTP, o pool JDBC e a conexão RabbitMQ. Cada JVM possui seu próprio contexto. O Compose executa somente o banco e o broker.

Um **bean** é um objeto cujo ciclo de vida o Spring administra. O produtor encontra EventosApi por @RestController e Publicador por @Service. No balcão, @Repository registra RetiradaRepository. @Import inclui EntregaListener, Processamento e ConsultaApi naquela JVM. Os construtores expressam as dependências. O Spring entrega ao Processamento o repositório específico daquela responsabilidade. Essa organização permite compartilhar a lógica de ACK mantendo o SQL de negócio visível em cada módulo.

## 2. Do formulário JSON ao registro de um fato

Em `scripts/disparar.ps1`, examine a construção de data. A fixture usa equipamento e cliente fictícios, novos identificadores de negócio e um runId para rastrear o experimento. Em `producer/.../EventosApi.java`, criar recebe data e o tipo da rota. Gera eventId e occurredAt, constrói Evento e valida o domínio. Em `shared/event-contracts/.../contrato/Evento.java`, confira a exigência de uma janela crescente e de motivo e destinatário para reprovação.

O ObjectMapper do Jackson serializa o envelope uma única vez. Essa string UTF-8 é persistida como text em producer.eventos. Na republicação, repetir recupera o texto integral e o envia novamente. Os consumidores usam Evento.ler para verificar a forma do JSON, versão numérica, UUID canônico, instante UTC terminado em Z e correspondência entre eventType e a chave AMQP recebida. Campos duplicados ou dois valores JSON concatenados falham na leitura. O campo data é um objeto JSON aberto. Um novo tipo válido pode chegar à auditoria; uma nova inspeção pode chegar também à manutenção.

## 3. O que o produtor consegue afirmar

Abra `Publicador.publicar`. O método cria um UUID de tentativa e uma linha inicialmente INDETERMINADO. Em enviar, RabbitTemplate publica bytes com content_type application/json, delivery_mode persistente e message_id do domínio. CorrelationData usa o UUID da tentativa para que duas publicações do mesmo fato sejam rastreadas separadamente. A exchange, o vhost, mandatory e as confirmações correlacionadas estão no código e no application.properties do produtor.

Uma conexão AMQP usa TCP. Nela, **channels** agrupam operações lógicas, como publicar ou receber entregas. O Spring mantém um cache para reutilizar conexões e canais. O produtor espera até cinco segundos pelo confirm; aguardar limita a oito segundos a operação incluindo fila local e envio. A capacidade local é de dois envios simultâneos e oito em espera. Uma tentativa recusada localmente falha antes do envio. Um timeout pode ocorrer depois que o broker já recebeu a mensagem. O cancelamento do trabalho local não recolhe uma publicação feita.

Quando uma publicação mandatory não encontra fila, o broker pode retornar a mensagem e confirmar que tratou a publicação. Por isso o código examina o return antes de aceitar o ACK. Um NACK do broker constitui falha. O framework também pode sinalizar NACK ao perder um canal com confirmação pendente; nesse caso o resultado é indeterminado. As saídas excepcionais são exercitadas com doubles nos testes do produtor. Consulte a descrição da ordem entre return e confirm na [documentação Spring AMQP](https://docs.spring.io/spring-amqp/reference/amqp/template.html).

O commit do fato, a publicação e a atualização da tentativa são operações separadas. Uma queda logo após inserir o fato deixa um evento pendente; outra queda logo após a publicação pode deixar uma tentativa indeterminada. A consulta reconstrói o estado do fato a partir das tentativas persistidas, preservando confirmações anteriores. Hoje a recuperação usa replay explícito. Uma evolução seria registrar fato e outbox na mesma transação PostgreSQL e ter um retransmissor que tente novamente e registre confirms. Os consumidores continuariam precisando de idempotência.

## 4. Da fila ao commit

Leia `shared/event-contracts/src/main/java/br/edu/rentflow/consumo/EntregaListener.java`. O contêiner Spring invoca receber por @RabbitListener. A configuração aponta para uma fila fixa, confirmação manual, uma thread de consumo e prefetch 1. O prefetch limita as entregas ainda sem confirmação naquela instância. Duas JVMs do mesmo JAR de preparação escutam a mesma fila. Quando ambas têm capacidade, o broker distribui trabalho entre elas. A participação dos dois workerIds pode ser medida no banco.

1. O listener lê o corpo e os metadados, valida o evento e registra RECEBIDO.
2. Chama o bean Processamento.aplicar. O proxy transacional inicia uma transação JDBC antes de entrar no método.
3. EfeitosRepository.registrar insere a chave em processed_events com ON CONFLICT DO NOTHING. A constraint no PostgreSQL arbitra disputas simultâneas. Em um conflito de UUID, a comparação jsonb verifica a igualdade de conteúdo, independentemente da ordem das propriedades.
4. Se o conteúdo é igual, aplicar retorna duplicata. Se o conteúdo mudou, lança ColisaoDeEvento. Para uma chave nova, criarEfeito executa o SQL do módulo. Os placeholders ? do JdbcTemplate vinculam valores em prepared statements. Os nomes dos schemas estão fixos no código.
5. Ao retornar do método transacional, o proxy tenta o commit. Somente quando o controle volta ao listener ele chama basicAck com o deliveryTag e o mesmo channel que entregou a mensagem. O log de ACK vem depois da chamada. Um erro de commit retorna como exceção e impede esse caminho.

Em `infra/sql/V001__nucleo.sql`, compare as chaves primárias de processed_events e efeitos com UNIQUE(reserva_id) em retirada. Se um segundo fato tem novo eventId e reutiliza a reserva, o INSERT da autorização falha e o identificador também sofre rollback. A autorização original permanece. No replay idêntico, a deduplicação ocorre antes desse INSERT.

## 5. O que consultar em cada módulo

| Repositório e método criarEfeito | Efeito observável em GET /effects |
|---|---|
| RetiradaRepository | Equipamento, cliente, reserva, início e fim da janela |
| ComunicacaoRepository | Conteúdo do aviso, destinatário e estado PENDING; o registro local conclui a responsabilidade |
| ManutencaoRepository | Tipo, dados originais, equipamento, resultado conhecido e motivo de reprovação. Resultado nulo para um fato novo |
| AuditoriaRepository | String original do envelope; filtros de UUID, tipo e ocorrência |
| PreparacaoRepository | Reserva, equipamento, planejamento 30 minutos antes da retirada e worker_id |

Todos os registros incluem event_id e processado. ConsultaApi delega a busca ao repositório do processo. Cada aplicação usa seu próprio login PostgreSQL. As duas instâncias de preparação compartilham schema e constraint.

## 6. Quando uma entrega falha

Falhas transitórias identificadas de acesso a dados têm até três tentativas na mesma entrega, com esperas locais de 250 e 500 ms. Dados inválidos, colisões e violações de integridade seguem para rejeição explícita. Ao esgotar as tentativas, o listener usa basicReject com requeue=false. A política versionada associa as cinco filas à exchange fanout rentflow.falhas e à fila durável rentflow.estacionamento. O operador pode investigar os cabeçalhos x-death, a fila de origem e o identificador sem apagar dados. Uma falha inesperada também é estacionada para investigação.

Com filas classic em um único nó, o dead-lettering interno pode perder uma mensagem se o destino estiver indisponível. Uma queda de conexão após o commit e antes do ACK permite redelivery. O experimento opcional fecha deliberadamente o canal apenas na retirada, somente para uma fixture marcada e somente após uma inserção nova. Na reentrega, a marca persistida impede repetir a autorização. Encerrar o processo de teste e iniciar retirada normalmente desabilita o gancho.

A garantia sustentada pelo desenho é a unicidade do **efeito local** dentro da transação e das chaves verificadas. Entregas, tentativas de publicação e registros de recebimento podem ocorrer mais de uma vez. Uma unidade PostgreSQL, um broker e um ensaio local delimitam o que foi medido.

## Perguntas de defesa

1. Qual UUID identifica o fato e qual identifica uma tentativa? Qual deles muda no replay?
2. Que linha impede um ACK prematuro se o PostgreSQL rejeitar o commit?
3. Qual constraint protege a reserva contra dois fatos diferentes e qual protege um worker de reprocessar o mesmo fato?
4. O que o produtor sabe quando o confirm expira? Como recuperar um evento nessa situação?
5. Por que existe apenas uma fila de preparação, e como provar que ambos os processos trabalharam?
