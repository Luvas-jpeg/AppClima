# Contexto do projeto

Este projeto será um Aplicativo Mobile de Climas, utilizando APIs gratuitas de climas, porém,
tive uma idéia de transformar numa gps com clima, como vai funcionar?
Ele terá uma tela inical a localização do usuário naquele momento, e deverá mostrar as chances de
precipitações, velocidade do tempo, temperatura, e radiação do sol, como um widget de clima que temos no celular
porém, quando u usuário clicar num botão de gps(ainda não decidi como entrar no "modo" gps), ele vai funcionar como
um GPS normal, o usuário defini uma localização, e tem o caminho mais rápido, dependendo do meio de veículo, só que.
No trajeto deste caminho, terá algumas previsões durante o caminho, por exemplo, ele quer ir numa padaria que está a 5km
e tem 10 minutos de caminhada, só que daqui 5 minutos, uma parte específica do caminho, vai começar a chover, eu quero que isso fique visível
na tragetória do GPS.
O objetivo desse app, seria para pessoas que viajam muito, mostrar previsões de climas da cidade em que vão ficar, ou hospedar, no caminho, ter as previsões no caminho, caso tiver chuva,
ventania, ou estiver muti quente, mostrar o local mais perto para repousar, talvez colocar pontos em que tem radar, colocar alguma maniera que caso a pessoa tiver com o pneu furado, ou
acontecer alguma coisa, ter um botão de sos no app, para pessoas próximas poderem ajudar.

# Arquitetura

Precisa ser definida, nunca trabalhei com o Flutter para desenvolvimento.

# Tecnologias a serem utilizadas

No momento, somente Flutter, pretendo criar só um Cliente-Server para o usuário usar o app, e conectar a uma API externa,
Mas no futuro, caso eu gostar do projeto, construir uma API dedicada para o App.
Utilizando as boas práticas de Clean Architeture.

# Duvidas tecnicas

Pretendo realizar mais de uma tela, o professor quis que o app tivesse paginacao;
Acho que login nao seria necessario, porem deve armazenar o historico de pesquisa dela;
E o GPS, deve ter sim escolhas como, carro, moto, bicicleta, caminhada, entre outros tipos;
O app precisa funcionar em android primeiro, vejo depois se vai funcionar em IOS;
Agora como os alertas pvai aparecer no caminho, eu pensei em algo simples como mudanca de cor na parte do caminho,
ou vai ter uma bolha de chuva, uma bolha de vento, ou uma bolha de radicao no caminho, estou em duvida ainda;

# Chaves de API

WEATHER_API_KEY
GEOAPIFY_API_KEY
