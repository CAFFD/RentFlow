# Relatório técnico da Etapa 00

**23/11/2026 · Windows 25H2, build 26200 · apresentação em 25/11/2026**

## Objetivo e plano

Preparar uma base compilável para o produtor e as cinco responsabilidades do Tema 07. O plano foi ler o kit e o enunciado, inventariar as ferramentas e portas, preparar Git e o projeto Maven e confrontar as validações com o backlog. Os testes de negócio começam em etapas posteriores.

## Registro de execução

Os comandos abaixo resumem o registro de PowerShell. As saídas são excertos do que foi observado. A sessão isolada tem permissões e PATH diferentes da sessão do usuário.

| Verificação ou comando | Resultado observado |
|---|---|
| `rg --files --hidden -g '!.git'`, `Get-Content -Encoding utf8 -Raw` | Leitura de AGENTS, README, BACKLOG, prompt 00 e todos os Markdown de docs, inclusive o índice de evidências. |
| `[IO.Compression.ZipFile]::OpenRead(...)` e leitura de `word/document.xml` | Texto integral do DOCX lido em ordem, incluindo eventos, cinco responsabilidades, critérios e tempos da apresentação. |
| `Get-Command java,javac,git,docker,winget,mvn,wsl -ErrorAction SilentlyContinue` | Git, Docker e WSL visíveis na sessão isolada. Java, javac e Maven global ausentes do PATH. WinGet encontrado ao repetir no perfil do usuário. |
| `Test-Path (Join-Path $env:JAVA_HOME 'bin/javac.exe')` | JAVA_HOME definido na sessão isolada, mas o teste retornou False. O PATH completo e valores privados foram omitidos. |
| `winget --version`, `winget show --id EclipseAdoptium.Temurin.21.JDK -e --source winget --disable-interactivity` | v1.29.380. Eclipse Adoptium, versão 21.0.13.102, instalador MSI x64 oficial, SHA256 `24742e4539f122f0427e33b195c96c93a5369da1f5da95f642825ce3813ff815`. |
| `git --version`, `git rev-parse --show-toplevel`, `git init -b main`, `git status --short --branch` | Git 2.45.1.windows.1. A pasta estava fora de repositório. Inicialização local confirmada por `No commits yet on main`. |
| `docker version` e consulta de Server.Version no perfil do usuário | Cliente 28.3.0. Conexão ao motor **FALHOU**, pipe dockerDesktopLinuxEngine ausente. |
| `docker compose version` | Na sessão isolada, acesso à configuração negado e comando desconhecido. No perfil do usuário, **PASSOU** com v2.38.2-desktop.1. |
| `wsl --status`, `wsl --list --verbose` | A sessão isolada recebeu E_ACCESSDENIED. No perfil do usuário, distribuição padrão docker-desktop, WSL 2, estado Stopped. |
| `[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()` | Zero listeners em 5672, 15672 e cada porta de 8080 a 8086. Dois listeners em 5432 e dois em 5433. Zero em 15432. Retrato do momento, sem reserva de porta. |
| `netstat -ano -p tcp` e `Get-Process -Id 7312` | Listener IPv4 em 5432 identificado como postgres. O modelo propõe 127.0.0.1:15432 no host e 5432 dentro do futuro contêiner. |
| `Invoke-WebRequest` do ZIP only-script 3.3.4 e extração de mvnw e mvnw.cmd | Rede bloqueada na sessão isolada. Download concluído via Maven Central no contexto autorizado. Consulta HTTP HEAD ao POM do Spring Boot 3.5.16 retornou 200. |
| `Get-FileHash mvnw,mvnw.cmd` | SHA256 dos scripts extraídos, respectivamente CAE96CEF89EBEA3531221F4AE17C23CF8EDF67D00EAE8306D4186AE1BBED4D02 e 46EEDB8419BD14FE70D5BB2916D7B6F51806E51B39D5B76A42610384CA929C1C. |

## Arquivos e decisões

Criados na raiz: `.git/`, `.gitignore`, `.gitattributes`, `.env.example`, `pom.xml`, `mvnw`, `mvnw.cmd` e `.mvn/wrapper/maven-wrapper.properties`. O modelo de ambiente contém exemplos fictícios. A regra de Git exclui o arquivo local `.env` e os diretórios de build.

Criado um `pom.xml` em cada módulo listado no README. Em producer e nos cinco módulos sob consumers, a classe de entrada fica em `src/main/java/br/edu/rentflow/<modulo>/<Nome>Application.java`. Cada método main chama `SpringApplication.run(..., args)`. O módulo shared/event-contracts reserva o local do futuro contrato. Atualizados README, BACKLOG e o índice de evidências.

