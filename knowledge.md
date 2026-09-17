# Knowledge

Este arquivo e um guia de aprendizado para acompanhar o desenvolvimento do AppClima. A ideia e registrar os conceitos, termos e decisoes tecnicas que aparecem durante o projeto, para que o aplicativo seja construido junto com o aprendizado.

## Visao do projeto

O AppClima sera um aplicativo mobile de previsao do tempo com uma ideia extra: combinar rota de GPS com previsao climatica ao longo do caminho.

Exemplo: o usuario quer ir ate uma padaria a 5 km. O app calcula a rota e tambem mostra que, em uma parte especifica do trajeto, existe chance de chuva quando o usuario chegar naquele ponto.

## Termos importantes

### Flutter

Flutter e o framework usado para criar o aplicativo mobile. Ele permite construir interfaces para Android e iOS usando a linguagem Dart.

Conceitos para aprender:

- `Widget`: qualquer parte visual da tela, como texto, botao, imagem, campo ou lista.
- `State`: dados que podem mudar na tela, como temperatura atual, localizacao ou rota selecionada.
- `Build`: processo em que o Flutter monta a interface a partir dos widgets.
- `MaterialApp`: estrutura principal de um app Flutter com estilo visual baseado no Material Design.
- `Scaffold`: estrutura comum de tela, com app bar, corpo, botoes flutuantes e barras.

### Dart

Dart e a linguagem usada pelo Flutter.

Conceitos para aprender:

- Variaveis e tipos: `String`, `int`, `double`, `bool`.
- Classes e objetos.
- Funcoes assincronas com `async` e `await`.
- Tratamento de erro com `try` e `catch`.
- Null safety, que ajuda a evitar erros quando um valor pode estar vazio.

### API

API e uma forma de um sistema conversar com outro. No AppClima, o aplicativo deve consultar APIs externas para buscar informacoes como clima, previsao, localizacao ou rota.

Exemplo simples:

```text
AppClima -> API de clima -> resposta com temperatura, chuva e vento
```

Conceitos para aprender:

- `Request`: pedido enviado para uma API.
- `Response`: resposta recebida da API.
- `Endpoint`: endereco especifico de uma API, como `/weather` ou `/forecast`.
- `JSON`: formato muito comum para troca de dados entre app e API.
- `Status code`: codigo que indica se a resposta deu certo, como `200`, ou falhou, como `404` e `500`.

APIs consideradas para o projeto:

- `WeatherAPI.com`: API de clima com limite citado de 1.000.000 de requisicoes por mes.
- `Open-Meteo`: API de clima com limite citado de 10.000 requisicoes por dia.
- `OpenRouteService`: API de mapas e rotas com limite citado de 2.000 requisicoes por dia.

Ao escolher uma API, pontos importantes para comparar:

- Limite gratuito de requisicoes.
- Se exige chave de API.
- Qualidade da documentacao.
- Dados disponiveis por horario.
- Suporte a latitude e longitude.
- Facilidade de integrar com Flutter.

### Cliente e servidor

O cliente e o aplicativo instalado no celular. O servidor e o sistema que fornece dados ou regras para o aplicativo.

No inicio, o AppClima pode ser apenas um cliente consumindo APIs externas. No futuro, pode ter uma API propria para centralizar regras, historico, usuarios ou dados personalizados.

### GPS

GPS e a tecnologia usada para descobrir a localizacao do usuario e acompanhar deslocamentos.

Conceitos para aprender:

- Latitude e longitude.
- Permissao de localizacao no celular.
- Localizacao atual.
- Destino.
- Rota.
- Tempo estimado de chegada.
- Meio de transporte, como caminhada, carro, moto e bicicleta.

### Previsao do tempo

O app deve mostrar dados climaticos importantes para o usuario.

Dados citados no contexto do projeto:

- Temperatura.
- Chance de precipitacao.
- Velocidade do vento.
- Radiacao solar.
- Previsao por horario.

Termos uteis:

