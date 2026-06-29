#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="out"
mkdir -p "$OUT_DIR"

cat README_output.txt > "$OUT_DIR/README.txt"

cat >> "$OUT_DIR/README.txt" << EOF

* Version
This version of this README generated from git commit: $(git describe --always)
EOF
