# Roteiro de defesa — 25/11/2026
O enunciado fixa 20 min e cinco blocos; todos participam. Preparar 8–10 slides, alternar com demonstração. Não usar tempo dos testes obrigatórios para diferencial.

| Tempo | Integrante | Conteúdo e prova |
|---|---|---|
| 0–3 min | 1 | Contexto, problema, objetivo, diagrama, JSON, justificativa Topic vs Direct/Fanout |
| 3–8 min | 2 | Matriz; prever destinos antes de cada um dos 4 eventos; confrontar painel e efeitos |
| 8–11 min | 3 | Duas instâncias, mesma fila; sequência distinta; workerId e contagem de efeitos |
| 11–15 min | 4 | Stop comunicação, publicar, mostrar outros destinos e Ready, start e recuperação |
| 15–20 min | 5 | Replay mesmo ID, COUNT=1, ACK após commit; novos eventos e conclusão; Circuit Breaker somente se houver tempo |

## Questões que todo integrante deve responder
1. Exchange armazena mensagens? Não; roteia, filas armazenam mensagens pendentes.
2. Por que topic? Exato, família com #, auditoria abrangente com #; direct e fanout não satisfazem juntos com a mesma flexibilidade.
3. Por que uma fila para dois workers? Competing consumers; duas filas criariam duas cópias.
4. O que ocorre se comunicação desligar? Fila preexistente permanece; outras filas independentes continuam; mensagens pendentes são entregues quando retornar, sob premissas de broker disponível.
5. ACK vs publisher confirm? Consumidor→broker confirma processamento; broker→produtor confirma publicação, não consumo.
6. Falha após commit antes de ACK? Possível redelivery; unicidade transacional evita novo efeito.
7. Por que não exactly-once? Entregas podem repetir; demonstramos idempotência do efeito local.
8. Evento novo inspecao.agendada? Manutenção e auditoria por padrão; manutenção registra fato genérico. equipamento.cadastrado? Apenas auditoria.
9. Circuit Breaker substitui fila ou retry? Não; limita chamadas a dependência HTTP defeituosa, preservando pendências locais.
10. O que não provamos? HA de broker/banco, escala de produção, latência sob carga, atomicidade global DB/broker, envio externo exatamente uma vez.

## Antes de apresentar
Precarregar imagens e builds, verificar portas, Docker, saúde dos serviços e fixtures; scripts com comandos curtos; browser management e consultas já abertas; guardar vídeo/screenshots reais de ensaio como contingência, nunca apresentar como execução ao vivo. Não usar reset destrutivo. Preencher nomes dos 5 integrantes e link repo.
