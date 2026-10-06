import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  // A 24 dp marker shown 1.3× on a 2.625 device (Pixel 7).
  const sizeDp = 24.0, scale = 1.3, pixelRatio = 2.625;

  test('a map symbol is rasterised at the size it is shown: one image pixel '
      'per device pixel, so it is not upscaled (blurry start/finish markers)',
      () {
    final r = symbolRaster(scale, pixelRatio);
    final imagePx = sizeDp * r.rasterRatio;
    final shownDp = imagePx * r.iconSize; // MapLibre: image px × icon-size = dp
    expect(shownDp, closeTo(sizeDp * scale, 1e-9));
    expect(shownDp * pixelRatio, closeTo(imagePx, 1e-9),
        reason: 'device pixels == image pixels');
  });

  test('scale 1: the device pixel ratio as is', () {
    final r = symbolRaster(1, pixelRatio);
    expect(r.rasterRatio, pixelRatio);
    expect(r.iconSize, closeTo(1 / pixelRatio, 1e-12));
  });
}
