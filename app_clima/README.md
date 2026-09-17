# AppClima

Prototipo em Flutter do AppClima, com foco inicial em Android.

## Foco atual

- Plataforma principal: Android.
- Interface com dados simulados.
- Navegacao por abas.
- Tela de clima atual.
- Tela de rota com alertas climaticos no trajeto.
- Tela de historico.
- Tela de aprendizado.

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

O prototipo ainda nao usa APIs reais. WeatherAPI, Open-Meteo e OpenRouteService entram depois que o fluxo visual estiver bom.

As chaves de API nao devem ir direto no codigo do app.
