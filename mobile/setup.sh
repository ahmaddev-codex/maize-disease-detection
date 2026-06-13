#!/usr/bin/env bash
# MaizeGuard React Native — one-shot setup for Android
# Run: bash setup.sh
set -e

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"

echo "==> Copying TFLite models..."
cp "$ROOT_DIR/models/exports/efficientnetb3_maize_int8.tflite" \
   "$MOBILE_DIR/assets/models/" 2>/dev/null || \
   echo "  [WARN] INT8 model not found at models/exports/ — place it in assets/models/ manually"

cp "$ROOT_DIR/models/exports/efficientnetb3_maize_fp16.tflite" \
   "$MOBILE_DIR/assets/models/" 2>/dev/null || \
   echo "  [WARN] FP16 model not found — using INT8 only"

echo "==> Installing npm packages..."
cd "$MOBILE_DIR"
npm install

echo "==> Linking font assets (react-native-vector-icons)..."
npx react-native-asset || echo "  [WARN] Asset link failed — run manually"

echo ""
echo "✓ Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Connect an Android device or start an emulator (API 24+)"
echo "  2. cd mobile && npx react-native run-android"
echo ""
echo "Note: If you see TFLite GPU errors at runtime, edit"
echo "  src/services/classifier.ts and remove the 'android-gpu' delegate."
