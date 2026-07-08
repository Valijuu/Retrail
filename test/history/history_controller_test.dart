import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history/history_controller.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview_cache.dart';

void main() {
  late AppDatabase db;
  late RideRepository repo;
  late Directory tmp;
  late List<int> evicted;
  late HistoryController controller;

  setUp(() async {
    db = AppDatabase.memory();
    repo = RideRepository(RideDao(db), now: () => 1000);
    tmp = await Directory.systemTemp.createTemp('history_ctl');
    evicted = [];
    final cache = _SpyCache(tmp, evicted);
    controller = HistoryController(repo, cache);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Future<int> insertRide({String? typ, bool fav = false}) => repo.insert(
      RidesCompanion.insert(typ: Value(typ), date: const Value(1000)));

  test('deleteRide removes the row and evicts the preview', () async {
    final id = await insertRide();
    await controller.deleteRide(id);
    expect(await repo.getById(id).first, isNull);
    expect(evicted, [id]);
  });

  test('deleteRides removes all rows and evicts each preview', () async {
    final a = await insertRide();
    final b = await insertRide();
    await controller.deleteRides([a, b]);
    expect(await repo.getAllRides().first, isEmpty);
    expect(evicted, [a, b]);
  });

  test('updateRideDetails writes description, comment and type', () async {
    final id = await insertRide(typ: 'LONGBOARD');
    await controller.updateRideDetails(
        id, 'Sunset', 'nice', ActivityType.scooter);
    final ride = (await repo.getById(id).first)!;
    expect(ride.description, 'Sunset');
    expect(ride.comment, 'nice');
    expect(ride.typ, 'SCOOTER');
  });

  test('toggleFavorite flips the flag', () async {
    final id = await insertRide();
    final ride = (await repo.getById(id).first)!;
    await controller.toggleFavorite(ride);
    expect((await repo.getById(id).first)!.isFavorite, isTrue);
  });
}

class _SpyCache extends RoutePreviewCache {
  _SpyCache(Directory dir, this.evicted)
      : super(
            baseDir: dir,
            render: (_, _) async =>
                PreviewResult(Uint8List(0), complete: true));
  final List<int> evicted;

  @override
  Future<void> evict(int rideId) async => evicted.add(rideId);
}
