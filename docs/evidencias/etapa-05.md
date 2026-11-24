# Etapa 05 — Circuit Breaker e estabilização

Data: 24/11/2026. Escopo: integração HTTP opcional da comunicação e regressão do núcleo. Nenhuma fila foi purgada, nenhum volume foi removido e a mensagem de laboratório em `rentflow.estacionamento` foi preservada.

## Versão estável e diagnóstico

- Núcleo 00–04 preservado antes da alteração no commit local `4abcead`, tag `core-etapas-00-04`.
- Espaço livre inicial em C: 1.440.792.576 bytes. Docker: duas imagens/containers do RENTFLOW em execução; nenhuma limpeza realizada.
- RabbitMQ e PostgreSQL saudáveis; aplicações 8080–8086 responderam `UP`.
- Cinco filas principais vazias antes dos ensaios. `rentflow.estacionamento`: Ready 1, Unacked 0, preservada.

## Implementação

- Resilience4j Circuit Breaker 2.4.0 somente em `consumers/comunicacao`.
- Circuito programático `notificationProvider`: COUNT_BASED 4; mínimo 4; limiar 50%; OPEN 10 s; duas permissões HALF_OPEN; transição automática desativada.
- Cliente HTTP real: conexão 1 s e leitura 2 s. HTTP 5xx, conexão e timeout são falhas; exceções chegam ao circuito.
- Migração incremental `V002__notificacao_http.sql`, aplicada ao volume existente, adicionou estado, tentativas, bloqueios, erros, horários e claim temporário sem apagar dados.
- Provedor independente com `jdk.httpserver` em 127.0.0.1:8090, modos 200/503, contadores e deduplicação em memória pela chave de idempotência.
- O listener e o ACK não foram alterados: evento → aviso/commit → ACK. O despacho HTTP é explícito e posterior.

## Validações reais

O build completo terminou com `BUILD SUCCESS`: 18 testes (10 contratos, 6 produtor, 2 comunicação), zero falhas. A primeira tentativa de empacotar encontrou o JAR da comunicação bloqueado pela JVM no Windows; somente esse processo foi parado, o build foi repetido e passou.

E07: [transcrição integral](e07-deffdd7c-1a93-437c-bc60-59588b7bd054.txt).

| Verificação | Observado |
|---|---|
| Fluxo saudável inicial | HTTP 200, aviso SENT, circuito CLOSED |
| Quatro falhas HTTP 503 | 4 chamadas chegaram ao provedor; circuito OPEN |
| Tentativa adicional em OPEN | bloqueada; 0 tentativa HTTP no aviso; provedor permaneceu com 4 chamadas |
| Reserva publicada em OPEN | retirada 1, comunicação PENDING 1, auditoria 1, preparação 1 |
| Após 10 s | permaneceu OPEN até a próxima chamada, conforme transição não automática |
| Duas sondas saudáveis | primeira levou a HALF_OPEN; segunda levou a CLOSED |
| Final | 10 chamadas reais, 6 IDs entregues, todos os avisos selecionados SENT |
| Estacionamento | Ready permaneceu 1 |

Regressão:

- Matriz dos seis tipos e novo tipo `inspecao.reaberta`: PASS em [evidência](exp-nucleo-fb2951e9-1f39-4ae6-9c85-b82bd75f280d.txt).
- Competing consumers: 10 tarefas, Worker-A 5 e Worker-B 5, sem duplicidade, em [evidência](exp-nucleo-673204f0-6968-4fa4-965e-b7c754ff5442.txt).
- Interrupção/recuperação: comunicação com zero consumidores reteve uma mensagem enquanto os demais processaram; reinício consumiu e persistiu o aviso, em [evidência](exp-nucleo-d716aa55-4a8d-40f1-9f3f-0766cbbef4f3.txt).
- Replay: duas publicações do mesmo envelope e um efeito por responsabilidade; ACK_DUPLICATA explícito, em [evidência](exp-nucleo-f3c64135-209b-4274-82ee-1a7a91ca6aac.txt).
- Uma tentativa antecipada de interrupção falhou de forma segura porque uma fila ainda assentava após concorrência. Sem limpar dados, aguardou-se Ready/Unacked chegar a zero e o cenário foi repetido com PASS. [Registro da recusa](exp-nucleo-4ff4da9e-5b2e-4aa7-ac73-9cd59383d323.txt).

## Limitações

- Não há agendador: o despacho é deliberadamente explícito e determinístico.
- O mock perde contadores e deduplicação quando o processo reinicia.
- Se o provedor aceitar uma chamada e a atualização `SENT` falhar, haverá nova tentativa. O mock tolera isso pela chave idempotente; um provedor real também precisa honrá-la.
- O Circuit Breaker protege o provedor HTTP, não garante entrega exactly-once e não substitui timeout, ACK, idempotência local ou DLQ.
