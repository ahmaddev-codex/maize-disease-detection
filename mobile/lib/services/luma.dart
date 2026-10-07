import 'dart:typed_data';

/// How well lit a preview frame is.
enum FrameLighting { dark, ok, bright }

/// Neutral mid-grey: what an unreadable frame is treated as, so a malformed
/// buffer never raises a false "low light" or "glare" alarm.
const double _neutralLuma = 128;

const double _darkBelow = 55;
const double _brightAbove = 215;

/// Average luma of a yuv420 Y plane (Android).
///
/// [bytesPerRow] is the plane's stride: it is usually wider than [width], and
/// reading the padding made a dark field look like glare (T20).
double lumaFromYPlane(
  Uint8List bytes, {
  required int width,
  required int height,
  int? bytesPerRow,
  int sampleStep = 4,
}) {
  final stride = bytesPerRow ?? width;
  if (width <= 0 || height <= 0 || stride < width) return _neutralLuma;
  if (bytes.length < stride * (height - 1) + width) return _neutralLuma;

  final step = sampleStep < 1 ? 1 : sampleStep;
  var sum = 0;
  var count = 0;
  for (var row = 0; row < height; row += step) {
    final rowStart = row * stride;
    for (var col = 0; col < width; col += step) {
      sum += bytes[rowStart + col];
      count++;
    }
  }
  return count > 0 ? sum / count : _neutralLuma;
}

/// Average luma of a bgra8888 plane (iOS), weighting the channels by Rec. 601.
/// Sampling raw bytes read mostly blue, so a blue frame scored as blown out.
double lumaFromBgra(
  Uint8List bytes, {
  required int width,
  required int height,
  int? bytesPerRow,
  int sampleStep = 4,
}) {
  final stride = bytesPerRow ?? width * 4;
  if (width <= 0 || height <= 0 || stride < width * 4) return _neutralLuma;
  if (bytes.length < stride * (height - 1) + width * 4) return _neutralLuma;

  final step = sampleStep < 1 ? 1 : sampleStep;
  var sum = 0.0;
  var count = 0;
  for (var row = 0; row < height; row += step) {
    final rowStart = row * stride;
    for (var col = 0; col < width; col += step) {
      final i = rowStart + col * 4;
      sum += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
      count++;
    }
  }
  return count > 0 ? sum / count : _neutralLuma;
}

FrameLighting lightingFrom(double luma) {
  if (luma < _darkBelow) return FrameLighting.dark;
  if (luma > _brightAbove) return FrameLighting.bright;
  return FrameLighting.ok;
}

/// What to tell the farmer, or null when the frame is fine as it is.
String? lightingHint(FrameLighting lighting) => switch (lighting) {
      FrameLighting.dark => 'Low light: move closer to daylight',
      FrameLighting.bright => 'Direct glare: shade leaf for accurate diagnosis',
      FrameLighting.ok => null,
    };
