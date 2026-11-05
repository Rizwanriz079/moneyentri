#!/usr/bin/env bash
# Builds the Play Store bundle with the Dart code scrambled (obfuscated).
#
#   ./tool/build_release.sh
#
# Output:  build/app/outputs/bundle/release/app-release.aab   -> upload to Play
#          release-symbols/<version>/                          -> keep, never upload/share
#
# The symbols folder is the "decoder" that turns scrambled crash stack traces
# back into real names (flutter symbolize). Keep one per released version.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(grep '^version:' pubspec.yaml | awk '{print $2}')
symbols="release-symbols/$version"

if [ ! -f android/key.properties ]; then
  echo "Warning: android/key.properties is missing, so this bundle is signed with the"
  echo "debug key and Google Play will reject it. See PLAY_STORE.md, step 2."
fi

flutter build appbundle --release --obfuscate --split-debug-info="$symbols"

echo
echo "Bundle:  build/app/outputs/bundle/release/app-release.aab  (version $version)"
echo "Symbols: $symbols  (keep this folder; it is git-ignored)"
