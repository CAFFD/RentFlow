# Instruções permanentes para o Codex

## Objetivo e limites
- Construir um laboratório acadêmico de EDA em Java 21, Spring Boot 3.5.x, Spring AMQP, JDBC, RabbitMQ e PostgreSQL. Cinco responsabilidades independentes; produtor independente; duas instâncias da preparação na mesma fila.
- Fonte de verdade: enunciado em docs/enunciado/Trabalho_07.docx; requisitos e decisões deste kit. Não mudar regras sem explicar e solicitar decisão. P0 tem precedência absoluta sobre extras. Não adicionar frontend, autenticação, cloud, Kubernetes ou dependências não justificadas.
- O aluno tem Java básico e quer compreender cada detalhe. Priorize código explícito, pequenos métodos, nomes legíveis, SQL visível, documentação em português. Evite abstrações prematuras e geração de código excessiva.
- Preserve arquivos existentes. Não apagar volumes, dados, repositórios nem alterar serviços externos. Antes de instalar ferramentas ou alterar PATH/sistema, apresente o comando, impacto e aguarde autorização; use fontes oficiais. Não imprimir segredos; manter .env fora do Git; .env.example com valores de laboratório.
- Fixar versões reais e compatíveis (sem latest, sem inventar versões), usar Maven Wrapper e Docker Compose. Portas de laboratório publicadas apenas em loopback por padrão. Não usar credenciais guest remotamente.

## Processo de trabalho
1. Ler o backlog e identificar a etapa autorizada. Não executar etapas futuras automaticamente.
2. Registrar plano pequeno, arquivos afetados e decisões. Implementar, executar testes e inspecionar saída real.
3. Atualizar BACKLOG.md, README e documentação. Salvar evidências reais em docs/evidencias/ (sem segredos). Não declarar sucesso sem executar. Se não foi possível testar, indicar NÃO EXECUTADO e motivo.
4. Entregar relatório por etapa: objetivo, mudanças, comandos e saídas relevantes, critérios verificados, falhas, próximos passos e explicação didática do fluxo. Incluir caminhos dos arquivos, trechos essenciais e perguntas para o aluno explicar sem IA.
5. Manter testes independentes do relógio quando possível; usar UUIDs e UTC; não limpar volumes sem aprovação. Nunca ocultar falhas com fallback fictício ou ACK antes do commit.

## Regra de ouro
A confirmação do broker ao produtor não é ACK do consumidor. Efeito persistido não equivale a entrega exactly-once. Separar o fluxo obrigatório de comunicação (registro de avisos) do envio HTTP opcional. O circuito protege apenas o cliente HTTP; não envolve o listener RabbitMQ nem seu ACK.
