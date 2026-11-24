# Base acadêmica — versão inicial

## Título
Aplicação da Arquitetura Orientada a Eventos em um Sistema Distribuído de Locação de Equipamentos utilizando RabbitMQ.

## Introdução e problema
No cenário proposto, uma locadora precisa organizar retiradas e inspeções sem atrasar a confirmação de reservas. As áreas possuem responsabilidades distintas e dependências de informação. Em uma integração diretamente síncrona, a indisponibilidade de um serviço pode comprometer operações que dependam de sua resposta. A mensageria assíncrona é investigada como alternativa para reduzir esse acoplamento temporal. Trata-se de um cenário fictício, não de uma pesquisa realizada com empresa real.

## Questão norteadora
Como a arquitetura orientada a eventos, apoiada por um broker de mensagens, pode favorecer a independência de processamento e a recuperação de consumidores em um sistema distribuído de locação?

## Objetivo geral
Desenvolver e avaliar experimentalmente um protótipo de locadora baseado em eventos, com RabbitMQ e aplicações Java.

## Objetivos específicos
Definir eventos e contratos; justificar a topologia; implementar cinco responsabilidades independentes; verificar roteamento e trabalho concorrente; demonstrar recuperação e efeito único; documentar procedimento reproduzível. Se implementado, avaliar Circuit Breaker em integração HTTP simulada como objetivo complementar.

## Fundamentação a desenvolver
Sistemas distribuídos; comunicação síncrona/assíncrona; EDA e eventos como fatos; AMQP e RabbitMQ; exchanges direct/fanout/topic; filas e competing consumers; ACK, publisher confirms, redelivery e idempotência; transações e restrições de unicidade; Circuit Breaker e diferenças de escopo.

## Metodologia
Pesquisa aplicada com prototipação e experimentos controlados em ambiente local. Variáveis manipuladas: tipo de evento, número de instâncias, disponibilidade de comunicação, repetição de identificador e (opcional) disponibilidade do provedor HTTP. Observáveis: registros persistidos, IDs de workers, filas Ready/Unacked, logs e estado do circuito. Usar os protocolos E01–E07, sem inferir desempenho ou alta disponibilidade não medidos.

## Resultados e discussão
PENDENTE — preencher somente após execução. Relatar resultados esperados versus observados, desvios e limitações. Não confundir evidência de roteamento com prova de alta disponibilidade, nem efeito único no teste com garantia de entrega exactly-once. Banco e broker únicos, ambiente local, ausência de transação distribuída DB/broker, integrações simuladas e ausência de teste de carga delimitam conclusões.

## Conclusão
PENDENTE — responder à questão norteadora com base nos resultados reais.

## Referências técnicas iniciais
- RabbitMQ. Exchanges. https://www.rabbitmq.com/docs/exchanges
- RabbitMQ. Consumer Acknowledgements and Publisher Confirms. https://www.rabbitmq.com/docs/confirms
- RabbitMQ. Reliability Guide. https://www.rabbitmq.com/docs/reliability
- RabbitMQ. Work Queues (Java). https://www.rabbitmq.com/tutorials/tutorial-two-java
- Spring. Spring Boot 3.5 System Requirements. https://docs.spring.io/spring-boot/3.5/system-requirements.html
- Spring. Spring AMQP — AmqpTemplate. https://docs.spring.io/spring-amqp/reference/amqp/template.html
- Resilience4j. CircuitBreaker. https://resilience4j.readme.io/docs/circuitbreaker
- Microsoft. Java on Windows. https://learn.microsoft.com/windows/dev-environment/java/
- Enunciado Tema 07, Sistemas Distribuídos e Cloud Computing (documento fornecido pelo aluno).

Complementar com bibliografia acadêmica efetivamente consultada; formatar referências de acordo com exigência institucional, sem autores ou datas inventados.
