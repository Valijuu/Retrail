import 'package:flutter/material.dart';

import '../theme/theme_context.dart';

/// Share of the screen a sheet may cover at most, so a strip stays free above
/// it even with the keyboard up — the sheet's content scrolls instead.
const sheetMaxHeightFactor = 0.9;

/// Dragged down to this share of the screen, a [showAppScrollableSheet]
/// closes.
const _sheetCloseFactor = 0.25;

/// M3's default sheet width cap, kept because [showAppBottomSheet] passes its
/// own constraints (which replace the theme default).
const _sheetMaxWidth = 640.0;

/// Compact modal bottom sheet in the app's style (short, non-scrolling
/// content such as a picker): drag handle, safe-area aware, height capped at
/// [sheetMaxHeightFactor].
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      constraints: BoxConstraints(
        maxWidth: _sheetMaxWidth,
        maxHeight: MediaQuery.sizeOf(context).height * sheetMaxHeightFactor,
      ),
      builder: builder,
    );

/// Sheet for taller, scrolling content (forms, filters) that drags like one
/// surface: the content scrolls, and dragging down past its top shrinks the
/// sheet and closes it — on iOS the bouncing scroll view otherwise swallowed
/// the drag. Opens at [sheetMaxHeightFactor], so the top stays free on small
/// screens (iPhone 8) and with the keyboard up. [builder] must hand the
/// controller to the content's scroll view; content with text input should pad
/// that scroll view by the keyboard inset from outside, so the viewport ends
/// above the keyboard.
Future<T?> showAppScrollableSheet<T>({
  required BuildContext context,
  required ScrollableWidgetBuilder builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: sheetMaxHeightFactor,
        maxChildSize: sheetMaxHeightFactor,
        minChildSize: _sheetCloseFactor,
        builder: builder,
      ),
    );
