#!/bin/sh
# ─────────────────────────────────────────────────────────────────────────────
# Automatically switches between iOS device and iOS simulator binary slices
# for Google MLKit vendor frameworks based on target platform.
#
# When PLATFORM_NAME=iphoneos:       links ${binary}.device (LC_BUILD_VERSION platform 2)
# When PLATFORM_NAME=iphonesimulator: links ${binary}.sim    (LC_BUILD_VERSION platform 7)
# ─────────────────────────────────────────────────────────────────────────────

set -e

if [ "$PLATFORM_NAME" = "iphoneos" ]; then
  SUFFIX="device"
else
  SUFFIX="sim"
fi

PODS_DIR="${SRCROOT}/Pods"

MLKIT_PODS="MLImage MLKitCommon MLKitTextRecognition MLKitTextRecognitionChinese MLKitTextRecognitionCommon MLKitTextRecognitionDevanagari MLKitTextRecognitionJapanese MLKitTextRecognitionKorean MLKitVision"

for pod in $MLKIT_PODS; do
  fw_dir="${PODS_DIR}/${pod}/Frameworks"
  if [ -d "$fw_dir" ]; then
    for fw in "${fw_dir}"/*.framework; do
      if [ -d "$fw" ]; then
        name=$(basename "$fw" .framework)
        binary="${fw}/${name}"
        target="${binary}.${SUFFIX}"
        if [ -f "$target" ]; then
          cp -f "$target" "$binary"
          echo "[MLKit Arch Switcher] Switched ${name} to ${SUFFIX} slice (${PLATFORM_NAME})"
        fi
      fi
    done
  fi
done
