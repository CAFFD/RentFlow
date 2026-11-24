# Etapa 01 — Broker e infraestrutura

**Aceite em 24/11/2026.** Seis publicações individuais produziram 14 cópias em cinco filas do vhost rentflow, com zero consumidores. As contagens permaneceram após parar e iniciar os dois serviços. O escopo autorizado nesta tarefa adiou o produtor Java previsto inicialmente no backlog.

## Diagnóstico antes da inicialização

Lemos o enunciado em DOCX, instruções, backlog, arquitetura, contratos, protocolos, roteiro da apresentação e evidências da fundação. O plano foi inventariar o host, reutilizar imagens verificadas, provisionar o laboratório, medir cada publicação, testar retomada e repetir o build.

| Comando ou inspeção | Resultado |
|---|---|
| `Get-PSDrive -PSProvider FileSystem` e localização do VHDX do Docker Desktop | C: era a única unidade listada. Tinha 1.658.871.808 bytes livres. O disco de dados em `%LOCALAPPDATA%/Docker/wsl/disk/docker_data.vhdx` estava na mesma unidade e tinha comprimento de 9.714.008.064 bytes. |
| `docker system df` | 11 imagens, 5,16 GB; zero contêineres; 24 volumes, 174,3 MB; 39 entradas de cache de build, 672,9 MB. |
| `docker ps -a`, `docker network ls`, `docker volume ls`, `docker image ls` | Redes bridge, host, none e server_default. Volumes preexistentes de outros projetos. Nenhuma colisão de nome com os recursos rentflow. |
| `GetActiveTcpListeners()` | Antes da subida, 5672, 15672 e 15432 tinham zero listeners; 5432 e 5433 tinham dois cada. |
| `docker image inspect rabbitmq:4-management` e `docker image inspect postgres:16-alpine` | Lemos RepoDigests e somente as variáveis de versão das imagens. As duas distribuições oficiais necessárias já estavam no cache. |
| Nova consulta de espaço após o experimento | 1.620.393.984 bytes livres em C:. Não foi necessária limpeza nem transferência do disco Docker. |

O Compose usa as referências imutáveis abaixo. A versão do executável foi conferida também no contêiner. Não foi necessário baixar camadas. Em outro computador com pouco espaço, confira o cache e escolha um host com capacidade disponível antes da subida. O valor “reclaimable” pode incluir dados de outros projetos.

| Imagem oficial | Versão executada | Digest utilizado |
|---|---|---|
| rabbitmq, variante Management | 4.4.0 | `sha256:af6f50d38098d8bd52fef7f3fa85015dd8b2bf6def58e995bf584ae9ba0f6407` |
| postgres, variante Alpine | 16.11 | `sha256:4327b9fd295502f326f44153a1045a7170ddbfffed1c3829798328556cfd09e2` |

## Arquivos e decisões

- `compose.yaml` define projeto rentflow, rede rentflow_default, volumes rentflow_rabbit-data e rentflow_pg-data, healthchecks e portas em 127.0.0.1. PostgreSQL usa 15432 externamente e 5432 internamente. As demais instâncias locais continuam com suas portas.
- `infra/rabbitmq/definitions.json` declara vhost, exchange, filas classic e bindings sem credenciais. `scripts/iniciar.ps1` espera os serviços, importa e confere o estado real. O hostname estável identifica o nó ao reabrir o volume.
- `scripts/comum.ps1` fixa projeto, arquivos e endereço da API. `estado.ps1`, `topologia.ps1`, `roteamento.ps1` e `parar.ps1` verificam saúde, conferem definições, executam o experimento e param o projeto, respectivamente.
- `.env.example` fornece nomes de variáveis e valores fictícios. O arquivo local .env contém as credenciais geradas; `git check-ignore .env` retornou `.env`.
- README, BACKLOG e arquitetura foram atualizados. A [transcrição do EXP-01A](exp-01a.txt) registra UTC, runId, seis eventIds, previsão antes de publicar, contagens antes/depois e resultado individual.

## Aceite operacional

