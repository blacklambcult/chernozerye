extends SceneTree


func _initialize() -> void:
    call_deferred("_verify_floor")


func _verify_floor() -> void:
    var floor_mesh := preload("res://forest_floor.gd").new()
    root.add_child(floor_mesh)
    var center := Vector2(-850, 480)
    var features := [{"type": "forest", "points": [[-900, 430], [-800, 430],
        [-800, 530], [-900, 530]]}]
    floor_mesh.prepare(features, [], [center])
    assert(floor_mesh.ponds.size() == 1)
    var pond: Dictionary = floor_mesh.ponds[0]
    assert(floor_mesh.sample_height(center) < pond.water)
    var bank := center + Vector2(7, 0)
    assert(floor_mesh.sample_height(bank) > pond.water)
    floor_mesh.build()
    await physics_frame
    await physics_frame
    var space := root.world_3d.direct_space_state
    for point in [center, bank, bank + Vector2(0.7, 0.3)]:
        var ray := PhysicsRayQueryParameters3D.create(
            Vector3(point.x, 6.0, -point.y), Vector3(point.x, -1.0, -point.y))
        var hit := space.intersect_ray(ray)
        assert(not hit.is_empty() and hit.normal.y > 0.5)
        assert(absf(hit.position.y - floor_mesh.sample_height(point)) < 0.025)
    print("FOREST_FLOOR_REGRESSION_OK")
    quit()
