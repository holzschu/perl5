#!/bin/bash
# Run from a fresh Perl 5.34.0 source directory.
set -euo pipefail
recipe=$1
work=$2
sdk=$3
arch=$4
sdkroot=$(xcrun --sdk "$sdk" --show-sdk-path)
if [ "$sdk" = iphoneos ]; then
  triple="$arch-apple-ios14.0"
  slice=ios-arm64
else
  triple="$arch-apple-ios14.0-simulator"
  slice=ios-arm64_x86_64-simulator
fi
frameworks="$work/deps/ios_system.xcframework/$slice"
# Recover the original port's config, without evaluating Config.pm on the host.
perl -0777 -ne ' /\$_ = <<\x27!END!\x27;\n(.*?)\n!END!/s or die "config block missing"; print "$1\n" ' "$work/Config_heavy.pl" >config.sh
# Discard machine-specific provenance; all toolchain paths are set below.
perl -i -pe 's{^([^=]+)=.*(?:/Users/|/Applications/).*$}{$1=\x27\x27}; s{^config_arg\d+=.*$}{}' config.sh
cat >>config.sh <<CONFIG
cc='clang'
ld='clang'
ccflags='-target $triple -isysroot $sdkroot -DPERL_DARWIN -DPERL_IOS -DPERL_USE_SAFE_PUTENV -fno-common -fno-strict-aliasing -fstack-protector-strong -Wno-error=implicit-function-declaration -Wno-deprecated-declarations -Wno-compound-token-split-by-macro -Wno-macro-redefined -I$work/deps'
cppflags='-target $triple -isysroot $sdkroot -DPERL_DARWIN -DPERL_IOS -DPERL_USE_SAFE_PUTENV -I$work/deps'
ldflags='-target $triple -isysroot $sdkroot -F$frameworks -framework ios_system'
lddlflags='-dynamiclib -target $triple -isysroot $sdkroot'
cccdlflags=''
ccdlflags=''
optimize='-O2'
ccwarnflags='-Wall -Wextra -Wno-compound-token-split-by-macro -Wno-macro-redefined'
libs=''
perllibs=''
libpth=''
libspath=''
locincpth=''
loclibpth=''
incpth=''
usrinc='$sdkroot/usr/include'
cppstdin='clang -E'
cppminus='-'
cpprun='clang -E'
ar='ar'
full_ar='ar'
ranlib='ranlib'
nm='nm'
_exe=''
exe_ext=''
usecrosscompile='define'
hostperl='$work/host/miniperl'
hostgenerate='$work/host/generate_uudmap'
hostosname='darwin'
targetarch='$arch-apple-darwin'
archname='darwin-2level'
usevfork='false'
d_vfork='undef'
d_fork='undef'
d_futimes='undef'
d_gethostent='undef'
d_getnetent='undef'
d_getnetbyaddr='undef'
d_getnetbyname='undef'
d_endhostent='undef'
d_endnetent='undef'
d_sethostent='undef'
d_setnetent='undef'
usensgetexecutablepath='undef'
CONFIG
# Config.pm looks up the first textual occurrence; keep one value per key.
perl -0777 -i -pe 'my %seen; $_ = join "", reverse grep { !/^(\w+)=/ or !$seen{$1}++ } reverse split /(?=^\w+=)/m, $_;' config.sh
cp "$recipe/ios/ios_port.h" "$work/deps/ios_port.h"
patch -p1 <"$recipe/ios/perl-ios.patch"
sh Configure -S
