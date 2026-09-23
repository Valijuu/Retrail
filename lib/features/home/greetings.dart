import '../../l10n/app_localizations.dart';

/// How many skater greetings there are — Home rolls a random index below this
/// per visit. Kept next to [skaterGreetings] so the two can't drift apart.
const int skaterGreetingCount = 8;

/// The skater greeting templates (each contains a `%s` token where the name
/// goes — split in code so the name can be styled).
List<String> skaterGreetings(AppLocalizations l10n) => [
      l10n.skaterGreeting1,
      l10n.skaterGreeting2,
      l10n.skaterGreeting3,
      l10n.skaterGreeting4,
      l10n.skaterGreeting5,
      l10n.skaterGreeting6,
      l10n.skaterGreeting7,
      l10n.skaterGreeting8,
    ];
