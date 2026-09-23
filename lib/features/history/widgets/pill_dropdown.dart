import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// A filled "pill"-styled dropdown: `surfaceContainer` background, rounded
/// corners, a `primary`-colored chevron, no underline. Used for the history
/// filter sheet's Year/Von/Bis pickers so all three share one look instead of
/// each re-styling a bare dropdown.
///
/// Built on [MenuAnchor]/[MenuItemButton] rather than [DropdownButton]:
/// `DropdownButton` positions its menu aligned to the *selected item*
/// (native Android-spinner behavior), which opens upward when the selected
/// value sits late in [items] — inconsistent and confusing for a picker like
/// the Von/Bis month range. `MenuAnchor` positions its menu relative to the
/// *anchor widget* instead, so it opens in the same place regardless of
/// which value is selected.
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

    return LayoutBuilder(builder: (context, constraints) {
      return MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(colors.surfaceContainer),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(_radius))),
          // Match the menu's width to the anchor's — MenuAnchor otherwise
          // sizes menuChildren to their own intrinsic content width, which
          // would make the Von/Bis dropdowns (narrower, in an Expanded Row)
          // pop a menu wider than the pill button itself.
          minimumSize: WidgetStatePropertyAll(Size(constraints.maxWidth, 0)),
        ),
        builder: (context, controller, child) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: BorderRadius.circular(_radius),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(_radius),
            onTap: () => controller.isOpen ? controller.close() : controller.open(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(itemLabel(value), style: itemStyle)),
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: colors.primary),
              ],
            ),
          ),
        ),
        menuChildren: [
          for (final item in items)
            MenuItemButton(
              onPressed: () => onChanged(item),
              child: item == value
                  ? Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
      );
    });
  }
}
