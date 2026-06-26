#!/usr/bin/env bash
# MaizeGuard Flutter setup script
# Usage:
#   ./setup.sh                  — detect platform and set up
#   ./setup.sh --android        — Android only
#   ./setup.sh --ios            — iOS only (macOS required)
#   ./setup.sh --all            — both platforms
#   ./setup.sh --clean          — remove build artefacts and reinstall packages

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$SCRIPT_DIR"

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'

info()    { echo -e "${CYAN}[setup]${NC} $*"; }
success() { echo -e "${GREEN}[ok]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
die()     { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

# ── Parse flags ───────────────────────────────────────────────────────────────
ANDROID=false; IOS=false; CLEAN=false
if [[ $# -eq 0 ]]; then
  ANDROID=true
  [[ "$(uname)" == "Darwin" ]] && IOS=true
fi
for arg in "$@"; do
  case $arg in
    --android) ANDROID=true ;;
    --ios)     IOS=true ;;
    --all)     ANDROID=true; IOS=true ;;
    --clean)   CLEAN=true ;;
    *) die "Unknown flag: $arg" ;;
  esac
done

echo ""
echo "============================================================"
echo "  MaizeGuard — Flutter Setup"
echo "  Android: $ANDROID | iOS: $IOS | Clean: $CLEAN"
echo "============================================================"
echo ""

# ── Pre-flight ────────────────────────────────────────────────────────────────
command -v flutter &>/dev/null || die "Flutter not found. Install from https://flutter.dev/docs/get-started/install"
info "Flutter: $(flutter --version 2>/dev/null | head -1)"

# ── Clean ─────────────────────────────────────────────────────────────────────
if $CLEAN; then
  info "Cleaning build artefacts…"
  flutter clean
  rm -rf .dart_tool build .flutter-plugins .flutter-plugins-dependencies
  success "Clean done"
fi

# ── Environment file ─────────────────────────────────────────────────────────
if [[ ! -f ".env.json" ]]; then
  cp .env.json.example .env.json
  warn ".env.json not found — created from example. Edit it before running the app."
else
  success ".env.json found"
fi

# ── Copy TFLite models ────────────────────────────────────────────────────────
info "Copying TFLite models into assets/models/…"
mkdir -p assets/models

for MODEL in efficientnetb3_maize_int8.tflite efficientnetb3_maize_fp16.tflite; do
  SRC="$ROOT_DIR/models/exports/$MODEL"
  DST="assets/models/$MODEL"
  if [[ -f "$SRC" ]]; then
    cp "$SRC" "$DST"
    success "Copied $MODEL"
  else
    warn "$MODEL not found at models/exports/ — run 'bash run_all.sh' first"
  fi
done

# ── Dependencies ──────────────────────────────────────────────────────────────
info "Fetching Flutter packages…"
flutter pub get
success "Packages fetched"

# ── Android ───────────────────────────────────────────────────────────────────
if $ANDROID; then
  info "Checking Android…"
  command -v java &>/dev/null || warn "Java not found — Android build requires JDK 17+"

  GRADLE_FILE="android/app/build.gradle"
  if [[ -f "$GRADLE_FILE" ]]; then
    CURRENT_MIN=$(grep "minSdkVersion" "$GRADLE_FILE" 2>/dev/null \
                  | grep -oE '[0-9]+' | head -1 || echo "0")
    if [[ "${CURRENT_MIN:-0}" -lt 21 ]]; then
      warn "minSdkVersion=$CURRENT_MIN — bumping to 21 (required by tflite_flutter)"
      sed -i.bak 's/minSdkVersion [0-9]*/minSdkVersion 21/' "$GRADLE_FILE"
      success "minSdkVersion patched to 21"
    else
      success "minSdkVersion=$CURRENT_MIN (OK)"
    fi
  fi

  success "Android ready"
fi

# ── iOS ───────────────────────────────────────────────────────────────────────
if $IOS; then
  [[ "$(uname)" == "Darwin" ]] || die "--ios requires macOS"
  command -v pod &>/dev/null || die "CocoaPods not found. Run: sudo gem install cocoapods"

  info "Running pod install…"
  (cd ios && pod install --repo-update)
  success "CocoaPods installed"

  PLIST="ios/Runner/Info.plist"
  if [[ -f "$PLIST" ]]; then
    patch_plist() {
      local key="$1"; local desc="$2"
      if ! /usr/libexec/PlistBuddy -c "Print :$key" "$PLIST" &>/dev/null; then
        /usr/libexec/PlistBuddy -c "Add :$key string '$desc'" "$PLIST"
        success "  Added $key"
      fi
    }
    patch_plist NSCameraUsageDescription           "MaizeGuard uses the camera to photograph maize leaves for disease detection"
    patch_plist NSPhotoLibraryUsageDescription     "MaizeGuard reads photos to run offline disease classification"
    patch_plist NSLocationWhenInUseUsageDescription "MaizeGuard tags your scan with GPS so you can map disease on your farm"
    patch_plist NSMicrophoneUsageDescription       "Required by the Flutter camera plugin"
  fi

  success "iOS ready"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "============================================================"
echo "  Setup complete!"
echo ""
$ANDROID && echo "  Android  →  flutter run -d android --dart-define-from-file=.env.json"
$IOS     && echo "  iOS      →  flutter run -d ios    --dart-define-from-file=.env.json"
echo "  Emulator →  flutter run --dart-define-from-file=.env.json"
echo ""
echo "  Other commands:"
echo "    flutter test                                           # unit tests"
echo "    flutter build apk --dart-define-from-file=.env.json   # release APK"
echo "    flutter build ios --dart-define-from-file=.env.json   # release iOS archive"
echo "    flutter pub get                                        # after adding packages"
echo ""
echo "  .env.json keys:"
echo "    GEMINI_API_KEY  — production Gemini key (release builds)"
echo "    OLLAMA_HOST     — Ollama server URL     (debug builds, default: http://localhost:11434)"
echo "    OLLAMA_MODEL    — model name             (debug builds, default: llama3.1:8b)"
echo "============================================================"
