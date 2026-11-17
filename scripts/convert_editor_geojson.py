#!/usr/bin/env python3
"""Convert user-exported GEO LAB 2.0 GeoJSON to Godot-local EPSG:32640 metres.

This is an explicit review/import step, NOT an automatic overwrite of 3D content.

Example:
  python -m pip install pyproj
  python scripts/convert_editor_geojson.py downloads/chernozerye-sector-survey.geojson \
      --output godot/manual_layout.json

Input coordinates are WGS84 [longitude, latitude]. Output world_data-compatible
2D points are [east_metres, north_metres] relative to existing project centre.
In Godot use Vector3(east, height, -north) for geographic orientation.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path
import sys
from datetime import datetime, timezone

from pyproj import Transformer

ROOT = Path(__file__).resolve().parents[1]
WORLD_PATH = ROOT / "godot" / "world_data.json"
SUPPORTED = {
    "road": "LineString",
    "path": "LineString",
    "water": "Polygon",
    "forest": "Polygon",
    "plot": "Polygon",
    "object": "Polygon",
    "house": "Polygon",
    "shed": "Polygon",
    "sauna": "Polygon",
    "car": "Point/Polygon",
}

def ensure_location(point: object) -> tuple[float, float]:
    if not isinstance(point, list) or len(point) != 2:
        raise ValueError("Each coordinate must be [longitude, latitude].")
    lon, lat = map(float, point)
    if not 55.70 <= lon <= 56.05 or not 54.55 <= lat <= 54.85:
        raise ValueError(f"Coordinate outside the Chernozerye project area: {point!r}")
    return lon, lat

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="GeoJSON exported by Geo Lab 2.0")
    parser.add_argument("--output", type=Path, default=ROOT / "godot/manual_layout.json")
    args = parser.parse_args()

    doc = json.loads(args.input.read_text(encoding="utf-8"))
    if doc.get("type") != "FeatureCollection" or not isinstance(doc.get("features"), list):
        raise SystemExit("Not a GeoJSON FeatureCollection")
    if doc.get("metadata", {}).get("schema") != "chernozerye-geo-constructor-1":
        raise SystemExit("Unrecognized schema: use GeoJSON exported from the Geo Lab constructor.")
    if not doc["features"]:
        raise SystemExit("The exported file is empty; no changes were made.")

    survey = json.loads(WORLD_PATH.read_text(encoding="utf-8"))["metadata"]
    center_lat = float(survey["center_lat"])
    center_lon = float(survey["center_lon"])
    transformer = Transformer.from_crs("EPSG:4326", "EPSG:32640", always_xy=True)
    cx, cy = transformer.transform(center_lon, center_lat)

    def to_local(point: object) -> list[float]:
        lon, lat = ensure_location(point)
        x, y = transformer.transform(lon, lat)
        return [round(x - cx, 3), round(y - cy, 3)]

    processed, used_ids = [], set()
    for source in doc["features"]:
        properties = source.get("properties", {})
        geom = source.get("geometry", {})
        category = str(properties.get("category", ""))
        if category not in SUPPORTED:
            raise SystemExit(f"Unknown object category: {category}")
        geometry_type = geom.get("type")
        expected = SUPPORTED[category]
        if geometry_type != expected and not (
            category == "car" and geometry_type in ("Point", "Polygon")
        ):
            raise SystemExit(f"Unexpected geometry for {category}: {geometry_type}")
        ident = str(properties.get("id", source.get("id", "")))
        if not ident or ident in used_ids:
            raise SystemExit(f"Missing or duplicate object ID: {ident}")
        used_ids.add(ident)
        coords = geom.get("coordinates")
        if geometry_type == "Point":
            world_points = [to_local(coords)]
        elif geometry_type == "LineString":
            if not isinstance(coords, list) or not 2 <= len(coords) <= 5000:
                raise SystemExit(f"Invalid line for {ident}")
            world_points = [to_local(pt) for pt in coords]
        else:
            if not isinstance(coords, list) or not coords or not isinstance(coords[0], list):
                raise SystemExit(f"Invalid polygon for {ident}")
            raw = coords[0]
            if not 4 <= len(raw) <= 5001 or raw[0] != raw[-1]:
                raise SystemExit(f"Polygon must be closed for {ident}")
            world_points = [to_local(pt) for pt in raw[:-1]]
            if len(set(tuple(pt) for pt in world_points)) < 3:
                raise SystemExit(f"Degenerate polygon for {ident}")
        processed.append({
            "id": ident,
            "type": category,
            "geometry_type": geometry_type,
            "name": str(properties.get("name", ""))[:120],
            "notes": str(properties.get("notes", ""))[:600],
            "points": world_points,
            "source": "user_manual_geo_lab_2"
        })

    out = {
        "metadata": {
            "projection": "EPSG:32640",
            "origin_lat": center_lat,
            "origin_lon": center_lon,
            "units": "metres",
            "coordinate_convention": "x=east, y=north; Godot Vector3(x, elevation, -y)",
            "source": "User-supplied Geo Lab 2.0 manual survey",
            "converted_at_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "type_counts": dict(Counter(item["type"] for item in processed)),
            "reviewed": False,
            "notice": "Human review required before replacing any world objects."
        },
        "features": processed
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("MANUAL_GEO_READY:", len(processed), "objects", out["metadata"]["type_counts"])
    print("Created:", args.output)

if __name__ == "__main__":
    main()
