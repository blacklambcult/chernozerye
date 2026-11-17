#!/usr/bin/env python3
"""Publish auditable WGS84 vector layers for the standalone Chernozerye satellite map.

Source data are local UTM metres relative to the EPSG:32640 survey origin.
No satellite imagery is downloaded, copied, traced or stored in this project.
"""
import json
from pathlib import Path
from datetime import datetime, timezone

from pyproj import Transformer

ROOT = Path(__file__).resolve().parents[1]
OSM_PATH = ROOT / "godot/world_data.json"
OVERTURE_PATH = ROOT / "godot/overture_buildings.json"
OUT = ROOT / "build/web/map/data"


def feature_collection(features):
    return {"type": "FeatureCollection", "features": features}


def write_json(filename, obj):
    path = OUT / filename
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"{path.relative_to(ROOT)}: {path.stat().st_size:,} bytes")


def area_m2(points):
    return round(abs(sum(
        points[i][0] * points[(i + 1) % len(points)][1]
        - points[(i + 1) % len(points)][0] * points[i][1]
        for i in range(len(points))
    )) / 2, 1)


def main():
    osm = json.loads(OSM_PATH.read_text(encoding="utf-8"))
    overture = json.loads(OVERTURE_PATH.read_text(encoding="utf-8"))
    om = osm["metadata"]
    tm = overture["metadata"]
    lat, lon = float(om["center_lat"]), float(om["center_lon"])
    if abs(lat - float(tm["center_lat"])) > 0.00001 or abs(lon - float(tm["center_lon"])) > 0.00001:
        raise ValueError("OSM and Overture have different projection origins")
    side = float(om["size_m"])
    forward = Transformer.from_crs("EPSG:4326", "EPSG:32640", always_xy=True)
    inverse = Transformer.from_crs("EPSG:32640", "EPSG:4326", always_xy=True)
    e0, n0 = forward.transform(lon, lat)

    def to_lonlat(point):
        x, y = point
        wlon, wlat = inverse.transform(e0 + float(x), n0 + float(y))
        return [round(wlon, 7), round(wlat, 7)]

    def polygon(points):
        ring = [to_lonlat(p) for p in points]
        if ring[0] != ring[-1]:
            ring.append(ring[0])
        return {"type": "Polygon", "coordinates": [ring]}

    def line(points):
        return {"type": "LineString", "coordinates": [to_lonlat(p) for p in points]}

    def square(center, half):
        x, y = center
        return [[x - half, y - half], [x + half, y - half],
                [x + half, y + half], [x - half, y + half]]

    # Overture polygons are independent candidates, not a verified dwelling inventory.
    buildings = []
    for item in overture["buildings"]:
        pts = item.get("points") or []
        if len(pts) < 3:
            continue
        buildings.append({
            "type": "Feature",
            "id": str(item.get("id", "")),
            "properties": {
                "id": str(item.get("id", "")),
                "area_m2": area_m2(pts),
                "height_m": item.get("height_m"),
                "source": "Overture Maps",
                "verified": False
            },
            "geometry": polygon(pts)
        })

    roads, osm_buildings, vegetation, water = [], [], [], []
    for item in osm["features"]:
        pts = item.get("points") or []
        tags = item.get("tags") or {}
        kind = item.get("type")
        fid = item.get("id")
        if kind == "road" and len(pts) >= 2:
            roads.append({
                "type": "Feature",
                "properties": {
                    "osm_id": fid,
                    "name": tags.get("name", ""),
                    "highway": tags.get("highway", ""),
                    "source": "OpenStreetMap"
                },
                "geometry": line(pts)
            })
        elif kind == "building" and len(pts) >= 3:
            osm_buildings.append({
                "type": "Feature",
                "properties": {"osm_id": fid, "source": "OpenStreetMap"},
                "geometry": polygon(pts)
            })
        elif kind in ("forest", "wood", "grassland") and len(pts) >= 3:
            vegetation.append({
                "type": "Feature",
                "properties": {"osm_id": fid, "source": "OpenStreetMap", "kind": kind},
                "geometry": polygon(pts)
            })
        elif kind == "water" and len(pts) >= 2:
            closed = pts[0] == pts[-1] and len(pts) >= 4
            water.append({
                "type": "Feature",
                "properties": {"osm_id": fid, "source": "OpenStreetMap"},
                "geometry": polygon(pts) if closed else line(pts)
            })

    if len(buildings) < 300:
        raise ValueError("Overture dataset is unexpectedly sparse; aborting map publish")
    if not roads:
        raise ValueError("OSM roads are missing")

    OUT.mkdir(parents=True, exist_ok=True)
    write_json("overture.geojson", feature_collection(buildings))
    write_json("roads.geojson", feature_collection(roads))
    write_json("osm-buildings.geojson", feature_collection(osm_buildings))
    write_json("vegetation.geojson", feature_collection(vegetation))
    write_json("water.geojson", feature_collection(water))

    bounds = [
        {"id": "all", "label": "Вся территория · 2×2 км", "size_m": 2000,
         "geometry": polygon(square((0.0, 0.0), side / 2))},
        {"id": "a", "label": "Сектор A · 680×680 м", "size_m": 680,
         "geometry": polygon(square((-660.0, 390.0), 340.0))},
        {"id": "a-street", "label": "Квартал A · 300×300 м", "size_m": 300,
         "geometry": polygon(square((-760.0, 360.0), 150.0))}
    ]
    write_json("study-areas.geojson", feature_collection([
        {"type": "Feature", "properties": {"id": area["id"], "label": area["label"], "size_m": area["size_m"]},
         "geometry": area["geometry"]} for area in bounds
    ]))

    metadata = {
        "version": "1.9",
        "name": "Чернозёрье · Геолаборатория",
        "center": [lat, lon],
        "crs": "EPSG:4326",
        "source_projection": "EPSG:32640",
        "generated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "counts": {
            "overture": len(buildings), "osm_buildings": len(osm_buildings),
            "roads": len(roads), "vegetation": len(vegetation), "water": len(water)
        },
        "data_sources": {
            "buildings": "Overture Maps Foundation and original contributors",
            "roads": "© OpenStreetMap contributors (ODbL)",
            "background": "Esri World Imagery / individual imagery contributors (visualization only)"
        },
        "warning": "Building data may be incomplete or inaccurate. Satellite basemap is for viewing, not extraction."
    }
    write_json("meta.json", metadata)
    print("MAP_DATA_READY:", metadata["counts"])


if __name__ == "__main__":
    main()
