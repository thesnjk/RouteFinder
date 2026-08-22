#!/bin/bash
set -euo pipefail

# Preprocess routing data into H3-indexed graph tiles.
#
# Usage:
#   ./Scripts/preprocess-osm.sh --input ./data/norfolk --output ./tiles
#   ./Scripts/preprocess-osm.sh --mode synthetic --output ./tiles/demo

MODE="csv"
INPUT=""
OUTPUT=""
RESOLUTION=7

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ARGS=(--output "$OUTPUT" --mode "$MODE" --resolution "$RESOLUTION")
if [[ -n "$INPUT" ]]; then
  ARGS+=(--input "$INPUT")
fi

swift run PBFPreprocessor "${ARGS[@]}"
