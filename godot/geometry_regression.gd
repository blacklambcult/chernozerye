extends SceneTree
# Geometry and clear-approach regressions for the browser village.
# Runs in CI headless, independent of actual house/road coordinates.

func _fail(message: String) -> void:
    push_error("GEOMETRY_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    var geo := Node3D.new()
    geo.set_script(load("res://manual_geo.gd"))
    var bend := PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(12.0, 0.0), Vector2(12.0, 10.0)
    ])
    var surface := PackedVector3Array()
    geo.call("_append_joined_ribbon", surface, bend, 3.8, 0.0, 0.11)
    if surface.size() != 12:
        _fail("joined road must have two adjacent quads (12 vertices)")
        return
    var joint_l: Vector2 = geo.call("_joined_offset", bend, 1, -1.9)
    var joint_r: Vector2 = geo.call("_joined_offset", bend, 1, 1.9)
    if not joint_l.is_finite() or not joint_r.is_finite():
        _fail("bad miter join at 90-degree bend")
        return
    # Both triangles at the turn must share exactly the same two edge vertices.
    if surface[2].distance_to(surface[7]) > 0.001 or (
            surface[5].distance_to(surface[6]) > 0.001):
        _fail("road strips are disconnected at the bend")
        return

    var art := Node3D.new()
    art.set_script(load("res://manual_art.gd"))
    art.set("_roads", [[Vector2(-20.0, -10.0), Vector2(20.0, -10.0), 3.8]])
    var house := {
        "type": "house",
        "points": [[0.0, 0.0], [8.0, 0.0], [8.0, 6.0], [0.0, 6.0]]
    }
    art.call("_build_entrance_routes", [house])
    var routes: Array = art.get("_entrance_routes")
    if routes.size() != 1:
        _fail("house entrance corridor was not reserved")
        return
    var route: Dictionary = routes[0]
    var start: Vector2 = route["start"]
    var finish: Vector2 = route["end"]
    var midpoint := (start + finish) * 0.5
    if not art.call("_entry_zone_conflict", midpoint):
        _fail("reserved doorway not treated as occupied")
        return
    # 2.45m greenhouse radius plus margins must be checked beyond the base AABB.
    if not art.call("_entry_zone_conflict", midpoint + Vector2(3.1, 0.0), 2.9):
        _fail("greenhouse clearance must include its full radius")
        return
    var garden := PackedVector2Array([
        Vector2(-5.0, -8.5), Vector2(13.0, -8.5),
        Vector2(13.0, 12.0), Vector2(-5.0, 12.0)
    ])
    if art.call("_fence_span_clear",
            midpoint + Vector2(-1.0, 0.0),
            midpoint + Vector2(1.0, 0.0), garden):
        _fail("a fence still crosses the doorway")
        return
    if art.call("_yard_spot_ok", midpoint + Vector2(3.1, 0.0), garden, [], 2):
        _fail("greenhouse allowed to overlap a doorway")
        return
    print("GEOMETRY_REGRESSION_OK: joined_roads and safe_gate / greenhouse clearance")
    quit(0)
