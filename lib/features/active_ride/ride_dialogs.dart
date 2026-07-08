import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../l10n/app_localizations.dart';

const _descMaxLength = 60;

/// "Stop ride?" confirmation. Ports `ConfirmStopDialog`.
class ConfirmStopDialog extends StatelessWidget {
  const ConfirmStopDialog({super.key, required this.onDismiss, required this.onConfirm});

  final VoidCallback onDismiss;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return _ConfirmScaffold(
      title: l10n.confirmStopTitle,
      body: l10n.confirmStopBody,
      dismissLabel: l10n.confirmStopKeep,
      confirmLabel: l10n.confirmStopConfirm,
      confirmBg: colors.primary,
      confirmFg: colors.onPrimary,
      onDismiss: onDismiss,
      onConfirm: onConfirm,
    );
  }
}

/// "Discard ride?" confirmation (destructive). Ports `DiscardRideConfirmDialog`.
class DiscardRideConfirmDialog extends StatelessWidget {
  const DiscardRideConfirmDialog({super.key, required this.onDismiss, required this.onConfirm});

  final VoidCallback onDismiss;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    return _ConfirmScaffold(
      title: l10n.discardRideTitle,
      body: l10n.discardRideBody,
      dismissLabel: l10n.confirmStopKeep,
      confirmLabel: l10n.discardRideConfirm,
      confirmBg: colors.deleteActionText,
      confirmFg: colors.onPrimary,
      onDismiss: onDismiss,
      onConfirm: onConfirm,
    );
  }
}

/// Shared two-button confirmation body (title + body + dismiss/confirm pills).
class _ConfirmScaffold extends StatelessWidget {
  const _ConfirmScaffold({
    required this.title,
    required this.body,
    required this.dismissLabel,
    required this.confirmLabel,
    required this.confirmBg,
    required this.confirmFg,
    required this.onDismiss,
    required this.onConfirm,
  });

  final String title;
  final String body;
  final String dismissLabel;
  final String confirmLabel;
  final Color confirmBg;
  final Color confirmFg;
  final VoidCallback onDismiss;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 8),
            Text(body,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: dismissLabel,
                    bg: colors.surfaceContainer,
                    fg: colors.onSurface,
                    onTap: onDismiss,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    label: confirmLabel,
                    bg: confirmBg,
                    fg: confirmFg,
                    onTap: onConfirm,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Post-ride summary: title + comment inputs, favorite toggle, Skip/Save and a
/// destructive Discard. Ports `PostRideSummaryDialog`. Non-dismissible.
class PostRideSummaryDialog extends StatefulWidget {
  const PostRideSummaryDialog({
    super.key,
    required this.onSkip,
    required this.onSave,
    required this.onDiscard,
  });

  final VoidCallback onSkip;
  final void Function(String? title, String? comment, bool favorite) onSave;
  final VoidCallback onDiscard;

  @override
  State<PostRideSummaryDialog> createState() => _PostRideSummaryDialogState();
}

class _PostRideSummaryDialogState extends State<PostRideSummaryDialog> {
  final _titleController = TextEditingController();
  final _commentController = TextEditingController();
  bool _favorite = false;

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
      child: Container(
        decoration: BoxDecoration(color: colors.surface, borderRadius: AppShapes.dialog),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        // Scroll INSIDE the card (same structure as EditRideDialog): when the
        // keyboard shrinks the space, the card compresses and its content
        // scrolls — no overflow stripe, dialog stays fully usable.
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.summaryTitle,
                style: text.titleLarge?.copyWith(color: colors.onSurface)),
            const SizedBox(height: 6),
            Text(l10n.summarySubtitle,
                style: text.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            const SizedBox(height: 20),
            _SheetInputField(
              label: l10n.summaryTitleLabel,
              controller: _titleController,
              singleLine: true,
              maxLength: _descMaxLength,
            ),
            const SizedBox(height: 12),
            _SheetInputField(
              label: l10n.summaryCommentLabel,
              controller: _commentController,
              singleLine: false,
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(l10n.summaryMarkFavorite,
                      style: text.bodyMedium?.copyWith(color: colors.onSurface)),
                ),
                IconButton(
                  onPressed: () => setState(() => _favorite = !_favorite),
                  icon: Icon(
                    _favorite ? Icons.favorite : Icons.favorite_border,
                    color: _favorite ? colors.primary : colors.onSurfaceVariant,
                    size: 28,
                  ),
                  tooltip: _favorite ? l10n.a11yFavoriteRemove : l10n.a11yFavoriteAdd,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    label: l10n.actionSkip,
                    bg: colors.surfaceContainer,
                    fg: colors.onSurfaceVariant,
                    onTap: widget.onSkip,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    label: l10n.actionSave,
                    bg: colors.primary,
                    fg: colors.onPrimary,
                    onTap: () => widget.onSave(
                      _titleController.text.isEmpty ? null : _titleController.text,
                      _commentController.text.isEmpty ? null : _commentController.text,
                      _favorite,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Centered under the Skip/Save row (the column is start-aligned,
            // which left the destructive action stuck to the left edge).
            Center(
              child: TextButton(
                onPressed: widget.onDiscard,
                child: Text(l10n.summaryDiscard,
                    style: text.labelLarge
                        ?.copyWith(color: colors.deleteActionText)),
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            style: Theme.of(context).textTheme.labelLarge),
      ),
    );
  }
}

class _SheetInputField extends StatelessWidget {
  const _SheetInputField({
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
      decoration: BoxDecoration(color: colors.surfaceContainer, borderRadius: AppShapes.card),
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
