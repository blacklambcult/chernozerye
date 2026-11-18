extends SceneTree
# Physics regression independent of the large village build. Verifies that
# procedural walls and fences are solid but intentional gate gaps stay open.

func _fail(reason: String) -> void:
    push_error("COLLISION_REGRESSION_FAILED: " + reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _ray(origin: Vector3, destination: Vector3) -> Dictionary:
    var params := PhysicsRayQueryParameters3D.create(origin, destination)
    params.collision_mask = 1
    return get_root().get_world_3d().direct_space_state.intersect_ray(params)

func _run() -> void:
    var art := Node3D.new()
    art.name = "CollisionHarness"
    art.set_script(load("res://manual_art.gd"))
    get_root().add_child(art)
    var polygon := PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(4.0, 0.0),
        Vector2(4.0, 4.0), Vector2(0.0, 4.0)
    ])
    art.call("_register_building_collider", polygon, 3.8)
    art.call("_register_fence_collider", Vector2(8, 0), Vector2(8, 4))
    art.call("_build_collision_bodies")
    var building := art.get_node_or_null("CollisionBuildings") as StaticBody3D
    var fence := art.get_node_or_null("CollisionFences") as StaticBody3D
    if building == null or fence == null:
        _fail("solid collision bodies were not built")
        return
    if int(art.get("_collision_building_count")) != 1:
        _fail("building count mismatch")
        return
    if int(art.get("_collision_fence_span_count")) != 1:
        _fail("fence count mismatch")
        return
    await physics_frame
    await physics_frame
    var house_hit := _ray(Vector3(2, 1.4, 2), Vector3(2, 1.4, -2))
    if house_hit.is_empty() or house_hit.get("collider") != building:
        _fail("building wall can be walked through")
        return
    var fence_hit := _ray(Vector3(6, 1.0, -2), Vector3(10, 1.0, -2))
    if fence_hit.is_empty() or fence_hit.get("collider") != fence:
        _fail("fence allows walking through visible rails")
        return
    var clear_passage := _ray(Vector3(6, 1.0, -8), Vector3(10, 1.0, -8))
    if not clear_passage.is_empty():
        _fail("unbuilt gate opening is blocked by invisible collision")
        return
    print("COLLISION_REGRESSION_OK: house=solid fence=solid gap=open")
    quit(0)
