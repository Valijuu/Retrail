import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/follow_coverage.dart';

void main() {
  group('followCoverage', () {
    test('no ridden intervals covers nothing — 0', () {
      expect(followCoverage(const [], 1000), 0.0);
    });
    test('a route without length covers nothing — [(0, 100)] on 0 m is 0', () {
      expect(followCoverage(const [(0, 100)], 0), 0.0);
    });
    test(
      'one interval is its share of the route — [(0, 500)] on 1000 m is 0.5',
      () {
        expect(followCoverage(const [(0, 500)], 1000), 0.5);
      },
    );
    test('the whole route is full coverage — [(0, 1000)] on 1000 m is 1', () {
      expect(followCoverage(const [(0, 1000)], 1000), 1.0);
    });
    test(
      'separate intervals add up — [(0, 200), (500, 800)] on 1000 m is 0.5',
      () {
        expect(followCoverage(const [(0, 200), (500, 800)], 1000), 0.5);
      },
    );
    test('overlapping intervals count once — [(0, 600), (400, 800)] on 1000 m '
        'is 0.8', () {
      expect(followCoverage(const [(0, 600), (400, 800)], 1000), 0.8);
    });
    test(
      'touching intervals count once — [(0, 500), (500, 700)] on 1000 m is 0.7',
      () {
        expect(followCoverage(const [(0, 500), (500, 700)], 1000), 0.7);
      },
    );
    test('an interval inside another adds nothing — [(0, 900), (200, 300)] on '
        '1000 m is 0.9', () {
      expect(followCoverage(const [(0, 900), (200, 300)], 1000), 0.9);
    });
    test('order does not matter — [(500, 800), (0, 600)] on 1000 m is 0.8', () {
      expect(followCoverage(const [(500, 800), (0, 600)], 1000), 0.8);
    });
    test('a loop split at the start/finish adds both parts — '
        '[(800, 1000), (0, 300)] on 1000 m is 0.5', () {
      expect(followCoverage(const [(800, 1000), (0, 300)], 1000), 0.5);
    });
    test('never more than full — [(0, 1200)] on 1000 m is 1', () {
      expect(followCoverage(const [(0, 1200)], 1000), 1.0);
    });
    test(
      'a negative route length covers nothing — [(0, 100)] on -1000 m is 0',
      () {
        expect(followCoverage(const [(0, 100)], -1000), 0.0);
      },
    );
    test(
      'metres before the start do not count — [(-200, 300)] on 1000 m is 0.3',
      () {
        expect(followCoverage(const [(-200, 300)], 1000), 0.3);
      },
    );
    test('an interval entirely before the start counts nothing — '
        '[(-500, -100)] on 1000 m is 0', () {
      expect(followCoverage(const [(-500, -100)], 1000), 0.0);
    });
    test(
      'a reversed interval counts nothing — [(600, 400)] on 1000 m is 0',
      () {
        expect(followCoverage(const [(600, 400)], 1000), 0.0);
      },
    );
  });
}
