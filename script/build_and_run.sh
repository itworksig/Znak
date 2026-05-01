#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"

cd "$ROOT_DIR"

xcodebuild \
  -project Znak.xcodeproj \
  -scheme Znak \
  -configuration Debug \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build

APP_PATH="$BUILD_DIR/DerivedData/Build/Products/Debug/Znak.app"

echo
echo "Built: $APP_PATH"
echo "Install without logging out:"
echo "  ./script/install_local.sh"
echo "If System Settings still hides it, install system-wide:"
echo "  ./script/install_system.sh"
