#!/bin/bash
set -euo pipefail

# Build global OSM H3 routing tiles for chunked online delivery.
#
# Prerequisites:
#   brew install osmium-tool   # or apt install osmium-tool
#
# Usage:
#   ./Scripts/build-global-tiles.sh --pbf planet.osm.pbf --output ./tiles/global --resolution 7
#   ./Scripts/build-global-tiles.sh --region norfolk --pbf norfolk.osm.pbf --output ./tiles/norfolk
#
# CDN upload (free tiers):
#   - Cloudflare R2 (10 GB free): wrangler r2 object put tiles/<cell>.graphjson --file=...
#   - GitHub Releases: attach continent bundles as .tar.gz
#   - nginx static: rsync -av tiles/ user@host:/var/www/tiles/
#
# App configuration:
#   Set Tile Server URL in RouteFinder Settings to your CDN base, e.g.
#   https://cdn.example.com/tiles/

PBF=""
OUTPUT=""
REGION=""
RESOLUTION=7
WORK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pbf) PBF="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$(mktemp -d)"
  CLEANUP_WORK=1
else
  CLEANUP_WORK=0
  mkdir -p "$WORK_DIR"
fi

CSV_DIR="$WORK_DIR/csv"
mkdir -p "$CSV_DIR" "$OUTPUT"

if [[ -n "$PBF" ]]; then
  if ! command -v osmium >/dev/null 2>&1; then
    echo "Error: osmium-tool is required. Install with: brew install osmium-tool"
    exit 1
  fi

  echo "==> Extracting drivable ways from $PBF"
  osmium tags-filter "$PBF" w/highway -o "$WORK_DIR/roads.osm.pbf" --overwrite

  echo "==> Exporting nodes.csv and edges.csv with HGV tags"
  echo "    OSM tags mapped to CSV columns:"
  echo "      highway      -> road_type"
  echo "      maxheight    -> max_height (metres)"
  echo "      maxweight    -> max_weight (tonnes)"
  echo "      maxwidth     -> max_width"
  echo "      maxlength    -> max_length"
  echo "      hgv=no       -> hgv_restricted=true"
  echo "      motor_vehicle=no -> hgv_restricted=true"
  echo "      oneway=yes   -> is_one_way=true"
  echo "      name         -> road_name"

  # Requires a custom osmium export profile or ogr2osm pipeline.
  # Placeholder: document expected CSV layout; convert with your regional toolchain.
  cat > "$CSV_DIR/README.txt" <<'EOF'
Convert roads.osm.pbf to nodes.csv + edges.csv using osmium export or osmosis.

Edge CSV header (16 columns):
from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,max_height,max_weight,max_width,max_length,has_camera,is_one_way,hgv_restricted,road_name

Parse OSM maxheight like "3.5 m" or "11'6\"" into metres.
Set hgv_restricted=1 when hgv=no or motor_vehicle=no on the way.
EOF

  echo "Wrote conversion instructions to $CSV_DIR/README.txt"
  echo "After CSV export, re-run with: --csv $CSV_DIR --output $OUTPUT"
fi

if [[ -d "$CSV_DIR" && -f "$CSV_DIR/nodes.csv" && -f "$CSV_DIR/edges.csv" ]]; then
  echo "==> Building H3 tiles at resolution $RESOLUTION"
  swift run PBFPreprocessor --mode csv --input "$CSV_DIR" --output "$OUTPUT" --resolution "$RESOLUTION"
  TILE_COUNT=$(find "$OUTPUT" -name '*.graphjson' | wc -l | tr -d ' ')
  echo "==> Exported $TILE_COUNT tiles to $OUTPUT"
  echo "Upload *.graphjson to your CDN; filename must match <h3hex>.graphjson"
else
  echo "No CSV found at $CSV_DIR — export OSM to CSV first (see README.txt)."
  if [[ -n "$REGION" ]]; then
    echo "Tip: download extract from https://download.geofabrik.de/ for region '$REGION'"
  fi
fi

if [[ "$CLEANUP_WORK" -eq 1 ]]; then
  rm -rf "$WORK_DIR"
fi
