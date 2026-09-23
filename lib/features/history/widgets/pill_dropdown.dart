import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A filled "pill"-styled dropdown: `surfaceContainer` background, rounded
/// corners, a `primary`-colored chevron, no underline. Used for the history
/// filter sheet's Year/Von/Bis pickers so all three share one look instead of
/// each re-styling a bare [DropdownButton].
class PillDropdown<T> extends StatelessWidget {
  const PillDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final T value;
  final List<T> items;
  final String Function(T item) itemLabel;
  final ValueChanged<T> onChanged;

  static const _radius = 10.0;
  static const _highlightRadius = 8.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // The selected-item highlight intentionally uses the M3 ColorScheme's
    // secondaryContainer/onSecondaryContainer, not the AppColors token set —
    // it matches the color Flutter renders for a selected FilterChip in this
    // sheet (none of them set an explicit selectedColor), keeping the
    // "selected" look consistent between chips and dropdown menus.
    final colorScheme = Theme.of(context).colorScheme;
    final itemStyle =
        Theme.of(context).textTheme.bodyLarge?.copyWith(color: colors.onSurface);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(_radius),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          borderRadius: BorderRadius.circular(_radius),
          dropdownColor: colors.surfaceContainer,
          icon: Icon(Icons.keyboard_arrow_down, color: colors.primary),
          // The closed button always shows plain text, regardless of
          // selection — only the open menu's matching item gets the
          // highlight container below.
          selectedItemBuilder: (context) => [
            for (final item in items)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(itemLabel(item), style: itemStyle),
              ),
          ],
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item,
                child: item == value
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(_highlightRadius),
                        ),
                        child: Text(itemLabel(item),
                            style: itemStyle?.copyWith(
                                color: colorScheme.onSecondaryContainer)),
                      )
                    : Text(itemLabel(item), style: itemStyle),
              ),
          ],
          onChanged: (v) => onChanged(v as T),
        ),
      ),
    );
  }
}
