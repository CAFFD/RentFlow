# Etapa 04 — Confiabilidade do processamento

## Implementação e procedimentos

O método receber de EntregaListener entrega o envelope validado ao bean Processamento. O proxy de transação conclui o commit antes de devolver o controle ao listener. O ACK usa o deliveryTag no canal recebido. Processamento.aplicar insere a marca e o efeito no mesmo PostgreSQL local. ON CONFLICT DO NOTHING, chave primária e comparação do envelope em jsonb distinguem novo fato, replay equivalente e colisão. Uma colisão é rejeitada e jamais sobrescreve o registro. Retirada tem uma segunda constraint UNIQUE em reserva_id.

A configuração das cinco filas principais permaneceu intacta. `infra/rabbitmq/estacionamento.json` adiciona a política falhas-nucleo, a exchange rentflow.falhas e a fila durável rentflow.estacionamento. A importação e a validação ficam em scripts/preparar-nucleo.ps1. Há no máximo três tentativas locais para falhas transitórias de acesso ao banco. Uma mensagem permanentemente inválida, um conflito de negócio ou uma falha esgotada é rejeitada com requeue=false. O log identifica o evento, tipo, instância e classe do erro. Dead-lettering interno com filas classic tem risco residual se o destino falhar.

**Correção durante a preparação.** A primeira aplicação da política ocorreu enquanto as 14 cópias do EXP-01A aguardavam o TTL. Como a política também pode encaminhar mensagens expiradas, retiramos apenas falhas-nucleo antes da expiração. Conferimos o estacionamento vazio, as cinco filas sem política e zero Unacked. O preparador agora executa preflight antes de instalar uma política nova. Não houve descarte manual nem purga.

Os cenários de scripts/demonstrar.ps1 usam consultas com prazos e identificadores de execução. O cenário conflito induz uma violação de unicidade antes do commit. O cenário falha habilita um gancho somente na retirada e numa fixture marcada: após gravar uma autorização nova, o listener fecha o canal antes do ACK. A transação seguinte encontra a marca de processamento e confirma a duplicata. A retirada volta à configuração normal em finally no script operacional. O código de consumo não envia ACK em finally.

O [guia de leitura](../GUIA-DO-CODIGO.md) relaciona SQL, classes, operações do protocolo e limitações. O experimento usa um broker e um banco únicos e mede efeitos persistidos localmente. Ele não mede taxa de entrega, alta disponibilidade ou garantia global de entrega exatamente uma vez.

## Resultados reais

Na interrupção da comunicação, o eventId `c76401b3-ce0a-4534-9b20-570188f5a3de` foi confirmado pelo broker. A fila tinha zero consumidores e uma mensagem Ready. Retirada, auditoria e preparação já tinham um efeito cada, enquanto a consulta SQL de avisos retornou zero. Após reiniciar somente comunicação, a fila voltou a Ready=0 e Unacked=0, com um consumidor e um aviso.

No replay de `aa730321-88eb-4996-bd8b-bb577254fd4d`, os logs de retirada, comunicação, auditoria e preparação mostraram primeiro `ACK_COMMIT` e depois `ACK_DUPLICATA`. Os dois workers participaram das duas entregas da fila de preparação, mas a constraint compartilhada manteve uma tarefa. As contagens SQL foram 1,1,0,1,1, e o total por reserva na retirada permaneceu um.

O teste de conflito criou outro eventId com a mesma reserva. O INSERT da retirada lançou DuplicateKeyException. A nova marca em processed_events sofreu rollback, a autorização original permaneceu e uma entrega foi adicionada ao estacionamento. O teste de falha controlada usou `473a8ead-ca03-4ed3-8b8b-93d9a812db68`: houve commit, fechamento do canal antes do ACK, `redelivered=true`, `ACK_DUPLICATA` e uma autorização.

| Experimento | Resultado observado | Veredito |
|---|---|---|
| E01 matriz obrigatória | 4, 2, 2 e 3 efeitos nos quatro eventos | PASS |
| E02 concorrência | 10 tarefas, Worker-A=6, Worker-B=4 | PASS |
| E03 interrupção | Ready 1 sem consumidor; aviso 0 antes e 1 depois | PASS |
| E04 duplicidade | Duas publicações, uma autorização e efeitos únicos | PASS |
| E05 extensibilidade | inspecao.agendada e inspecao.reaberta em manutenção + auditoria | PASS |
| E06 commit/ACK e falhas | rollback antes do commit e reentrega após commit comprovados | PASS |

## Limitações e verificação final

A transcrição completa está em [exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt](exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt). O script completo terminou com código 0 e restaurou a retirada sem o argumento de teste. Uma consulta final adicional de saúde, prefetch e contagens agregadas foi solicitada depois do ensaio, mas o revisor automático de execução recusou a chamada por limite de uso. Essa recusa não executou comando e não invalida as verificações feitas dentro do próprio experimento.

O cenário de conflito deixa propositalmente uma mensagem na fila `rentflow.estacionamento` para inspeção. Nenhuma fila principal foi purgada. As JVMs e os contêineres ficaram ativos após o ensaio.

## Perguntas para defesa

1. Por que basicAck aparece somente depois do retorno do serviço transacional?
2. Como ON CONFLICT DO NOTHING evita uma disputa entre os dois workers?
3. O que diferencia replay idêntico, colisão de eventId e nova reserva com reservaId repetida?
4. Por que uma falha após commit pode gerar redelivery?
5. O que a fila de estacionamento resolve e qual risco permanece em um broker de nó único?
