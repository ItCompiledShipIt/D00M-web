#!/usr/bin/env bash
# Build the browser bundle into web/ (index.html + d00m.js + d00m_bg.wasm).
# Needs: the wasm32 target (`rustup target add wasm32-unknown-unknown`) and
# the wasm-bindgen CLI at the same version as the crate in Cargo.lock.
set -euo pipefail
cd "$(dirname "$0")"

cargo build --release --target wasm32-unknown-unknown
wasm-bindgen --target web --out-dir web --out-name d00m \
    target/wasm32-unknown-unknown/release/d00m.wasm
cp index.html web/index.html

echo
echo "Built web/. Try it with:"
echo "  python3 -m http.server 8901 -d web"
echo "then open http://localhost:8901/"
