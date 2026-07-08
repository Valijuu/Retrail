# Design tokens — Retrail

> Keep this file in sync with the actual code — update it as part of the same change whenever something documented here changes.

## Colors — light

```dart
// Brand / primary
Primary            = 0xFFB45309   OnPrimary          = 0xFFFFF8F5
PrimaryContainer   = 0xFFFFEDD5   OnPrimaryContainer = 0xFF431407
// Surfaces
Surface            = 0xFFFFF8F5   OnSurface          = 0xFF1C1B1F
SurfaceContainer   = 0xFFF3EDE8   OnSurfaceVariant   = 0xFF857470
SubtleText         = 0xFFA89080   HintText           = 0xFFC8B8A8
// Chips / actions
ChipSecondary      = 0xFFFED7AA   ChipSecondaryText  = 0xFF7C2D12
EditActionBg       = 0xFFFFEDD5   EditActionText     = 0xFF92400E
DeleteActionBg     = 0xFFFEE2E2   DeleteActionText   = 0xFFB91C1C
LiveIndicator      = 0xFFFFBB70
// Map
MapTerrain         = 0xFFDDE8DD   MapTerrainGrid     = 0xFFCCE0CC
RouteLineBlue      = 0xFF2563EB   RouteLineHalo      = 0xFFFFFFFF
MarkerStartGreen   = 0xFF16A34A   MarkerEndRed       = 0xFFDC2626
```

## Colors — dark

```dart
DarkSurface          = 0xFF1C1B1F   DarkSurfaceContainer = 0xFF2B2118
DarkPrimary          = 0xFFF59E42   DarkOnPrimary        = 0xFF431407
DarkPrimaryContainer = 0xFF7C3A0A   DarkOnPrimaryContainer = 0xFFFFEDD5
DarkOnSurface        = 0xFFF3EDE8   DarkOnSurfaceVariant = 0xFFB5A8A0
DarkSubtleText       = 0xFF8A7C70   DarkHintText         = 0xFF6E6258
DarkChipSecondary    = 0xFF7C3A0A   DarkChipSecondaryText= 0xFFFED7AA
DarkEditActionBg     = 0xFF3A2A12   DarkEditActionText   = 0xFFFCD9A6
DarkDeleteActionBg   = 0xFF3A1A1A   DarkDeleteActionText = 0xFFFCA5A5
DarkLiveIndicator    = 0xFFFFBB70
DarkMapTerrain       = 0xFF20292A   DarkMapTerrainGrid   = 0xFF2C3A3A
// Route line colors are identical across themes.
```

Tokens live in an `AppColors` `ThemeExtension`; access via `Theme.of(context).extension<AppColors>()!`. Dynamic color is OFF — Retrail uses brand colors on both themes. Theme mode (system/light/dark) is user-selectable and persisted.

## Shapes

```
RoundedRectangleBorder radius 14  // hero card, route maps
                       radius 12  // recent-ride cards, stat cells
                       radius 50  // FAB / pill buttons
                       radius 10  // GPS status line, dialog inputs
                       radius 8   // small icon containers
```

## Typography (Material 3 mapping)

| Element | M3 style |
|---|---|
| Page title ("Retrail") | `titleLarge` |
| Greeting | `labelSmall`, dimmed |
| Hero number (24.3 km) | `displaySmall` |
| Hero unit | `titleSmall`, dimmed |
| Section labels ("Recent rides") | `labelSmall`, uppercase, dimmed |
| Card title | `bodyMedium`, medium weight |
| Card metadata | `labelSmall`, dimmed |
| Primary button | `labelLarge` |
| Stat value | `titleMedium` |
| Stat label | `labelSmall`, dimmed |
