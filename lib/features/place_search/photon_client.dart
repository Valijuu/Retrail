import 'dart:async' show TimeoutException;
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/heading.dart' show LatLng;
import '../../map/openfreemap.dart' show kMapUserAgent;

/// One place Photon suggested: its name, a second line with the city and
/// country, and where it is.
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.name,
    required this.detail,
    required this.point,
  });

  final String name;

  /// City and country, without the name again; empty when Photon knows
  /// neither.
  final String detail;
  final LatLng point;
}

/// Thrown when Photon could not be asked or answered with an error.
class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable(this.cause);
  final Object cause;

  @override
  String toString() => 'PlaceSearchUnavailable: $cause';
}

/// Asks Photon (photon.komoot.io, OpenStreetMap data, no key) for places by
/// name (#106). The request carries the text and the app language only: no
/// position, no ride data, no identifier.
class PhotonClient {
  PhotonClient({
    http.Client? client,
    this.baseUrl = 'https://photon.komoot.io/api/',
    this.timeout = const Duration(seconds: 8),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;
  final Duration timeout;

  /// At most this many suggestions per request.
  static const int limit = 5;

  Uri requestUri(String query, {required String lang}) => Uri.parse(
    baseUrl,
  ).replace(queryParameters: {'q': query, 'limit': '$limit', 'lang': lang});

  Future<List<PlaceSuggestion>> search(
    String query, {
    required String lang,
  }) async {
    final http.Response response;
    try {
      // The same app user agent as the map tiles: Photon answers the default
      // Dart one with 403.
      response = await _client
          .get(
            requestUri(query, lang: lang),
            headers: const {'User-Agent': kMapUserAgent},
          )
          .timeout(timeout);
    } on TimeoutException catch (e) {
      throw PlaceSearchUnavailable(e);
    } on http.ClientException catch (e) {
      throw PlaceSearchUnavailable(e);
    }
    if (response.statusCode != 200) {
      throw PlaceSearchUnavailable('HTTP ${response.statusCode}');
    }
    try {
      return parsePhotonResponse(response.body);
    } on FormatException catch (e) {
      throw PlaceSearchUnavailable(e);
    }
  }

  void close() => _client.close();
}

/// The suggestions in a Photon GeoJSON answer, in its order; a feature
/// without a name or a point is skipped.
List<PlaceSuggestion> parsePhotonResponse(String body) {
  final json = jsonDecode(body);
  if (json is! Map || json['features'] is! List) {
    throw const FormatException('no features');
  }
  final out = <PlaceSuggestion>[];
  for (final feature in json['features'] as List) {
    if (feature is! Map) continue;
    final props = feature['properties'];
    final geometry = feature['geometry'];
    if (props is! Map || geometry is! Map) continue;
    final coords = geometry['coordinates'];
    final name = props['name'];
    if (coords is! List || coords.length < 2 || name is! String) continue;
    final lon = coords[0];
    final lat = coords[1];
    if (lon is! num || lat is! num) continue;
    out.add(
      PlaceSuggestion(
        name: name,
        detail: placeDetail(props, name),
        point: (lat: lat.toDouble(), lng: lon.toDouble()),
      ),
    );
  }
  return out;
}

/// The second line of a suggestion: city (or state for a city itself) and
/// country, whichever Photon has, never repeating [name].
String placeDetail(Map<dynamic, dynamic> props, String name) {
  final parts = <String>[];
  for (final key in ['city', 'state', 'country']) {
    final value = props[key];
    if (value is String && value.isNotEmpty && value != name) {
      if (key == 'state' && parts.isNotEmpty) continue;
      parts.add(value);
    }
  }
  return parts.join(', ');
}
