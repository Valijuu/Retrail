import 'package:flutter/material.dart';

/// A dialog's two actions as full-width buttons stacked vertically, primary
/// (filled) on top. Side by side each button only gets half the width, and
/// long German labels ("Einstellungen öffnen", "Trotzdem starten") then had
/// to be shrunk or wrapped — stacked, both labels render at full size.
class StackedDialogActions extends StatelessWidget {
  const StackedDialogActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.secondaryLabel,
    required this.onSecondary,
  });

  final String primaryLabel;
  final VoidCallback onPrimary;
  final String secondaryLabel;
  final VoidCallback onSecondary;

  static const double _buttonHeight = 44;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _buttonHeight,
          child: FilledButton(
              onPressed: onPrimary, child: _label(primaryLabel)),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _buttonHeight,
          child: TextButton(
              onPressed: onSecondary, child: _label(secondaryLabel)),
        ),
      ],
    );
  }

  Widget _label(String text) =>
      Text(text, maxLines: 1, overflow: TextOverflow.ellipsis);
}
