# Capturas manuais

Use resolução 1920 × 1080, zoom entre 110% e 140% e recorte apenas a área relevante. Oculte notificações, barra de favoritos, usuário do Windows e qualquer arquivo `.env` ou `.runtime`.

## Código

Abra cada arquivo de `01-code` no VS Code. Use fonte monoespaçada, tema escuro e desative minimapa, breadcrumbs e painel lateral. Os recortes já têm o tamanho recomendado para um slide.

## RabbitMQ

1. Execute `./scripts/estado.ps1` e confirme que o painel responde.
2. Abra `http://127.0.0.1:15672/#/exchanges/rentflow/rentflow.events`.
3. Faça login usando o `.env` local sem mostrar o arquivo na gravação.
4. Capture o cabeçalho com nome `rentflow.events`, tipo `topic`, durable `true` e a seção Bindings.
5. Abra `http://127.0.0.1:15672/#/queues/rentflow`.
6. Capture as cinco filas principais e a coluna Consumers. Se a fila de estacionamento aparecer, explique que ela preserva uma mensagem de laboratório e não pertence às cinco filas de negócio.

## Resultados no terminal

Execute em uma janela PowerShell limpa:

```powershell
./scripts/topologia.ps1
./scripts/filas.ps1
Get-Content ./presentation-assets/03-experiments/02-matriz-roteamento.txt
Get-Content ./presentation-assets/03-experiments/03-competing-consumers.txt
Get-Content ./presentation-assets/03-experiments/04-comunicacao-offline-recuperacao.txt
Get-Content ./presentation-assets/03-experiments/05-replay-autorizacao-unica.txt
Get-Content ./presentation-assets/03-experiments/06-ack-commit-duplicata.txt
Get-Content ./presentation-assets/03-experiments/07-circuit-breaker.txt
```

## Circuit Breaker ao vivo

Com a comunicação iniciada com `-Notificacoes`, abra `http://127.0.0.1:8082/circuit-breaker`. Para uma nova execução demonstrativa, use `./scripts/e07.ps1`; isso cria novos registros identificados por UUID e não purga dados. Capture o terminal no `PASS final` e o endpoint após o script. O arquivo `07-circuit-breaker.txt` preserva a execução aprovada de 24/11/2026.
