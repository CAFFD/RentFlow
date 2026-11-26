# Entrega acadêmica final — RENTFLOW

Data da auditoria: 25/11/2026. Equipe: **CodeForge**.

## Integrantes

- Gabriel Guarsoni Dadário
- Bruno Cavalcante Nunes
- Bruno Henrique Franco Paião
- Matheus de Souza Lemos
- Reinaldo Candeo Filho

## Checklist de conformidade

| Item | Situação | Evidência |
|---|---|---|
| Producer independente e cinco responsabilidades consumidoras | Conforme | Módulos Maven, saúde nas portas 8080–8086 e arquitetura versionada |
| Duas instâncias de preparação na mesma fila | Conforme | `Worker-A` e `Worker-B` saudáveis; E02 aprovado na Etapa 04 |
| RabbitMQ reproduzível | Conforme | `definitions.json` contém vhost, exchange topic, cinco filas e sete bindings; `estacionamento.json` contém DLX, fila e política |
| Exportações sem credenciais | Conforme | Os dois JSON não contêm usuários, permissões, senhas ou hashes |
| PostgreSQL e migrations | Conforme | Scripts `V*.sql`, controle de hash e schemas isolados por login |
| Quatro eventos obrigatórios | Conforme | Comandos reais documentados no README; E01 aprovado |
| Publisher confirm e consumer ACK após commit | Conforme | Código, diagrama de sequência, testes e evidências E01/E06 |
| Concorrência, recuperação e idempotência | Conforme | E02, E03 e E04 aprovados com transcrições versionadas |
| Circuit Breaker como diferencial | Conforme | Resilience4j isolado do listener; E07 aprovado e identificado como opcional |
| Documentação de execução e limitações | Conforme | README, arquitetura, contratos, experimentos e guia do código |
| Segredos e artefatos locais | Conforme | `.env`, `.runtime/` e `target/` ignorados; `.env.example` contém somente valores fictícios |

## Arquivos alterados nesta auditoria

- `README.md`: identificação acadêmica, equipe, tecnologias, pré-requisitos, variáveis, importação das definições, quatro publicações obrigatórias e limitações.
- `docs/ARQUITETURA.md`: diagrama de sequência com publisher confirm, transação, commit e consumer ACK; Circuit Breaker fora do listener.
- `docs/EXPERIMENTOS.md`: estado do E07 corrigido para executado e aprovado, com runId e evidência.
- `docs/ENTREGA-FINAL.md`: este checklist final.

Nenhum código de negócio, migration, binding ou configuração funcional foi alterado.

## Validações executadas

- Parse dos 16 scripts PowerShell: PASS.
- Parse de `definitions.json` e `estacionamento.json`: PASS.
- Links locais do README: PASS.
- `docker compose --env-file .env -p rentflow config --quiet`: PASS.
- PostgreSQL saudável e `SELECT 1`: PASS.
- Painel RabbitMQ HTTP 200: PASS.
- Topologia: vhost `rentflow`, exchange topic durável, cinco filas classic duráveis e sete bindings: PASS.
- Maven Wrapper `verify`: BUILD SUCCESS para os nove projetos do reactor.
- Testes automatizados: 18 executados, zero falhas e zero erros.
- Após o build, producer, cinco consumidores e as duas instâncias de preparação: UP.
- Remoto conferido: `origin` aponta para `https://github.com/CAFFD/RentFlow.git`.
- Histórico de nomes versionados: nenhum `.env`, arquivo de `.runtime`, chave privada ou certificado sensível encontrado.
- Assinaturas comuns de chaves e tokens no HEAD: nenhuma ocorrência encontrada.

### Falha encontrada e correção

A primeira execução de `mvnw verify` em 25/11/2026 falhou no `spring-boot:repackage`, pois o Windows mantinha o JAR do producer aberto pelas aplicações em execução. Os testes realizados até a falha tinham passado. A correção foi parar exclusivamente as sete JVMs registradas pelo RENTFLOW, repetir o build completo e reiniciar as mesmas aplicações. A segunda execução terminou com `BUILD SUCCESS`; todas as instâncias retornaram saudáveis.

## Validação não executada

Não foi criada uma segunda infraestrutura vazia nesta auditoria. Fazer isso no ambiente atual exigiria novos volumes/portas ou interferência nos volumes validados, contrariando a preservação dos dados. Em vez disso, os dois arquivos de definições foram parseados, a topologia existente foi comparada com o modelo e os procedimentos idempotentes foram conferidos. Em um computador limpo, a reprodução começa com:

```powershell
.\scripts\iniciar.ps1
.\mvnw.cmd --batch-mode --no-transfer-progress verify
.\scripts\preparar-nucleo.ps1
.\scripts\apps.ps1 iniciar todos
.\scripts\apps.ps1 estado
```

## Pendências manuais antes do AVA

1. Confirmar no GitHub que o commit final aparece na branch `main` após o push autorizado.
2. Abrir o README diretamente no GitHub e conferir a renderização dos dois diagramas Mermaid.
3. Fazer um ensaio cronometrado de até 20 minutos com os cinco integrantes.
4. Manter as evidências PNG e TXT como contingência caso a demonstração ao vivo falhe.
5. Enviar no AVA o link `https://github.com/CAFFD/RentFlow` e verificar a visibilidade exigida pelo professor.

## Estado da publicação

O remoto é conhecido e corresponde ao repositório informado pela equipe. O commit final deve ser conferido com `git log -1 --oneline`. O push não faz parte desta auditoria sem autorização explícita para publicar esta versão definitiva.
