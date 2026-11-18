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

    # Crossed road ribbons must be handled without visible circular geometry.
    # Detection still reserves a small no-ruts zone.
    geo.set("manual_roads", [
        [Vector2(-12, 0), Vector2(12, 0), 0],
        [Vector2(0, -11), Vector2(0, 11), 1],
        [Vector2(6, 0), Vector2(12, 0), 0]
    ])
    geo.call("_detect_road_intersections")
    var crossings: Array = geo.get("_junctions")
    if crossings.size() != 1:
        _fail("crossroads must produce exactly one de-duplicated surface cover")
        return
    if (crossings[0]["center"] as Vector2).length() > 0.01:
        _fail("crossing patch is not centred on the intersection")
        return
    if not geo.call("_near_junction", Vector2(1.0, 0.0), 2.8):
        _fail("wheel ruts must be suppressed at a crossing")
        return
    if geo.call("_near_junction", Vector2(50.0, 50.0), 2.8):
        _fail("junction suppression may not erase a distant road")
        return
    # The old junction cap reached 8 m radius; it must no longer exist.
    var main_radius: float = crossings[0]["radius"]
    if main_radius < 2.2 or main_radius > 3.2:
        _fail("junction no-ruts zone outside compact 2.2–3.2 m range")
        return
    var elevation_zero: float = geo.call("_road_elevation", 0)
    var elevation_one: float = geo.call("_road_elevation", 1)
    var elevation_last: float = geo.call("_road_elevation", 17)
    if elevation_one - elevation_zero < 0.003 or elevation_last - elevation_zero > 0.065:
        _fail("separate roads need a small but effective height bias")
        return
    geo.call("_build_road_intersections")
    if int(geo.get("_junction_mesh_count")) != 0 or geo.get_child_count() != 0:
        _fail("junctions must not create any visible round cap meshes")
        return

    # Confirm the generated interrupted track geometry stays entirely outside
    # the reserved crossing radius + taper distance.
    var line := PackedVector2Array([
        Vector2(-14.0, 0.0), Vector2(14.0, 0.0)
    ])
    geo.call("_add_road_wear", line, 0.145)
    var ruts: MeshInstance3D = null
    for child in geo.get_children():
        if child is MeshInstance3D and str(child.name).contains("прерывистые колеи"):
            ruts = child
            break
    if ruts == null or ruts.mesh == null:
        _fail("no road wheel marks generated for the regression segment")
        return
    var vertices: PackedVector3Array = ruts.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
    for p in vertices:
        if Vector2(p.x, -p.z).length() < main_radius + 1.2:
            _fail("wheel-mark geometry crosses the protected junction")
            return
    # Almost touching endpoints should form a small T-junction cover.
    geo.set("manual_roads", [
        [Vector2(-12, 0), Vector2(12, 0), 0],
        [Vector2(0, 10), Vector2(0, 0.8), 1]
    ])
    geo.call("_detect_road_intersections")
    if (geo.get("_junctions") as Array).size() != 1:
        _fail("nearby T-junction endpoint not joined")
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
    print("GEOMETRY_REGRESSION_OK: no circle caps, biased road levels, crossroads and safe entrances")
    quit(0)