| Comando executado | Evidência observada | Resultado |
|---|---|---|
| `docker compose config --quiet` | Código 0 | PASS |
| `.\scripts\iniciar.ps1` e `.\scripts\estado.ps1` | rentflow-rabbitmq-1 e rentflow-postgres-1 healthy; painel HTTP 200; psql SELECT 1 retornou 1 em uma linha | PASS |
| `.\scripts\topologia.ps1` | Vhost rentflow, exchange rentflow.events do tipo topic, durável, interna=false e auto_delete=false. Cinco filas classic duráveis, não exclusivas e sem auto-delete; sete vínculos verificados | PASS |
| `.\scripts\roteamento.ps1` | Seis casos passaram, conforme matriz abaixo | PASS |
| `.\scripts\parar.ps1`, `docker compose ps -a`, `.\scripts\iniciar.ps1` | postgres exited e rabbitmq exited; após a retomada, ambos healthy, importação repetida, topologia aprovada, painel 200 e SQL 1 | PASS |
| Consulta das filas após a retomada | Ready: retirada 1, comunicação 3, manutenção 3, auditoria 6, preparação 1; zero consumidores em todas | PASS |
| `rabbitmq-diagnostics -q server_version` e `postgres --version`, via compose exec | 4.4.0 e postgres (PostgreSQL) 16.11 | PASS |
| `.\mvnw.cmd --batch-mode --no-transfer-progress verify` com JAVA_HOME do JDK 21 | Agregador e sete módulos SUCCESS, BUILD SUCCESS, 7,949 s, 24/11/2026 00:18:19 -03:00 | PASS |

### Matriz esperada e observada

Cada célula mostra **cópias previstas / aumento medido de Ready**. O teste partiu de cinco filas vazias. O script comparou todas as filas após cada evento e esperou até 35 segundos pela atualização das métricas, com timeout de 8 segundos por consulta HTTP.

| Routing key | Retirada | Comunicação | Manutenção | Auditoria | Preparação | Resultado |
|---|---:|---:|---:|---:|---:|---|
| reserva.confirmada | 1/1 | 1/1 | 0/0 | 1/1 | 1/1 | PASS |
| reserva.cancelada | 0/0 | 1/1 | 0/0 | 1/1 | 0/0 | PASS |
| inspecao.aprovada | 0/0 | 0/0 | 1/1 | 1/1 | 0/0 | PASS |
| inspecao.reprovada | 0/0 | 1/1 | 1/1 | 1/1 | 0/0 | PASS |
| inspecao.agendada | 0/0 | 0/0 | 1/1 | 1/1 | 0/0 | PASS |
| equipamento.cadastrado | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | PASS |
| **Total** | **1/1** | **3/3** | **3/3** | **6/6** | **1/1** | **14/14** |

## Falhas, proteção dos dados e limites

O comando de importação informou que o processamento é assíncrono. O inicializador trata essa condição com consulta limitada da topologia antes de liberar publicações. Nenhum caso da matriz divergiu. Fizemos também um teste negativo: ao tentar repetir EXP-01A durante a vigência das 14 cópias, o script interrompeu a execução antes da primeira publicação com `baseline=1 3 3 6 1 esperado=0 0 0 0 0`.

Cada mensagem de laboratório carrega cabeçalho runId, identificador, JSON e delivery_mode=2. Somente essas mensagens recebem TTL de uma hora. Para repetir, siga o procedimento de expiração no README e confira filas vazias e consumidores desligados. A medição foi realizada antes do vencimento; a expiração em si não integrou a medição. Os dois serviços ficaram saudáveis e em execução para inspeção.

A resposta HTTP routed=true indica que a exchange encontrou destino. Os deltas mostram onde as cópias aguardaram. ACK de consumidor, publisher confirm AMQP, efeitos no banco, idempotência, concorrência e desempenho permanecem fora deste experimento. A consulta SQL verificou a instância dedicada, sem criar tabelas de negócio. As explicações de TCP, AMQP, channels e das decisões de roteamento estão em [Arquitetura, D05](../ARQUITETURA.md#d05--infraestrutura-executada-na-etapa-01).

## Cinco perguntas para a defesa

1. Por que reserva.confirmada gerou quatro cópias e equipamento.cadastrado apenas uma?
2. Como o experimento distingue a resposta routed=true das filas que efetivamente receberam cópias?
3. Por que inspecao.agendada chegou à manutenção sem um binding adicional? O que mudaria com direct ou fanout?
4. Onde as 14 cópias ficaram durante a parada do broker e qual condição limita seu tempo de vida?
5. Por que a preparação precisa de uma fila para dois workers, e qual experimento futuro poderá mostrar a divisão de trabalho?