- `Precipitacao`: chuva, garoa, neve ou qualquer agua que cai da atmosfera.
- `Probabilidade de precipitacao`: chance de chover em determinado lugar e horario.
- `Vento`: velocidade e direcao do ar.
- `Indice UV`: medida relacionada ao risco da radiacao solar.
- `Forecast`: previsao futura do clima.

## A ideia mais importante do app

O diferencial do AppClima nao e apenas mostrar o clima atual. O ponto principal e cruzar duas informacoes:

1. Onde o usuario vai passar.
2. Como o clima estara naquele lugar quando ele chegar la.

Isso significa que o app precisa considerar espaco e tempo ao mesmo tempo.

Exemplo:

```text
Agora: 14:00
Destino: padaria
Tempo total da rota: 10 minutos

Ponto A da rota: usuario chega em 2 minutos
Ponto B da rota: usuario chega em 5 minutos
Ponto C da rota: usuario chega em 8 minutos

Se chover no Ponto B as 14:05, o app deve alertar isso na rota.
```

## Clean Architecture

Clean Architecture e uma forma de organizar o codigo para separar responsabilidades. Isso evita que tudo fique misturado em uma unica tela ou arquivo.

Uma estrutura comum pode ter:

### Presentation

Parte visual do app.

Exemplos:

- Telas.
- Widgets.
- Botoes.
- Estados da interface.

Pergunta principal desta camada:

```text
Como o usuario ve e interage com o app?
```

### Domain

Parte das regras principais do aplicativo.

Exemplos:

- Calcular se havera chuva durante a rota.
- Representar uma rota.
- Representar uma previsao climatica.
- Definir casos de uso do app.

Pergunta principal desta camada:

```text
O que o app faz de importante?
```

### Data

Parte responsavel por buscar e salvar dados.

Exemplos:

- Chamar API de clima.
- Chamar API de mapas.
- Converter JSON em objetos Dart.
- Tratar erros de conexao.

Pergunta principal desta camada:

```text
De onde os dados vem?
```

## Possivel fluxo do aplicativo

1. Usuario abre o app.
2. App pede permissao de localizacao.
3. App mostra clima atual da localizacao do usuario.
4. Usuario entra no modo GPS.
5. Usuario escolhe um destino.
6. Usuario escolhe o meio de transporte.
7. App calcula a rota.
8. App divide a rota em pontos.
9. App estima em que horario o usuario chegara em cada ponto.
10. App consulta a previsao do tempo para esses pontos e horarios.
11. App mostra alertas climaticos no trajeto.

## Telas e paginacao

O professor pediu que o app tenha paginacao, entao o projeto deve ter mais de uma tela.

Uma divisao inicial possivel:

1. Tela de clima atual.
2. Tela de busca ou historico.
3. Tela de mapa/GPS.
4. Tela de detalhes da previsao.

No Flutter, isso envolve estudar navegacao entre telas. Alguns termos importantes:

- `Route`: representa uma tela ou caminho de navegacao.
- `Navigator`: controla a troca entre telas.
- `push`: abre uma nova tela.
- `pop`: volta para a tela anterior.
- `BottomNavigationBar`: barra inferior usada para navegar entre secoes principais.
- `PageView`: componente para trocar paginas deslizando para os lados.

## Historico sem login

Por enquanto, login nao parece necessario. Mesmo assim, o app deve armazenar historico de pesquisa.

Isso significa que o historico pode ficar salvo localmente no aparelho do usuario.

Possiveis opcoes para estudar no Flutter:

- `shared_preferences`: bom para dados simples, como ultima cidade pesquisada.
- `sqflite`: banco SQLite local, melhor para listas e dados mais estruturados.
- `hive`: banco local rapido e simples para Flutter.

Exemplos de dados que podem ir para o historico:

- Cidade pesquisada.
- Local de destino.
- Data e horario da pesquisa.
- Meio de transporte usado.
- Resumo do clima encontrado.

## Perguntas tecnicas que o projeto ainda precisa responder

