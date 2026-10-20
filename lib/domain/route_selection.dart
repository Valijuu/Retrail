import '../data/db/followed_route.dart';
import 'ride_title.dart';

/// The followed [routes] whose display title — the original's description,
/// or its full localized date when untitled — contains [query], trimmed and
/// case-insensitive; feeds the "Followed routes" picker search (Spec 20).
/// An empty query keeps every route.
List<FollowedRoute> searchRoutes(
  List<FollowedRoute> routes,
  String query, {
  String? locale,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final route in routes)
      if (_routeTitle(route, locale).toLowerCase().contains(needle)) route,
  ];
}

/// The display titles of the [routes] whose original ride id is in [ids], in
/// list order; ids without a route are dropped. Feeds the History filter
/// row's route summary (Spec 20).
List<String> selectedRouteTitles(
  List<FollowedRoute> routes,
  Set<int> ids, {
  String? locale,
}) => [
  for (final route in routes)
    if (ids.contains(route.original.rideId)) _routeTitle(route, locale),
];

/// The title a route shows: the display title of its original ride.
String _routeTitle(FollowedRoute route, String? locale) =>
    rideDisplayTitle(route.original, locale: locale);
