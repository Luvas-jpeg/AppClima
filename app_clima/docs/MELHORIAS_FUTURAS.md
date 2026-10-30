# AppClima — melhorias futuras para viagens longas

Documento de planejamento · atualizado em 30/10/2026.

**Objetivo:** ajudar quem viaja de carro ou moto a entender o clima que poderá encontrar ao longo do caminho, no horário estimado de passagem, inclusive com conexão instável.

Este documento descreve trabalho futuro. As cotas abaixo foram consultadas em fontes públicas; não houve acesso ao painel de consumo das contas. Lentidão pode decorrer de rede, GPS, servidor ou processamento local: ainda não está confirmado que o problema atual seja esgotamento da gratuidade.

## 1. Ponto de partida

Já existem no código:

- Rota com progresso por GPS e remoção visual dos trechos percorridos.
- Previsões por horário estimado de passagem, exibidas conforme chegam.
- Painéis recolhíveis, opção de ocultar previsões e agrupamento de cidades.
- Até quatro requisições meteorológicas simultâneas por instância do cliente; consultas idênticas em andamento são compartilhadas.
- Cache meteorológico em memória de até 16 respostas, válido por até cinco minutos e invalidado na mudança da janela de quinze minutos. A chave inclui coordenadas exatas e quantidade de dias.
- Última previsão da tela inicial salva localmente, recuperável por até 24 horas. Isso ainda não constitui um pacote offline da viagem.
- Navegação com atualização meteorológica em janelas de quinze minutos, consultando os pontos restantes.
- Solicitação de GPS a cada dois segundos no Android, com suspensão em segundo plano.

**Limites atuais relevantes:** amostragem entre 4 e 16 pontos; consulta de dois dias de previsão na rota; ausência de garantia de funcionamento com tela bloqueada. Não tratar a navegação atual como um substituto completo de GPS rodoviário com instruções de conversão, recálculo e operação contínua em segundo plano.

## 2. APIs e dependências

Os números são uma referência, não um contrato permanente. Conferir o plano efetivamente contratado, as regras de créditos, a cobertura e as condições de armazenamento antes de lançar uma funcionalidade dependente deles.