- A API de clima sera WeatherAPI.com ou Open-Meteo?
- A API de mapas sera OpenRouteService?
- O historico sera salvo com `shared_preferences`, `sqflite` ou `hive`?
- O modo GPS sera uma tela separada ou um estado dentro da tela principal?
- Como sera feita a paginacao exigida pelo professor?
- Como os alertas de chuva aparecerao na rota?

## Primeira versao recomendada

Para aprender bem e nao tentar construir tudo de uma vez, uma primeira versao pode ter:

1. Tela inicial.
2. Permissao de localizacao.
3. Clima atual da posicao do usuario.
4. Previsao das proximas horas.
5. Campo para buscar uma cidade manualmente.
6. Historico local das ultimas pesquisas.
7. Segunda tela ou paginacao simples para atender ao requisito da aula.

## Prototipo atual

Foi criado um primeiro prototipo em Flutter na pasta `app_clima`.

Arquivos principais:

- `app_clima/pubspec.yaml`: configuracao basica do projeto Flutter.
- `app_clima/lib/main.dart`: codigo principal do prototipo.
- `app_clima/README.md`: instrucoes para rodar e continuar o projeto.

O prototipo atual ainda usa dados simulados. Ele serve para validar a ideia visual antes de conectar APIs reais.

Telas do prototipo:

1. Clima atual.
2. Rota com clima.
3. Historico.

Decisoes representadas no prototipo:

- Navegacao por abas com `NavigationBar`.
- Selecao de transporte com `ChoiceChip`.
- Campo para o usuario informar o destino.
- Mapa ilustrativo na tela de clima, com bolhas para as condicoes nas regioes proximas.
- Rota ilustrativa com bolhas para chuva, vento e radiacao nos pontos do caminho.
- Historico local ainda simulado.

Depois disso, o projeto pode evoluir para:

1. Mapa real.
2. Busca real de destino.
3. Calculo de rota.
4. Previsao climatica ao longo do caminho.
5. Alertas visuais alimentados por dados reais.

### Mapa ilustrativo e mapa real

O mapa que aparece agora foi desenhado pelo proprio Flutter para testar a ideia da interface. Ele nao mostra ruas reais, nao usa GPS e nao faz requisicoes na internet.

Na versao real, usaremos um pacote de mapas no Flutter. Esse pacote exibe o mapa e permite colocar marcadores, bolhas e a posicao do usuario. O servico de rotas recebera origem, destino e meio de transporte e retornara o caminho. A API de clima retornara a previsao para os pontos daquele caminho.

### Decisao sobre a camada termica

A primeira versao da camada termica sera continua e simples. Ela mostra as previsoes reais obtidas para pontos da area que o usuario esta vendo, misturando as cores para formar regioes sem bordas de bolhas.

Nao vamos aumentar a quantidade de pontos nem trocar a fonte de dados apenas para tentar diferenciar todos os bairros. Essa melhoria pode ser reavaliada depois, caso seja necessaria para a aula ou para uma versao futura do app.

### Primeira integracao real: clima e localizacao

A aba Clima agora usa tres pacotes: `flutter_map` para exibir o mapa, `geolocator` para pedir a localizacao atual ao Android e `http` para consultar a WeatherAPI.

Para proteger a chave, ela nao deve ser escrita em `main.dart`. O Flutter recebe valores de configuracao no momento de rodar o app com `--dart-define`. Neste projeto, o nome usado e `WEATHER_API_KEY`.

O mapa completo consulta uma grade de coordenadas ao redor da area visualizada e usa esses dados para desenhar uma camada termica. A cor mais forte representa um valor maior no filtro ativo.

### Camada termica por regioes

Uma previsao para uma cidade inteira nao representa todos os bairros. Para mostrar variacoes no mapa, o app precisa dividir a area visivel em uma grade, por exemplo 5 por 5 pontos. Cada ponto tem latitude e longitude e recebe uma previsao propria.

Depois, o app interpola os valores: pontos proximos com valores parecidos formam uma mancha continua de cor. Esse processo e chamado de **interpolacao espacial**.

