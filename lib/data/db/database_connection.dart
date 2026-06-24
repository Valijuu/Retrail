import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_database.dart';

/// Opens the on-device [AppDatabase] backed by a file in the app documents
/// directory. Kept separate from `app_database.dart` so the database + its Drift
/// row types stay free of Flutter-plugin imports (path_provider), letting the
/// pure-Dart domain layer depend on the row types.
AppDatabase openAppDatabase() {
  final executor = LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'retrail.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
  return AppDatabase(executor);
}
