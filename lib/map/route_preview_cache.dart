import 'dart:async';
import 'dart:io';
import 'dart:ui' show Brightness;

import 'preview_projection.dart';
import 'preview_snapshot.dart' show PreviewResult;

/// Produces the preview PNG for a route at a given [Brightness]. The app
/// composes this from the snapshot renderer (online) or the flat sketch
/// (offline) — see Spec 12 wiring. The result says whether it is final quality
/// or a degraded fallback ([PreviewResult.complete]).
typedef PreviewRenderer = Future<PreviewResult> Function(
    List<RoutePoint> points, Brightness brightness);

/// Disk cache of ride-preview PNGs, keyed by `rideId` **and brightness** (light
/// + dark variants coexist). Generated once per variant (at save or first view)
/// so list scrolling never fetches tiles, and the card always matches the
/// current theme — mirroring the original, whose live preview followed the app
/// theme.
///
/// A degraded render (offline sketch, or a snapshot with failed tiles) is
/// served immediately but flagged with a `.stale` sidecar; the next
/// [ensurePreview] re-renders it, upgrading to the full-tile PNG once online —
/// "save flat sketch now, regenerate full tiles later".
class RoutePreviewCache {
  RoutePreviewCache(
      {required this.baseDir,
      required this.render,
      this.maxConcurrentRenders = 3})
      : _renderLanes =
            List.generate(maxConcurrentRenders, (_) => Future<void>.value());

  final Directory baseDir;
  final PreviewRenderer render;

  /// Previews known to be final (on disk, not stale), memoized so a list card
  /// can resolve its image **synchronously** on first build — no per-scroll
  /// `exists()` round-trips, no sketch-then-image pop-in.
  final Map<String, File> _resolved = {};

  /// How many renders may run at once. Bounded (not unlimited) so a fast
  /// scroll over many un-rendered rides doesn't fan out unboundedly many
  /// concurrent tile fetches + decodes + PNG encodes on the UI isolate
  /// (visible as scroll stutter); >1 so a backlog of many un-rendered rides —
  /// a bulk import, or first-ever big History open — drains meaningfully
  /// faster than one at a time (issue #23).
  final int maxConcurrentRenders;

  /// One render-queue tail per lane; a new render joins the lane it's
  /// assigned to round-robin, so at most [maxConcurrentRenders] run at once
  /// while each lane still serializes its own renders.
  final List<Future<void>> _renderLanes;
  int _nextLane = 0;

  final StreamController<int> _upgrades = StreamController<int>.broadcast();

  /// Ride ids whose stale (degraded) preview was just replaced by a complete
  /// render — e.g. an offline sketch upgraded to the real map once back
  /// online. Shown previews listen so they swap in the new PNG (issue #31).
  Stream<int> get upgrades => _upgrades.stream;

  String _key(int rideId, Brightness brightness) =>
      '$rideId:${brightness.name}';

  File fileFor(int rideId, {required Brightness brightness}) {
    final suffix = brightness == Brightness.dark ? '_dark' : '';
    // `_v5`: previewPixelRatio raised 2.0 -> 3.0 (see preview_projection.dart)
    // — a new directory forces existing rides to re-render at the sharper
    // resolution instead of serving the old, now visibly blurry PNG.
    return File('${baseDir.path}/ride_previews_v5/$rideId$suffix.png');
  }

  /// Sidecar flagging the cached PNG as a degraded fallback to be re-rendered.
  File staleMarkerFor(int rideId, {required Brightness brightness}) =>
      File('${fileFor(rideId, brightness: brightness).path}.stale');

  /// The final (complete, non-stale) preview file if this cache instance has
  /// already resolved it — synchronous, for jank-free list builds. Null means
  /// "unknown or still degraded": call [ensurePreview].
  File? resolvedFileFor(int rideId, {required Brightness brightness}) =>
      _resolved[_key(rideId, brightness)];

  /// Returns the cached preview file for [brightness], rendering + writing it
  /// once if missing. A stale (degraded) preview is re-rendered on each call
  /// until a complete render replaces it.
  Future<File> ensurePreview(int rideId, List<RoutePoint> points,
      {required Brightness brightness}) async {
    final key = _key(rideId, brightness);
    final resolved = _resolved[key];
    if (resolved != null) return resolved;

    final file = fileFor(rideId, brightness: brightness);
    final marker = staleMarkerFor(rideId, brightness: brightness);
    if (await file.exists() && !await marker.exists()) {
      _resolved[key] = file;
      return file;
    }
    return _enqueue(() async {
      // Re-check inside the queue slot — an earlier queued call for the same
      // ride (e.g. two cards / a rebuild) may already have rendered it.
      if (await file.exists() && !await marker.exists()) {
        _resolved[key] = file;
        return file;
      }
      final result = await render(points, brightness);
      await file.parent.create(recursive: true);
      if (result.complete) {
        await file.writeAsBytes(result.bytes, flush: true);
        final wasStale = await marker.exists();
        if (wasStale) await marker.delete();
        _resolved[key] = file;
        if (wasStale) _upgrades.add(rideId);
      } else {
        // Still degraded: keep already-written bytes (same sketch — no churn),
        // only write when there is nothing to show yet; stays marked stale.
        if (!await file.exists()) await file.writeAsBytes(result.bytes, flush: true);
        await marker.create();
      }
      return file;
    });
  }

  /// Chains [task] onto one render lane (round-robin), bounding concurrency
  /// to [maxConcurrentRenders] instead of either serializing everything or
  /// fanning out unboundedly.
  Future<File> _enqueue(Future<File> Function() task) {
    final lane = _nextLane;
    _nextLane = (_nextLane + 1) % maxConcurrentRenders;
    final run = _renderLanes[lane].then((_) => task());
    _renderLanes[lane] = run.then((_) {}, onError: (_) {});
    return run;
  }

  void dispose() => _upgrades.close();

  /// Deletes both cached variants and their stale markers (on ride
  /// edit/delete), so neither theme serves a stale preview.
  Future<void> evict(int rideId) async {
    for (final brightness in Brightness.values) {
      _resolved.remove(_key(rideId, brightness));
      final file = fileFor(rideId, brightness: brightness);
      if (await file.exists()) await file.delete();
      final marker = staleMarkerFor(rideId, brightness: brightness);
      if (await marker.exists()) await marker.delete();
    }
  }
}
