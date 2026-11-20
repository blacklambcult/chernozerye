extends RefCounted

static func read() -> Dictionary:
    if not OS.has_feature("web"):
        return {}
    var raw: Variant = JavaScriptBridge.eval(
        "(() => { try { return location.hash === '#studio-playtest' ? sessionStorage.getItem('chernozerye.studio-playtest.v1') : null; } catch (_) { return null; } })()", true)
    if not raw is String or raw.length() > 2500000:
        return {}
    var data: Variant = JSON.parse_string(raw)
    if not data is Dictionary or data.get("format") != "chernozerye.studio-project" or data.get("version") != 1:
        return {}
    return data

static func convert_quest(data: Dictionary, projector: Node) -> Dictionary:
    var editor: Variant = data.get("editors", {}).get("quest")
    if not editor is Dictionary or not editor.get("quests") is Array:
        return {}
    var chosen: Dictionary = {}
    for entry in editor["quests"]:
        if not entry is Dictionary:
            continue
        if str(entry.get("id", "")) == str(editor.get("selectedId", "")):
            chosen = entry
            break
        if chosen.is_empty() and entry.get("type") == "main":
            chosen = entry
    if chosen.is_empty():
        return {}
    var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world_data.json"))["metadata"]
    var origin: Array = projector.call("_project", metadata["center_lat"], metadata["center_lon"])
    var spawn := _point(chosen.get("spawn"), projector, origin)
    if spawn.is_empty() or not chosen.get("steps") is Array:
        return {}
    var compiled := []
    for step in chosen["steps"]:
        if not step is Dictionary or not ["reach", "interact", "collect", "message"].has(step.get("type")):
            return {}
        var target := _point(step.get("target"), projector, origin)
        if not str(step.get("objectId", "")).is_empty() or not str(step.get("noteId", "")).is_empty():
            return {}
        if step["type"] != "message" and target.is_empty():
            return {}
        compiled.append({"id": str(step.get("id", "")), "type": step["type"],
            "title": str(step.get("title", "")), "text": str(step.get("text", "")),
            "document": step.get("document"), "target_world": target if not target.is_empty() else null})
    if compiled.is_empty():
        return {}
    return {"id": str(chosen.get("id", "")), "title": str(chosen.get("title", "")),
        "spawn_world": spawn, "spawn_bearing": float(chosen["spawn"].get("bearing", 0)), "steps": compiled}

static func convert_world_items(data: Dictionary, projector: Node) -> Array:
    var editor: Variant = data.get("editors", {}).get("quest")
    if not editor is Dictionary or not editor.get("worldItems") is Array:
        return []
    var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world_data.json"))["metadata"]
    var origin: Array = projector.call("_project", metadata["center_lat"], metadata["center_lon"])
    var result := []
    for item in editor["worldItems"]:
        if not item is Dictionary or not ["note", "item"].has(item.get("type")):
            continue
        var at := _point(item.get("target"), projector, origin)
        if at.is_empty():
            continue
        result.append({"id": str(item.get("id", "")), "type": item["type"],
            "title": str(item.get("title", "")), "body": str(item.get("body", "")),
            "position_world": at})
    return result

static func _point(value: Variant, projector: Node, origin: Array) -> Array:
    if not value is Dictionary:
        return []
    var lat: Variant = value.get("lat")
    var lon: Variant = value.get("lon")
    if not (lat is float or lat is int) or not (lon is float or lon is int):
        return []
    if not is_finite(lat) or not is_finite(lon) or absf(lat) > 85 or absf(lon) > 180:
        return []
    var projected: Array = projector.call("_project", lat, lon)
    return [projected[0] - origin[0], 0.22, origin[1] - projected[1]]
