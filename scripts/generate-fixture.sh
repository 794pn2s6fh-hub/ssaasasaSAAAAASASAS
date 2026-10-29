#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p out/PoCFixture
clang -fobjc-arc -framework Foundation -framework ImageIO -framework CoreGraphics \
  -o out/PoCFixture/gen_heic PoCFixture/gen_heic.m
out/PoCFixture/gen_heic out/PoCFixture/trigger.heic
cp PoCFixture/index.html out/PoCFixture/index.html
cp PoCFixture/LICENSE out/PoCFixture/LICENSE
printf 'Fixture created in %s\n' "$PWD/out/PoCFixture"
