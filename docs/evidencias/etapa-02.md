# Etapa 02 — Contrato e produtor AMQP

## Objetivo e alterações

O produtor agora grava o fato no PostgreSQL e publica o envelope pela exchange rentflow.events. O ciclo começou com leitura do kit, do DOCX e das evidências anteriores. Preservamos as versões, a infraestrutura e os módulos Maven. As aplicações rodam como JARs no Windows.

- `shared/event-contracts/src/main/java/br/edu/rentflow/contrato/Evento.java` implementa envelope v1, leitura e validação de data conforme o tipo. Os testes estão em src/test do módulo.
- `producer/src/main/java/br/edu/rentflow/producer/EventosApi.java` define criação, consulta e replay. `Publicador.java` registra a tentativa, envia com RabbitTemplate e classifica confirm/return/timeout. `PublicadorTest.java` exercita saídas excepcionais.
- Os POMs declaram as dependências necessárias sob o parent existente. Em application.properties, JDBC usa o banco local, AMQP usa vhost rentflow, confirms correlacionados, returns e mandatory. HTTP e Actuator usam loopback.
- `infra/sql/V001__nucleo.sql` cria producer.eventos e producer.tentativas. O texto original fica preservado; cada tentativa usa sua própria chave e referencia o UUID do fato.
- `scripts/disparar.ps1` gera dados fictícios identificáveis. O README e docs/CONTRATOS.md documentam os endpoints e a consulta do estado.

## Diagnóstico inicial e build

Em 24/11/2026 às 00:30 de Brasília, C: tinha 1.669.730.304 bytes livres. Docker Compose mostrou rabbitmq e postgres saudáveis nas portas de loopback previamente aprovadas. As sete portas HTTP estavam livres. As cinco filas tinham, na ordem retirada, comunicação, manutenção, auditoria e preparação, 1/3/3/6/1 mensagens prontas, zero consumidores e zero entregas Unacked. A transcrição de EXP-01A identificava o runId e os seis eventos anteriores com expiração de uma hora. Foi escolhida a expiração natural.

Executamos `.\mvnw.cmd -B -ntp verify`. O build passou no agregador e nos sete módulos. Os módulos de contrato e produtor executaram 16 testes ao todo. Seis usaram RabbitTemplate simulado para cobrir ACK, ACK com return, NACK do broker, canal fechado, timeout e conexão recusada. Quatro validaram campos e janela; quatro testaram leitura interoperável e entradas inválidas; dois verificaram deduplicação e colisão. A [saída do build](build-02-04.txt) registra 46,522 s e BUILD SUCCESS. O Maven resolveu as dependências necessárias usando o cache do usuário e o repositório Maven. Nenhuma imagem de aplicação foi construída.

## Decisão de confiabilidade

O fato e a tentativa são persistidos antes da chamada AMQP. A resposta contém eventId e attemptId. Apenas um confirm positivo sem return permite PUBLICADO. Quando há incerteza, a operação retorna HTTP 503 e o histórico continua consultável. Uma queda entre as operações do banco e do broker permite que um fato fique pendente ou que um envio cujo resultado é incerto já tenha sido entregue. O replay manual e a evolução para outbox estão explicados no [guia do código](../GUIA-DO-CODIGO.md).

## Resultados reais e aceite

O ensaio integrado usou o runId `2d25e89d-2c75-4acd-acb1-e48579033b55`. As seis fixtures iniciais e o tipo novo receberam `PUBLICADO`, um `attemptId` exclusivo e a justificativa `ACK do broker, sem return`. Uma reserva sem campos obrigatórios recebeu HTTP 400. Para cada evento da matriz, GET /events/{id} retornou uma tentativa e a auditoria preservou o texto `original` de forma idêntica.

No replay do evento `aa730321-88eb-4996-bd8b-bb577254fd4d`, o produtor manteve o mesmo eventId, occurredAt, data e texto original. As duas tentativas foram `c17a6ccc-24fe-4029-bc39-02dce7a3c109` e `0802a31b-02e8-4c94-a0fe-2bce0bba2d25`.

| Critério | Evidência | Veredito |
|---|---|---|
| Quatro eventos pela API Java | Matriz com reserva confirmada/cancelada e inspeção aprovada/reprovada | PASS |
| JSON validado | Reserva vazia retornou HTTP 400; 10 testes do contrato passaram | PASS |
| Fatos e tentativas registrados | eventId e attemptId distintos em cada publicação | PASS |
| Confirm e return tratados | Confirm real positivo; seis testes unitários cobriram todas as saídas | PASS |
| Replay fiel | Duas tentativas, mesmo texto original | PASS |
| Build | Agregador e sete módulos SUCCESS em 46,522 s | PASS |

Uma repetição offline final em 24/11/2026 apontou explicitamente para o cache Maven já usado e voltou a concluir os sete módulos com BUILD SUCCESS, 16 testes e tempo total de 48,918 s. A primeira tentativa dessa repetição falhou antes do build porque a sessão isolada escolheu `C:\.m2\repository`, sem permissão de escrita. O comando corrigido usou `-Dmaven.repo.local=C:/Users/gabri/.m2/repository`; nenhuma alteração de código foi necessária.

Limitação medida: o ensaio real comprovou o caminho de confirmação positiva. Return, NACK, timeout, canal fechado e conexão recusada foram exercitados com RabbitTemplate simulado, pois provocar essas condições no broker comprovado alteraria a topologia ou disponibilidade durante o ensaio. Não há transação distribuída entre PostgreSQL e RabbitMQ.

## Perguntas para defesa

1. Por que o eventId não pode ser usado como identificador da tentativa de publicação?
2. Como um ACK do broker pode coexistir com uma mensagem retornada por ausência de rota?
3. O que significa INDETERMINADO e por que a aplicação preserva o fato?
4. Quais partes do envelope permanecem iguais no replay?
5. Como uma outbox reduziria a janela entre banco e broker?
