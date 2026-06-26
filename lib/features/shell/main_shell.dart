import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';

/// When a ride is tapped on Home, its id is parked here; the shell switches to
/// the History tab and the History screen scrolls to it, then clears this.
final historyTargetRideProvider = StateProvider<int?>((ref) => null);

/// Top-level swipeable tab shell: a [PageView] (Home / History / Settings) plus
/// a Material 3 bottom bar driven by one source-of-truth tab list. Placeholder
/// tab bodies are replaced by the real screens in their phases.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final PageController _controller = PageController();
  int _current = 0;
  // Counts each landing on Home so the greeting re-rolls per visit; the first
  // view counts as visit 1.
  int _homeVisits = 1;

  void _goToTab(int index) => _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  void _onPageChanged(int index) {
    setState(() {
      _current = index;
      if (index == 0) _homeVisits++;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final tabs = <_TabSpec>[
      _TabSpec(Icons.home, l10n.navHome),
      _TabSpec(Icons.list, l10n.navHistory),
      _TabSpec(Icons.settings, l10n.navSettings),
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      body: PageView(
        controller: _controller,
        onPageChanged: _onPageChanged,
        children: [
          HomeScreen(
            greetingKey: _homeVisits,
            onOpenRide: (rideId) {
              ref.read(historyTargetRideProvider.notifier).state = rideId;
              _goToTab(1);
            },
          ),
          const HistoryScreen(),
          const _PlaceholderTab(label: 'settings'),
        ],
      ),
      bottomNavigationBar:
          _BottomNav(tabs: tabs, current: _current, onTap: _goToTab, colors: colors),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Center(child: Text(label));
}

/// Custom bottom bar matching the original: a selected icon sits in a
/// `primaryContainer` pill with `primary` icon+label; unselected uses
/// `subtleText`. A 0.5dp divider tops the bar.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.tabs,
    required this.current,
    required this.onTap,
    required this.colors,
  });

  final List<_TabSpec> tabs;
  final int current;
  final ValueChanged<int> onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(height: 0.5, thickness: 0.5, color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
        ColoredBox(
          color: colors.surface,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < tabs.length; i++)
                    Expanded(child: _NavItem(spec: tabs[i], selected: i == current, onTap: () => onTap(i), colors: colors)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.colors,
  });

  final _TabSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? colors.primary : colors.subtleText;
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? colors.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(50),
            ),
            child: Icon(spec.icon, color: tint, semanticLabel: spec.label),
          ),
          const SizedBox(height: 2),
          Text(spec.label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tint)),
        ],
      ),
    );
  }
}
