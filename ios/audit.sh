#!/bin/bash
set -euo pipefail
out=$1
(
  cd "$out"
  shasum -a 256 -c checksums.txt
)
for name in perl perlA perlB; do
  zip="$out/$name.xcframework.zip"
  unzip -tq "$zip"
  expected=$(awk -v name="$name.xcframework.zip" '$2 == name {print $1}' "$out/checksums.txt")
  [ "$(swift package compute-checksum "$zip")" = "$expected" ]
  xcf="$out/$name.xcframework"
  [ -d "$xcf/ios-arm64" ]
  [ -d "$xcf/ios-arm64_x86_64-simulator" ]
  plutil -convert json -o - "$xcf/Info.plist" | jq -r \
    '.AvailableLibraries[] | [.LibraryIdentifier, .LibraryPath, (.SupportedArchitectures | sort | join(" "))] | @tsv' |
    while IFS=$'\t' read -r slice lib expected; do
      bin="$xcf/$slice/$lib/$name"
      actual=$(lipo -archs "$bin" | tr ' ' '\n' | sort | paste -sd ' ' -)
      [ "$actual" = "$expected" ]
      printf '%s %s %s\n' "$name" "$slice" "$actual"
      nm -arch arm64 -gU "$bin" | awk '$3 == "_main" {found=1} END {exit !found}'
      otool -L "$bin"
      while read -r dep; do
        case "$dep" in
        "@rpath/$name.framework/$name" | @rpath/ios_system.framework/ios_system | /usr/lib/* | /System/Library/*) ;;
        *)
          echo "Unexpected dependency: $dep" >&2
          exit 1
          ;;
        esac
      done < <(otool -arch arm64 -L "$bin" | awk '/^\t/ {print $1}')
    done
done
