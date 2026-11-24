# RENTFLOW | Laboratório de mensageria

Laboratório acadêmico de mensageria do Tema 07. A defesa está prevista para 25/11/2026, com cinco integrantes e até 20 minutos. O enunciado está em [Trabalho_07.docx](docs/enunciado/Trabalho_07.docx). O [relatório da Etapa 00](docs/evidencias/etapa-00.md) reúne diagnóstico, versões, resultados e correções.

## Estrutura

| Caminho | Função |
|---|---|
| `pom.xml` | Agrega os sete módulos e define Java 21 e Spring Boot 3.5.16. |
| `mvnw.cmd`, `mvnw`, `.mvn/wrapper/` | Executam a versão 3.9.9 do Maven selecionada pelo projeto. |
| `shared/event-contracts/` | Módulo reservado ao contrato JSON da etapa seguinte. |
| `producer/` | Ponto de entrada Java do futuro produtor. |
| `consumers/` | Um módulo para cada responsabilidade: retirada, comunicacao, manutencao, auditoria e preparacao. |
| `.env.example` | Modelo de credenciais locais usado pelo inicializador. O Compose publica o PostgreSQL na porta 15432 do Windows. |
| `docs/`, `prompts/` | Requisitos, arquitetura, contratos, experimentos, evidências e instruções por etapa. |

## Verificar a fundação no PowerShell

Com o JDK 21 disponível, abra o PowerShell na raiz do projeto. O primeiro uso do Wrapper requer rede para obter o Maven e as dependências. O Docker pode ser verificado separadamente.

```powershell
java -version
javac -version
.\mvnw.cmd --version
.\mvnw.cmd verify
docker version
docker compose version
```

O Maven lê o POM agregador e constrói os módulos em uma execução. Cada aplicação tem seu próprio método `main` e seu próprio JAR. O esqueleto inicia o contexto Spring e pode encerrar normalmente, pois ainda não há servidor HTTP nem listener. A preparação usará o mesmo JAR em dois processos ligados à mesma fila.

Consulte o [backlog](BACKLOG.md) antes de iniciar qualquer etapa. Os testes de roteamento, concorrência, interrupção e duplicidade têm seus protocolos em [Experimentos](docs/EXPERIMENTOS.md).

## Resultado da Etapa 00

Em 24/11/2026, o Wrapper executou Maven 3.9.9 com Eclipse Temurin 21.0.13.1+2. O build com Spring Boot 3.5.16 terminou com `BUILD SUCCESS` para o agregador e os sete módulos. O Docker Engine Linux respondeu com a versão 28.3.0 e o Compose com v2.38.2-desktop.1. O PostgreSQL do laboratório usará a porta 15432 no Windows, livre na conferência após o início do Docker.

Se o terminal da IDE já estava aberto quando o JDK foi instalado, reabra a IDE para carregar o JAVA_HOME e o PATH persistidos. A primeira tentativa de instalação falhou por espaço insuficiente em C:. O relatório contém o diagnóstico, a repetição bem-sucedida e as saídas do build.

## Executar a infraestrutura da Etapa 01 no Windows

A partir da raiz do projeto, com Docker Desktop em execução, use os comandos abaixo. Em uma máquina nova, confira primeiro o espaço livre no volume do Docker Desktop, `docker system df`, os recursos existentes (`docker ps -a`, `docker network ls`, `docker volume ls`) e as portas 5672, 15672 e 15432. Na primeira execução, o Compose pode precisar baixar as imagens. Use o nome de projeto `rentflow` exclusivamente para este laboratório.

| Comando PowerShell | Resultado |
|---|---|
| `.\scripts\iniciar.ps1` | Cria o .env com senhas locais se ausente, sobe os dois serviços, espera saúde, importa e verifica a topologia. Aguarde a conclusão antes de publicar. |
| `.\scripts\estado.ps1` | Mostra saúde e portas, testa o painel e executa SELECT 1. |
| `.\scripts\topologia.ps1` | Compara o broker real com as definições. Imprime os sete bindings. |
| `.\scripts\roteamento.ps1` | Executa EXP-01A nas cinco filas vazias e sem consumidores. Use o laboratório sem outro publicador durante o teste. |
| `.\scripts\parar.ps1` | Para exclusivamente os dois serviços do projeto e preserva os volumes. Para retomar, execute iniciar.ps1. |

O painel fica em http://127.0.0.1:15672/ e usa o usuário e a senha RabbitMQ do arquivo local `.env`. O Compose fixa os endereços em loopback. O PostgreSQL responde em 127.0.0.1:15432 no Windows e em postgres:5432 na rede do projeto. Para conferir a configuração sem exibir os valores das variáveis, execute `docker compose config --quiet`. Uma falha nos scripts interrompe a execução com erro.

