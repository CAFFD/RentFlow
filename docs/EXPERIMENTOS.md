# Protocolo experimental
E01–E06 foram executados em 24/11/2026 com o runId `2d25e89d-2c75-4acd-acb1-e48579033b55` e passaram. IDs, contagens, logs e análise estão no [relatório da Etapa 04](evidencias/etapa-04.md) e na [transcrição integral](evidencias/exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt). O diferencial E07 também foi executado e aprovado com o runId `deffdd7c-1a93-437c-bc60-59588b7bd054`; consulte a [evidência da Etapa 05](evidencias/etapa-05.md). Em novas execuções, usar fixtures distintas, registrar runId, eventIds, data/hora, commit Git, versões, comandos reais, saídas e observações. Comparar deltas ou filtrar IDs; não depender de banco vazio. Capturar filas Ready/Unacked/Consumers e efeitos via GET/SQL. Screenshots sem segredos. Nunca apagar volumes automaticamente.

| ID | Procedimento | Critério esperado |
|---|---|---|
| E01 | Prever destinos e publicar os quatro tipos separadamente; aguardar processamento com timeout e consultar cada efeito | Matriz exata; uma confirmação gera 4 efeitos, cancelamento 2, aprovação 2, reprovação 3; total 11 efeitos de negócio em execução limpa |
| E02 | Subir dois workers da mesma fila; confirmar dois consumidores no painel; publicar 10 reservas distintas, usar pequeno delay de teste se necessário | 10 tarefas únicas por eventId, IDs dos dois workers presentes para demonstrar partilha; não exigir 5/5; retirada/comunicação/auditoria também recebem as 10 |
| E03 | Parar somente comunicação; publicar reserva confirmada; consultar outras filas e registros; mostrar Ready >= 1 na comunicação; religar | Outros três destinos processam; comunicação acumula e depois registra aviso; fila drena; broker permanece ativo |
| E04 | Escolher uma reserva já processada; consultar autorização; replay com mesmo envelope e ID; aguardar; consultar novamente | COUNT por reserva = 1 antes e depois; log duplicidade e ACK; não confundir publicação repetida com flag redelivered |
| E05 | Publicar inspecao.agendada e equipamento.cadastrado | Manutenção + auditoria no primeiro, auditoria somente no segundo, sem novo binding; efeitos genéricos preservam tipo e dados |
| E06 | Usar falha de persistência controlada antes do commit e, se possível, interrupção após commit antes do ACK | Sem ACK de sucesso antes do commit; falha segue política finita; redelivery/replay não duplica efeito; descrever o que foi de fato demonstrado |
| E07 | Com P0 concluído, mock HTTP 503; quatro tentativas, observar OPEN; quinta bloqueada sem HTTP; publicar evento enquanto circuito aberto; restaurar mock, esperar 10s e efetuar duas chamadas bem-sucedidas | Estado CLOSED→OPEN→HALF_OPEN→CLOSED; aviso permanece PENDING em falha; fluxo RabbitMQ continua; após sucesso marca SENT |

## Modelo de registro (copiar para cada teste)
- ID / objetivo:
- Ambiente / commit:
- Procedimento / comando:
- Resultado esperado:
- Resultado observado: PENDENTE
- Evidência (caminho, consulta, IDs):
- Veredito: NÃO EXECUTADO / PASSOU / FALHOU
- Limitações / análise:

Se um teste não puder ser executado, não usar 'passou'. Anexar logs brutos relevantes e screenshots reais em docs/evidencias/.
