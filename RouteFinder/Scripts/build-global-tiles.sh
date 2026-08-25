#!/bin/bash
set -euo pipefail

# Build global OSM H3 routing tiles for chunked online delivery.
#
# Prerequisites (optional — script degrades gracefully):
#   brew install osmium-tool   # or apt install osmium-tool
#   python3                    # for GeoJSON → CSV conversion
#
# Usage:
#   ./Scripts/build-global-tiles.sh --pbf planet.osm.pbf --output ./tiles/global --resolution 7
#   ./Scripts/build-global-tiles.sh --region norfolk --pbf norfolk.osm.pbf --output ./tiles/norfolk
#   ./Scripts/build-global-tiles.sh --csv ./data/norfolk --output ./tiles/norfolk
#
# Osmium profile: Scripts/osmium-hgv-export.yaml
# Converter:      Scripts/osm-geojson-to-csv.py
#
# CDN upload (free tiers):
#   - Cloudflare R2 (10 GB free): wrangler r2 object put tiles/<cell>.graphjson --file=...
#   - GitHub Releases: attach continent bundles as .tar.gz
#   - nginx static: rsync -av tiles/ user@host:/var/www/tiles/
#
# App configuration:
#   Set Tile Server URL in RouteFinder Settings to your CDN base, e.g.
#   https://cdn.example.com/tiles/
#   Or pre-place *.graphjson under:
#   ~/Library/Application Support/RouteFinder/tiles/

PBF=""
CSV_INPUT=""
OUTPUT=""
REGION=""
RESOLUTION=7
WORK_DIR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pbf) PBF="$2"; shift 2 ;;
    --csv) CSV_INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --region) REGION="$2"; shift 2 ;;
    --resolution) RESOLUTION="$2"; shift 2 ;;
    --work-dir) WORK_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,30p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $1"; exit 1 ;;
  esac
done

if [[ -z "$OUTPUT" ]]; then
  echo "Error: --output is required"
  exit 1
fi

if [[ -z "$PBF" && -z "$CSV_INPUT" ]]; then
  echo "Error: provide --pbf <file> or --csv <dir with nodes.csv/edges.csv>"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCRIPT_DIR="$ROOT/Scripts"
EXPORT_CONFIG="$SCRIPT_DIR/osmium-hgv-export.yaml"
GEOJSON_CONVERTER="$SCRIPT_DIR/osm-geojson-to-csv.py"

if [[ -z "$WORK_DIR" ]]; then
  WORK_DIR="$(mktemp -d)"
  CLEANUP_WORK=1
else
  CLEANUP_WORK=0
  mkdir -p "$WORK_DIR"
fi

CSV_DIR="$WORK_DIR/csv"
mkdir -p "$CSV_DIR" "$OUTPUT"

copy_existing_csv() {
  local src="$1"
  if [[ ! -f "$src/nodes.csv" || ! -f "$src/edges.csv" ]]; then
    echo "Error: --csv directory must contain nodes.csv and edges.csv: $src"
    exit 1
  fi
  cp "$src/nodes.csv" "$CSV_DIR/nodes.csv"
  cp "$src/edges.csv" "$CSV_DIR/edges.csv"
  echo "==> Using existing CSV from $src"
}

try_osmium_export() {
  local pbf="$1"

  if ! command -v osmium >/dev/null 2>&1; then
    echo "⚠ osmium-tool not found — skipping PBF→CSV conversion."
    echo "  Install with: brew install osmium-tool"
    echo "  Or convert offline and re-run with: --csv <dir> --output $OUTPUT"
    return 1
  fi

  if [[ ! -f "$EXPORT_CONFIG" ]]; then
    echo "⚠ Missing osmium export config at $EXPORT_CONFIG"
    return 1
  fi

  echo "==> Extracting drivable ways from $pbf"
  osmium tags-filter "$pbf" w/highway -o "$WORK_DIR/roads.osm.pbf" --overwrite

  echo "==> Exporting roads GeoJSON with HGV tags (osmium-hgv-export.yaml)"
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

  local geojson="$WORK_DIR/roads.geojson"
  if ! osmium export "$WORK_DIR/roads.osm.pbf" \
      -c "$EXPORT_CONFIG" \
      -f geojson \
      -o "$geojson" \
      --overwrite; then
    echo "⚠ osmium export failed — check osmium-tool version and config."
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    echo "⚠ python3 not found — cannot convert GeoJSON to nodes.csv/edges.csv."
    echo "  Install Python 3, or convert $geojson yourself and re-run with --csv."
    cat > "$CSV_DIR/README.txt" <<EOF
Osmium exported GeoJSON to:
  $geojson

Convert to nodes.csv + edges.csv (see Scripts/osm-geojson-to-csv.py), then:
  ./Scripts/build-global-tiles.sh --csv <csv-dir> --output $OUTPUT
EOF
    return 1
  fi

  echo "==> Converting GeoJSON → nodes.csv / edges.csv"
  if ! python3 "$GEOJSON_CONVERTER" --input "$geojson" --output "$CSV_DIR"; then
    echo "⚠ GeoJSON→CSV conversion failed."
    return 1
  fi
  return 0
}

if [[ -n "$CSV_INPUT" ]]; then
  copy_existing_csv "$CSV_INPUT"
elif [[ -n "$PBF" ]]; then
  if ! try_osmium_export "$PBF"; then
    cat > "$CSV_DIR/README.txt" <<'EOF'
Convert roads.osm.pbf to nodes.csv + edges.csv using osmium export + Scripts/osm-geojson-to-csv.py.

Edge CSV header (16 columns):
from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,max_height,max_weight,max_width,max_length,has_camera,is_one_way,hgv_restricted,road_name

Parse OSM maxheight like "3.5 m" or "11'6\"" into metres.
Set hgv_restricted=1 when hgv=no or motor_vehicle=no on the way.

After CSV export, re-run with:
  ./Scripts/build-global-tiles.sh --csv <dir> --output <tiles-dir>
EOF
    echo "Wrote conversion instructions to $CSV_DIR/README.txt"
  fi
fi

if [[ -f "$CSV_DIR/nodes.csv" && -f "$CSV_DIR/edges.csv" ]]; then
  echo "==> Building H3 tiles at resolution $RESOLUTION"
  swift run PBFPreprocessor --mode csv --input "$CSV_DIR" --output "$OUTPUT" --resolution "$RESOLUTION"
  TILE_COUNT=$(find "$OUTPUT" -name '*.graphjson' | wc -l | tr -d ' ')
  echo "==> Exported $TILE_COUNT tiles to $OUTPUT"
  echo "Upload *.graphjson to your CDN; filename must match <h3hex>.graphjson"
  echo "Or copy into Application Support/RouteFinder/tiles/ for offline use."
else
  echo "No CSV found at $CSV_DIR — export OSM to CSV first (see README.txt)."
  if [[ -n "$REGION" ]]; then
    echo "Tip: download extract from https://download.geofabrik.de/ for region '$REGION'"
  fi
  if [[ "$CLEANUP_WORK" -eq 1 ]]; then
    # Keep README if present by copying before cleanup
    if [[ -f "$CSV_DIR/README.txt" ]]; then
      mkdir -p "$OUTPUT"
      cp "$CSV_DIR/README.txt" "$OUTPUT/CSV_CONVERSION_README.txt"
    fi
  fi
fi

if [[ "$CLEANUP_WORK" -eq 1 ]]; then
  rm -rf "$WORK_DIR"
fi
