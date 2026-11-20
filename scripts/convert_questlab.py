#!/usr/bin/env python3
"""Compile Quest Lab v1 WGS84 JSON into Godot-space mission data.

Run this during the Web build, after the Geo Lab survey is selected:
    python scripts/convert_questlab.py data/questlab_return_cordon.json \
      --output godot/questlab_runtime.json
Source files remain unchanged; game-space coordinates are derived from
godot/world_data.json, the same UTM origin used by Geo Lab.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path

from pyproj import Transformer

ROOT = Path(__file__).resolve().parents[1]
WORLD = ROOT / "godot" / "world_data.json"
FORMATS = {"reach", "interact", "collect", "message"}
QUEST_TYPES = {"main", "side"}
WORLD_ITEM_TYPES = {"note", "item"}
INTERACTION_CLEARANCE_M = 1.8
GEO_KINDS = {"house", "sauna", "shed", "car", "road", "path", "plot", "forest", "water", "object"}


def _string(value: object, length: int, field: str) -> str:
    if not isinstance(value, str) or len(value) > length:
        raise ValueError(f"Invalid {field}: expected string up to {length} chars")
    return value.strip()


def _coordinates(point: object, field: str) -> tuple[float, float]:
    if not isinstance(point, dict):
        raise ValueError(f"Missing coordinates for {field}")
    lon, lat = point.get("lon"), point.get("lat")
    if any(isinstance(v, bool) or not isinstance(v, (float, int)) or not math.isfinite(v) for v in (lon, lat)):
        raise ValueError(f"Coordinates must be finite numeric values: {field}")
    if not (55.70 <= lon <= 56.05 and 54.55 <= lat <= 54.85):
        raise ValueError(f"{field} lies outside the Chernozerye survey area")
    return float(lon), float(lat)




def _nearest_on_segment(px: float, py: float, ax: float, ay: float,
                        bx: float, by: float) -> tuple[float, float]:
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length2)) if length2 > 1e-10 else 0.0
    return ax + t * dx, ay + t * dy


def _geo_object_anchor(feature: dict, spawn_world: list[float]) -> list[float]:
    """Reachable interaction point in the *existing* Geo Lab survey, x=east / y=north.
    For polygons prefer a nearby perimeter point outside the footprint instead
    of the unreachable building centre. Do not modify the imported 3D geometry.
    """
    points = feature.get("points", [])
    if not isinstance(points, list) or not points:
        raise ValueError(f"Empty Geo Lab object: {feature.get('id', '')}")
    coords = []
    for raw in points:
        if (not isinstance(raw, list) or len(raw) != 2 or
                any(isinstance(v, bool) or not isinstance(v, (int, float))
                    or not math.isfinite(v) for v in raw)):
            raise ValueError(f"Invalid Geo Lab point for {feature.get('id', '')}")
        coords.append((float(raw[0]), float(raw[1])))
    shape = feature.get("geometry_type")
    if shape == "Point":
        return [round(coords[0][0], 3), 0.22, round(-coords[0][1], 3)]
    if shape == "LineString":
        if len(coords) < 2:
            raise ValueError("Geo Lab line has less than 2 points")
        lengths = [math.dist(coords[i], coords[i+1]) for i in range(len(coords)-1)]
        total = sum(lengths)
        remaining = total / 2
        for i, length in enumerate(lengths):
            if remaining <= length or i == len(lengths)-1:
                fraction = max(0.0, min(1.0, remaining / length)) if length > 0 else 0.0
                x = coords[i][0] + (coords[i+1][0]-coords[i][0]) * fraction
                y = coords[i][1] + (coords[i+1][1]-coords[i][1]) * fraction
                return [round(x, 3), 0.22, round(-y, 3)]
            remaining -= length
    if shape != "Polygon" or len(coords) < 3:
        raise ValueError(f"Unsupported Geo Lab geometry for {feature.get('id', '')}")
    sx, sy = float(spawn_world[0]), -float(spawn_world[2])
    candidates = [_nearest_on_segment(sx, sy, *coords[i], *coords[(i+1) % len(coords)])
                  for i in range(len(coords))]
    px, py = min(candidates, key=lambda p: (p[0] - sx)**2 + (p[1] - sy)**2)
    center_x = sum(p[0] for p in coords) / len(coords)
    center_y = sum(p[1] for p in coords) / len(coords)
    dx, dy = px - center_x, py - center_y
    # If the spawn lies on the correct exterior side, prefer its direction;
    # otherwise use the normal from the footprint centre to the boundary.
    ux, uy = sx - px, sy - py
    if (ux * dx + uy * dy) <= 0:
        ux, uy = dx, dy
    size = math.hypot(ux, uy)
    if size < 1e-5:
        ux, uy, size = 1.0, 0.0, 1.0
    px += ux / size * INTERACTION_CLEARANCE_M
    py += uy / size * INTERACTION_CLEARANCE_M
    return [round(px, 3), 0.22, round(-py, 3)]


def _geo_index(geo_layout: dict | None, origin: dict) -> dict[str, dict]:
    if geo_layout is None:
        return {}
    if not isinstance(geo_layout, dict):
        raise ValueError("Geo Lab layout must be a dictionary")
    metadata = geo_layout.get("metadata", {})
    if (not isinstance(metadata, dict) or
            metadata.get("projection") != "EPSG:32640" or
            abs(float(metadata.get("origin_lon", -999)) - float(origin["center_lon"])) > 1e-7 or
            abs(float(metadata.get("origin_lat", -999)) - float(origin["center_lat"])) > 1e-7):
        raise ValueError("Geo Lab layout projection / origin mismatch")
    features = geo_layout.get("features")
    if not isinstance(features, list) or len(features) > 10000:
        raise ValueError("Invalid Geo Lab layout feature list")
    index: dict[str, dict] = {}
    for feature in features:
        if not isinstance(feature, dict):
            raise ValueError("Corrupt Geo Lab feature")
        key = _string(feature.get("id", ""), 120, "Geo Lab ID")
        if not key or key in index:
            raise ValueError("Duplicate or empty Geo Lab feature ID")
        if feature.get("type") not in GEO_KINDS:
            raise ValueError(f"Unsupported Geo Lab object category: {key}")
        index[key] = feature
    return index

def _document_for_step(step: dict, kind: str) -> dict | None:
    if kind != "collect":
        return None
    note = step.get("document")
    if note is None:
        return None
    if not isinstance(note, dict):
        raise ValueError("Collectible document must be a dictionary")
    title = _string(note.get("title", ""), 140, "document title")
    body = _string(note.get("body", ""), 4000, "document body")
    if not title and not body:
        return None
    if not title or not body:
        raise ValueError("A collectible note needs both title and body")
    return {"title": title, "body": body}


def compile_questlab(document: dict, origin: dict, geo_layout: dict | None = None) -> dict:
    if (not isinstance(document, dict) or document.get("format") != "chernozerye.questlab"
            or document.get("version") != 1 or document.get("coordinates") != "WGS84"):
        raise ValueError("Unsupported Quest Lab JSON format or version")
    raw_quests = document.get("quests")
    if not isinstance(raw_quests, list) or len(raw_quests) > 100:
        raise ValueError("A project must include a quest list (max 100)")
    transformer = Transformer.from_crs("EPSG:4326", "EPSG:32640", always_xy=True)
    origin_lon = float(origin["center_lon"])
    origin_lat = float(origin["center_lat"])
    cx, cy = transformer.transform(origin_lon, origin_lat)
    objects = _geo_index(geo_layout, origin)

    def world(point: object, field: str) -> list[float]:
        lon, lat = _coordinates(point, field)
        east, north = transformer.transform(lon, lat)
        return [round(east - cx, 3), 0.22, round(cy - north, 3)]

    result = []
    seen_quests: set[str] = set()
    for raw in raw_quests:
        if not isinstance(raw, dict):
            raise ValueError("Malformed quest")
        qid = _string(raw.get("id"), 120, "quest ID")
        if not qid or qid in seen_quests:
            raise ValueError("Empty or repeated quest ID")
        seen_quests.add(qid)
        if raw.get("type") not in QUEST_TYPES:
            raise ValueError(f"Unsupported quest type: {qid}")
        title = _string(raw.get("title"), 140, "quest title")
        if not title:
            raise ValueError(f"Empty quest title: {qid}")
        spawn = raw.get("spawn")
        spawn_world = world(spawn, "spawn")
        heading = spawn.get("bearing", 0)
        if (not isinstance(heading, (float, int)) or isinstance(heading, bool)
                or not math.isfinite(heading) or not 0 <= heading < 360):
            raise ValueError(f"Invalid spawn bearing for {qid}")
        raw_steps = raw.get("steps")
        if not isinstance(raw_steps, list) or len(raw_steps) > 100:
            raise ValueError(f"Invalid steps for {qid}")
        steps = []
        seen_steps: set[str] = set()
        for raw_step in raw_steps:
            if not isinstance(raw_step, dict):
                raise ValueError("Malformed quest step")
            sid = _string(raw_step.get("id"), 120, "step ID")
            if not sid or sid in seen_steps:
                raise ValueError("Empty or duplicate step ID")
            seen_steps.add(sid)
            stype = raw_step.get("type")
            if stype not in FORMATS:
                raise ValueError(f"Unsupported quest step type: {stype}")
            step_title = _string(raw_step.get("title"), 140, "step title")
            if not step_title:
                raise ValueError("Quest step title must not be empty")
            target = raw_step.get("target")
            object_id = _string(raw_step.get("objectId", ""), 120, "Geo Lab object ID")
            if stype == "message" and object_id:
                raise ValueError("Message-only quest step cannot link a Geo Lab object")
            # Link-by-ID supersedes a stale editor centroid, including a missing
            # target field. An unknown ID is a build error, not a silent fallback.
            feature = None
            if object_id and geo_layout is not None:
                feature = objects.get(object_id)
                if feature is None:
                    raise ValueError(f"Geo Lab object not found: {object_id}")
                target_world = _geo_object_anchor(feature, spawn_world)
            else:
                target_world = None if target is None else world(target, "quest target")
            if stype == "reach" and target_world is None:
                raise ValueError(f"Reach step requires a target: {sid}")
            steps.append({
                "id": sid,
                "type": stype,
                "title": step_title,
                "text": _string(raw_step.get("text", ""), 1400, "step text"),
                "target_world": target_world,
                "object_id": object_id,
                "object_type": str(feature.get("type", "")) if feature else "",
                "object_name": _string(feature.get("name", ""), 120, "Geo Lab name") if feature else "",
                "target_source": "geo_lab_id" if feature else "free_point",
                "document": _document_for_step(raw_step, stype)
            })
        result.append({
            "id": qid, "type": raw["type"], "title": title,
            "description": _string(raw.get("description", ""), 1200, "quest description"),
            "spawn_world": spawn_world,
            "spawn_bearing": float(heading),
            "steps": steps
        })
    raw_items = document.get("worldItems", [])
    if not isinstance(raw_items, list) or len(raw_items) > 150:
        raise ValueError("World items must be a list of at most 150 entries")
    world_items = []
    seen_items: set[str] = set()
    for raw in raw_items:
        if not isinstance(raw, dict):
            raise ValueError("Malformed world item")
        item_id = _string(raw.get("id"), 120, "world item ID")
        if not item_id or item_id in seen_items:
            raise ValueError("Empty or repeated world item ID")
        seen_items.add(item_id)
        kind = raw.get("type")
        if kind not in WORLD_ITEM_TYPES:
            raise ValueError(f"Unsupported world item type: {item_id}")
        title = _string(raw.get("title"), 140, "world item title")
        body = _string(raw.get("body", ""), 4000, "world item body")
        if not title or (kind == "note" and not body):
            raise ValueError("World notes require a title and body")
        geo_id = _string(raw.get("objectId", ""), 120, "Geo Lab object ID")
        anchor = raw.get("target")
        if geo_id:
            if geo_layout is None:
                raise ValueError(f"Geo Lab map required to resolve world item {item_id}")
            geo_feature = objects.get(geo_id)
            if geo_feature is None:
                raise ValueError(f"Geo Lab object not found: {geo_id}")
            # Editor target is a side-choice hint; surveyed geometry is authoritative.
            hint = world(anchor, "world item anchor") if anchor is not None else [130, 0.22, -82]
            local_point = _geo_object_anchor(geo_feature, hint)
            source = "geo_lab_id"
        else:
            if anchor is None:
                raise ValueError(f"World item must have a mapped position: {item_id}")
            local_point = world(anchor, "world item position")
            source = "free_point"
        world_items.append({
            "id": item_id, "type": kind, "title": title, "body": body,
            "position_world": local_point, "object_id": geo_id,
            "target_source": source
        })
    requested_id = document.get("selectedId")
    selection = requested_id if requested_id in seen_quests else (result[0]["id"] if result else "")
    return {
        "schema": "chernozerye.questlab.runtime-1",
        "projection": "EPSG:32640",
        "origin_lat": origin_lat,
        "origin_lon": origin_lon,
        "selected_id": selection,
        "quests": result,
        "world_items": world_items
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "godot" / "questlab_runtime.json")
    parser.add_argument("--geo-layout", type=Path, default=None,
                        help="Reviewed local-metre Geo Lab layout; activates stable ID resolution")
    args = parser.parse_args()
    source = json.loads(args.input.read_text(encoding="utf-8"))
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["metadata"]
    layout = json.loads(args.geo_layout.read_text(encoding="utf-8")) if args.geo_layout else None
    converted = compile_questlab(source, origin, layout)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(converted, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("QUEST_LAB_CONVERTED: quests=", len(converted["quests"]),
          "steps=", sum(len(q["steps"]) for q in converted["quests"]),
          "world_items=", len(converted["world_items"]))


if __name__ == "__main__":
    main()
