import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../l10n/app_localizations.dart';

/// Shown instead of the app when the database cannot be opened or migrated at
/// launch (#139). It runs before the app's providers and router exist, so it
/// is its own small [MaterialApp]. Nothing is deleted or reset here: the rides
/// stay on the device and the rider can try again.
class StartupFailureApp extends StatelessWidget {
  const StartupFailureApp({
    super.key,
    required this.retry,
    required this.onRecovered,
  });

  /// Tries the failed start again; true when it worked.
  final Future<bool> Function() retry;

  /// Called once after a successful [retry], to start the real app.
  final VoidCallback onRecovered;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
    debugShowCheckedModeBanner: false,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: _StartupFailureBody(retry: retry, onRecovered: onRecovered),
  );
}

class _StartupFailureBody extends StatefulWidget {
  const _StartupFailureBody({required this.retry, required this.onRecovered});

  final Future<bool> Function() retry;
  final VoidCallback onRecovered;

  @override
  State<_StartupFailureBody> createState() => _StartupFailureBodyState();
}

class _StartupFailureBodyState extends State<_StartupFailureBody> {
  bool _busy = false;

  Future<void> _retry() async {
    setState(() => _busy = true);
    final worked = await widget.retry();
    if (!mounted) return;
    if (worked) {
      widget.onRecovered();
    } else {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.startupFailureTitle,
                  style: text.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.startupFailureBody,
                  style: text.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _retry,
                  child: Text(l10n.startupFailureRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