Mais pontos deixam o mapa mais detalhado, mas aumentam o custo de requisicoes. Por isso, a grade deve ser atualizada somente quando o usuario para de mover o mapa e os resultados devem ser guardados em cache por alguns minutos.

Para uma grade grande, o Open-Meteo pode ser mais adequado: ele aceita varias coordenadas em uma unica chamada. A WeatherAPI continua util para os dados detalhados da localizacao atual.

## Conceitos para estudar em ordem

1. Fundamentos de Dart.
2. Widgets basicos do Flutter.
3. Navegacao entre telas.
4. Consumo de API HTTP.
5. Conversao de JSON para classes Dart.
6. Gerenciamento de estado.
7. Permissao de localizacao.
8. Navegacao e paginacao.
9. Armazenamento local.
10. Mapas no Flutter.
11. Arquitetura em camadas.
12. Testes basicos.

## Boas praticas para este projeto

- Criar telas pequenas e componentes reutilizaveis.
- Evitar colocar regra de negocio diretamente dentro da tela.
- Separar codigo visual, regras e acesso a dados.
- Tratar erros de internet e permissao negada.
- Pensar primeiro em uma versao simples funcionando.
- Registrar decisoes tecnicas neste arquivo ou em outros `.md`.

## Organizacao Clean Architecture

O projeto passou a separar responsabilidades por funcionalidade:

```text
lib/
  core/                 # componentes compartilhados
  features/
    weather/
      data/             # chamadas para servicos externos
      domain/           # entidades que representam os dados
      presentation/     # telas e widgets do clima
    history/
      presentation/     # tela de historico
    route/
      presentation/     # tela e elementos da rota
```

`main.dart` deve apenas iniciar o aplicativo e reunir as telas. Uma tela nao deve fazer a requisicao HTTP diretamente: ela pede dados a uma classe da camada `data`, que devolve entidades da camada `domain`.

## Glossario rapido

| Termo | Significado |
| --- | --- |
| App | Aplicativo usado pelo usuario. |
| API | Servico externo ou interno que fornece dados. |
| JSON | Formato de dados usado em muitas APIs. |
| GPS | Sistema usado para localizacao e navegacao. |
| Widget | Bloco visual no Flutter. |
| Estado | Informacao que pode mudar durante o uso do app. |
| Rota | Caminho entre origem e destino. |
| Forecast | Previsao futura do clima. |
| Endpoint | Endereco de uma funcionalidade em uma API. |
| Clean Architecture | Organizacao do codigo em camadas com responsabilidades separadas. |
| Paginacao | Divisao do app em telas ou paginas navegaveis. |
| Historico local | Dados salvos no aparelho do usuario. |
| Requisicao | Pedido enviado para uma API. |
| Limite de requisicoes | Quantidade maxima de chamadas permitidas em uma API. |

## Diario de aprendizado

Use esta secao para registrar descobertas durante o projeto.

### Decisoes

- O app sera desenvolvido com Flutter.
- A arquitetura desejada sera baseada em Clean Architecture.
- No inicio, o app deve consumir APIs externas gratuitas.
- Uma API propria pode ser criada no futuro.
- O app deve ter mais de uma tela por requisito da aula.
- Login nao e necessario na primeira versao.
- O app deve armazenar historico de pesquisa.
- O GPS deve permitir escolhas como carro, moto, bicicleta e caminhada.
- APIs candidatas de clima: WeatherAPI.com ou Open-Meteo.
- API candidata de mapa/rota: OpenRouteService.
- A primeira plataforma do projeto sera Android.

### Duvidas em aberto

- Qual servico de clima escolher entre WeatherAPI.com e Open-Meteo?
- Confirmar se OpenRouteService atende bem as rotas desejadas.
- Como representar chuva diretamente na rota?
- Qual sera a primeira tela real do aplicativo?
- Qual estrategia usar para salvar historico local?
- Qual formato de paginacao usar: telas separadas, menu inferior ou paginas deslizaveis?
