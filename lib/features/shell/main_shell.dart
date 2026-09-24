import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../history/history_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_edit_sheet.dart';
import '../settings/settings_screen.dart';
import '../../core/theme/theme_context.dart';

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

  // Notifiers instead of setState: a shell setState mid-swipe rebuilds the
  // whole PageView (all three pages) during the page animation and visibly
  // stutters. With notifiers, a page change repaints ONLY the bottom bar, and
  // the greeting re-roll ONLY the Home subtree — after the swipe has settled.
  final ValueNotifier<int> _current = ValueNotifier(0);

  // Counts each landing on Home so the greeting re-rolls per visit; the first
  // view counts as visit 1. Bumped on scroll-settle (not onPageChanged, which
  // fires mid-animation) so Home rebuilds after the swipe finishes, not during.
  final ValueNotifier<int> _homeVisits = ValueNotifier(1);
  int _lastSettledPage = 0;

  /// The mounted History tab's back handler (see
  /// [HistoryScreen.onRegisterBackHandler]).
  bool Function()? _historyBack;

  /// The shell's single back handler, so the steps run in a fixed order
  /// (issue #32): the History tab may consume it (leaving selection mode),
  /// then any tab but Home returns to Home. Only Home lets the route pop.
  void _onBack(bool didPop) {
    if (didPop) return;
    if (_current.value == 1 && (_historyBack?.call() ?? false)) return;
    _goToTab(0);
  }

  void _goToTab(int index) => _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );

  void _onPageChanged(int index) => _current.value = index;

  /// Fired when the PageView's own scroll settles (depth 0 — inner list
  /// scrolling doesn't bubble in as a page change).
  void _onPageSettled() {
    final page = _controller.page?.round() ?? 0;
    if (page == 0 && _lastSettledPage != 0) _homeVisits.value++;
    _lastSettledPage = page;
  }

  @override
  void dispose() {
    _controller.dispose();
    _current.dispose();
    _homeVisits.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final tabs = <_TabSpec>[
      _TabSpec(Icons.home, l10n.navHome),
      _TabSpec(Icons.list, l10n.navHistory),
      _TabSpec(Icons.settings, l10n.navSettings),
    ];

    return Scaffold(
      backgroundColor: colors.surface,
      body: NotificationListener<ScrollEndNotification>(
        onNotification: (n) {
          if (n.depth == 0) _onPageSettled();
          return false;
        },
        child: PageView(
          controller: _controller,
          onPageChanged: _onPageChanged,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: _homeVisits,
              builder: (_, visits, _) => HomeScreen(
                greetingKey: visits,
                onOpenRide: (rideId) {
                  ref.read(historyTargetRideProvider.notifier).state = rideId;
                  _goToTab(1);
                },
                onAvatarTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: colors.surface,
                  builder: (_) => const ProfileEditSheet(),
                ),
              ),
            ),
            HistoryScreen(onRegisterBackHandler: (h) => _historyBack = h),
            const SettingsScreen(),
          ],
        ),
      ),
      // The back scope lives with the bottom bar so a tab change rebuilds
      // only this subtree, not the PageView.
      bottomNavigationBar: ValueListenableBuilder<int>(
        valueListenable: _current,
        builder: (_, current, _) => PopScope(
          canPop: current == 0,
          onPopInvokedWithResult: (didPop, _) => _onBack(didPop),
          child: _BottomNav(
              tabs: tabs, current: current, onTap: _goToTab, colors: colors),
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec(this.icon, this.label);
  final IconData icon;
  final String label;
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
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: tint)),
        ],
      ),
    );
  }
}
