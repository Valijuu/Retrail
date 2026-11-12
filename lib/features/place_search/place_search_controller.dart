import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_providers.dart' show localeProvider;
import 'photon_client.dart';

/// How long typing pauses before Photon is asked (#106).
const Duration placeSearchDebounce = Duration(milliseconds: 400);

/// Shorter texts are not sent.
const int placeSearchMinChars = 3;

enum PlaceSearchStatus {
  /// Closed, or open with too little text.
  idle,
  loading,
  results,
  empty,

  /// Offline, timed out or an error answer.
  unavailable,
}

class PlaceSearchState {
  const PlaceSearchState({
    this.open = false,
    this.query = '',
    this.status = PlaceSearchStatus.idle,
    this.suggestions = const [],
  });

  final bool open;
  final String query;
  final PlaceSearchStatus status;
  final List<PlaceSuggestion> suggestions;

  PlaceSearchState copyWith({
    bool? open,
    String? query,
    PlaceSearchStatus? status,
    List<PlaceSuggestion>? suggestions,
  }) => PlaceSearchState(
    open: open ?? this.open,
    query: query ?? this.query,
    status: status ?? this.status,
    suggestions: suggestions ?? this.suggestions,
  );
}

final photonClientProvider = Provider<PhotonClient>((ref) {
  final client = PhotonClient();
  ref.onDispose(client.close);
  return client;
});

/// The debounce, as a provider so tests can shorten it.
final placeSearchDebounceProvider = Provider<Duration>(
  (_) => placeSearchDebounce,
);

/// `de` or `en` for Photon's `lang`: the app language, or the device's when
/// the app follows the system.
final placeSearchLangProvider = Provider<String>((ref) {
  final locale =
      ref.watch(localeProvider) ?? PlatformDispatcher.instance.locale;
  return locale.languageCode == 'de' ? 'de' : 'en';
});

/// The place search over the map (#106): opens and closes the field, asks
/// Photon after a pause, keeps only the newest answer. Nothing is stored.
class PlaceSearchController extends Notifier<PlaceSearchState> {
  Timer? _debounce;
  int _seq = 0;
  String _lastSent = '';

  @override
  PlaceSearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const PlaceSearchState();
  }

  void open() => state = const PlaceSearchState(open: true);

  void close() {
    _debounce?.cancel();
    _seq++;
    _lastSent = '';
    state = const PlaceSearchState();
  }

  void setQuery(String text) {
    _debounce?.cancel();
    final trimmed = text.trim();
    if (trimmed.length < placeSearchMinChars) {
      // Too short: nothing goes out, no failure hint.
      _seq++;
      _lastSent = '';
      state = state.copyWith(
        query: text,
        status: PlaceSearchStatus.idle,
        suggestions: const [],
      );
      return;
    }
    state = state.copyWith(query: text);
    if (trimmed == _lastSent) return;
    _debounce = Timer(ref.read(placeSearchDebounceProvider), () {
      _send(trimmed);
    });
  }

  Future<void> _send(String text) async {
    final seq = ++_seq;
    _lastSent = text;
    state = state.copyWith(status: PlaceSearchStatus.loading);
    try {
      final places = await ref
          .read(photonClientProvider)
          .search(text, lang: ref.read(placeSearchLangProvider));
      if (seq != _seq || !ref.mounted) return;
      state = state.copyWith(
        status: places.isEmpty
            ? PlaceSearchStatus.empty
            : PlaceSearchStatus.results,
        suggestions: places,
      );
    } on PlaceSearchUnavailable {
      if (seq != _seq || !ref.mounted) return;
      _lastSent = '';
      state = state.copyWith(
        status: PlaceSearchStatus.unavailable,
        suggestions: const [],
      );
    }
  }
}

final placeSearchProvider =
    NotifierProvider<PlaceSearchController, PlaceSearchState>(
      PlaceSearchController.new,
    );
