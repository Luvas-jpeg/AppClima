"""Smoke test using local keys; never prints URLs, keys or response bodies."""
import json
from pathlib import Path
from urllib.request import urlopen
from urllib.parse import urlencode
from urllib.error import HTTPError, URLError

root = Path(__file__).resolve().parents[1]
env = root / 'app_clima/.env'
if not env.exists():
    env = root / '.env'
keys = {}
for line in env.read_text().splitlines():
    if '=' in line and not line.lstrip().startswith('#'):
        key, value = line.split('=', 1)
        keys[key.strip()] = value.strip().strip('\"\'')
geo = keys.get('GEOAPIFY_API_KEY', '')
weather = keys.get('WEATHER_API_KEY', '')
checks = [
    ('ViaCEP 15054-700', 'https://viacep.com.br/ws/15054700/json/', {}, lambda d: int(d.get('cep', '').replace('-', '') == '15054700' and bool(d.get('localidade')))),
    ('Geoapify regiao do CEP 15054-700', 'https://api.geoapify.com/v1/geocode/search', dict(apiKey=geo, city='São José do Rio Preto', state='SP', country='Brasil', type='city', filter='countrycode:br', lang='pt', limit=5), lambda d: sum(f.get('properties', {}).get('city') == 'São José do Rio Preto' and f.get('properties', {}).get('result_type') == 'city' for f in d.get('features', []))),
    ('Geoapify CEP', 'https://api.geoapify.com/v1/geocode/search', dict(apiKey=geo, postcode='01310-100', type='postcode', filter='countrycode:br', lang='pt', limit=5), lambda d: sum(f.get('properties', {}).get('postcode', '').replace('-', '') == '01310100' for f in d.get('features', []))),
    ('Geoapify cidades', 'https://api.geoapify.com/v2/places', dict(apiKey=geo, categories='populated_place.city,populated_place.town,populated_place.municipality', filter='rect:-46.9,-23.8,-46.3,-23.3', limit=8, lang='pt'), lambda d: len(d['features'])),
    ('WeatherAPI previsao', 'https://api.weatherapi.com/v1/forecast.json', dict(key=weather, q='-23.5505,-46.6333', days=3), lambda d: len(d['forecast']['forecastday'])),
    ('Geoapify autocomplete', 'https://api.geoapify.com/v1/geocode/autocomplete', dict(apiKey=geo, text='Avenida Paulista, Sao Paulo', limit=5, lang='pt'), lambda d: len(d['features'])),
    ('Geoapify geocoding', 'https://api.geoapify.com/v1/geocode/search', dict(apiKey=geo, text='Avenida Paulista, Sao Paulo', limit=5, lang='pt'), lambda d: len(d['features'])),
    ('Geoapify reverse', 'https://api.geoapify.com/v1/geocode/reverse', dict(apiKey=geo, lat=-23.5505, lon=-46.6333), lambda d: len(d['features'])),
]
for mode in ['walk', 'bicycle', 'motorcycle', 'drive']:
    checks.append(('Geoapify rota ' + mode, 'https://api.geoapify.com/v1/routing', dict(apiKey=geo, waypoints='-23.5505,-46.6333|-23.5614,-46.6559', mode=mode), lambda d: len(d['features'][0]['geometry']['coordinates'])))
failed = False
for name, endpoint, params, validate in checks:
    try:
        with urlopen(endpoint + '?' + urlencode(params), timeout=25) as response:
            data = json.load(response)
            count = validate(data)
            print(f'{name}: HTTP {response.status}, itens={count}')
            failed |= count == 0
    except HTTPError as error:
        print(f'{name}: HTTP {error.code}')
        failed = True
    except (URLError, TimeoutError):
        print(f'{name}: falha de rede/timeout')
        failed = True
    except (KeyError, TypeError, ValueError, IndexError):
        print(f'{name}: resposta fora do formato esperado')
        failed = True
raise SystemExit(1 if failed else 0)
