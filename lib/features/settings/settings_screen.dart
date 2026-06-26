import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_providers.dart';
import '../onboarding/activity_tile.dart';
import '../onboarding/activity_type_ui.dart';
import '../shell/theme_mode_provider.dart';
import 'settings_providers.dart';

/// Settings tab: default activity, language and appearance. Reads the live
/// preference providers; a [SettingsController] writes back. Ports `SettingsPage`.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(settingsControllerProvider);

    final activity =
        ref.watch(lastActivityTypeProvider).asData?.value ?? ActivityType.defaultType;
    final theme = ref.watch(themeModeProvider).asData?.value ?? ThemeMode.system;
    final language =
        ref.watch(appLanguageProvider).asData?.value ?? AppLanguage.system;

    return Semantics(
      label: l10n.a11ySettingsScreen,
      child: ColoredBox(
        color: colors.surface,
        child: SafeArea(
          child: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Text(l10n.navSettings,
                    style: text.titleLarge?.copyWith(color: colors.onSurface)),
              ),

              // Default activity.
              _SectionHeader(
                  title: l10n.settingsSectionActivity,
                  subtitle: l10n.settingsActivitySubtitle),
              const SizedBox(height: 8),
              _ActivitySummaryRow(
                activity: activity,
                onTap: () => _pickActivity(context, ref, activity),
              ),
              const SizedBox(height: 16),

              // Language.
              _SectionHeader(
                  title: l10n.settingsSectionLanguage,
                  subtitle: l10n.settingsLanguageSubtitle),
              const SizedBox(height: 8),
              _OptionRow(
                  label: l10n.settingsLanguageSystem,
                  selected: language == AppLanguage.system,
                  onTap: () => controller.setLanguage(AppLanguage.system)),
              _OptionRow(
                  label: l10n.settingsLanguageGerman,
                  selected: language == AppLanguage.german,
                  onTap: () => controller.setLanguage(AppLanguage.german)),
              _OptionRow(
                  label: l10n.settingsLanguageEnglish,
                  selected: language == AppLanguage.english,
                  onTap: () => controller.setLanguage(AppLanguage.english)),
              const SizedBox(height: 16),

              // Appearance / theme.
              _SectionHeader(
                  title: l10n.settingsSectionTheme,
                  subtitle: l10n.settingsThemeSubtitle),
              const SizedBox(height: 8),
              _OptionRow(
                  label: l10n.settingsThemeSystem,
                  selected: theme == ThemeMode.system,
                  onTap: () => controller.setTheme(ThemeMode.system)),
              _OptionRow(
                  label: l10n.settingsThemeLight,
                  selected: theme == ThemeMode.light,
                  onTap: () => controller.setTheme(ThemeMode.light)),
              _OptionRow(
                  label: l10n.settingsThemeDark,
                  selected: theme == ThemeMode.dark,
                  onTap: () => controller.setTheme(ThemeMode.dark)),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickActivity(
      BuildContext context, WidgetRef ref, ActivityType current) async {
    final selected = await showDialog<ActivityType>(
      context: context,
      builder: (_) => _ActivityPickerDialog(current: current),
    );
    if (selected != null) {
      await ref.read(settingsControllerProvider).setDefaultActivity(selected);
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
          child: Text(title,
              style: text.labelSmall?.copyWith(color: colors.subtleText)),
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(subtitle,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _ActivitySummaryRow extends StatelessWidget {
  const _ActivitySummaryRow({required this.activity, required this.onTap});
  final ActivityType activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: colors.surfaceContainer,
        borderRadius: AppShapes.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShapes.card,
          child: Semantics(
            button: true,
            label: l10n.a11yChangeActivity,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(activity.icon, size: 24, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(activity.label(l10n),
                        style:
                            text.bodyLarge?.copyWith(color: colors.onSurface)),
                  ),
                  Icon(Icons.keyboard_arrow_right,
                      size: 24, color: colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected ? colors.surfaceContainer : colors.surface,
        borderRadius: AppShapes.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppShapes.card,
          child: MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? colors.primary : colors.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  Text(label,
                      style: text.bodyLarge?.copyWith(color: colors.onSurface)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityPickerDialog extends StatefulWidget {
  const _ActivityPickerDialog({required this.current});
  final ActivityType current;

  @override
  State<_ActivityPickerDialog> createState() => _ActivityPickerDialogState();
}

class _ActivityPickerDialogState extends State<_ActivityPickerDialog> {
  late ActivityType _selected = widget.current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration:
            BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.settingsActivityDialogTitle,
                style: text.titleLarge?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.6,
              children: [
                for (final type in ActivityType.values)
                  ActivityTile(
                    type: type,
                    selected: _selected == type,
                    onTap: () {
                      setState(() => _selected = type);
                      Navigator.of(context).pop(type);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
