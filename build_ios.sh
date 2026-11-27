#!/bin/bash
set -euo pipefail
recipe=$(cd "$(dirname "$0")" && pwd)
work=${PERL_IOS_BUILD_DIR:-$recipe/.build/ios}
mkdir -p "$work"
work=$(cd "$work" && pwd)
fetch() {
  local url=$1 path=$2 sum=$3
  if [ ! -f "$path" ]; then curl -fLsS --retry 3 "$url" -o "$path"; fi
  printf '%s  %s\n' "$sum" "$path" | shasum -a 256 -c -
}
fetch https://www.cpan.org/src/5.0/perl-5.34.0.tar.gz "$work/perl.tar.gz" 551efc818b968b05216024fb0b727ef2ad4c100f8cb6b43fab615fa78ae5be9a
fetch https://raw.githubusercontent.com/holzschu/a-shell/0dfdbc0aa75c58328fb2cb1e478ad92018d18c7a/Resources/Perl/Config_heavy.pl "$work/Config_heavy.pl" 0fb095eb4a234f99e525fdeb5122c4f0c16029de240f3c4a80267ff4f5ac5592
fetch https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_system.xcframework.zip "$work/ios_system.zip" 635fc346304416f05f94a61ded08a2a5792f5072081eca7c142834326366d4d0
mkdir -p "$work/deps"
unzip -qo "$work/ios_system.zip" -d "$work/deps"
fetch https://github.com/holzschu/ios_system/releases/download/v3.0.1/ios_error.h "$work/deps/ios_error.h" e5a68bfcddac3a24cce484d1f63202e8c6459e88fe5c3cd463fe43f47fafbcd3
if [ ! -f "$work/host/.built" ]; then
  mkdir -p "$work/host"
  tar -xzf "$work/perl.tar.gz" -C "$work/host" --strip-components=1
  (
    cd "$work/host"
    nice -n 15 sh Configure -des -Dprefix=/usr -Dcc=clang -Dccflags=-Wno-error=implicit-function-declaration -Uusethreads -Uusemultiplicity -Uuseshrplib -Ud_pipe2 -Ud_dup3
    nice -n 15 make -j2 miniperl generate_uudmap
    ./miniperl -e 'print "Host miniperl $^V OK\n"'
    touch .built
  )
fi
fingerprint=$(cat "$recipe/ios/configure.sh" "$recipe/ios/perl-ios.patch" "$recipe/ios/ios_port.h" | shasum -a 256 | awk '{print $1}')
for spec in ${PERL_IOS_SLICES:-iphoneos:arm64 iphonesimulator:arm64 iphonesimulator:x86_64}; do
  sdk=${spec%:*}
  arch=${spec#*:}
  src="$work/$sdk-$arch"
  if [ "$(cat "$src/.configured" 2>/dev/null || :)" != "$fingerprint" ]; then
    rm -rf "$src"
    mkdir -p "$src"
    tar -xzf "$work/perl.tar.gz" -C "$src" --strip-components=1
    (
      cd "$src"
      bash "$recipe/ios/configure.sh" "$recipe" "$work" "$sdk" "$arch"
      printf '%s\n' "$fingerprint" >.configured
    )
  fi
  (
    cd "$src"
    TIME_HIRES_DONT_RUN_PROBES=1 nice -n 15 make -j2 AR=ar perl
  )
  bash "$recipe/ios/frameworks.sh" "$work" "$sdk" "$arch"
done
if [ "${PERL_IOS_SLICES:-}" = "" ]; then
  bash "$recipe/ios/package.sh" "$work" "$recipe/.build"
fi
