#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

select_xcode() {
  shopt -s nullglob
  local candidates=(/Applications/Xcode_27*.app /Applications/Xcode_26.6.app /Applications/Xcode.app)
  if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "No Xcode.app found" >&2
    exit 1
  fi
  sudo xcode-select -s "${candidates[0]}"
  xcodebuild -version
}

if [[ "${SELECT_XCODE:-1}" == "1" ]] && command -v xcodebuild >/dev/null 2>&1; then
  select_xcode || true
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

xcodegen generate

DERIVED="$ROOT/build"
rm -rf "$DERIVED" Payload Stage.ipa
mkdir -p "$DERIVED"

xcodebuild \
  -project "$ROOT/Stage.xcodeproj" \
  -scheme Stage \
  -configuration Release \
  -destination "generic/platform=iOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  DEVELOPMENT_TEAM="" \
  build

APP="$(find "$DERIVED/Build/Products/Release-iphoneos" -maxdepth 1 -name '*.app' -print -quit)"
if [[ -z "$APP" ]]; then
  echo "Built app not found" >&2
  exit 1
fi

mkdir -p "$ROOT/Payload"
cp -R "$APP" "$ROOT/Payload/"
rm -f "$ROOT/Stage.ipa"
ditto -c -k --keepParent "$ROOT/Payload" "$ROOT/Stage.ipa"
rm -rf "$ROOT/Payload"
echo "Wrote $ROOT/Stage.ipa"
