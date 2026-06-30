import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

/// A full-viewBox square glyph: fills the entire 960×960 box, so after the
/// badge transform the centre of the 96px badge must land inside the glyph
/// (tinted white) and the corners on the bare amber circle. This pins the
/// viewBox transform in CI instead of an on-device eyeball (the proven result
/// is: NO `translate(0,960)` — vector_graphics already bakes the origin).
const _fullViewBoxSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -960 960 960">'
    '<path d="M0,-960 H960 V0 H0 Z"/></svg>';

void main() {
  test('badge glyph fills centre (white), amber shows at corners', () async {
    final Uint8List png =
        await activityBadgePngFromLoader(SvgStringLoader(_fullViewBoxSvg));

    final codec = await instantiateImageCodec(png);
    final frame = await codec.getNextFrame();
    final data =
        (await frame.image.toByteData(format: ImageByteFormat.rawRgba))!;

    Color pixel(int x, int y) {
      final i = (y * frame.image.width + x) * 4;
      return Color.fromARGB(
          data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1),
          data.getUint8(i + 2));
    }

    final centre = pixel(48, 48);
    expect(centre.r * 255, closeTo(255, 1), reason: 'centre should be white glyph');
    expect(centre.g * 255, closeTo(255, 1));
    expect(centre.b * 255, closeTo(255, 1));

    // (48, 8): inside the radius-48 amber circle but above the padded glyph
    // square (y 18..78), so it must be bare amber — proves the glyph is scaled
    // into the centre, not overflowing the badge.
    final amber = pixel(48, 8);
    expect(amber.r * 255, closeTo(180, 2), reason: 'should be amber badge');
    expect(amber.g * 255, closeTo(83, 2));
    expect(amber.b * 255, closeTo(9, 2));
  });
}
