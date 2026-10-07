import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:maizeguard/services/luma.dart';

/// T20: the brightness hint sampled every twelfth byte of whatever the stream
/// happened to deliver — row padding on Android, the blue channel on iOS. The
/// luma maths is pulled out here so both frame layouts can be proven.
void main() {
  Uint8List yPlane({required int width, required int height, required int value, int? bytesPerRow, int padding = 255}) {
    final stride = bytesPerRow ?? width;
    final bytes = Uint8List(stride * height);
    for (var row = 0; row < height; row++) {
      for (var col = 0; col < stride; col++) {
        bytes[row * stride + col] = col < width ? value : padding;
      }
    }
    return bytes;
  }

  Uint8List bgraPlane({required int width, required int height, required int b, required int g, required int r}) {
    final bytes = Uint8List(width * height * 4);
    for (var i = 0; i < width * height; i++) {
      bytes[i * 4] = b;
      bytes[i * 4 + 1] = g;
      bytes[i * 4 + 2] = r;
      bytes[i * 4 + 3] = 255;
    }
    return bytes;
  }

  group('Y plane (Android yuv420)', () {
    test('reads the average luma of the visible pixels', () {
      final frame = yPlane(width: 8, height: 4, value: 130);
      expect(lumaFromYPlane(frame, width: 8, height: 4), closeTo(130, 0.5));
    });

    test('ignores row padding, which would otherwise read as glare', () {
      // 4 visible dark pixels per row, 4 bytes of bright padding after them.
      final frame = yPlane(width: 4, height: 4, value: 20, bytesPerRow: 8);
      final luma = lumaFromYPlane(frame, width: 4, height: 4, bytesPerRow: 8);
      expect(luma, closeTo(20, 0.5));
      expect(lightingFrom(luma), FrameLighting.dark);
    });
  });

  group('BGRA plane (iOS bgra8888)', () {
    test('weights the colour channels instead of reading blue alone', () {
      final blue = bgraPlane(width: 4, height: 4, b: 255, g: 0, r: 0);
      final luma = lumaFromBgra(blue, width: 4, height: 4);
      expect(luma, closeTo(0.114 * 255, 1.0), reason: 'a blue frame is dark, not blown out');
      expect(lightingFrom(luma), FrameLighting.dark);

      final red = bgraPlane(width: 4, height: 4, b: 0, g: 0, r: 255);
      expect(lumaFromBgra(red, width: 4, height: 4), closeTo(0.299 * 255, 1.0));

      final white = bgraPlane(width: 4, height: 4, b: 255, g: 255, r: 255);
      expect(lumaFromBgra(white, width: 4, height: 4), closeTo(255, 1.0));
      expect(lightingFrom(lumaFromBgra(white, width: 4, height: 4)), FrameLighting.bright);
    });
  });

  group('hints', () {
    test('only dark and bright frames are worth interrupting for', () {
      expect(lightingFrom(20), FrameLighting.dark);
      expect(lightingFrom(128), FrameLighting.ok);
      expect(lightingFrom(240), FrameLighting.bright);

      expect(lightingHint(FrameLighting.dark), isNotNull);
      expect(lightingHint(FrameLighting.bright), isNotNull);
      expect(lightingHint(FrameLighting.ok), isNull);
    });

    test('an empty or malformed frame gives no hint rather than a false alarm', () {
      expect(lightingFrom(lumaFromYPlane(Uint8List(0), width: 0, height: 0)), FrameLighting.ok);
      expect(lightingFrom(lumaFromBgra(Uint8List(3), width: 4, height: 4)), FrameLighting.ok);
    });
  });
}
