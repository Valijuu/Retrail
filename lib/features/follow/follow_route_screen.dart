// lib/features/follow/follow_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Follow-only mode (Spec 17 §E2). Filled in by the follow-screen task.
class FollowRouteScreen extends ConsumerStatefulWidget {
  const FollowRouteScreen({super.key});

  @override
  ConsumerState<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends ConsumerState<FollowRouteScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
