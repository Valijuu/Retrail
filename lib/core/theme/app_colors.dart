import 'package:flutter/material.dart';

/// Retrail's semantic color tokens, carried over verbatim from the original
/// Android app's `Color.kt`. Access via `Theme.of(context).extension<AppColors>()!`.
///
/// Dynamic color is intentionally OFF — Retrail uses its brand palette on both
/// light and dark themes. Route line colors are identical across themes.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.surface,
    required this.onSurface,
    required this.surfaceContainer,
    required this.onSurfaceVariant,
    required this.subtleText,
    required this.hintText,
    required this.chipSecondary,
    required this.chipSecondaryText,
    required this.editActionBg,
    required this.editActionText,
    required this.deleteActionBg,
    required this.deleteActionText,
    required this.liveIndicator,
    required this.mapTerrain,
    required this.mapTerrainGrid,
    required this.routeLineBlue,
    required this.routeLineHalo,
    required this.markerStartGreen,
    required this.markerEndRed,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color surface;
  final Color onSurface;
  final Color surfaceContainer;
  final Color onSurfaceVariant;
  final Color subtleText;
  final Color hintText;
  final Color chipSecondary;
  final Color chipSecondaryText;
  final Color editActionBg;
  final Color editActionText;
  final Color deleteActionBg;
  final Color deleteActionText;
  final Color liveIndicator;
  final Color mapTerrain;
  final Color mapTerrainGrid;
  final Color routeLineBlue;
  final Color routeLineHalo;
  final Color markerStartGreen;
  final Color markerEndRed;

  static const AppColors light = AppColors(
    primary: Color(0xFFB45309),
    onPrimary: Color(0xFFFFF8F5),
    primaryContainer: Color(0xFFFFEDD5),
    onPrimaryContainer: Color(0xFF431407),
    surface: Color(0xFFFFF8F5),
    onSurface: Color(0xFF1C1B1F),
    surfaceContainer: Color(0xFFF3EDE8),
    onSurfaceVariant: Color(0xFF857470),
    subtleText: Color(0xFFA89080),
    hintText: Color(0xFFC8B8A8),
    chipSecondary: Color(0xFFFED7AA),
    chipSecondaryText: Color(0xFF7C2D12),
    editActionBg: Color(0xFFFFEDD5),
    editActionText: Color(0xFF92400E),
    deleteActionBg: Color(0xFFFEE2E2),
    deleteActionText: Color(0xFFB91C1C),
    liveIndicator: Color(0xFFFFBB70),
    mapTerrain: Color(0xFFDDE8DD),
    mapTerrainGrid: Color(0xFFCCE0CC),
    routeLineBlue: Color(0xFF2563EB),
    routeLineHalo: Color(0xFFFFFFFF),
    markerStartGreen: Color(0xFF16A34A),
    markerEndRed: Color(0xFFDC2626),
  );

  static const AppColors dark = AppColors(
    primary: Color(0xFFF59E42),
    onPrimary: Color(0xFF431407),
    primaryContainer: Color(0xFF7C3A0A),
    onPrimaryContainer: Color(0xFFFFEDD5),
    surface: Color(0xFF1C1B1F),
    onSurface: Color(0xFFF3EDE8),
    surfaceContainer: Color(0xFF2B2118),
    onSurfaceVariant: Color(0xFFB5A8A0),
    subtleText: Color(0xFF8A7C70),
    hintText: Color(0xFF6E6258),
    chipSecondary: Color(0xFF7C3A0A),
    chipSecondaryText: Color(0xFFFED7AA),
    editActionBg: Color(0xFF3A2A12),
    editActionText: Color(0xFFFCD9A6),
    deleteActionBg: Color(0xFF3A1A1A),
    deleteActionText: Color(0xFFFCA5A5),
    liveIndicator: Color(0xFFFFBB70),
    mapTerrain: Color(0xFF20292A),
    mapTerrainGrid: Color(0xFF2C3A3A),
    routeLineBlue: Color(0xFF2563EB),
    routeLineHalo: Color(0xFFFFFFFF),
    markerStartGreen: Color(0xFF16A34A),
    markerEndRed: Color(0xFFDC2626),
  );

  @override
  AppColors copyWith({
    Color? primary,
    Color? onPrimary,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? surface,
    Color? onSurface,
    Color? surfaceContainer,
    Color? onSurfaceVariant,
    Color? subtleText,
    Color? hintText,
    Color? chipSecondary,
    Color? chipSecondaryText,
    Color? editActionBg,
    Color? editActionText,
    Color? deleteActionBg,
    Color? deleteActionText,
    Color? liveIndicator,
    Color? mapTerrain,
    Color? mapTerrainGrid,
    Color? routeLineBlue,
    Color? routeLineHalo,
    Color? markerStartGreen,
    Color? markerEndRed,
  }) {
    return AppColors(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceContainer: surfaceContainer ?? this.surfaceContainer,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      subtleText: subtleText ?? this.subtleText,
      hintText: hintText ?? this.hintText,
      chipSecondary: chipSecondary ?? this.chipSecondary,
      chipSecondaryText: chipSecondaryText ?? this.chipSecondaryText,
      editActionBg: editActionBg ?? this.editActionBg,
      editActionText: editActionText ?? this.editActionText,
      deleteActionBg: deleteActionBg ?? this.deleteActionBg,
      deleteActionText: deleteActionText ?? this.deleteActionText,
      liveIndicator: liveIndicator ?? this.liveIndicator,
      mapTerrain: mapTerrain ?? this.mapTerrain,
      mapTerrainGrid: mapTerrainGrid ?? this.mapTerrainGrid,
      routeLineBlue: routeLineBlue ?? this.routeLineBlue,
      routeLineHalo: routeLineHalo ?? this.routeLineHalo,
      markerStartGreen: markerStartGreen ?? this.markerStartGreen,
      markerEndRed: markerEndRed ?? this.markerEndRed,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      primary: Color.lerp(primary, other.primary, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      primaryContainer: Color.lerp(primaryContainer, other.primaryContainer, t)!,
      onPrimaryContainer:
          Color.lerp(onPrimaryContainer, other.onPrimaryContainer, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      onSurface: Color.lerp(onSurface, other.onSurface, t)!,
      surfaceContainer: Color.lerp(surfaceContainer, other.surfaceContainer, t)!,
      onSurfaceVariant:
          Color.lerp(onSurfaceVariant, other.onSurfaceVariant, t)!,
      subtleText: Color.lerp(subtleText, other.subtleText, t)!,
      hintText: Color.lerp(hintText, other.hintText, t)!,
      chipSecondary: Color.lerp(chipSecondary, other.chipSecondary, t)!,
      chipSecondaryText:
          Color.lerp(chipSecondaryText, other.chipSecondaryText, t)!,
      editActionBg: Color.lerp(editActionBg, other.editActionBg, t)!,
      editActionText: Color.lerp(editActionText, other.editActionText, t)!,
      deleteActionBg: Color.lerp(deleteActionBg, other.deleteActionBg, t)!,
      deleteActionText:
          Color.lerp(deleteActionText, other.deleteActionText, t)!,
      liveIndicator: Color.lerp(liveIndicator, other.liveIndicator, t)!,
      mapTerrain: Color.lerp(mapTerrain, other.mapTerrain, t)!,
      mapTerrainGrid: Color.lerp(mapTerrainGrid, other.mapTerrainGrid, t)!,
      routeLineBlue: Color.lerp(routeLineBlue, other.routeLineBlue, t)!,
      routeLineHalo: Color.lerp(routeLineHalo, other.routeLineHalo, t)!,
      markerStartGreen: Color.lerp(markerStartGreen, other.markerStartGreen, t)!,
      markerEndRed: Color.lerp(markerEndRed, other.markerEndRed, t)!,
    );
  }
}
