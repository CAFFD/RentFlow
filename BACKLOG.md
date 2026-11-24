# Backlog — RENTFLOW
Etapa 00 concluída em 24/11/2026. P0 obrigatório. Prioridade do enunciado acima de diferenciais. Cada item só vira [x] com evidência real.

## 00 — Fundação (P0)
- [x] Diagnóstico inicial registrado em [etapa-00.md](docs/evidencias/etapa-00.md), incluindo o catálogo do JDK e o conflito em 5432.
- [x] Instalar o JDK com aprovação e verificar java e javac 21.
- [x] Verificar Docker Compose no perfil do usuário.
- [x] Confirmar acesso ao Docker Engine em execução.
- [x] Inicializar Git local, preparar .gitignore, .env.example, estrutura Maven e versões fixadas.
- [x] Executar o Wrapper e validar o build mínimo.

## 01 — Broker e infraestrutura (TASK-01 aprovada para este escopo)

- [x] Compose dedicado, volumes, rede, portas em loopback, credenciais locais e duas sondas de saúde.
- [x] Painel HTTP e SQL verificados. Vhost, exchange, cinco filas e sete bindings conferidos sem consumidores.
- [x] EXP-01A: seis eventos pela Management API e 14 cópias observadas. Build Maven preservado. [Relatório](docs/evidencias/etapa-01.md).

## 02 — Contrato e produtor AMQP (P0)

- [x] Contrato aberto e validado, registro do JSON original, API dos quatro eventos, consulta e replay idêntico.
- [x] RabbitTemplate com mensagens persistentes, mandatory, returns, confirms correlacionados e timeout limitado.
- [x] Estados PUBLICADO, FALHA e INDETERMINADO testados; build completo aprovado. [Relatório](docs/evidencias/etapa-02.md).

## 03 — Consumidores e efeitos (P0)

- [x] Cinco aplicações independentes, seis schemas de negócio, consultas HTTP, logs por processo e Actuator Health.
- [x] Matriz dos quatro eventos obrigatórios, dois adicionais e um novo tipo da família de inspeção comprovada.
- [x] Dois processos de preparação na mesma fila dividiram dez tarefas em 6/4, sem duplicidade. [Relatório](docs/evidencias/etapa-03.md).

## 04 — Confiabilidade e experimentos (P0)

- [x] ACK manual após retorno transacional, dedupe atômico, unicidade de reserva e estacionamento de falhas.
- [x] Comunicação offline/retomada, replay idêntico, conflito antes do commit e falha após commit antes do ACK comprovados.
- [x] E01–E06 executados com IDs, contagens SQL, métricas de fila e logs reais. [Relatório](docs/evidencias/etapa-04.md).

### Diferencial concluído na Etapa 05

- [x] E07 Circuit Breaker + provedor HTTP local: transições CLOSED → OPEN → HALF_OPEN → CLOSED, bloqueio sem chamada externa e recuperação comprovados. [Evidência](docs/evidencias/etapa-05.md).

## 05 — Estabilização final e defesa (P0)
- [x] Núcleo preservado no commit `4abcead` e tag local `core-etapas-00-04`, sem segredos.
- [x] Circuit Breaker isolado, migração incremental, E07 e regressão do núcleo aprovados.
- [x] Guardar evidências de ensaio e atualizar diagrama, comandos e limitações do repositório.
- [ ] Conferir e publicar o link do repositório remoto; nenhum remoto foi configurado automaticamente.
- [ ] Cinco integrantes, ensaio cronometrado de 20 min, contingência com evidências reais gravadas.
