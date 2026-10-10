#!/bin/sh
# Builds the next release APK and saves it as releases/LINKUP_version-<N>.apk.
#
# N is the build number after "+" in pubspec.yaml's version. It goes up by one
# on every successful build and is also Android's versionCode, so each new APK
# installs as an update over the previous one.
#
# Release builds are obfuscated; the symbols needed to read their stack traces
# are kept in releases/symbols/version-<N>/ (flutter symbolize). With --bundle,
# the Play Store bundle is saved too: releases/LINKUP_version-<N>.aab.
#
# Signing uses android/key.properties (git-ignored, TESTING.md §4). Without it
# the build is signed with the debug key and can't update a release install.
#
# Usage: tool/build_apk.sh [--bundle]   (set FLUTTER=/path/to/flutter if not on PATH)
set -eu
cd "$(dirname "$0")/.."

FLUTTER=${FLUTTER:-flutter}
current=$(sed -n 's/^version: .*+\([0-9][0-9]*\)$/\1/p' pubspec.yaml)
if [ -z "$current" ]; then
  echo "pubspec.yaml has no build number (expected version: x.y.z+N)" >&2
  exit 1
fi
next=$((current + 1))
[ -f android/key.properties ] || echo "Warning: no android/key.properties, signing with the debug key" >&2

symbols="releases/symbols/version-$next"
mkdir -p "$symbols"
flags="--release --build-number=$next --obfuscate --split-debug-info=$symbols"

"$FLUTTER" build apk $flags
if [ "${1:-}" = "--bundle" ]; then
  "$FLUTTER" build appbundle $flags
fi

# Record the new build number only after the build succeeded.
sed -i.bak "s/^\(version: .*\)+$current\$/\1+$next/" pubspec.yaml
rm pubspec.yaml.bak

out="releases/LINKUP_version-$next"
cp build/app/outputs/flutter-apk/app-release.apk "$out.apk"
echo "Saved $out.apk"
if [ "${1:-}" = "--bundle" ]; then
  cp build/app/outputs/bundle/release/app-release.aab "$out.aab"
  echo "Saved $out.aab"
fi
