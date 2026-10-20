import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/app_shapes.dart';

/// A radio-style choice row (language, theme).
class SettingsOptionRow extends StatelessWidget {
  const SettingsOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
                      color: selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                  Text(
                    label,
                    style: text.bodyLarge?.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// An on/off row with a description (countdown cue, #81).
class SettingsSwitchRow extends StatelessWidget {
  const SettingsSwitchRow({
    super.key,
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: colors.surface,
        borderRadius: AppShapes.card,
        child: InkWell(
          onTap: () => onChanged(!value),
          borderRadius: AppShapes.card,
          child: MergeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: text.bodyLarge?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          description,
                          style: text.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(value: value, onChanged: onChanged),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