| Serviço | Uso atual | Referência pública consultada | Consequência para o produto |
|---|---|---|---|
| WeatherAPI | Clima atual e previsão por ponto/cidade | Free: 100 mil chamadas/mês, previsão de três dias e alertas limitados | Planejar orçamento mensal e explicitar o horizonte disponível; o código da rota hoje solicita somente dois dias. [Planos](https://www.weatherapi.com/pricing) |
| Geoapify | Endereços, busca reversa, cidades e rotas | Free: 3 mil créditos/dia e até cinco requisições/segundo | Medir créditos por operação, além da contagem de chamadas. [Planos](https://www.geoapify.com/pricing/) |
| Geoapify Routing | Cálculo do trajeto | A documentação inclui custo por par de pontos, opções adicionais e acréscimo por cada 500 km completos | Uma rota longa pode consumir mais de um crédito. [Cálculo de créditos](https://apidocs.geoapify.com/docs/routing/) |
| OpenStreetMap, servidor público de imagens | Mapa de fundo | Serviço sem garantia de disponibilidade; proíbe download em massa e pré-carregamento de mapas | Não usar esse servidor para oferecer download offline do corredor da viagem. Escolher infraestrutura que permita essa modalidade. [Política de uso](https://operations.osmfoundation.org/policies/tiles/) |
| ViaCEP | Consulta auxiliar de CEP brasileiro | Serviço público de consulta de CEP | Manter validação local, cache e tratamento de falhas; não presumir capacidade ilimitada. [Documentação](https://viacep.com.br/) |

Os mapas de fundo atuais vêm do servidor público do OpenStreetMap, não de tiles da Geoapify. Não misturar esses consumos na contabilidade. A fila de quatro consultas meteorológicas também **não** é um limitador de requisições por segundo da Geoapify, nem controla o consumo agregado de vários celulares.

## 3. Como descobrir onde está o limite

**Prioridade P0 — antes de contratar planos ou trocar fornecedores.**

- [ ] Registrar provedor, operação, duração, resultado, timeout, resposta 429, acerto de cache e quantidade de novas tentativas.
- [ ] Medir chamadas por planejamento, por viagem e por hora de navegação; separar rota, mapa exploratório e tela inicial.
- [ ] Conferir esses contadores com o painel do provedor. Vários aparelhos podem compartilhar a mesma cota da conta.
- [ ] Medir tempo até mostrar a rota e tempo até a primeira previsão, separadamente.
- [ ] Medir memória, quadros lentos, tráfego e bateria em aparelhos físicos, com conexão boa e instável.
- [ ] Não registrar chaves, URLs autenticadas nem coordenadas exatas na telemetria de desempenho. Usar identificadores de sessão e agregações suficientes para a análise.

**Critério de conclusão:** conseguir explicar o custo de uma viagem de 2, 4 e 8 horas e distinguir lentidão do GPS, da rede, da API e da interface. Testes automatizados atuais validam comportamento; não substituem essa medição.

### Simulação de consumo meteorológico

Modelo para planejamento, não medição do aplicativo:

`chamadas ≈ pontos iniciais sem cache + soma dos pontos restantes sem cache a cada atualização + extras`

Exemplo hipotético: oito horas, 16 pontos iniciais, 32 atualizações de quinze minutos e média de oito pontos consultados por atualização:

`16 + (32 × 8) = 272 chamadas por viagem`

| Cenário ilustrativo, mês de 30 dias | Chamadas apenas dessas viagens |
|---|---:|
| 10 viagens por dia | 81.600/mês |
| 30 viagens por dia | 244.800/mês |

A média de oito pontos é uma hipótese. Pausas, avanços, desvios, consultas de início, cache, buscas no mapa, abertura da tela inicial e novas tentativas alteram o resultado. Uma cota de 100 mil chamadas equivaleria a aproximadamente 367 dessas viagens por mês **se nenhum outro recurso consumisse chamadas**; isso não é uma estimativa de usuários suportados.

## 4. Economizar consultas sem esconder mudanças importantes

**Prioridade P0/P1 — após instrumentar o consumo.**

- [ ] Definir orçamento por sessão e por provedor, com prioridade para a viagem ativa sobre a exploração do mapa.
- [ ] Atualizar primeiro os trechos mais próximos da passagem. Pontos distantes podem usar dados recentes já disponíveis, com indicação da idade.
- [ ] Reavaliar a frequência conforme avanço, alteração da chegada, desvio e validade do dado. Reduzir consultas durante paradas prolongadas.
- [ ] Testar cache por região e período, respeitando a resolução do provedor. Evitar arredondamentos que confundam serra, litoral e áreas próximas com condições diferentes.
- [ ] Compartilhar respostas compatíveis: uma resposta com três dias pode atender uma necessidade menor, se cobrir o horário e estiver válida.
- [ ] Evitar picos sincronizados na virada dos quinze minutos em todos os aparelhos; distribuir as atualizações dentro de uma janela aceitável.
- [ ] Implementar espera progressiva em falhas transitórias e respeitar `Retry-After` quando fornecido. Evitar repetição automática para credenciais inválidas ou cota esgotada.
- [ ] Interromper trabalho ainda na fila quando a viagem for encerrada ou substituída; preservar respostas úteis já recebidas.
- [ ] Mostrar “dados salvos”, “atualização pendente” ou “serviço temporariamente indisponível”, sem travar o mapa.

**Critério de conclusão:** comparar a mesma viagem gravada antes/depois e obter menor consumo sem perder as atualizações previstas para os próximos trechos. Definir a meta numérica depois da linha de base.

## 5. Viagens longas: qualidade da informação

**Prioridade P1 — fundamento do produto.**

- [ ] Permitir partida futura, paradas e pernoites, recalculando os horários de passagem.
- [ ] Usar o horizonte disponível do plano e tratar períodos fora dele como “previsão ainda indisponível”.
- [ ] Corrigir a seleção pela hora mais próxima: ela não pode reaproveitar silenciosamente a última hora disponível para uma chegada fora da cobertura temporal.
- [ ] Tratar fusos horários entre origem, trechos e destino; manter instantes consistentes internamente e apresentar o horário local correspondente.
- [ ] Substituir o limite fixo de amostragem por uma estratégia adaptativa, com orçamento. Em 1.000 km, 16 pontos produzem intervalos médios de aproximadamente 67 km, que podem ocultar mudanças entre regiões.
- [ ] Concentrar amostras onde houver mudanças relevantes de relevo, região ou previsão, sem prometer precisão superior à fonte.
- [ ] Comparar horários de saída e, quando o provedor permitir, rotas alternativas, informando diferença de duração, distância e exposição prevista.
- [ ] Mostrar fonte, atualização e incerteza dos dados. Diferenciar observação atual, previsão e alerta oficial.

**Critério de conclusão:** testar viagens que atravessem mudança de dia, fusos, pernoite e horizonte máximo; nunca apresentar um período sem cobertura como previsão válida.

## 6. Continuidade da viagem e conexão instável

**Prioridade P1.**

- [ ] Salvar um pacote da viagem: geometria, destino, progresso, paradas, previsões, fonte e horários de validade.
- [ ] Recuperar a viagem após fechamento do app, perda de conexão ou reinício do aparelho.
- [ ] Implementar acompanhamento em segundo plano e com tela bloqueada no Android, com serviço adequado, notificação persistente e controles claros de início e encerramento.
- [ ] Avaliar consumo com localização contínua; parar o serviço ao encerrar a viagem.
- [ ] Detectar desvio sustentado, distinguindo-o de ruído do GPS. Solicitar nova rota com intervalo mínimo e proteção contra recálculos repetidos.
- [ ] Para mapas offline, contratar ou hospedar uma solução que permita download, armazenamento e atribuição adequados. Tratar mapas offline e roteamento offline como capacidades diferentes.
- [ ] Oferecer abertura do destino em um navegador externo como opção enquanto a navegação própria evolui. Comunicar que o trajeto externo pode diferir do trajeto usado na previsão.

**Critério de conclusão:** em teste controlado, manter ou recuperar a sessão após 30 minutos sem internet e alternância entre primeiro plano e tela bloqueada, sem perder o destino nem iniciar serviços duplicados.

## 7. Experiência para carro e moto

**Prioridade P2 — construir sobre dados e navegação confiáveis.**

| Necessidade | Evolução proposta | Dependência/validação |
|---|---|---|
| Menor distração | Resumo do próximo trecho, comandos grandes, contraste e modo noturno | Testar com celular fixado e fontes ampliadas |
| Avisos úteis | Avisos sonoros breves, configuráveis e sem repetição excessiva | Validar dados, antecedência e frequência; não depender de leitura durante a condução |
| Motociclista | Destacar precipitação, rajadas, visibilidade e variação de temperatura | Avaliar confiabilidade por região; vento transversal exige direção do vento e orientação do trecho |
| Motorista em viagem longa | Paradas planejadas, postos e pontos de apoio ao longo do corredor | Dados e custos de pontos de interesse; não presumir estabelecimento aberto ou combustível disponível |
| Planejar a partida | Comparar cenários de saída e paradas | Horizonte da previsão e custo adicional explícitos |
| Compartilhar viagem | Compartilhar roteiro e, futuramente, localização temporária | Consentimento, prazo de expiração e possibilidade de revogar acesso |

Não transformar ausência de dados em indicação de “trajeto seguro”. Condições da pista, interdições e alertas oficiais precisam de fontes próprias e validação; a previsão meteorológica sozinha não comprova esses eventos.

## 8. Arquitetura para crescer

**Prioridade P1/P2, conforme consumo e distribuição do aplicativo.**

- [ ] Separar interfaces de clima, geocodificação, rotas e mapas para permitir substituição de fornecedores.
- [ ] Avaliar um backend com cache compartilhado, proteção contra abuso, orçamento global e gestão das credenciais. `.env` empacotado no aplicativo não torna a chave secreta no aparelho.
- [ ] Não usar o backend para contornar cotas. Confirmar permissões de cache e redistribuição de cada plano.
- [ ] Definir retenção mínima de dados de localização e histórico, exclusão pelo usuário e acesso restrito.
- [ ] Versionar o pacote offline e o cache; aplicar limite de espaço e expiração.
- [ ] Escolher ferramentas de armazenamento e processamento após medir volume e necessidade. Evitar infraestrutura complexa antes de comprovar o gargalo.

## 9. Quando pagar ou mudar de provedor

Proposta de política interna, a validar após medir o uso:

1. Emitir aviso interno ao atingir 70% do orçamento do período; projetar o consumo até o fechamento.
2. Se a projeção exceder a cota, limitar primeiro a exploração não essencial e as consultas redundantes, mantendo visível a idade dos dados.
3. Comparar fornecedores com as mesmas rotas e horários: cobertura no Brasil, qualidade, latência, disponibilidade, horizonte, alertas, direitos de cache/offline e custo por viagem.
4. Contratar capacidade antes de ampliar o público se o piloto continuar projetando estouro mesmo após as otimizações, ou se uma função essencial não existir no plano gratuito.
5. Separar custo de clima, geocodificação, rotas, mapas e backend. Trocar somente o componente que não atende à necessidade.

Não escolher um plano apenas pela quantidade de chamadas. Uma pequena mensalidade pode ser justificável por cobertura ou continuidade; uma cota maior também pode manter um problema de consultas desnecessárias.

## 10. Sequência recomendada

| Etapa | Entrega | Condição para avançar |
|---|---|---|
| 1 — Medir | Painel de consumo e ensaios de 2, 4 e 8 horas | Gargalos e custo por viagem conhecidos |
| 2 — Corrigir fundamentos | Horizonte temporal, fusos e atualização por prioridade | Dados fora da cobertura identificados e economia comprovada |
| 3 — Continuar a viagem | Pacote persistente, retomada e GPS em segundo plano | Testes de perda de rede, bloqueio e reinício aprovados |
| 4 — Piloto rodoviário | Pequeno grupo de motoristas e motociclistas | Relatos de uso, bateria, precisão e consumo consolidados |
| 5 — Expandir | Capacidade contratada quando necessária, alertas e comparação de cenários | Orçamento, qualidade e suporte compatíveis com o público |

### Próxima entrega sugerida

Começar pela instrumentação de consumo, pelo tratamento explícito de horários fora da previsão e por um ensaio reproduzível de viagem longa. Esses três itens permitem decidir onde investir sem presumir que toda lentidão exige uma API paga.

## Referências do código

- [Amostragem da rota](../lib/features/route/domain/route_forecast_plan.dart)
- [Navegação e atualização das previsões](../lib/features/route/presentation/route_page.dart)
- [Cache e requisições meteorológicas](../lib/features/weather/data/weather_forecast_client.dart)
- [Seleção de horários e previsão salva](../lib/features/weather/data/weather_service.dart)
- [Consultas de endereços e rotas](../lib/features/route/data/route_service.dart)
- [Busca de cidades](../lib/features/weather/data/weather_city_service.dart)
- [Fila de requisições](../lib/core/network/request_pool.dart)
