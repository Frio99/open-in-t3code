#!/bin/sh
# Never opens the real T3 Code.
set -eu
cd "$(dirname "$0")/.."
work=$(mktemp -d)
xcrun clang -fobjc-arc -Wall -Werror -mmacosx-version-min=13.0 -arch arm64 -arch x86_64 \
  -framework Cocoa src/Launcher.m tests/test.m -o "$work/test"
echo "== native"
mkdir "$work/native" && "$work/test" "$work/native"
if arch -x86_64 /usr/bin/true 2>/dev/null; then
  echo "== x86_64"
  mkdir "$work/intel" && arch -x86_64 "$work/test" "$work/intel"
fi
