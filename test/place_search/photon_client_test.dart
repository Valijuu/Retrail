import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/features/place_search/photon_client.dart';

const _body = '''
{"features":[
 {"geometry":{"coordinates":[9.99,53.55],"type":"Point"},"type":"Feature",
  "properties":{"osm_type":"R","name":"Hamburg","state":"Hamburg","country":"Deutschland","type":"city"}},
 {"geometry":{"coordinates":[8.8,53.08],"type":"Point"},"type":"Feature",
  "properties":{"name":"Hamburger Straße","city":"Bremen","state":"Bremen","country":"Deutschland","type":"street"}},
 {"geometry":{"coordinates":[1,2],"type":"Point"},"type":"Feature","properties":{"country":"X"}}
],"type":"FeatureCollection"}
''';

void main() {
  test('the request carries the text, the limit and the language only', () {
    final uri = PhotonClient().requestUri('Hamburg', lang: 'de');
    expect(
      uri.toString(),
      'https://photon.komoot.io/api/?q=Hamburg&limit=5&lang=de',
    );
  });

  test('suggestions come with name, a city/country line and the point', () {
    final places = parsePhotonResponse(_body);
    expect(places, hasLength(2));
    expect(places[0].name, 'Hamburg');
    expect(places[0].detail, 'Deutschland');
    expect(places[0].point, (lat: 53.55, lng: 9.99));
    expect(places[1].name, 'Hamburger Straße');
    expect(places[1].detail, 'Bremen, Deutschland');
  });

  test('a city as its own state shows only the country', () {
    expect(
      placeDetail({'state': 'Berlin', 'country': 'Deutschland'}, 'Berlin'),
      'Deutschland',
    );
    expect(
      placeDetail({
        'city': 'Kiel',
        'state': 'Schleswig-Holstein',
        'country': 'Deutschland',
      }, 'Hafen'),
      'Kiel, Deutschland',
    );
    expect(
      placeDetail({'state': 'Bayern', 'country': 'Deutschland'}, 'Zugspitze'),
      'Bayern, Deutschland',
    );
  });

  test('a good answer is parsed, an error status is "unavailable"', () async {
    http.Request? seen;
    final ok = PhotonClient(
      client: MockClient((req) async {
        seen = req;
        return http.Response(_body, 200);
      }),
    );
    expect(await ok.search('Hamburg', lang: 'de'), hasLength(2));
    // Photon refuses the default Dart user agent; the app names itself.
    expect(seen!.headers['User-Agent'], 'Retrail (io.github.valijuu.retrail)');
    final bad = PhotonClient(
      client: MockClient((_) async => http.Response('nope', 503)),
    );
    expect(
      () => bad.search('Hamburg', lang: 'de'),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
  });

  test('no network and a timeout are "unavailable" too', () async {
    final offline = PhotonClient(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(
      () => offline.search('Hamburg', lang: 'de'),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
    final slow = PhotonClient(
      timeout: const Duration(milliseconds: 20),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    expect(
      () => slow.search('Hamburg', lang: 'de'),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
  });

  test('a body that is not GeoJSON is "unavailable"', () async {
    final c = PhotonClient(
      client: MockClient((_) async => http.Response('<html>', 200)),
    );
    expect(
      () => c.search('x', lang: 'en'),
      throwsA(isA<PlaceSearchUnavailable>()),
    );
  });
}
