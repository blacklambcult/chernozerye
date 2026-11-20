extends Node3D
## Loads decorative placements from the current browser profile.

func _ready() -> void:
    if not OS.has_feature("web"):
        return
    # Let the first playable frame render before reading IndexedDB.
    await RenderingServer.frame_post_draw
    if not JavaScriptBridge.eval("typeof window.chernozeryeLoadLocalObjects === 'function'", true):
        return
    JavaScriptBridge.eval("window.chernozeryeLoadLocalObjects()", true)
    for attempt in range(150):
        var payload = JavaScriptBridge.eval("window.chernozeryeLocalObjects || ''", true)
        if payload is String and not payload.is_empty():
            JavaScriptBridge.eval("delete window.chernozeryeLocalObjects", true)
            await _load_objects(JSON.parse_string(payload), true)
            return
        await get_tree().create_timer(0.2).timeout


# WGS84 transverse Mercator, UTM zone 40N (the Geo Lab projection).
func _project(lat: float, lon: float) -> Array[float]:
    const A := 6378137.0
    const E2 := 0.0066943799901413165
    const K0 := 0.9996
    var phi := deg_to_rad(lat)
    var sin_phi := sin(phi)
    var cos_phi := cos(phi)
    var ep2 := E2 / (1.0 - E2)
    var n := A / sqrt(1.0 - E2 * sin_phi * sin_phi)
    var t := tan(phi) ** 2.0
    var c := ep2 * cos_phi * cos_phi
    var d := cos_phi * deg_to_rad(lon - 57.0)
    var e4 := E2 * E2
    var e6 := e4 * E2
    var m := A * ((1.0 - E2 / 4.0 - 3.0 * e4 / 64.0 - 5.0 * e6 / 256.0) * phi
        - (3.0 * E2 / 8.0 + 3.0 * e4 / 32.0 + 45.0 * e6 / 1024.0) * sin(2.0 * phi)
        + (15.0 * e4 / 256.0 + 45.0 * e6 / 1024.0) * sin(4.0 * phi)
        - 35.0 * e6 / 3072.0 * sin(6.0 * phi))
    var east := K0 * n * (d + (1.0 - t + c) * d ** 3.0 / 6.0
        + (5.0 - 18.0 * t + t * t + 72.0 * c - 58.0 * ep2) * d ** 5.0 / 120.0)
    var north := K0 * (m + n * tan(phi) * (d * d / 2.0
        + (5.0 - t + 9.0 * c + 4.0 * c * c) * d ** 4.0 / 24.0
        + (61.0 - 58.0 * t + t * t + 600.0 * c - 330.0 * ep2) * d ** 6.0 / 720.0))
    return [east, north]


func _load_objects(data: Variant, spread_over_frames := false) -> void:
    if not data is Dictionary or not data.get("placements") is Array \
            or not data.get("models") is Array or data["placements"].is_empty():
        return
    var world: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://world_data.json"))
    var metadata: Dictionary = world["metadata"]
    var origin := _project(float(metadata["center_lat"]), float(metadata["center_lon"]))
    var scenes := {}
    for model in data["models"]:
        if spread_over_frames:
            await RenderingServer.frame_post_draw
        var document := GLTFDocument.new()
        var state := GLTFState.new()
        if document.append_from_buffer(Marshalls.base64_to_raw(model["glb"]), "", state) != OK:
            push_warning("LOCAL_OBJECT_MODEL_FAILED: " + str(model["id"]))
            continue
        var scene := document.generate_scene(state)
        if scene != null:
            scenes[model["id"]] = scene
    var count := 0
    for placement in data["placements"]:
        var template := scenes.get(placement["modelId"]) as Node3D
        if template == null:
            continue
        var point := _project(float(placement["lat"]), float(placement["lon"]))
        if spread_over_frames and count > 0 and count % 16 == 0:
            await RenderingServer.frame_post_draw
        var instance := template.duplicate() as Node3D
        instance.position = Vector3(point[0] - origin[0], 0.04, origin[1] - point[1])
        instance.scale *= clampf(float(placement.get("scale", 1.0)), 0.1, 4.0)
        instance.rotate_y(-deg_to_rad(float(placement.get("heading", 0.0))))
        add_child(instance)
        count += 1
    for scene in scenes.values():
        scene.free()
    print("LOCAL_OBJECT_LIBRARY_READY: placed=", count)
