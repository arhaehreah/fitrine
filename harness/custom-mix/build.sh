#!/bin/sh
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SRC="$HERE/../../tweak/Sources"
OUT="$HERE/build"
mkdir -p "$OUT"
SDK=$(xcrun --sdk macosx --show-sdk-path)
xcrun --sdk macosx clang -fobjc-arc -O1 -g   -isysroot "$SDK" -I"$SRC"   "$HERE/check.m"   "$SRC/Shared/CustomMix/SGCustomMixModel.m"   "$SRC/Shared/CustomMix/SGCustomMixDSP.m"   -framework Foundation -framework AudioToolbox   -o "$OUT/check"
"$OUT/check"
