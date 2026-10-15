import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar icons that follow the app's theme (not the system's: the user
/// can pick a theme in the settings). Wraps the whole app; without it a dark
/// screen's light icons stayed after leaving it (#66).
class ThemeStatusBar extends StatelessWidget {
  const ThemeStatusBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? DarkChromeStatusBar.style : _light,
      child: child,
    );
  }

  static const _light = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS: light bar → dark content
  );
}

/// Light status bar icons while a screen with the original's fixed dark
/// chrome is shown (ride, follow, countdown) — in the light theme they stayed
/// dark on the dark header (#66). Only the status bar is set; the navigation
/// bar keeps whatever the theme gives it.
class DarkChromeStatusBar extends StatelessWidget {
  const DarkChromeStatusBar({super.key, required this.child});

  static const style = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS: dark bar → light content
  );

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AnnotatedRegion<SystemUiOverlayStyle>(value: style, child: child);
}
