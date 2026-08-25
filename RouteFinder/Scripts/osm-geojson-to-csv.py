#!/usr/bin/env python3
"""Convert osmium-export GeoJSON (LineStrings) into RouteFinder nodes.csv / edges.csv.

Expected GeoJSON: FeatureCollection of LineString (or MultiLineString) features
with OSM tags from Scripts/osmium-hgv-export.yaml.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from pathlib import Path
from typing import Any


EDGE_HEADER = (
    "from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,"
    "max_height,max_weight,max_width,max_length,has_camera,is_one_way,"
    "hgv_restricted,road_name"
)


def parse_length_metres(raw: str | None) -> float:
    if not raw:
        return 0.0
    text = str(raw).strip().lower().replace(",", ".")
    # feet'inches"
    m = re.match(r"^(\d+)'\s*(\d+(?:\.\d+)?)\"?$", text)
    if m:
        return float(m.group(1)) * 0.3048 + float(m.group(2)) * 0.0254
    m = re.match(r"^(\d+(?:\.\d+)?)\s*(m|metre|metres|meter|meters)?$", text)
    if m:
        return float(m.group(1))
    m = re.match(r"^(\d+(?:\.\d+)?)\s*ft$", text)
    if m:
        return float(m.group(1)) * 0.3048
    try:
        return float(re.findall(r"[\d.]+", text)[0])
    except (IndexError, ValueError):
        return 0.0


def parse_weight_tonnes(raw: str | None) -> float:
    if not raw:
        return 0.0
    text = str(raw).strip().lower().replace(",", ".")
    m = re.match(r"^(\d+(?:\.\d+)?)\s*(t|ton|tons|tonne|tonnes)?$", text)
    if m:
        return float(m.group(1))
    m = re.match(r"^(\d+(?:\.\d+)?)\s*kg$", text)
    if m:
        return float(m.group(1)) / 1000.0
    try:
        return float(re.findall(r"[\d.]+", text)[0])
    except (IndexError, ValueError):
        return 0.0


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    r = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lon2 - lon1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


def road_type(highway: str | None) -> str:
    if not highway:
        return "unknown"
    mapping = {
        "motorway": "motorway",
        "motorway_link": "motorway",
        "trunk": "trunk",
        "trunk_link": "trunk",
        "primary": "primary",
        "primary_link": "primary",
        "secondary": "secondary",
        "secondary_link": "secondary",
        "tertiary": "tertiary",
        "tertiary_link": "tertiary",
        "residential": "residential",
        "living_street": "residential",
        "service": "service",
        "unclassified": "unclassified",
        "road": "unclassified",
        "track": "track",
        "path": "path",
        "cycleway": "cycleway",
        "footway": "footway",
        "pedestrian": "footway",
        "steps": "footway",
    }
    return mapping.get(highway, "unknown")


def default_speed(highway: str | None) -> float:
    speeds = {
        "motorway": 112,
        "motorway_link": 80,
        "trunk": 96,
        "trunk_link": 64,
        "primary": 80,
        "primary_link": 48,
        "secondary": 64,
        "secondary_link": 48,
        "tertiary": 48,
        "tertiary_link": 40,
        "residential": 30,
        "living_street": 20,
        "service": 20,
        "unclassified": 40,
    }
    return float(speeds.get(highway or "", 40))


def csv_escape(value: str) -> str:
    if any(c in value for c in [",", '"', "\n"]):
        return '"' + value.replace('"', '""') + '"'
    return value


def node_key(lat: float, lon: float) -> str:
    return f"{lat:.6f},{lon:.6f}"


def iter_lines(geom: dict[str, Any]):
    gtype = geom.get("type")
    coords = geom.get("coordinates") or []
    if gtype == "LineString":
        yield coords
    elif gtype == "MultiLineString":
        for line in coords:
            yield line


def convert(geojson_path: Path, out_dir: Path) -> tuple[int, int]:
    data = json.loads(geojson_path.read_text(encoding="utf-8"))
    features = data.get("features") or []

    nodes: dict[str, tuple[str, float, float, str]] = {}
    edges: list[str] = []
    next_id = 1

    def ensure_node(lat: float, lon: float, name: str) -> str:
        nonlocal next_id
        key = node_key(lat, lon)
        if key not in nodes:
            nid = f"N{next_id}"
            next_id += 1
            nodes[key] = (nid, lat, lon, name)
        return nodes[key][0]

    for feature in features:
        props = feature.get("properties") or {}
        highway = props.get("highway")
        if not highway:
            continue
        geom = feature.get("geometry") or {}
        name = str(props.get("name") or "")
        max_h = parse_length_metres(props.get("maxheight"))
        max_w = parse_weight_tonnes(props.get("maxweight"))
        max_width = parse_length_metres(props.get("maxwidth"))
        max_len = parse_length_metres(props.get("maxlength"))
        oneway = str(props.get("oneway") or "").lower() in {"yes", "true", "1", "-1"}
        hgv = str(props.get("hgv") or "").lower()
        motor = str(props.get("motor_vehicle") or "").lower()
        hgv_restricted = 1 if hgv in {"no", "private"} or motor in {"no", "private"} else 0
        is_toll = 1 if str(props.get("toll") or "").lower() in {"yes", "true", "1"} else 0
        is_tunnel = 1 if str(props.get("tunnel") or "").lower() in {"yes", "true", "1"} else 0
        is_ferry = 1 if str(props.get("route") or "").lower() == "ferry" or highway == "ferry" else 0
        rtype = road_type(str(highway))
        speed = default_speed(str(highway))

        for line in iter_lines(geom):
            if len(line) < 2:
                continue
            for i in range(len(line) - 1):
                lon1, lat1 = float(line[i][0]), float(line[i][1])
                lon2, lat2 = float(line[i + 1][0]), float(line[i + 1][1])
                a = ensure_node(lat1, lon1, name)
                b = ensure_node(lat2, lon2, name)
                dist = haversine_m(lat1, lon1, lat2, lon2)
                if dist < 0.5:
                    continue
                road_name = csv_escape(name)
                row = (
                    f"{a},{b},{dist:.2f},{speed:.0f},{rtype},{is_toll},{is_ferry},{is_tunnel},"
                    f"{max_h:.2f},{max_w:.2f},{max_width:.2f},{max_len:.2f},0,"
                    f"{1 if oneway else 0},{hgv_restricted},{road_name}"
                )
                edges.append(row)
                if not oneway:
                    edges.append(
                        f"{b},{a},{dist:.2f},{speed:.0f},{rtype},{is_toll},{is_ferry},{is_tunnel},"
                        f"{max_h:.2f},{max_w:.2f},{max_width:.2f},{max_len:.2f},0,0,"
                        f"{hgv_restricted},{road_name}"
                    )

    out_dir.mkdir(parents=True, exist_ok=True)
    nodes_path = out_dir / "nodes.csv"
    edges_path = out_dir / "edges.csv"
    with nodes_path.open("w", encoding="utf-8") as fh:
        fh.write("id,latitude,longitude,name\n")
        for nid, lat, lon, name in nodes.values():
            fh.write(f"{nid},{lat:.7f},{lon:.7f},{csv_escape(name)}\n")
    with edges_path.open("w", encoding="utf-8") as fh:
        fh.write(EDGE_HEADER + "\n")
        for row in edges:
            fh.write(row + "\n")
    return len(nodes), len(edges)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, help="GeoJSON from osmium export")
    parser.add_argument("--output", required=True, help="Directory for nodes.csv / edges.csv")
    args = parser.parse_args()
    n_nodes, n_edges = convert(Path(args.input), Path(args.output))
    print(f"Wrote {n_nodes} nodes and {n_edges} edges to {args.output}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
