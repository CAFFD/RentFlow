# Experimentos reproduzíveis

## Preparação

Execute os testes com infraestrutura e aplicações saudáveis:

```powershell
.\scripts\iniciar.ps1
.\scripts\preparar-nucleo.ps1
.\scripts\apps.ps1 iniciar todos
.\scripts\apps.ps1 estado
.\scripts\filas.ps1
```

Cada execução gera UUIDs próprios e registra uma transcrição em `docs/evidencias/`. Os scripts consultam condições com timeout; não truncam tabelas nem purgam filas.

## Teste 1 — Roteamento

```powershell
.\scripts\demonstrar.ps1 matriz
```

| Evento | Efeitos esperados |
|---|---|
| `reserva.confirmada` | retirada, comunicação, auditoria e preparação |
| `reserva.cancelada` | comunicação e auditoria |
| `inspecao.aprovada` | manutenção e auditoria |
| `inspecao.reprovada` | comunicação, manutenção e auditoria |

O script publica via producer AMQP, consulta as cinco APIs e compara as contagens observadas com a matriz.

## Teste 2 — Competing Consumers

```powershell
.\scripts\apps.ps1 estado
.\scripts\demonstrar.ps1 concorrencia
```

Resultado esperado: dez reservas distintas, dez tarefas únicas e participação de Worker-A e Worker-B. A divisão não precisa ser igual porque os dois processos competem pela mesma fila com prefetch 1.

```powershell
Invoke-RestMethod "http://127.0.0.1:8085/effects?eventId=<UUID>"
```

## Teste 3 — Interrupção e recuperação

```powershell
.\scripts\demonstrar.ps1 interrupcao
```

O script para somente comunicação, publica uma reserva e comprova que retirada, auditoria e preparação continuam processando. `comunicacao.queue` fica com mensagem pronta e zero consumidores. Após reiniciar comunicação, a fila retorna ao estado esperado e o aviso é persistido.

```powershell
.\scripts\filas.ps1
```

## Teste 4 — Idempotência e replay

```powershell
.\scripts\demonstrar.ps1 duplicidade
```

O procedimento publica uma reserva, aguarda o efeito e chama `POST /events/{eventId}/replay`. A segunda tentativa conserva o envelope original. Os logs registram `ACK_DUPLICATA`; as consultas SQL e HTTP comprovam uma autorização, um aviso, uma auditoria e uma tarefa.

Execução manual equivalente:

```powershell
$publicacao = .\scripts\disparar.ps1 -Tipo reserva.confirmada
$id = $publicacao.eventId
.\scripts\efeitos.ps1 -EventId $id
Invoke-RestMethod -Method Post "http://127.0.0.1:8080/events/$id/replay"
.\scripts\efeitos.ps1 -EventId $id
```

## Teste 5 — ACK após commit

```powershell
.\scripts\demonstrar.ps1 falha
```

O listener valida a entrega, chama o serviço transacional e envia `basicAck` somente após o retorno do commit. O gancho de laboratório simula falha depois do commit e antes do ACK. A reentrega é reconhecida pela tabela `processed_events`, recebe `ACK_DUPLICATA` e não repete o efeito.

## Teste 6 — Circuit Breaker opcional

Este teste é um diferencial e não um requisito obrigatório do professor.

```powershell
.\scripts\provedor.ps1 iniciar
.\scripts\apps.ps1 parar comunicacao
.\scripts\apps.ps1 iniciar comunicacao -Notificacoes
.\scripts\e07.ps1
.\scripts\provedor.ps1 estado
Invoke-RestMethod http://127.0.0.1:8082/circuit-breaker | ConvertTo-Json -Depth 10
```

Resultado esperado: `CLOSED → OPEN → HALF_OPEN → CLOSED`. Quatro falhas abrem o circuito; a tentativa seguinte é bloqueada sem alcançar o provedor. Uma reserva publicada com o circuito aberto continua gerando os efeitos RabbitMQ. Depois de 10 segundos, duas chamadas bem-sucedidas fecham o circuito.

## Evidências reais selecionadas

| Evidência | Resultado observado |
|---|---|
| [EXP-01A](evidencias/exp-01a.txt) | seis publicações e quatorze cópias roteadas nas cinco filas |
| [E01–E06](evidencias/exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt) | matriz PASS; dez tarefas divididas 6/4; recuperação; replay sem efeitos duplicados; ACK após commit |
| [E07](evidencias/e07-deffdd7c-1a93-437c-bc60-59588b7bd054.txt) | transições do circuito, chamada bloqueada, fluxo principal preservado e recuperação |

As evidências registram IDs, contagens e resultados reais de 24/11/2026. Novas execuções podem produzir divisões diferentes entre workers sem violar o critério de concorrência.

## Encerramento

```powershell
.\scripts\apps.ps1 parar todos
.\scripts\provedor.ps1 parar
.\scripts\parar.ps1
```