O POM raiz fixa `<java.version>21</java.version>` e herda as versões de plugins e dependências do pai Spring Boot 3.5.16. O Wrapper aponta para `apache-maven-3.9.9-bin.zip`. A documentação do Spring indica suporte a Java 21 e Maven a partir de 3.6.3. Nesta etapa o único starter das aplicações é o básico. As versões das imagens do broker e do banco serão verificadas ao preparar o Compose da Etapa 01. [Spring Boot](https://docs.spring.io/spring-boot/3.5/system-requirements.html) · [Maven 3.9.9](https://maven.apache.org/docs/3.9.9/release-notes.html) · [Apache Maven Wrapper](https://maven.apache.org/tools/wrapper/)

## Como explicar o ambiente

1. O **JDK** traz o compilador `javac` e o ambiente de execução. O compilador traduz o código fonte em bytecode. A **JVM** executa esse bytecode. **JRE** designa o ambiente de execução, que reúne a JVM e as bibliotecas necessárias. O JDK já inclui o que precisamos para executar e compilar.
2. O **Maven** lê o POM, obtém dependências e executa fases como compilação, testes e empacotamento. O **Wrapper** escolhe a distribuição fixada pelo projeto, baixa-a no primeiro uso e volta a usá-la pelo cache. Isso permite que cada integrante use o mesmo Maven.
3. O **Spring Boot** inicia o contexto que cria e conecta os componentes de cada processo. Depois, Spring AMQP fará a integração com RabbitMQ e JDBC permitirá executar SQL no PostgreSQL. Um build multi-module organiza o código em conjunto e ainda gera artefatos separados.
4. O **Docker Engine** executa contêineres. No Windows, o Docker Desktop pode usar o kernel Linux via **WSL 2**. O **Compose** lê o arquivo que descreverá serviços, redes, portas e volumes. A versão do cliente pode responder mesmo com o motor parado.
5. No fluxo previsto, o produtor registra o fato e publica no RabbitMQ. A exchange topic escolhe filas usando a chave do evento. Dois processos de preparação competem por entregas de uma única fila. Cada consumidor persiste seu efeito no PostgreSQL antes de enviar ACK. O publisher confirm vem do broker para o produtor. Uma reentrega ainda pode ocorrer após o commit, por isso a unicidade do efeito depende do banco.

## Quatro perguntas para revisão

1. Que problema você investigaria se `java -version` funcionasse e `javac -version` falhasse?
2. Como o colega compila sete módulos com a mesma versão do Maven em outro computador?
3. Por que `docker compose version` pode funcionar enquanto `docker version` falha na conexão ao servidor?
4. Se um worker concluir o commit e cair antes do ACK, o que o outro worker pode receber e o que protege o efeito no banco?

## Situação antes das autorizações

Proposto `winget install --id EclipseAdoptium.Temurin.21.JDK -e --source winget --version 21.0.13.102`. O comando instala o JDK no Windows, pode atualizar PATH e solicitar elevação. Abrir um terminal novo permite ler o ambiente atualizado. Proposto separadamente `docker desktop start`, que inicia o backend WSL 2 e pode retomar contêineres com política de reinício.

**NÃO EXECUTADO**: java -version, javac -version, validação do Wrapper e build com `.\mvnw.cmd verify`. O JDK 21 requer instalação autorizada. A validação do daemon está pendente de inicialização autorizada e de nova consulta que retorne a versão do servidor. Naquele momento, ambos aguardavam comprovação. Consulte o aceite final abaixo.

## Validações locais que já passaram

- Leitura dos oito POMs com `[xml](Get-Content -Raw ...)` e conferência de cada `parent.relativePath` com `Resolve-Path`: os sete módulos referenciam o POM da raiz.
- Busca com `Get-ChildItem -Recurse -Filter '*Application.java'` e `Select-String`: exatamente um main em cada uma das seis aplicações e zero no módulo de contratos. Essa inspeção verifica a estrutura; a compilação exige o JDK.
- `git check-ignore -v .env consumers/retirada/target/test.jar` confirmou as regras de exclusão; `git check-ignore .env.example` retornou 1, como esperado para um arquivo versionável. A sandbox inicialmente recebeu “dubious ownership”. A repetição usou `git -c safe.directory=<pasta-do-projeto>` apenas naquele processo.
## Aceite final em 24/11/2026

**Etapa 00 concluída.** O JDK foi instalado com autorização, o Wrapper compilou os seis pontos de entrada com Java 21, o empacotamento terminou com sucesso e o Docker Engine respondeu. As verificações abaixo complementam o diagnóstico inicial de 23/11.

### Instalação do JDK e correção do erro 1603

Antes de instalar, executamos `winget show --id EclipseAdoptium.Temurin.21.JDK -e --source winget --version 21.0.13.102 --disable-interactivity`. O catálogo confirmou a versão exata, o fornecedor Eclipse Adoptium e o MSI x64 publicado em seu repositório oficial. O SHA256 consta no registro inicial. [Distribuição oficial do Temurin](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.13.1%2B2)

```powershell
winget install --id EclipseAdoptium.Temurin.21.JDK -e --source winget --version 21.0.13.102
```

Na primeira tentativa, o WinGet informou `Hash do instalador verificado com êxito`. A ação InstallValidate do MSI terminou com erro 1603. A consulta do log do instalador com `Select-String` revelou a causa:

```text
Disk full: Out of disk space -- Volume: 'C:'; required space: 513.544 KB; available space: 11.800 KB.
```

Uma medição posterior com `Get-PSDrive -PSProvider FileSystem` mostrou 2.036.924.416 bytes livres em C:. Com essa capacidade, repetimos o mesmo comando e recebemos `Hash do instalador verificado com êxito` e `Instalado com êxito`. A recuperação consistiu em repetir a instalação após a mudança de espaço disponível. Não executamos limpeza de arquivos ou de recursos Docker.

### JAVA_HOME, PATH e build

O processo de terminal herdara o JAVA_HOME anterior. O MSI já havia gravado o diretório correto no ambiente da máquina. Recarregamos os valores persistidos apenas na sessão do build; a variável de usuário JAVA_HOME estava ausente. Para uma IDE já aberta durante a instalação, fechá-la e reabri-la permite herdar o ambiente atualizado.

```powershell
$env:JAVA_HOME = [Environment]::GetEnvironmentVariable('JAVA_HOME', 'Machine')
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
Get-Command java,javac
java -version
javac -version
.\mvnw.cmd --version
.\mvnw.cmd --batch-mode --no-transfer-progress verify
```

O caminho de cada executável resolvido pelo PATH coincidiu com o do respectivo arquivo em `$env:JAVA_HOME\bin`. O nome de versão do pacote WinGet é 21.0.13.102. A JVM instalada identifica a distribuição como Temurin-21.0.13.1+2.

```text
JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.13.10002-hotspot\
java corresponde a JAVA_HOME: True
javac corresponde a JAVA_HOME: True
openjdk version "21.0.13.1" 2026-11-17 LTS
javac 21.0.13.1
Apache Maven 3.9.9 (8e8579a9e76f7d015ee5ec7bfcdc97d260186937)
Java version: 21.0.13.1, vendor: Eclipse Adoptium
```

O compilador emitiu `Compiling 1 source file with javac [debug parameters release 21]` para cada aplicação. O plugin Spring Boot 3.5.16 executou a fase de reempacotamento. Resultado observado no resumo do Maven:

```text
[INFO] rentflow ........................................... SUCCESS [  0.008 s]
[INFO] event-contracts .................................... SUCCESS [  7.896 s]
[INFO] producer ........................................... SUCCESS [  5.860 s]
[INFO] retirada ........................................... SUCCESS [  0.903 s]
[INFO] comunicacao ........................................ SUCCESS [  0.739 s]
[INFO] manutencao ......................................... SUCCESS [  0.840 s]
[INFO] auditoria .......................................... SUCCESS [  0.735 s]
[INFO] preparacao ......................................... SUCCESS [  0.866 s]
[INFO] BUILD SUCCESS
[INFO] Total time:  18.938 s
[INFO] Finished at: 2026-11-24T00:05:34-03:00
```

O resultado comprova a compatibilidade das versões fixadas para compilar e empacotar o esqueleto. O módulo de contratos está reservado e ainda não há testes de negócio nesta etapa.

### Docker e portas

`docker desktop start` iniciou o backend já instalado. `docker desktop status` retornou `running`. Não foi necessária reinicialização do Windows. As consultas seguintes verificaram o motor e o plugin:

```powershell
docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}} OS={{.Server.Os}}'
docker compose version
```

```text
Client=28.3.0 Server=28.3.0 OS=linux
Docker Compose version v2.38.2-desktop.1
```

Depois da inicialização, repetimos a contagem de listeners TCP: **5432 = 2, 5433 = 2, 15432 = 0**. O modelo `.env.example` define `BIND_ADDRESS=127.0.0.1` e `POSTGRES_PORT=15432`. Quando a infraestrutura for implementada, o acesso do Windows usará 127.0.0.1:15432 e o banco usará 5432 dentro do contêiner. A disponibilidade medida vale para o instante da consulta. Nenhum comando de criação, parada, remoção ou reconfiguração de contêineres, imagens, volumes ou bancos foi executado.

