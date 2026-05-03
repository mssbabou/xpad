#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

echo "Regenerating FFI bindings from native/header/*"
dart run tool/ffigen.dart

echo "Done. lib/*.g.dart updated."
