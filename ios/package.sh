#!/bin/bash
set -euo pipefail
work=$1
out=$2
mkdir -p "$out"
for name in perl perlA perlB perlC; do
  sim="$work/frameworks/iphonesimulator-universal/$name.framework"
  mkdir -p "$sim"
  cp "$work/frameworks/iphonesimulator-arm64/$name.framework/Info.plist" "$sim/Info.plist"
  lipo -create "$work/frameworks/iphonesimulator-arm64/$name.framework/$name" \
    "$work/frameworks/iphonesimulator-x86_64/$name.framework/$name" -output "$sim/$name"
  rm -rf "$out/$name.xcframework"
  xcodebuild -create-xcframework \
    -framework "$work/frameworks/iphoneos-arm64/$name.framework" \
    -framework "$sim" -output "$out/$name.xcframework"
  (
    cd "$out"
    rm -f "$name.xcframework.zip"
    zip -qry "$name.xcframework.zip" "$name.xcframework"
  )
done
(
  cd "$out"
  for name in perl perlA perlB perlC; do
    printf '%s  %s.xcframework.zip\n' "$(swift package compute-checksum "$name.xcframework.zip")" "$name"
  done >checksums.txt
)

cp "$(dirname "$0")/README.md" "$out/release.md"
