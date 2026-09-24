import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history/history_controller.dart';
import 'package:retrail/map/preview_snapshot.dart' show PreviewResult;
import 'package:retrail/map/route_preview_cache.dart';
import '../support/ride_lookup.dart';

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

  Future<int> insertRide({String? typ, bool fav = false}) =>
      repo.startRide(activityTypeId: typ, startedAtMs: 1000);

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

  test('deleteRides makes a single bulk deleteByIds call, not N deleteById '
      'calls', () async {
    final calls = <String>[];
    final spyRepo = _CallSpyRepo(RideDao(db), calls);
    final spyController = HistoryController(spyRepo, _SpyCache(tmp, evicted));
    final a = await spyRepo.startRide(activityTypeId: null, startedAtMs: 1000);
    final b = await spyRepo.startRide(activityTypeId: null, startedAtMs: 1000);
    calls.clear(); // drop setup noise (startRide doesn't call delete*)

    await spyController.deleteRides([a, b]);

    expect(calls, ['deleteByIds:[$a, $b]']);
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

/// Records which delete method was actually called, so the test can assert
/// [HistoryController.deleteRides] issues one bulk [RideRepository.deleteByIds]
/// call instead of N [RideRepository.deleteById] calls.
class _CallSpyRepo extends RideRepository {
  _CallSpyRepo(super.dao, this.calls);
  final List<String> calls;

  @override
  Future<void> deleteById(int rideId) {
    calls.add('deleteById:$rideId');
    return super.deleteById(rideId);
  }

  @override
  Future<void> deleteByIds(List<int> rideIds) {
    calls.add('deleteByIds:$rideIds');
    return super.deleteByIds(rideIds);
  }
}
