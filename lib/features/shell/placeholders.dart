import 'package:flutter/material.dart';

/// Simple placeholder for routes whose real screens land in later phases.
class RoutePlaceholder extends StatelessWidget {
  const RoutePlaceholder(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label)));
}
