# AppClima

## Configurar as chaves das APIs

O app le as chaves de um arquivo local `.env`. Isso evita colocar as chaves no codigo ou na configuracao de execucao do editor.

Crie o arquivo `.env` na raiz do projeto, ao lado de `pubspec.yaml`, com este formato:

```text
WEATHER_API_KEY=SUA_CHAVE_DA_WEATHERAPI
ORS_API_KEY=SUA_CHAVE_DO_OPENROUTESERVICE
```

Use `.env.example` como modelo. Em seguida, rode o app normalmente pelo VS Code, Android Studio ou terminal. Na primeira abertura, permita o acesso a localizacao para que o mapa seja centralizado na sua posicao.

`WEATHER_API_KEY` e usada para o clima; `ORS_API_KEY` e usada para buscar destinos e calcular a rota. As duas chaves ficam fora do codigo Dart e o `.env` ja esta ignorado pelo Git.

Prototipo em Flutter do AppClima, com foco inicial em Android.

## Foco atual

- Plataforma principal: Android.
- Clima e rota consultados por APIs.
- Navegacao por abas.
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
