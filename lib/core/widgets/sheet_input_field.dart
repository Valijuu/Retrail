import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shapes.dart';

/// Labelled text input on a rounded surface card — the title/comment fields of
/// the post-ride summary and the edit-ride dialog. [singleLine] pins it to one
/// line; otherwise it grows from [minLines] to [maxLines].
class SheetInputField extends StatelessWidget {
  const SheetInputField({
    super.key,
    required this.label,
    required this.controller,
    required this.singleLine,
    this.minLines = 1,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final TextEditingController controller;
  final bool singleLine;
  final int minLines;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: AppShapes.card,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: colors.primary)),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            minLines: singleLine ? 1 : minLines,
            maxLines: singleLine ? 1 : maxLines,
            maxLength: maxLength,
            cursorColor: colors.primary,
            style: text.bodyLarge?.copyWith(color: colors.onSurface),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}
