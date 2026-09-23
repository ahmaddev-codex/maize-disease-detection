import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Decodes [bytes] and resizes to [size]x[size] as packed RGB bytes.
///
/// Uses bilinear interpolation to match `tf.image.resize` in training.
/// `img.copyResize` defaults to nearest-neighbour, which cost about 1.8
/// accuracy points on the held-out test split (T09, see models/exports/metrics.json).
Uint8List preprocessForModel(Uint8List bytes, {int size = 300}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw ArgumentError('Failed to decode image');
  }

  final resized = img.copyResize(
    decoded,
    width: size,
    height: size,
    interpolation: img.Interpolation.linear,
  );

  final rgb = Uint8List(size * size * 3);
  var i = 0;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final pixel = resized.getPixel(x, y);
      rgb[i++] = pixel.r.toInt();
      rgb[i++] = pixel.g.toInt();
      rgb[i++] = pixel.b.toInt();
    }
  }
  return rgb;
}
