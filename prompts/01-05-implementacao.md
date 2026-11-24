# Prompts subsequentes — enviar apenas uma etapa por vez

## 01 — Broker e produtor
Leia AGENTS.md, o enunciado, backlog e relatório 00. Execute somente 01. Crie Compose com broker e banco, volumes e healthchecks; declare topic rentflow.events e as cinco filas com bindings exatos antes de publicar. Documente credenciais locais, versões e comandos. Implemente producer com contrato, fixtures dos quatro eventos, registro do fato original, replay idêntico, publisher confirms + mandatory/returns e estados de publicação honestos. Documente a janela DB/broker. Teste e registre evidências; explique exchange, routing key, binding, fila, JSON e diferença entre HTTP e AMQP. Pare e relate.

## 02 — Consumidores
Leia decisões, contratos e relatório 01. Execute somente 02. Implemente cinco processos independentes Java Spring Boot, JDBC, schemas/migrations e efeitos consultáveis exigidos. Idempotência transacional e unique reservaId na retirada; workerId e mesma fila em duas instâncias; ACK manual após retorno do serviço transacional, falhas tratadas de modo finito, prefetch 1. Auditoria consulta ID/tipo/horário; manutenção aceita novos fatos da família. Adicione Compose para apps independentes e dois workers sem conflito de porta. Execute testes reais, documente rotas e comandos. Explique cada camada e cada linha essencial do fluxo ACK. Pare e relate.

## 03 — Experimentos e estabilização
Execute E01–E06 descritos em docs/EXPERIMENTOS.md. Use PowerShell scripts reproduzíveis, aguarde efeitos com polling limitado e registre IDs, consultas, contagens, logs e painel. Corrija desvios sem alterar enunciado. Garanta P0: matriz, concorrência, offline/retomada e duplicidade. Atualize README e backlog; não apagar dados automaticamente. Gere relatório com critérios de nota e evidências reais. Pare e relate.

## 04 — Circuit Breaker opcional
Somente se P0 estável e houver tempo. Implemente D03 com Resilience4j, mock HTTP opcional, aviso PENDING persistido e fluxo de despacho separado do ACK. Timeout, estado e métricas visíveis; teste 503, OPEN, chamada bloqueada sem HTTP, consumo principal independente, HALF_OPEN e CLOSED após recuperação. Não alegue envio externo único; documente limitações. Execute E07 e reteste P0. Pare e relate.

## 05 — Entrega e apresentação
Leia resultados reais. Congele versão estável; confirme instruções de execução em ambiente limpo se possível. Atualize diagramas e matriz conforme implementação, preencher relatório acadêmico com resultados reais e limitações, preparar sequência de demo 20 minutos, script e perguntas por integrante. Nenhuma alegação sem evidência. Circuit Breaker somente se realizado, sem substituir os cinco blocos do professor. Não publicar GitHub nem enviar credenciais sem autorização; entregar instrução para push e repo. Liste itens não executados.
