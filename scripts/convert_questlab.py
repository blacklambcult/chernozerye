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


def compile_questlab(document: dict, origin: dict) -> dict:
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
            # A message-only step has no geographic target.
            target_world = None if target is None else world(target, "quest target")
            if stype == "reach" and target_world is None:
                raise ValueError(f"Reach step requires a target: {sid}")
            steps.append({
                "id": sid,
                "type": stype,
                "title": step_title,
                "text": _string(raw_step.get("text", ""), 1400, "step text"),
                "target_world": target_world,
                "object_id": _string(raw_step.get("objectId", ""), 120, "Geo Lab object ID")
            })
        result.append({
            "id": qid, "type": raw["type"], "title": title,
            "description": _string(raw.get("description", ""), 1200, "quest description"),
            "spawn_world": spawn_world,
            "spawn_bearing": float(heading),
            "steps": steps
        })
    requested_id = document.get("selectedId")
    selection = requested_id if requested_id in seen_quests else (result[0]["id"] if result else "")
    return {
        "schema": "chernozerye.questlab.runtime-1",
        "projection": "EPSG:32640",
        "origin_lat": origin_lat,
        "origin_lon": origin_lon,
        "selected_id": selection,
        "quests": result
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path)
    parser.add_argument("--output", type=Path, default=ROOT / "godot" / "questlab_runtime.json")
    args = parser.parse_args()
    source = json.loads(args.input.read_text(encoding="utf-8"))
    origin = json.loads(WORLD.read_text(encoding="utf-8"))["metadata"]
    converted = compile_questlab(source, origin)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(converted, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("QUEST_LAB_CONVERTED: quests=", len(converted["quests"]),
          "steps=", sum(len(q["steps"]) for q in converted["quests"]))


if __name__ == "__main__":
    main()
