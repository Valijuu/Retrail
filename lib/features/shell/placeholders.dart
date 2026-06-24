import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'startup_provider.dart';

/// Simple placeholder for routes whose real screens land in later phases.
class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}

/// Active-ride placeholder. Clears the deep-link flag once shown so the router
/// settles on `/ride` instead of looping. The real screen is Spec 12.
class RidePlaceholder extends ConsumerStatefulWidget {
  const RidePlaceholder({super.key});

  @override
  ConsumerState<RidePlaceholder> createState() => _RidePlaceholderState();
}

class _RidePlaceholderState extends ConsumerState<RidePlaceholder> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pendingRideDeepLinkProvider.notifier).state = false;
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('ride')));
}
