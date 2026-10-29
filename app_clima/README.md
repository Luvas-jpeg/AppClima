# AppClima

## Configurar as chaves das APIs

O app le as chaves de um arquivo local `.env`. Isso evita colocar as chaves no codigo ou na configuracao de execucao do editor.

Crie o arquivo `.env` na raiz do projeto, ao lado de `pubspec.yaml`, com este formato:

```text
WEATHER_API_KEY=SUA_CHAVE_DA_WEATHERAPI
GEOAPIFY_API_KEY=SUA_CHAVE_DA_GEOAPIFY
```

Use `.env.example` como modelo. Em seguida, rode o app normalmente pelo VS Code, Android Studio ou terminal. Na primeira abertura, permita o acesso a localizacao para que o mapa seja centralizado na sua posicao.

`WEATHER_API_KEY` e usada para o clima; `GEOAPIFY_API_KEY` e usada para buscar destinos e calcular a rota. As duas chaves ficam fora do codigo Dart e o `.env` ja esta ignorado pelo Git.

Prototipo em Flutter do AppClima, com foco inicial em Android.

## Foco atual

- Plataforma principal: Android.
- Clima e rota consultados por APIs.
- Navegação entre páginas com botão de voltar.
- Tela de clima atual.
- Tela de rota com alertas climaticos no trajeto.
- Tela de historico.

As pastas de iOS, web e desktop foram geradas pelo Flutter, mas por enquanto o desenvolvimento e os testes devem mirar Android.

## Como rodar no Android

Dentro da pasta `app_clima`, rode:

```powershell
flutter pub get
flutter run
```

Ou pelo VS Code:

1. Abra a pasta `app_clima`.
2. Selecione um emulador Android ou aparelho fisico.
3. Use `Run > Start Debugging`.

## Observacoes

As chaves de API nao devem ir direto no codigo do app.

## Busca e rotas

Toque em “Para onde você vai?” para abrir a página de busca. Digite pelo menos
três caracteres, escolha uma das sugestões de endereço e aguarde a rota.
O botão de busca do teclado faz uma pesquisa completa caso as sugestões não
encontrem o local. Também é possível selecionar o destino diretamente no mapa.

Geoapify fornece autocomplete, geocoding, busca reversa e rotas nos modos
walk, bicycle, motorcycle e drive. WeatherAPI fornece a previsão nos pontos
do trajeto para os horários estimados de chegada.

O arquivo usado pelo Flutter é `app_clima/.env` (ao lado de `pubspec.yaml`).
Após alterar as chaves, pare e execute o app novamente.

Para testar as credenciais sem imprimir chaves ou respostas completas, execute
`python3 scripts/check_apis.py` na raiz do repositório. O teste faz doze consultas
reais: CEP direto, ViaCEP, localização da região do CEP, cidades, previsão, autocomplete, geocoding, busca reversa e os quatro transportes.

## Navegação e interface

A tela inicial reúne o clima e os acessos a Planejar rota, Histórico e Mapa
do clima. Cada opção abre uma página própria, preservando a tela anterior.

Fluxo principal: Clima → Planejar viagem → Buscar destino → escolher endereço
→ Rota com clima → Abrir mapa ou Iniciar rota. O histórico também permite
reaproveitar um endereço no planejamento.

A interface usa cartões arredondados, azul e verde, botões amplos e dimensões
que acompanham o tamanho do texto nos cartões de previsão por hora.

### Marcações no mapa geral

Na tela inicial, toque em “Explorar mapa do clima”. A Geoapify busca cidades
e municípios dentro da área visível; cada marcação usa as coordenadas e o nome
da cidade, sem a antiga grade 3×3. O mapa exibe até oito cidades por consulta,
priorizando a proximidade do centro, e reutiliza previsões por 15 minutos
enquanto a página está aberta. As marcações exibem o valor do filtro
selecionado (chuva, temperatura, vento ou UV). Toque em uma cidade
para abrir as condições locais e a previsão das próximas horas. Pontos próximos
usam ícones compactos para reduzir a sobreposição. O estilo de mapa modifica
somente o fundo; as marcações mantêm suas cores.

As rotas continuam mostrando os trechos coloridos e etiquetas simples.

## Resumo e previsão da viagem

Depois de calcular a rota, o resumo mostra distância, duração, data e horário
estimados de chegada, uma síntese da chuva nos pontos consultados e o botão
Iniciar viagem. “Ver previsão do trajeto” abre uma linha do tempo com saída,
trechos intermediários e chegada. Cada item informa a previsão no horário
estimado de passagem e permite retornar ao mapa centralizado nesse trecho.
Os ícones no mapa abrem os detalhes da previsão por toque.

A chegada e a linha do tempo usam a mesma referência de partida, registrada
no cálculo da rota. Horários são estimativas e a disponibilidade da previsão
depende da WeatherAPI; falhas de consulta não aparecem como ausência de chuva.

## Busca por CEP e visualização da rota

A busca aceita CEP brasileiro completo, com ou sem hífen (ex.: 01310-100
ou 01310100), e usa geocoding de código postal com filtro para o Brasil. O resultado precisa
conter o mesmo CEP solicitado. Se a Geoapify não o encontrar, o ViaCEP recupera
rua, bairro, cidade e estado, sem chave adicional. O app tenta localizar essa
rua ou região e não aceita ruas ou cidades diferentes como correspondência.

Quando só houver coordenadas aproximadas, a busca informa isso e abre a página
de confirmação na região encontrada. O usuário deve tocar no destino exato
antes de calcular a rota. O CEP 15054-700 é um caso coberto por esse fluxo.
A escolha de um endereço com número continua disponível pela busca normal.

As previsões são distribuídas pela distância acumulada ao longo da geometria,
com coordenadas intermediárias interpoladas. O número de pontos considera
a duração (referência de 20 minutos) e distância (referência de 25 km), com
mínimo de quatro e máximo de dezesseis consultas por rota. Saída e chegada
também aparecem no mapa. Em viagens muito longas o limite aumenta o intervalo.
O horário de passagem ainda é estimado pela velocidade média do trajeto.

Ao iniciar a viagem, o mapa enquadra o trajeto completo. Os controles
“Ver trajeto completo” e “Acompanhar minha localização” alternam a câmera,
e os painéis ficam fora da área do mapa para preservar a leitura dos pontos.

## Filtros do mapa da rota

Chuva, temperatura, vento e UV alteram o valor e a unidade apresentados em
cada ponto do trajeto, o destaque nos detalhes e o painel do próximo trecho.
O filtro de chuva mostra chance (%) e precipitação prevista; temperatura
mostra °C e sensação; vento mostra km/h e rajadas; UV mostra o índice.

A legenda numérica usa a mesma escala de cores dos trechos e marcadores.
As cores servem para comparar valores, sem classificar uma viagem como segura
ou perigosa. A troca de filtro usa a previsão já carregada, sem novas consultas.

## Atualizar o clima na tela inicial

Puxe a lista para baixo ou toque no botão Atualizar clima. Cada atualização
consulta novamente a posição do aparelho e a previsão da WeatherAPI; chamadas
simultâneas compartilham a operação em andamento. Se a consulta falhar, os
últimos dados continuam visíveis com uma mensagem de erro.

A tela diferencia o horário da consulta no app do horário de atualização
informado pela WeatherAPI (`last_updated_epoch`), quando disponível. Repetir
a consulta não garante uma temperatura diferente: o provedor pode retornar
a mesma observação até receber novos dados.
