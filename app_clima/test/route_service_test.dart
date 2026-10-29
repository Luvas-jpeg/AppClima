import 'dart:convert';

import 'package:app_clima/features/route/data/route_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

const origin = LatLng(-23.55, -46.63);
const destination = LatLng(-23.56, -46.65);

Map<String, dynamic> address() => {
  'features': [
    {
      'properties': <String, dynamic>{
        'formatted': 'Avenida Paulista, São Paulo, Brasil',
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [-46.65, -23.56],
      },
    },
  ],
};

void main() {
  test(
    'CEP com e sem hífen usa geocoding de código postal no Brasil',
    () async {
      for (final query in ['01310-100', '01310100', 'CEP 01310-100']) {
        final service = RouteService(
          apiKey: 'test',
          client: MockClient((request) async {
            expect(request.url.path, '/v1/geocode/search');
            expect(request.url.queryParameters['postcode'], '01310-100');
            expect(request.url.queryParameters['type'], 'postcode');
            expect(request.url.queryParameters['filter'], 'countrycode:br');
            expect(request.url.queryParameters.containsKey('text'), isFalse);
            final data = address();
            (data['features'] as List).first['properties'].addAll({
              'postcode': '01310-100',
              'country_code': 'br',
            });
            return http.Response(jsonEncode(data), 200);
          }),
        );
        expect(await service.searchDestinations(query, origin), hasLength(1));
        service.close();
      }
    },
  );

  test('15054700 sem cobertura postal usa ViaCEP e exige confirmar localização aproximada', () async {
    var viaCalls = 0;
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((request) async {
        if (request.url.host == 'viacep.com.br') {
          viaCalls++;
          expect(request.url.path, '/ws/15054700/json/');
          return http.Response(
            jsonEncode({
              'cep': '15054-700',
              'logradouro': 'Rua de Teste',
              'bairro': 'Bairro de Teste',
              'localidade': 'São José do Rio Preto',
              'uf': 'SP',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        final query = request.url.queryParameters;
        final data = address();
        final props =
            (data['features'] as List).first['properties']
                as Map<String, dynamic>;
        props.addAll({'city': 'São José do Rio Preto', 'state_code': 'SP'});
        if (query['postcode'] != null) {
          return http.Response('{"features":[]}', 200);
        }
        if (query['street'] != null) {
          // Reject a city center and an unrelated street returned for a street query.
          props.addAll({'result_type': 'street', 'street': 'Rua Errada'});
          return http.Response(jsonEncode(data), 200);
        }
        if (query['type'] == 'locality') {
          return http.Response('{"features":[]}', 200);
        }
        expect(query['type'], 'city');
        props['result_type'] = 'city';
        return http.Response(jsonEncode(data), 200);
      }),
    );
    final result = await service.searchDestinations('15054700', origin);
    expect(viaCalls, 1);
    expect(result.single.name, contains('CEP 15054-700'));
    expect(result.single.name, contains('Rua de Teste'));
    expect(result.single.requiresMapConfirmation, isTrue);
    service.close();
  });

  test(
    'não usa outro CEP retornado pela Geoapify nem inventa CEP inexistente',
    () async {
      final service = RouteService(
        apiKey: 'test',
        client: MockClient((request) async {
          if (request.url.host == 'viacep.com.br') {
            return http.Response('{"erro":true}', 200);
          }
          final data = address();
          (data['features'] as List).first['properties'].addAll({
            'postcode': '01001-000',
            'country_code': 'br',
          });
          return http.Response(jsonEncode(data), 200);
        }),
      );
      expect(await service.searchDestinations('99999999', origin), isEmpty);
      service.close();
    },
  );

  test(
    'falha no ViaCEP mostra mensagem de consulta, sem expor chaves',
    () async {
      final service = RouteService(
        apiKey: 'segredo',
        client: MockClient((request) async {
          return request.url.host == 'viacep.com.br'
              ? http.Response('falha', 503)
              : http.Response('{"features":[]}', 200);
        }),
      );
      await expectLater(
        service.searchDestinations('15054700', origin),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('serviço de CEP') &&
                !e.toString().contains('segredo'),
          ),
        ),
      );
      service.close();
    },
  );

  test('CEP incompleto não dispara consultas por dígito', () async {
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((_) async => throw StateError('Consulta indevida')),
    );
    for (final cep in ['013', '01310', '01310-10']) {
      expect(await service.searchDestinations(cep, origin), isEmpty);
    }
    service.close();
  });

  test(
    'autocomplete e busca usam endpoints Geoapify e preservam endereço',
    () async {
      for (final autocomplete in [true, false]) {
        final service = RouteService(
          apiKey: 'test',
          client: MockClient((request) async {
            expect(request.url.host, 'api.geoapify.com');
            expect(
              request.url.path,
              '/v1/geocode/${autocomplete ? 'autocomplete' : 'search'}',
            );
            expect(
              request.url.queryParameters['bias'],
              'proximity:-46.63,-23.55',
            );
            expect(request.url.queryParameters['apiKey'], 'test');
            return http.Response(jsonEncode(address()), 200);
          }),
        );
        final result = await service.searchDestinations(
          'Paulista',
          origin,
          autocomplete: autocomplete,
        );
        expect(result.single.name, 'Avenida Paulista, São Paulo, Brasil');
        expect(result.single.location, destination);
        service.close();
      }
    },
  );

  test('busca reversa preserva o ponto selecionado no mapa', () async {
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((request) async {
        expect(request.url.path, '/v1/geocode/reverse');
        return http.Response(jsonEncode(address()), 200);
      }),
    );
    final result = await service.reverseGeocode(origin);
    expect(result.location, origin);
    expect(result.isMapSelection, isTrue);
    service.close();
  });

  test('rotas convertem MultiLineString e usam metros e segundos em todos os modos', () async {
    for (final mode in ['walk', 'bicycle', 'motorcycle', 'drive']) {
      final service = RouteService(
        apiKey: 'test',
        client: MockClient((request) async {
          expect(request.url.path, '/v1/routing');
          expect(request.url.queryParameters['mode'], mode);
          expect(
            request.url.queryParameters['waypoints'],
            '-23.55,-46.63|-23.56,-46.65',
          );
          expect(request.url.queryParameters['units'], 'metric');
          return http.Response(
            jsonEncode({
              'features': [
                {
                  'properties': {'distance': 2500, 'time': 1800},
                  'geometry': {
                    'type': 'MultiLineString',
                    'coordinates': [
                      [
                        [-46.63, -23.55],
                        [-46.65, -23.56],
                      ],
                    ],
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final result = await service.calculateRoute(
        origin: origin,
        destination: destination,
        profile: mode,
      );
      expect(result.points, [origin, destination]);
      expect(result.distanceMeters, 2500);
      expect(result.durationSeconds, 1800);
      service.close();
    }
  });

  test('retorna lista vazia para endereço inexistente', () async {
    final service = RouteService(
      apiKey: 'test',
      client: MockClient((_) async => http.Response('{"features":[]}', 200)),
    );
    expect(await service.searchDestinations('inexistente', origin), isEmpty);
    await expectLater(
      service.calculateRoute(
        origin: origin,
        destination: destination,
        profile: 'walk',
      ),
      throwsException,
    );
    service.close();
  });

  test('erros de chave, cota e resposta inválida não expõem a chave', () async {
    for (final code in [401, 403, 429, 500, 200]) {
      final service = RouteService(
        apiKey: 'segredo',
        client: MockClient((_) async => http.Response('segredo', code)),
      );
      await expectLater(
        service.searchDestinations('Paulista', origin),
        throwsA(
          predicate((e) => e is Exception && !e.toString().contains('segredo')),
        ),
      );
      service.close();
    }
  });

  test(
    'não consulta a rede sem chave ou com menos de três caracteres',
    () async {
      final service = RouteService(
        apiKey: '',
        client: MockClient(
          (_) async => throw StateError('Não deveria consultar'),
        ),
      );
      expect(await service.searchDestinations('ab', origin), isEmpty);
      await expectLater(
        service.searchDestinations('Paulista', origin),
        throwsException,
      );
      service.close();
    },
  );
}
