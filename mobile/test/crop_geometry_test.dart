import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:flutter/painting.dart' show BoxFit;
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:maizeguard/services/crop_geometry.dart';

/// T19: the camera tells the farmer to "align leaf in box", then classifies the
/// whole frame. These are the coordinates that make the box mean something.
void main() {
  // The preview is centred and letterboxed (BoxFit.contain), and the 280pt
  // reticle is centred on the same area, so every crop is centred too.
  const screen = Size(400, 800);
  const reticle = 280.0;

  test('portrait sensor: the box maps to a centred square of the image', () {
    final rect = reticleCropRect(
      imageSize: const Size(3000, 4000),
      previewArea: screen,
      reticleSide: reticle,
    );

    // contain scale = 400/3000 = 0.1333; 280 / 0.1333 = 2100 image pixels.
    expect(rect.width, closeTo(2100, 1));
    expect(rect.height, closeTo(2100, 1));
    expect(rect.left, closeTo(450, 1));
    expect(rect.top, closeTo(950, 1));
  });

  test('landscape sensor: the same box covers more of a wider image', () {
    final rect = reticleCropRect(
      imageSize: const Size(4000, 3000),
      previewArea: screen,
      reticleSide: reticle,
    );

    // contain scale = 800/... no: min(400/4000, 800/3000) = 0.1; 280 / 0.1 = 2800.
    expect(rect.width, closeTo(2800, 1));
    expect(rect.height, closeTo(2800, 1));
    expect(rect.left, closeTo(600, 1));
    expect(rect.top, closeTo(100, 1));
  });

  test('a preview that fills the screen (cover) maps the box differently', () {
    final rect = reticleCropRect(
      imageSize: const Size(4000, 3000),
      previewArea: screen,
      reticleSide: reticle,
      fit: BoxFit.cover,
    );

    // cover scale = max(0.1, 0.2667) = 0.2667; 280 / 0.2667 = 1050.
    expect(rect.width, closeTo(1050, 2));
    expect(rect.left, closeTo(1475, 2));
    expect(rect.top, closeTo(975, 2));
  });

  test('a box larger than the frame is clamped inside the image', () {
    final rect = reticleCropRect(
      imageSize: const Size(4000, 3000),
      previewArea: const Size(400, 200),
      reticleSide: reticle,
    );

    expect(rect.left, greaterThanOrEqualTo(0));
    expect(rect.top, greaterThanOrEqualTo(0));
    expect(rect.right, lessThanOrEqualTo(4000));
    expect(rect.bottom, lessThanOrEqualTo(3000));
    expect(rect.width * rect.height, greaterThan(0));
  });

  test('a degenerate frame yields the whole image rather than nothing', () {
    final rect = reticleCropRect(
      imageSize: const Size(300, 300),
      previewArea: Size.zero,
      reticleSide: reticle,
    );
    expect(rect, const Rect.fromLTWH(0, 0, 300, 300));
  });

  group('cropping a capture', () {
    Uint8List jpegOf(int width, int height) {
      final image = img.Image(width: width, height: height);
      img.fill(image, color: img.ColorRgb8(20, 120, 40));
      return Uint8List.fromList(img.encodeJpg(image));
    }

    test('the stored photo shows only the boxed region', () {
      final cropped = cropJpegToReticle(
        jpegOf(1200, 1600),
        previewArea: screen,
        reticleSide: reticle,
      );

      expect(cropped, isNotNull);
      final decoded = img.decodeJpg(cropped!)!;
      // contain scale = 400/1200 = 0.3333; 280 / 0.3333 = 840.
      expect(decoded.width, closeTo(840, 2));
      expect(decoded.height, closeTo(840, 2));
    });

    test('bytes that are not an image are left to the caller, not thrown', () {
      expect(
        cropJpegToReticle(Uint8List.fromList([1, 2, 3]),
            previewArea: screen, reticleSide: reticle),
        isNull,
      );
    });
  });
}
