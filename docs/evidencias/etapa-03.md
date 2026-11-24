# Etapa 03 — Consumidores e efeitos locais

## Objetivo e arquivos

Cinco aplicações Spring Boot recebem entregas por @RabbitListener e persistem efeitos usando JDBC. Em consumers/{retirada,comunicacao,manutencao,auditoria,preparacao} estão os POMs, application.properties, classes Application e repositórios específicos. Cada aplicação importa os beans do pacote br.edu.rentflow.consumo em shared/event-contracts. O listener, o serviço transacional, o repositório base e a API de leitura ficam em arquivos separados.

- Retirada guarda janela, cliente e equipamento e impõe unicidade à reserva.
- Comunicação guarda o texto, destinatário e estado PENDING. O commit do aviso conclui o trabalho local.
- Manutenção retém os dados originais e atribui resultado apenas aos tipos aprovação e reprovação. Auditoria preserva o texto integral em original.
- Preparação grava o prazo de retirada menos 30 minutos e identifica o worker. Dois processos usam o mesmo código e banco.
- GET /effects oferece filtros eventId, eventType, inicio e fim. O [contrato HTTP](../CONTRATOS.md) explica a resposta.

## Instalação sobre o volume existente

Executamos scripts/preparar-nucleo.ps1 e repetimos a migração. A primeira execução criou seis schemas de negócio e as tabelas. Na segunda, o psql verificou o hash e retornou 1 para a versão aplicada; ambos os blocos terminaram com COMMIT. As migrações usam trava transacional para serializar dois preparadores. scripts/acessos-db.ps1 criou e configurou seis logins locais. Na consulta a pg_roles e pg_namespace, os seis tinham USAGE no próprio schema e havia **zero acessos cruzados** aos demais schemas de negócio. O arquivo de credenciais permanece fora do Git.

Scripts/apps.ps1 inicia, consulta e encerra instâncias validadas pelo executável, caminho do JAR, PID e token aleatório. Os logs ficam separados em .runtime. Scripts/filas.ps1 exibe Ready, Unacked e Consumers; scripts/preflight.ps1 exige a linha de base limpa antes da primeira partida. Scripts/efeitos.ps1 consulta as cinco APIs por UUID. O experimento matriz de scripts/demonstrar.ps1 confronta as cinco contagens com a previsão, valida conteúdo e testa os filtros da auditoria.

## Matriz esperada e observada

Cada célula mostra os efeitos esperados e observados para o eventId novo. Os consumidores estavam ativos, portanto a medição consultou as APIs e o PostgreSQL em vez de contar mensagens Ready.

| Evento | Retirada | Comunicação | Manutenção | Auditoria | Preparação | Veredito |
|---|---:|---:|---:|---:|---:|---|
| reserva.confirmada | 1/1 | 1/1 | 0/0 | 1/1 | 1/1 | PASS |
| reserva.cancelada | 0/0 | 1/1 | 0/0 | 1/1 | 0/0 | PASS |
| inspecao.aprovada | 0/0 | 0/0 | 1/1 | 1/1 | 0/0 | PASS |
| inspecao.reprovada | 0/0 | 1/1 | 1/1 | 1/1 | 0/0 | PASS |
| inspecao.agendada | 0/0 | 0/0 | 1/1 | 1/1 | 0/0 | PASS |
| equipamento.cadastrado | 0/0 | 0/0 | 0/0 | 1/1 | 0/0 | PASS |

O evento novo `inspecao.reaberta`, eventId `e3465144-7976-4775-8432-a43f157f9ab7`, gerou manutenção e auditoria. A manutenção preservou os dados e gravou resultado SQL NULL. Isso comprova que o consumidor abrangente não inventou aprovação ou reprovação.

No experimento concorrente, dez UUIDs distintos geraram dez autorizações, dez avisos, dez auditorias e dez tarefas. Worker-A gravou seis tarefas e Worker-B quatro. A divisão desigual é compatível com competing consumers.

| Critério | Evidência | Veredito |
|---|---|---|
| Responsabilidades independentes | Sete JVMs, portas 8080–8086 e logs separados | PASS |
| Efeitos consultáveis | GET /effects validado por UUID e filtros da auditoria | PASS |
| Conteúdo de negócio | Janela, aviso PENDING, inspeção e prazo de preparação comparados à fixture | PASS |
| Auditoria abrangente | Seis tipos documentados e inspecao.reaberta | PASS |
| Dois workers | 10 tarefas únicas divididas em 6/4 | PASS |
| Isolamento de schemas | Seis logins com acesso próprio e zero acessos cruzados | PASS |

## Perguntas para defesa

1. Por que existem duas JVMs de preparação e apenas uma fila?
2. Em que momento o prazo da tarefa é calculado?
3. Como a manutenção representa um tipo novo sem inventar resultado?
4. Qual a diferença entre o login PostgreSQL e o schema de cada aplicação?
5. O que a consulta da auditoria preserva que uma tabela somente com campos selecionados perderia?
