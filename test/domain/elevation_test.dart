import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/elevation.dart';

ElevationGain? gainOf(List<double?> altitudes) => ElevationGain.of(altitudes);

void main() {
  group('ElevationGain', () {
    test('flat ride with noise within ±2 m has no ascent or descent', () {
      const noise = [0.0, 2.0, -2.0, 1.0, -1.0, 2.0, -2.0, 0.5, -1.5];
      final altitudes = [
        for (var i = 0; i < 200; i++) 100.0 + noise[i % noise.length],
      ];
      final gain = gainOf(altitudes)!;
      expect(gain.ascent, 0);
      expect(gain.descent, 0);
    });

    test(
      'steady climb of 100 m in 1 m steps gives about 100 m ascent (±5 m)',
      () {
        final gain = gainOf([for (var i = 0; i <= 100; i++) 100.0 + i])!;
        expect(gain.ascent, closeTo(100, 5));
        expect(gain.descent, 0);
      },
    );

    test('steady descent mirrors the climb', () {
      final gain = gainOf([for (var i = 0; i <= 100; i++) 200.0 - i])!;
      expect(gain.descent, closeTo(100, 5));
      expect(gain.ascent, 0);
    });

    test('a single spike of 40 m adds nothing', () {
      final altitudes = List<double?>.filled(30, 100.0);
      altitudes[15] = 140;
      final gain = gainOf(altitudes)!;
      expect(gain.ascent, 0);
      expect(gain.descent, 0);
    });

    test('example 100, 110, 100: ascent 10 and descent 10', () {
      final gain = gainOf([100, 110, 100])!;
      expect(gain.ascent, 10);
      expect(gain.descent, 10);
    });

    test('only null altitudes have no elevation', () {
      expect(gainOf([null, null]), isNull);
    });

    test('one altitude has no elevation', () {
      expect(gainOf([100]), isNull);
    });

    test('empty list has no elevation', () {
      expect(gainOf([]), isNull);
    });

    test('null altitudes are skipped and do not move the level', () {
      final withNulls = gainOf([100, null, 110, null, null, 100])!;
      final without = gainOf([100, 110, 100])!;
      expect(withNulls.ascent, without.ascent);
      expect(withNulls.descent, without.descent);
    });

    test('two usable altitudes among nulls already count as elevation', () {
      expect(gainOf([null, 100, null, 100]), isNotNull);
    });

    test('a change below 3 m is not counted', () {
      final gain = gainOf([100, 102.9, 102.9, 102.9])!;
      expect(gain.ascent, 0);
    });

    test('totals are never negative', () {
      final gain = gainOf([300, 250, 200, 150, 100, 100, 100])!;
      expect(gain.ascent, greaterThanOrEqualTo(0));
      expect(gain.descent, greaterThan(0));
    });
  });

  group('ElevationAccumulator', () {
    test('has no gain before two usable altitudes', () {
      final acc = ElevationAccumulator();
      expect(acc.gain, isNull);
      acc.add(null);
      acc.add(100);
      expect(acc.gain, isNull);
      acc.add(100);
      expect(acc.gain, isNotNull);
    });

    test('running totals grow while altitudes are fed', () {
      final acc = ElevationAccumulator();
      for (final a in [100.0, 110.0]) {
        acc.add(a);
      }
      expect(acc.gain!.ascent, 10);
    });

    test('equals the batch result for a hilly ride with nulls and spikes', () {
      final altitudes = <double?>[
        for (var i = 0; i < 400; i++)
          i % 17 == 0
              ? null
              : 100 +
                    40 * (i < 200 ? i / 200 : (400 - i) / 200) +
                    (i % 23 == 0 ? 35 : 0) +
                    (i % 5) * 0.7,
      ];
      final acc = ElevationAccumulator();
      for (final a in altitudes) {
        acc.add(a);
      }
      final batch = ElevationGain.of(altitudes)!;
      expect(acc.gain!.ascent, batch.ascent);
      expect(acc.gain!.descent, batch.descent);
    });

    test('equals the batch result at every prefix', () {
      final altitudes = <double?>[
        for (var i = 0; i < 120; i++)
          100 + 30 * (i % 40 < 20 ? i % 40 : 40 - i % 40) / 20,
      ];
      final acc = ElevationAccumulator();
      for (var i = 0; i < altitudes.length; i++) {
        acc.add(altitudes[i]);
        final batch = ElevationGain.of(altitudes.sublist(0, i + 1));
        expect(acc.gain?.ascent, batch?.ascent);
        expect(acc.gain?.descent, batch?.descent);
      }
    });
  });
}
