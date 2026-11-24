# Requisitos e rastreabilidade
Fonte: enunciado Tema 07, páginas 1–3. A solução proposta complementa, não substitui o enunciado.

| ID | Requisito | Evidência | Experimento |
|---|---|---|---|
| R01 | Produtor Java registra fatos e publica quatro eventos separadamente | API, registro de fatos, JSON e confirmação de publicação | E01 |
| R02 | Cinco responsabilidades iniciáveis/interrompíveis independentemente | Compose e logs por processo | E01/E03 |
| R03 | Balcão somente reserva confirmada; autorização com equipamento, cliente, janela | consulta retirada | E01/E04 |
| R04 | Comunicação: reserva confirmada/cancelada e inspeção reprovada; aviso registrado | consulta comunicação | E01/E03 |
| R05 | Manutenção: família inspeção, inclusive novos fatos; resultados e motivo da reprovação | consulta manutenção | E01/E05 |
| R06 | Auditoria: todos os eventos; consulta por ID, tipo, horário | consulta auditoria | E01/E05 |
| R07 | Preparação: apenas confirmação; tarefa com prazo antes da retirada; duas instâncias na mesma fila | registros por eventId e workerId | E02 |
| R08 | Contrato JSON com ID único, tipo, ocorrência e dados; repetir mesmo ID | exemplo e replay | E04 |
| R09 | Broker reproduzível e comparação topic/direct/fanout; novos eventos | configuração versionada e matriz | E01/E05 |
| R10 | ACK vinculado ao sucesso e consumidor temporariamente offline sem bloquear outros | logs, painel, transação | E03/E06 |
| R11 | Duplicidade: uma única autorização por reserva | consulta COUNT e logs de duplicidade | E04 |
| R12 | Entrega: repo, instruções, configuração, diagrama, matriz, contrato, testes, integrantes e decisões | README e docs | checklist final |
| X01 | Circuit Breaker opcional em envio HTTP de comunicação | métricas/estados, avisos pendentes | E07 |

Notas: interface, autenticação e cloud não são requisitos. Topic Exchange, banco, Docker e circuit breaker são escolhas nossas, não exigências explícitas. Nota: arquitetura 2; roteamento 2; concorrência 1,5; interrupção 1,5; duplicidade/ACK 2; reprodutibilidade/domínio 1.

## Situação em 24/11/2026

R01–R11 foram comprovados no laboratório. R12 está parcialmente atendido com código, instruções, configuração, diagramas, matriz, contrato e procedimentos; nomes dos cinco integrantes e link do repositório permanecem para a Etapa 05. X01 não foi implementado neste ciclo. Consulte o [consolidado das Etapas 02 a 04](evidencias/etapas-02-04.md).
