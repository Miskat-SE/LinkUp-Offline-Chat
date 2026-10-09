#!/bin/sh
# Builds the next release APK and saves it as releases/LINKUP_version-<N>.apk.
#
# N is the build number after "+" in pubspec.yaml's version. It goes up by one
# on every successful build and is also Android's versionCode, so each new APK
# installs as an update over the previous one.
#
# Usage: tool/build_apk.sh        (set FLUTTER=/path/to/flutter if not on PATH)
set -eu
cd "$(dirname "$0")/.."

FLUTTER=${FLUTTER:-flutter}
current=$(sed -n 's/^version: .*+\([0-9][0-9]*\)$/\1/p' pubspec.yaml)
if [ -z "$current" ]; then
  echo "pubspec.yaml has no build number (expected version: x.y.z+N)" >&2
  exit 1
fi
next=$((current + 1))

"$FLUTTER" build apk --release --build-number="$next"

# Record the new build number only after the build succeeded.
sed -i.bak "s/^\(version: .*\)+$current\$/\1+$next/" pubspec.yaml
rm pubspec.yaml.bak

mkdir -p releases
out="releases/LINKUP_version-$next.apk"
cp build/app/outputs/flutter-apk/app-release.apk "$out"
echo "Saved $out"
