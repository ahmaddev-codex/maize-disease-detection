/**
 * TFLite classifier service — react-native-fast-tflite v3 (Nitro Modules).
 *
 * Model: EfficientNetB3 INT8 quantized (300×300 RGB input, 4-class output)
 * Input:  [1, 300, 300, 3]  uint8  [0–255]
 * Output: [1, 4]            uint8  → dequantise → float probability
 *
 * v3 API changes from v1:
 *   - loadTensorflowModel(source, delegates[])  (array, not string)
 *   - model.run(ArrayBuffer[]) → Promise<ArrayBuffer[]>
 *   - model.runSync(ArrayBuffer[]) → ArrayBuffer[]
 */
import {loadTensorflowModel, TfliteModel} from 'react-native-fast-tflite';
import {Prediction} from '../types/prediction';
import {DISEASE_INFO} from '../constants/diseases';

// INT8 dequantisation params confirmed from Python export:
//   scale=0.00390625 (1/256), zeroPoint=0
const OUTPUT_SCALE = 0.00390625;
const OUTPUT_ZERO_POINT = 0;

let _model: TfliteModel | null = null;

export async function loadModel(): Promise<void> {
  try {
    // Try GPU delegate first
    _model = await loadTensorflowModel(
      require('../../assets/models/efficientnetb3_maize_int8.tflite'),
      ['android-gpu'],
    );
  } catch {
    // Fallback to CPU (NNAPI on Android)
    _model = await loadTensorflowModel(
      require('../../assets/models/efficientnetb3_maize_int8.tflite'),
      [],
    );
  }
}

export function isModelLoaded(): boolean {
  return _model !== null;
}

/**
 * Run inference on a preprocessed RGB uint8 flat array.
 * Input must be 300×300×3 = 270,000 bytes, values in [0, 255].
 */
export async function classify(rgbPixels: Uint8Array): Promise<Prediction> {
  if (!_model) {
    throw new Error('Model not loaded. Call loadModel() first.');
  }

  const start = Date.now();

  // v3: run() accepts ArrayBuffer[], returns ArrayBuffer[]
  const inputBuffer = rgbPixels.buffer.slice(
    rgbPixels.byteOffset,
    rgbPixels.byteOffset + rgbPixels.byteLength,
  ) as ArrayBuffer;
  const outputs = await _model.run([inputBuffer]);
  const rawOutput = new Uint8Array(outputs[0]);

  const latencyMs = Date.now() - start;

  // Dequantise INT8 → float probabilities
  const scores = Array.from(rawOutput).map(
    v => (v - OUTPUT_ZERO_POINT) * OUTPUT_SCALE,
  );

  // Normalise to sum = 1
  const sum = scores.reduce((a, b) => a + b, 0);
  const normalizedScores = scores.map(s => (sum > 0 ? s / sum : 0.25));

  const classId = normalizedScores.indexOf(Math.max(...normalizedScores));
  const disease = DISEASE_INFO[classId];

  return {
    classId,
    className: disease.fullName,
    shortName: disease.shortName,
    confidence: normalizedScores[classId],
    allScores: normalizedScores,
    latencyMs,
  };
}

/**
 * Strip alpha channel: RGBA[0..3] → RGB[0..2] per pixel.
 * Input: Uint8Array of length W*H*4
 * Output: Uint8Array of length W*H*3
 */
export function rgbaToRgb(rgba: Uint8Array): Uint8Array {
  const pixelCount = rgba.length / 4;
  const rgb = new Uint8Array(pixelCount * 3);
  for (let i = 0; i < pixelCount; i++) {
    rgb[i * 3] = rgba[i * 4];
    rgb[i * 3 + 1] = rgba[i * 4 + 1];
    rgb[i * 3 + 2] = rgba[i * 4 + 2];
  }
  return rgb;
}
