import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/activity_type_ui.dart';
import '../../core/widgets/pill_button.dart';
import '../../core/widgets/sheet_input_field.dart';

const _descMaxLength = 60;

/// Edit a saved ride's title, activity type and comment. Ports `EditRideDialog`.
class EditRideDialog extends StatefulWidget {
  const EditRideDialog({
    super.key,
    this.initialDescription,
    this.initialComment,
    this.initialType,
    required this.onDismiss,
    required this.onSave,
  });

  final String? initialDescription;
  final String? initialComment;
  final ActivityType? initialType;
  final VoidCallback onDismiss;
  final void Function(String? description, String? comment, ActivityType? type)
      onSave;

  @override
  State<EditRideDialog> createState() => _EditRideDialogState();
}

class _EditRideDialogState extends State<EditRideDialog> {
  late final _titleController =
      TextEditingController(text: widget.initialDescription ?? '');
  late final _commentController =
      TextEditingController(text: widget.initialComment ?? '');
  late ActivityType? _type = widget.initialType;

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      // Wider than the M3 default (40dp side margins) so the activity chips
      // and inputs get room.
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        decoration:
            BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(l10n.editRideTitle,
                  style: text.titleLarge?.copyWith(color: colors.onSurface)),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(l10n.editRideSubtitle,
                  textAlign: TextAlign.center,
                  style:
                      text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            ),
            const SizedBox(height: 20),
            SheetInputField(
              label: l10n.summaryTitleLabel,
              controller: _titleController,
              singleLine: true,
              maxLength: _descMaxLength,
            ),
            const SizedBox(height: 12),
            Text(l10n.editRideActivityLabel,
                style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in ActivityType.values)
                  FilterChip(
                    selected: _type == option,
                    onSelected: (_) => setState(
                        () => _type = _type == option ? null : option),
                    avatar: option.glyph(size: 18),
                    // M3 draws the checkmark on top of the avatar glyph —
                    // the fill already marks the selection (issue #29).
                    showCheckmark: false,
                    label: Text(option.label(l10n)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SheetInputField(
              label: l10n.summaryCommentLabel,
              controller: _commentController,
              singleLine: false,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: PillButton(
                    label: l10n.actionCancel,
                    bg: colors.surfaceContainer,
                    fg: colors.onSurface,
                    onTap: widget.onDismiss,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PillButton(
                    label: l10n.actionSave,
                    bg: colors.primary,
                    fg: colors.onPrimary,
                    onTap: () => widget.onSave(
                      _titleController.text.isEmpty ? null : _titleController.text,
                      _commentController.text.isEmpty
                          ? null
                          : _commentController.text,
                      _type,
                    ),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
