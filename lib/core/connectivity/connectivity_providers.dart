import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'connectivity_observer.dart';

final connectivityObserverProvider =
    Provider<ConnectivityObserver>((ref) => ConnectivityObserver());

/// Real online/offline state (VPN-aware). Unknown (loading) is treated as online
/// by consumers so the start flow isn't blocked spuriously.
final isOnlineProvider =
    StreamProvider<bool>((ref) => ref.watch(connectivityObserverProvider).isOnline);
