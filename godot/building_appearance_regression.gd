extends SceneTree

func _initialize() -> void:
    call_deferred("_run")


func _fail(reason: String) -> void:
    push_error("BUILDING_APPEARANCE_FAILED: " + reason)
    quit(1)


func _run() -> void:
    var village = load("res://generated_village.gd").new()
    village.model_dir = "res://generated_village_test/"
    root.add_child(village)
    var data = JSON.parse_string(FileAccess.get_file_as_string("res://generated_village_test/layout.json"))
    if not data is Dictionary:
        _fail("missing regression layout")
        return
    var features: Array = data.features
    village.prepare(features)
    var a: Dictionary = village.appearance_for("test-house-a")
    var b: Dictionary = village.appearance_for("test-house-b")
    var c: Dictionary = village.appearance_for("test-house-c")
    if a.is_empty() or b.is_empty() or c.is_empty():
        _fail("missing imported model mapping")
        return
    if a.model != b.model or a.model == c.model or a.floors != 2 or c.floors != 1:
        _fail("recipe deduplication or floor selection mismatch")
        return
    for feature in features:
        var points := PackedVector2Array()
        for point in feature.points:
            points.append(Vector2(float(point[0]), float(point[1])))
        var entry: Dictionary = village.appearance_for(feature.id)
        var result: Dictionary = village.add_building(points, "house", 0, entry.floors, 0, Callable(), feature.id)
        if result.is_empty() or result.model_id != entry.model or result.foundation.size() != 4:
            _fail("custom model not selected by existing placement pipeline")
            return
    if village.get("_transforms").size() != 2:
        _fail("expected two shared model groups for three houses")
        return
    village.finish()
    var batches := 0
    var shared := 0
    for child in village.get_children():
        if child is MultiMeshInstance3D:
            batches += 1
            if child.multimesh.instance_count == 2:
                shared += 1
    if batches == 0 or shared == 0 or int(village.get("_custom_placed")) != 3:
        _fail("expected actual shared MultiMesh instances")
        return
    # Exercise the real art-placement path as well: a custom two-storey
    # recipe must set the wall collider height, not the baseline floor rule.
    var art = load("res://manual_art.gd").new()
    root.add_child(art)
    var collision_village = load("res://generated_village.gd").new()
    collision_village.model_dir = "res://generated_village_test/"
    art.add_child(collision_village)
    collision_village.prepare(features)
    art.set("_studio_village", collision_village)
    var footprint := PackedVector2Array([Vector2(0, 0), Vector2(5, 0), Vector2(5, 5), Vector2(0, 5)])
    art.call("_place_studio_building", footprint, "house", "test-house-a")
    var faces: PackedVector3Array = art.get("_timber_faces")
    var max_height := 0.0
    for point in faces:
        max_height = maxf(max_height, point.y)
    if int(art.get("_collision_building_count")) != 1 or max_height < 5.0:
        _fail("two-storey recipe did not reach actual wall collider")
        return
    print("BUILDING_APPEARANCE_OK: features=3 unique=2 shared_batches=", shared, " collider_height=", max_height)
    quit()
