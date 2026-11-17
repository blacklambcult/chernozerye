#!/usr/bin/env python3
"""Download licensed Overture building polygons for Chernozerye's 2x2 km UTM square.

Usage: pip install overturemaps pyproj shapely
       python scripts/import_overture_buildings.py

This never reads Google Maps imagery. It produces an *audit-only* Godot JSON
source: do not silently replace existing 3D buildings before visual review.
"""
import json
import math
import shutil
import subprocess
import tempfile
from datetime import datetime, timezone
from pathlib import Path

from pyproj import Transformer
from shapely.geometry import Polygon, box, shape
from shapely.ops import transform

ROOT = Path(__file__).resolve().parents[1]
OSM_FILE = ROOT / "godot" / "world_data.json"
OUT_FILE = ROOT / "godot" / "overture_buildings.json"


def read_geojson(path: Path):
    """Accept a FeatureCollection, a single Feature or GeoJSONSeq/NDJSON."""
    with path.open(encoding="utf-8") as file:
        first = file.read(1024).lstrip()
        file.seek(0)
        if first.startswith('{"type": "FeatureCollection"') or (
            first.startswith('{"type":"FeatureCollection"')
        ):
            return json.load(file).get("features", [])
        if first.startswith('{"type": "Feature"') and '"features"' in first:
            payload = json.load(file)
            return payload.get("features", [])
        # Overture GeoJSON CLI normally writes newline-delimited features.
        result = []
        for line in file:
            line = line.strip().lstrip("\x1e")
            if not line:
                continue
            obj = json.loads(line)
            if obj.get("type") == "FeatureCollection":
                result.extend(obj.get("features", []))
            elif obj.get("type") == "Feature":
                result.append(obj)
        return result


def main():
    meta = json.loads(OSM_FILE.read_text(encoding="utf-8"))["metadata"]
    lat, lon = float(meta["center_lat"]), float(meta["center_lon"])
    forward = Transformer.from_crs("EPSG:4326", "EPSG:32640", always_xy=True)
    inverse = Transformer.from_crs("EPSG:32640", "EPSG:4326", always_xy=True)
    cx, cy = forward.transform(lon, lat)
    half = float(meta.get("size_m", 2000)) / 2
    corners = [inverse.transform(cx + x, cy + y)
               for x in (-half, half) for y in (-half, half)]
    west = min(p[0] for p in corners)
    east = max(p[0] for p in corners)
    south = min(p[1] for p in corners)
    north = max(p[1] for p in corners)
    bbox = ",".join(f"{value:.7f}" for value in (west, south, east, north))
    executable = shutil.which("overturemaps")
    if not executable:
        raise SystemExit("Missing overturemaps CLI; run pip install overturemaps.")

    with tempfile.TemporaryDirectory() as temp:
        geojson = Path(temp) / "buildings.geojson"
        cmd = [executable, "download", f"--bbox={bbox}", "-f", "geojson",
               "--type=building", "-o", str(geojson)]
        print("Overture building query bbox:", bbox, flush=True)
        subprocess.run(cmd, check=True, timeout=480)
        raw = read_geojson(geojson)

    boundary = box(-half, -half, half, half)
    records = []
    seen = set()
    for feature in raw:
        geom = feature.get("geometry")
        if not geom:
            continue
        try:
            projected = transform(
                lambda x, y, z=None: tuple(v - o for v, o in zip(forward.transform(x, y), (cx, cy))),
                shape(geom),
            )
        except Exception:
            continue
        if projected.is_empty:
            continue
        if not projected.is_valid:
            projected = projected.buffer(0)
        if not projected.intersects(boundary):
            continue
        projected = projected.intersection(boundary)
        if projected.geom_type == "MultiPolygon":
            polygons = list(projected.geoms)
        elif projected.geom_type == "Polygon":
            polygons = [projected]
        else:
            continue
        props = feature.get("properties") or {}
        base_id = str(feature.get("id", props.get("id", "")))
        height = props.get("height")
        height = round(float(height), 1) if isinstance(height, (float, int)) and math.isfinite(height) and height > 1 else None
        for index, polygon in enumerate(polygons):
            if not isinstance(polygon, Polygon) or not 9.0 <= polygon.area <= 5000.0:
                continue
            points = [[round(x, 2), round(y, 2)] for x, y in list(polygon.exterior.coords)[:-1]]
            if len(points) < 3 or len(points) > 250:
                continue
            ident = f"{base_id}:{index}" if base_id else f"item:{len(records)}"
            if ident in seen:
                continue
            seen.add(ident)
            records.append({"id": ident, "points": points, "height_m": height})
    records.sort(key=lambda b: b["id"])
    if not records:
        raise SystemExit("Overture returned no usable buildings; keep existing map unchanged.")
    if len(records) > 5500:
        raise SystemExit(f"Unexpectedly many buildings ({len(records)}); refusing to publish unreviewed data.")

    out = {
        "metadata": {
            "name": "Overture Maps building polygons",
            "purpose": "geographic coverage audit only; 3D scene unchanged",
            "projection": "EPSG:32640",
            "center_lat": lat,
            "center_lon": lon,
            "size_m": int(half * 2),
            "features": len(records),
            "retrieved_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "credits": "Overture Maps Foundation and original contributors; respect per-source CDLA/ODbL terms",
            "reference": "https://docs.overturemaps.org/getting-data/",
        },
        "buildings": records,
    }
    OUT_FILE.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"Overture candidate polygons: {len(records)}; file bytes: {OUT_FILE.stat().st_size}", flush=True)
    print("GEODATA_READY", flush=True)


if __name__ == "__main__":
    main()
