# Relatório consolidado das Etapas 02 a 04

**Execução principal em 24/11/2026, runId `2d25e89d-2c75-4acd-acb1-e48579033b55`.**

## Resultado

O núcleo RENTFLOW foi implementado em Java 21 e Spring Boot 3.5.16. O produtor registra o envelope original, publica por AMQP com confirmação correlacionada e permite replay fiel. Cinco aplicações independentes processam as filas, gravam efeitos em schemas separados e enviam ACK manual depois do retorno transacional. Duas instâncias do mesmo JAR de preparação competem pela mesma fila.

| Bloco | Resultado principal |
|---|---|
| Etapa 02 | Quatro eventos obrigatórios e eventos adicionais publicados pela API Java; confirm positivo e tentativas persistidas |
| Etapa 03 | Matriz completa comprovada por efeitos; tipo novo de inspeção preservado; dez tarefas divididas 6/4 |
| Etapa 04 | Comunicação offline recuperada; replay idempotente; rollback por conflito e redelivery após commit comprovados |

## Comandos executados

```powershell
.\mvnw.cmd -B -ntp verify
.\scripts\preflight.ps1
.\scripts\preparar-nucleo.ps1
.\scripts\apps.ps1 iniciar todos
.\scripts\apps.ps1 estado
.\scripts\demonstrar.ps1 completo
```

O build executou 16 testes e terminou com BUILD SUCCESS em 46,522 segundos. O experimento integrado terminou com código 0. A linha de base antiga foi preservada até suas 14 mensagens expirarem naturalmente. Às 01:18:46 de Brasília, as cinco filas principais estavam com Ready=0, Unacked=0 e Consumers=0. Somente então a política de falhas foi reaplicada e os consumidores foram iniciados.

Depois da documentação, uma segunda execução offline do build também passou, com 16 testes e 48,918 segundos. A sintaxe dos 14 scripts PowerShell foi validada pelo parser sem erros.

## Evidências

- [Build Maven](build-02-04.txt)
- [Transcrição integral do experimento](exp-nucleo-2d25e89d-2c75-4acd-acb1-e48579033b55.txt)
- [Etapa 02](etapa-02.md)
- [Etapa 03](etapa-03.md)
- [Etapa 04](etapa-04.md)
- [Guia didático do código](../GUIA-DO-CODIGO.md)

## Decisões e limites

As aplicações Java são executadas diretamente no Windows, com HTTP em loopback. RabbitMQ e PostgreSQL permanecem no Compose. As migrações são versionadas e aplicáveis sobre o volume existente. Credenciais locais ficam em arquivos ignorados pelo Git. O producer usa replay explícito para recuperação; uma outbox é evolução possível. A fila classic e o banco operam em nó único. Os resultados comprovam roteamento, concorrência, recuperação e unicidade dos efeitos locais nas condições do laboratório. Não comprovam alta disponibilidade, desempenho de produção ou entrega exatamente uma vez.

Circuit Breaker, frontend, autenticação e imagens Docker das aplicações ficaram fora do ciclo, conforme solicitado.