**Limpeza das mensagens de teste.** Cada publicação do EXP-01A recebe um identificador de execução e prazo de uma hora. Mantenha o broker disponível, aguarde uma hora após a última publicação e confira no painel que Ready e Unacked são zero nas cinco filas antes de repetir. O prazo vale exclusivamente para essas mensagens. Se houver dados de outra origem, preserve-os e use uma instância de laboratório separada para uma nova execução. Evite publicar durante a verificação. A [evidência de 24/11](docs/evidencias/exp-01a.txt) conserva o resultado após a expiração.

Consulte o [relatório da Etapa 01](docs/evidencias/etapa-01.md) para a matriz medida, as versões por digest e os limites do experimento.

## Executar o núcleo Java no Windows

Use o PowerShell na raiz. O Compose mantém o RabbitMQ e o PostgreSQL; os sete processos Java usam os seis JARs locais. Para a primeira partida, confira espaço no disco com `Get-PSDrive C` e portas de 8080 a 8086. Cada início confere a porta correspondente. O script de preflight pressupõe os consumidores desligados e Ready/Unacked em zero nas cinco filas.

```powershell
.\scripts\iniciar.ps1
.\scripts\filas.ps1
.\scripts\preflight.ps1
.\mvnw.cmd --batch-mode --no-transfer-progress verify
.\scripts\preparar-nucleo.ps1
.\scripts\apps.ps1 iniciar todos
.\scripts\apps.ps1 estado
.\scripts\demonstrar.ps1 completo
```

O preparador aplica `infra/sql/V*.sql` em ordem, dentro de transações. Registra versão e SHA256 no próprio banco, inclusive em volumes existentes. Para alterar o modelo, adicione a próxima migração e reaplique o preparador. Um arquivo já aplicado com outro hash interrompe a execução. Os logins das aplicações só recebem acesso ao próprio schema. O arquivo local `.runtime/banco.json` contém suas credenciais; preserve-o junto ao ambiente privado. A recriação desse arquivo com um banco já provisionado requer reconciliação das credenciais pelo administrador. Mantenha .runtime e .env fora do Git.

| Instância | Porta padrão | Operação |
|---|---:|---|
| producer | 8080 | POST /events/{tipo}, GET /events/{id}, POST /events/{id}/replay |
| retirada | 8081 | GET /effects |
| comunicacao | 8082 | GET /effects |
| manutencao | 8083 | GET /effects |
| auditoria | 8084 | GET /effects |
| Worker-A e Worker-B | 8085 e 8086 | GET /effects, mesma fila e mesmo banco de preparação |

Cada processo oferece GET /actuator/health em 127.0.0.1. Para iniciar um único JAR em outra porta, use, por exemplo, `.\scripts\apps.ps1 iniciar Worker-B -Porta 8186` com a instância parada. A demonstração automatizada usa as portas padrão. Identidade do processo, token, porta e caminho de log ficam em .runtime. Cada partida cria arquivos de stdout e stderr individuais.

```powershell
$publicacao = .\scripts\disparar.ps1 -Tipo reserva.confirmada
$id = $publicacao.eventId
Invoke-RestMethod "http://127.0.0.1:8080/events/$id"
.\scripts\efeitos.ps1 -EventId $id
Invoke-RestMethod -Method Post "http://127.0.0.1:8080/events/$id/replay"
.\scripts\apps.ps1 parar comunicacao
.\scripts\apps.ps1 iniciar comunicacao
```

O disparador também aceita reserva.cancelada, inspecao.aprovada, inspecao.reprovada, inspecao.agendada e equipamento.cadastrado. Execute cenários individuais com `.\scripts\demonstrar.ps1 matriz`, `concorrencia`, `interrupcao`, `duplicidade`, `conflito` ou `falha`. Cada execução cria novos IDs e registra sua transcrição em docs/evidencias/exp-nucleo-<runId>.txt. O cenário conflito deixa uma entrega intencional na fila de estacionamento para inspeção. As contagens da demonstração são filtradas pelos novos IDs.

Para encerrar, use `.\scripts\apps.ps1 parar todos` e depois `.\scripts\parar.ps1`. O primeiro verifica executável, JAR, PID e token antes de encerrar cada JVM. O segundo preserva os volumes do projeto. Os procedimentos antigos da Etapa 01 descrevem um laboratório sem consumidores; o núcleo acrescenta uma política de dead-lettering que também pode estacionar mensagens expiradas. Use o relatório histórico para estudar o EXP-01A.

Consulte o [guia de leitura do código](docs/GUIA-DO-CODIGO.md), o [contrato e exemplos HTTP](docs/CONTRATOS.md) e os relatórios individuais das [Etapas 02](docs/evidencias/etapa-02.md), [03](docs/evidencias/etapa-03.md) e [04](docs/evidencias/etapa-04.md).
