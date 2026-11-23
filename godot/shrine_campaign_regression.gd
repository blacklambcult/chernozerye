extends SceneTree

func _initialize() -> void:
    call_deferred("_check")

func _check() -> void:
    var world := (load("res://main.tscn") as PackedScene).instantiate()
    root.add_child(world)
    var map := world.get_node("ManualSurvey")
    for i in 30:
        await process_frame
        if map.shrine_objective().ready:
            break
    assert(map.shrine_objective().ready)
    assert(world.get_node_or_null("WorldDocument") == null)
    var placement_id := "597ee44d-1f24-4952-a868-f4f6801e868d"
    var found := false
    for node in world.get_children():
        if node.has_node(placement_id):
            found = true
            break
    assert(found)
    var player := world.get_node("Player")
    assert(player.forge_weapons.keys() == [1])
    var shrine_ids := ["shrine_0", "shrine_1", "shrine_2", "shrine_3", "crimson_totem"]
    map.get_node("crimson_totem").apply_damage(1000)
    assert(map.shrine_objective().cleared == 0)
    for i in shrine_ids.size():
        var shrine := map.get_node(shrine_ids[i]) as Node3D
        assert(map.shrine_objective().target == shrine.global_position)
        shrine.apply_damage(1000)
        assert(map.shrine_objective().cleared == i + 1)
    assert(map.shrine_objective().target == null)
    print("SHRINE_CAMPAIGN_OK")
    quit()
