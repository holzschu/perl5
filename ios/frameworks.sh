#!/bin/bash
set -euo pipefail
work=$1
sdk=$2
arch=$3
src="$work/$sdk-$arch"
if [ "$sdk" = iphoneos ]; then
  triple="$arch-apple-ios14.0"
  slice=ios-arm64
  platform=iPhoneOS
else
  triple="$arch-apple-ios14.0-simulator"
  slice=ios-arm64_x86_64-simulator
  platform=iPhoneSimulator
fi
sdkroot=$(xcrun --sdk "$sdk" --show-sdk-path)
cd "$src"
# The config is checksum-pinned input plus this recipe's toolchain overrides.
# shellcheck source=/dev/null
. ./config.sh
: "${static_ext:?missing static extension list}"
archives=()
for ext in $static_ext; do archives+=("lib/auto/$ext/${ext##*/}.a"); done
: <ext.libs
for name in perl perlA perlB perlC; do
  framework="$work/frameworks/$sdk-$arch/$name.framework"
  mkdir -p "$framework"
  # Match Perl's link rule: ext.libs contains the static extensions' linker flags.
  # shellcheck disable=SC2046
  nice -n 15 clang -dynamiclib -undefined error -fstack-protector-strong -target "$triple" -isysroot "$sdkroot" \
    -F"$work/deps/ios_system.xcframework/$slice" -framework ios_system \
    -Wl,-install_name,"@rpath/$name.framework/$name" \
    -o "$framework/$name" perlmain.o "${archives[@]}" libperl.a $(cat ext.libs)
  cat >"$framework/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>$name</string>
<key>CFBundleIdentifier</key><string>org.perl.$name</string>
<key>CFBundleName</key><string>$name</string>
<key>CFBundlePackageType</key><string>FMWK</string>
<key>CFBundleVersion</key><string>1</string>
<key>CFBundleShortVersionString</key><string>5.34.0</string>
<key>MinimumOSVersion</key><string>14.0</string>
<key>CFBundleSupportedPlatforms</key><array><string>$platform</string></array>
</dict></plist>
PLIST
done
