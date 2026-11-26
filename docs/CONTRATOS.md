# Contratos de eventos e APIs

## Envelope JSON

```json
{
  "eventId": "9c3bc476-9e16-4bc8-9859-bd1a60873c98",
  "eventType": "reserva.confirmada",
  "occurredAt": "2026-11-25T12:00:00Z",
  "schemaVersion": 1,
  "data": {
    "reservaId": "RES-001",
    "equipamentoId": "EQ-001",
    "equipamento": "Gerador portátil",
    "cliente": "Cliente fictício",
    "retiradaInicio": "2026-11-25T14:00:00Z",
    "retiradaFim": "2026-11-25T16:00:00Z"
  }
}
```

| Campo | Regra |
|---|---|
| `eventId` | UUID do fato de domínio; permanece igual no replay |
| `eventType` | identificador textual igual à routing key AMQP |
| `occurredAt` | instante UTC no formato ISO-8601 terminado em `Z` |
| `schemaVersion` | versão numérica do contrato; atualmente `1` |
| `data` | objeto JSON com os dados específicos do evento |

O JSON é interoperável e não contém nomes de classes Java em cabeçalhos AMQP. `attemptId` não integra o envelope: ele identifica cada tentativa de publicação e muda no replay; `eventId` identifica o fato e permanece igual.

## Dados dos eventos obrigatórios

### `reserva.confirmada`

```json
{
  "reservaId": "RES-001",
  "equipamentoId": "EQ-001",
  "equipamento": "Gerador portátil",
  "cliente": "Cliente fictício",
  "retiradaInicio": "2026-11-25T14:00:00Z",
  "retiradaFim": "2026-11-25T16:00:00Z"
}
```

### `reserva.cancelada`

```json
{
  "reservaId": "RES-002",
  "equipamentoId": "EQ-002",
  "equipamento": "Betoneira",
  "cliente": "Cliente fictício",
  "motivo": "Cancelamento de demonstração"
}
```

### `inspecao.aprovada`

```json
{
  "inspecaoId": "INS-001",
  "equipamentoId": "EQ-001",
  "equipamento": "Gerador portátil"
}
```

### `inspecao.reprovada`

```json
{
  "inspecaoId": "INS-002",
  "equipamentoId": "EQ-002",
  "equipamento": "Betoneira",
  "motivo": "Freio em revisão",
  "destinatario": "Oficina fictícia"
}
```

O endpoint do producer recebe somente o objeto `data`. A aplicação gera `eventId`, `occurredAt` e o restante do envelope.

## API do producer

| Método e rota | Função |
|---|---|
| `POST /events/{eventType}` | valida os dados, registra o fato e publica por AMQP |
| `GET /events/{eventId}` | consulta envelope, JSON original, estado e tentativas |
| `POST /events/{eventId}/replay` | republica os mesmos bytes, mantendo `eventId`, `occurredAt` e `data` |

Exemplo:

```powershell
$dados = @{
    reservaId='RES-exemplo'
    equipamentoId='EQ-exemplo'
    equipamento='Gerador fictício'
    cliente='Cliente fictício'
    retiradaInicio='2026-11-25T14:00:00Z'
    retiradaFim='2026-11-25T16:00:00Z'
}
$evento = Invoke-RestMethod -Method Post `
    -Uri http://127.0.0.1:8080/events/reserva.confirmada `
    -ContentType 'application/json; charset=utf-8' `
    -Body ([Text.Encoding]::UTF8.GetBytes(($dados | ConvertTo-Json)))

Invoke-RestMethod "http://127.0.0.1:8080/events/$($evento.eventId)"
Invoke-RestMethod -Method Post "http://127.0.0.1:8080/events/$($evento.eventId)/replay"
```

HTTP 200 indica publicação confirmada. Falha conhecida ou resultado indeterminado retorna HTTP 503 e mantém o fato consultável. Dados inválidos retornam HTTP 400; UUID inexistente retorna HTTP 404.

## APIs dos consumidores

Todos disponibilizam `GET /effects`. Os filtros opcionais são `eventId`, `eventType`, `inicio` e `fim`. A resposta possui no máximo 500 registros, ordenados por ocorrência e UUID.

```powershell
Invoke-RestMethod "http://127.0.0.1:8084/effects?eventId=$($evento.eventId)" |
    ConvertTo-Json -Depth 10
```

Portas: retirada `8081`, comunicação `8082`, manutenção `8083`, auditoria `8084`, Worker-A `8085` e Worker-B `8086`.

## API opcional de notificações

Com comunicação iniciada usando `-Notificacoes`:

| Método e rota | Função |
|---|---|
| `POST /notifications/{eventId}/dispatch` | tenta enviar um aviso pendente pelo provedor HTTP |
| `GET /notifications/{eventId}` | consulta estado e tentativas do aviso |
| `GET /circuit-breaker` | consulta estado, métricas e transições do circuito |
