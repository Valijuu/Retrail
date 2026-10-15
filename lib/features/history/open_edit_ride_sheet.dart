import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_bottom_sheet.dart';
import '../../data/db/app_database.dart' show Ride;
import '../../domain/activity_type.dart';
import 'edit_ride_sheet.dart';
import 'history_providers.dart';

/// Opens [EditRideSheet] for [ride] and writes the result through the history
/// controller. Shared by History's card menu and the "Ride saved" hint (#75).
Future<void> showEditRideSheet(
  BuildContext context,
  WidgetRef ref,
  Ride ride,
) => showAppScrollableSheet<void>(
  context: context,
  builder: (sheetContext, scrollController) => EditRideSheet(
    scrollController: scrollController,
    initialDescription: ride.description,
    initialComment: ride.comment,
    initialType: ActivityType.fromId(ride.typ),
    initialFavorite: ride.isFavorite,
    onDismiss: () => Navigator.of(sheetContext).pop(),
    onSave: (description, comment, type, favorite) {
      Navigator.of(sheetContext).pop();
      ref
          .read(historyControllerProvider)
          .updateRideDetails(ride, description, comment, type, favorite);
    },
  ),
);
