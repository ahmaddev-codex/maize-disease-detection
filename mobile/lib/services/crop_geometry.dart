import 'dart:math' as math;
import 'dart:ui' show Rect, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show BoxFit;
import 'package:image/image.dart' as img;

/// Maps the on-screen reticle onto the captured image.
///
/// The camera tells the farmer to align the leaf in the box but classifies the
/// whole frame, so background soil and neighbouring plants reach the model
/// (T19). The preview is centred and letterboxed, and the reticle is centred on
/// the same area, so the crop is a centred square whose side is the reticle
/// scaled back into image pixels.
///
/// [imageSize] is the image as it is displayed — bake EXIF orientation before
/// measuring it, or the rectangle lands on a rotated frame.
Rect reticleCropRect({
  required Size imageSize,
  required Size previewArea,
  required double reticleSide,
  BoxFit fit = BoxFit.contain,
}) {
  final whole = Rect.fromLTWH(0, 0, imageSize.width, imageSize.height);
  if (imageSize.width <= 0 || imageSize.height <= 0) return whole;
  if (previewArea.width <= 0 || previewArea.height <= 0 || reticleSide <= 0) {
    return whole;
  }

  final scaleX = previewArea.width / imageSize.width;
  final scaleY = previewArea.height / imageSize.height;
  final scale = fit == BoxFit.cover
      ? math.max(scaleX, scaleY)
      : math.min(scaleX, scaleY);
  if (scale <= 0) return whole;

  // The reticle is measured on screen; divide by the scale to get image pixels.
  var side = reticleSide / scale;
  side = math.min(side, math.min(imageSize.width, imageSize.height));

  final left = (imageSize.width - side) / 2;
  final top = (imageSize.height - side) / 2;
  return Rect.fromLTWH(left, top, side, side);
}

/// Re-encodes [bytes] cropped to the reticle, or null when the bytes are not a
/// decodable image — the caller then keeps the original capture.
Uint8List? cropJpegToReticle(
  Uint8List bytes, {
  required Size previewArea,
  required double reticleSide,
  BoxFit fit = BoxFit.contain,
  int quality = 92,
}) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    // What the farmer framed is the oriented image, not the sensor's raw one.
    final oriented = img.bakeOrientation(decoded);
    final rect = reticleCropRect(
      imageSize: Size(oriented.width.toDouble(), oriented.height.toDouble()),
      previewArea: previewArea,
      reticleSide: reticleSide,
      fit: fit,
    );

    final cropped = img.copyCrop(
      oriented,
      x: rect.left.round(),
      y: rect.top.round(),
      width: rect.width.round(),
      height: rect.height.round(),
    );
    return Uint8List.fromList(img.encodeJpg(cropped, quality: quality));
  } catch (e) {
    debugPrint('[CropGeometry] crop failed: $e');
    return null;
  }
}
