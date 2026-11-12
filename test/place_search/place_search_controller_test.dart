import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/features/place_search/photon_client.dart';
import 'package:retrail/features/place_search/place_search_controller.dart';

String _body(List<String> names) =>
    '{"type":"FeatureCollection","features":[${names.map((n) => '{"type":"Feature","geometry":{"type":"Point","coordinates":[10,53]},"properties":{"name":"$n","country":"DE"}}').join(',')}]}';

void main() {
  const debounce = Duration(milliseconds: 30);
  late List<Uri> sent;
  late ProviderContainer c;

  ProviderContainer make(Future<http.Response> Function(http.Request) handler) {
    sent = [];
    final container = ProviderContainer(
      overrides: [
        placeSearchDebounceProvider.overrideWithValue(debounce),
        placeSearchLangProvider.overrideWithValue('de'),
        photonClientProvider.overrideWithValue(
          PhotonClient(
            client: MockClient((req) {
              sent.add(req.url);
              return handler(req);
            }),
          ),
        ),
      ],
    );
    // Riverpod pauses a provider nobody listens to; the panel listens in the app.
    container.listen(placeSearchProvider, (_, _) {});
    return container;
  }

  Future<http.Response> Function(http.Request) answering(
    String body, {
    int status = 200,
  }) =>
      (_) async => http.Response(body, status);

  Future<void> wait([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  tearDown(() => c.dispose());

  test('one request goes out after the pause, with the full text', () async {
    c = make(answering(_body(['Hamburg'])));
    final n = c.read(placeSearchProvider.notifier)..open();
    for (final t in ['H', 'Ha', 'Ham', 'Hamb', 'Hambu', 'Hamburg']) {
      n.setQuery(t);
      await wait(5);
    }
    await wait();
    expect(sent, hasLength(1));
    expect(sent.single.queryParameters, {
      'q': 'Hamburg',
      'limit': '5',
      'lang': 'de',
    });
    final s = c.read(placeSearchProvider);
    expect(s.status, PlaceSearchStatus.results);
    expect(s.suggestions.single.name, 'Hamburg');
  });

  test('under three characters nothing goes out and nothing fails', () async {
    c = make(answering(_body(['x'])));
    c.read(placeSearchProvider.notifier)
      ..open()
      ..setQuery('Ha');
    await wait();
    expect(sent, isEmpty);
    expect(c.read(placeSearchProvider).status, PlaceSearchStatus.idle);
  });

  test('the same text again is not sent twice', () async {
    c = make(answering(_body(['Kiel'])));
    final n = c.read(placeSearchProvider.notifier)
      ..open()
      ..setQuery('Kiel');
    await wait();
    n.setQuery('Kiel ');
    await wait();
    expect(sent, hasLength(1));
  });

  test('an older answer is dropped when a newer request started', () async {
    final gates = <String, Completer<http.Response>>{};
    c = make((req) {
      final q = req.url.queryParameters['q']!;
      return (gates[q] = Completer<http.Response>()).future;
    });
    final n = c.read(placeSearchProvider.notifier)
      ..open()
      ..setQuery('Berlin');
    await wait();
    n.setQuery('Bremen');
    await wait();
    expect(gates.keys, ['Berlin', 'Bremen']);
    gates['Bremen']!.complete(http.Response(_body(['Bremen']), 200));
    await wait(5);
    gates['Berlin']!.complete(http.Response(_body(['Berlin']), 200));
    await wait(5);
    expect(c.read(placeSearchProvider).suggestions.single.name, 'Bremen');
  });

  test(
    'no match says empty, a failure says unavailable and may retry',
    () async {
      c = make(answering(_body([])));
      final n = c.read(placeSearchProvider.notifier)
        ..open()
        ..setQuery('Nirgendwo');
      await wait();
      expect(c.read(placeSearchProvider).status, PlaceSearchStatus.empty);
      c.dispose();

      c = make(answering('down', status: 503));
      c.read(placeSearchProvider.notifier)
        ..open()
        ..setQuery('Hamburg');
      await wait();
      expect(c.read(placeSearchProvider).status, PlaceSearchStatus.unavailable);
      // The same text may be sent again after a failure.
      c.read(placeSearchProvider.notifier).setQuery('Hamburg!');
      c.read(placeSearchProvider.notifier).setQuery('Hamburg');
      await wait();
      expect(sent, hasLength(2));
      expect(n, isNotNull);
    },
  );

  test('closing clears the text and the suggestions', () async {
    c = make(answering(_body(['Hamburg'])));
    final n = c.read(placeSearchProvider.notifier)
      ..open()
      ..setQuery('Hamburg');
    await wait();
    n.close();
    final s = c.read(placeSearchProvider);
    expect((s.open, s.query), (false, ''));
    expect(s.suggestions, isEmpty);
  });
}
