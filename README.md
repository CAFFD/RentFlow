# RENTFLOW

Sistema acadêmico de locação de equipamentos baseado em arquitetura orientada a eventos. Uma aplicação produtora publica fatos no RabbitMQ e cinco responsabilidades independentes persistem seus efeitos no PostgreSQL.

**Disciplina:** Sistemas Distribuídos e Cloud Computing

**Tema 07:** Locadora de Equipamentos

**Equipe:** CodeForge

## Integrantes

- Gabriel Guarsoni Dadário
- Bruno Cavalcante Nunes
- Bruno Henrique Franco Paião
- Matheus de Souza Lemos
- Reinaldo Candeo Filho

## Tecnologias

- Java 21 e Spring Boot 3.5.16
- Spring Web, Spring AMQP, Spring JDBC e Actuator
- RabbitMQ 4.4.0 com AMQP 0-9-1 e Management Plugin
- PostgreSQL 16.11
- Resilience4j 2.4.0
- Maven Wrapper 3.9.9
- Docker Engine e Docker Compose

## Pré-requisitos

- Windows com PowerShell
- Eclipse Temurin JDK 21 e `JAVA_HOME` configurado
- Docker Desktop em execução
- Portas livres: `5672`, `15672`, `15432` e `8080` a `8090`

Verifique o ambiente na raiz do projeto:

```powershell
java -version
.\mvnw.cmd --version
docker version
docker compose version
```

## Configuração local

`.env.example` contém somente valores fictícios. Na primeira execução, o inicializador cria `.env` com senhas aleatórias. `.env`, `.runtime/`, logs e artefatos Maven não são versionados.

Os serviços são publicados somente em `127.0.0.1`:

| Serviço | Porta |
|---|---:|
| RabbitMQ AMQP | 5672 |
| RabbitMQ Management | 15672 |
| PostgreSQL | 15432 |
| Producer | 8080 |
| Retirada | 8081 |
| Comunicação | 8082 |
| Manutenção | 8083 |
| Auditoria | 8084 |
| Preparação Worker-A | 8085 |
| Preparação Worker-B | 8086 |
| Provedor HTTP opcional | 8090 |

## Instalação e execução

### 1. Infraestrutura e definições RabbitMQ

```powershell
.\scripts\iniciar.ps1
```

O script cria `.env` quando necessário, inicia RabbitMQ e PostgreSQL, espera os healthchecks e importa `infra/rabbitmq/definitions.json`. Essa definição contém o vhost `rentflow`, a exchange `rentflow.events`, cinco filas e sete bindings, sem credenciais.

Valide a infraestrutura:

```powershell
.\scripts\estado.ps1
.\scripts\topologia.ps1
```

Painel RabbitMQ: http://127.0.0.1:15672. Use as credenciais do arquivo local `.env`.

### 2. Build, migrations e política de falhas

Com as aplicações Java paradas:

```powershell
.\mvnw.cmd --batch-mode --no-transfer-progress verify
.\scripts\preparar-nucleo.ps1
```

`preparar-nucleo.ps1` aplica as migrations `infra/sql/V*.sql`, cria acessos isolados por schema e importa `infra/rabbitmq/estacionamento.json`. Essa segunda definição acrescenta a Dead Letter Exchange, a fila de estacionamento e a política das filas principais. Os scripts são idempotentes e preservam os volumes existentes.

### 3. Producer e consumidores

```powershell
.\scripts\apps.ps1 iniciar todos
.\scripts\apps.ps1 estado
```

O comando inicia producer, retirada, comunicação, manutenção, auditoria e duas instâncias do mesmo JAR de preparação. Worker-A e Worker-B consomem `preparacao.queue`; não existem filas individuais por worker.

Cada aplicação disponibiliza `/actuator/health` em sua porta. Os logs e PIDs ficam em `.runtime/`.

## Publicar os quatro eventos obrigatórios

```powershell
$confirmada = .\scripts\disparar.ps1 -Tipo reserva.confirmada
$cancelada  = .\scripts\disparar.ps1 -Tipo reserva.cancelada
$aprovada   = .\scripts\disparar.ps1 -Tipo inspecao.aprovada
$reprovada  = .\scripts\disparar.ps1 -Tipo inspecao.reprovada
```

Cada resposta contém `eventId`, `attemptId`, estado e resultado do publisher confirm.

Consulte uma publicação e seus efeitos:

```powershell
$id = $confirmada.eventId
Invoke-RestMethod "http://127.0.0.1:8080/events/$id" | ConvertTo-Json -Depth 10
.\scripts\efeitos.ps1 -EventId $id | Format-List
Invoke-RestMethod "http://127.0.0.1:8084/effects?eventId=$id" | ConvertTo-Json -Depth 10
```

## Testes reproduzíveis

O cenário completo cria UUIDs próprios e não trunca tabelas nem purga filas:

```powershell
.\scripts\demonstrar.ps1 completo
```

Também é possível executar separadamente:

```powershell
.\scripts\demonstrar.ps1 matriz
.\scripts\demonstrar.ps1 concorrencia
.\scripts\demonstrar.ps1 interrupcao
.\scripts\demonstrar.ps1 duplicidade
.\scripts\demonstrar.ps1 falha
```

O Circuit Breaker é um diferencial opcional e não participa do ACK RabbitMQ:

```powershell
.\scripts\provedor.ps1 iniciar
.\scripts\apps.ps1 parar comunicacao
.\scripts\apps.ps1 iniciar comunicacao -Notificacoes
.\scripts\e07.ps1
Invoke-RestMethod http://127.0.0.1:8082/circuit-breaker | ConvertTo-Json -Depth 10
```

Os procedimentos, resultados esperados e evidências selecionadas estão em [Experimentos](docs/EXPERIMENTOS.md).

## Encerramento

```powershell
.\scripts\apps.ps1 parar todos
.\scripts\provedor.ps1 parar
.\scripts\parar.ps1
```

Esses comandos param somente os processos e containers do RENTFLOW e preservam os volumes.

## Documentação

- [Arquitetura, roteamento e confiabilidade](docs/ARQUITETURA.md)
- [Contratos de eventos e endpoints](docs/CONTRATOS.md)
- [Roteiro dos experimentos](docs/EXPERIMENTOS.md)
- [Evidências selecionadas](docs/evidencias/README.md)
- [Enunciado original](docs/enunciado/Trabalho_07.docx)

## Limitações

- RabbitMQ e PostgreSQL executam em nó único; não há demonstração de alta disponibilidade.
- Persistência do fato e publicação AMQP não são uma transação atômica. O laboratório usa replay explícito; Transactional Outbox seria uma evolução.
- O consumo é *at-least-once*. Constraints e idempotência impedem efeitos conhecidos duplicados, mas não oferecem garantia global de exatamente uma vez.
- O provedor HTTP simulado mantém sua deduplicação somente em memória.
- O projeto não inclui frontend, autenticação, cloud ou Kubernetes.
