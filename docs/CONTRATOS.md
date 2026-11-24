# Contratos e API propostos
Envelope JSON: `eventId` UUID, `eventType` igual à routing key, `occurredAt` ISO-8601 UTC, `schemaVersion` 1, `data` objeto. JSON explícito e independente de nomes de classes Java. Validação por tipo, versão e campos necessários; eventos novos da família inspeção devem ter tratamento genérico seguro e preservar dados originais (não inventar resultado aprovado/reprovado).

```json
{
  "eventId": "9c3bc476-9e16-4bc8-9859-bd1a60873c98",
  "eventType": "reserva.confirmada",
  "occurredAt": "2026-11-24T12:00:00Z",
  "schemaVersion": 1,
  "data": {
    "reservaId": "RES-001",
    "equipamentoId": "EQ-001",
    "equipamento": "Gerador portátil",
    "cliente": "Cliente Fictício A",
    "retiradaInicio": "2026-11-25T14:00:00Z",
    "retiradaFim": "2026-11-25T16:00:00Z"
  }
}
```

- reserva.confirmada: campos do exemplo; janela válida; preparação define prazo antes de retiradaInicio (ex. 30 minutos antes, regra proposta).
- reserva.cancelada: reservaId, equipamentoId, cliente, motivo (opcional).
- inspecao.aprovada: inspecaoId, equipamentoId, equipamento, cliente se aplicável.
- inspecao.reprovada: mesmos campos e motivo obrigatório; incluir destinatário fictício para aviso.
- inspecao.agendada extra: inspecaoId, equipamentoId, agendadaPara; manutenção registra fato genérico.
- equipamento.cadastrado extra: equipamentoId, equipamento; auditoria somente.

API proposta: POST /events/{eventType} cria fato com dados enviados ou endpoint de demonstração com fixtures explícitas; GET /events/{eventId} consulta original e estado; POST /events/{eventId}/replay republica envelope original. GET /effects em cada consumidor com filtro eventId e outros filtros pertinentes; auditoria precisa também de eventType e intervalo de ocorrência. API final deve ter exemplos reais no README; rotas podem ser refinadas com justificativa. Não publicar dados pessoais reais.

## API implementada no núcleo

A API local do produtor recebe **somente o objeto data** em POST /events/{eventType}. EventosApi.criar gera o UUID e o instante UTC e monta o envelope v1 mostrado acima. Os dados de domínio são enviados pelo cliente. O script disparar.ps1 produz fixtures e permite associar diferentes fatos ao mesmo runId. Exemplos de requisição no PowerShell:

```powershell
$dados = @{ reservaId = 'RES-exemplo-01'; equipamentoId = 'EQ-7'; cliente = 'Cliente fictício' }
$evento = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:8080/events/reserva.cancelada -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes(($dados | ConvertTo-Json)))
Invoke-RestMethod "http://127.0.0.1:8080/events/$($evento.eventId)"
Invoke-RestMethod -Method Post "http://127.0.0.1:8080/events/$($evento.eventId)/replay"
```

HTTP 200 inclui eventId, attemptId, estado PUBLICADO e motivo. Quando a tentativa não pode ser confirmada, HTTP 503 preserva esses campos e distingue FALHA e INDETERMINADO. Um corpo inválido recebe HTTP 400 e um UUID ausente na consulta ou replay recebe HTTP 404. GET /events/{id} retorna envelope, original (texto), estado e tentativas. O estado agregado é PUBLICADO se alguma tentativa confirmou; sem confirmação, qualquer tentativa incerta mantém INDETERMINADO. Se todas falharam é FALHA, e um fato ainda sem tentativa é PENDENTE.

O corpo AMQP é o envelope em JSON UTF-8, com content_type application/json, message_id igual ao eventId, entrega persistente e routing key igual ao eventType. O produtor guarda o texto original e usa os mesmos bytes de conteúdo no replay. A correlação de confirm é própria de cada tentativa. O consumidor aceita tipos novos com formato textual de segmentos e schemaVersion 1, preservando dados extensíveis. Para a inspeção reprovada, o destinatário do aviso e o motivo são obrigatórios.

Em cada consumidor, GET /effects aceita eventId, eventType, inicio e fim (instantes ISO-8601). Os limites de ocorrência são inclusivos. A resposta é um array ordenado por ocorrência e UUID, limitado a 500 linhas. Os nomes de campos seguem o SQL, por exemplo event_id, processado, reserva_id, worker_id. O aviso usa estado PENDING e o conteúdo da auditoria fica em original. O relatório de cada etapa contém IDs que podem ser consultados neste ambiente enquanto o volume for preservado.
