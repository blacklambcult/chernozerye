extends SceneTree


func _initialize() -> void:
    call_deferred("_verify_shrine")


func _verify_shrine() -> void:
    var shrine := preload("res://forest_shrine.gd").new()
    root.add_child(shrine)
    shrine.install(load("res://generated_forest/shrine_0_active.glb"),
        load("res://generated_forest/shrine_0_broken.glb"), Color.WHITE)
    var active := shrine.get_child(0) as Node3D
    var animation := active.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
    assert(animation.current_animation == "Ritual_Idle")
    var collider := shrine.get_child(1) as CollisionShape3D
    var light := shrine.get_child(2) as OmniLight3D
    shrine.can_take_damage = func() -> bool: return false
    shrine.apply_damage(100.0)
    assert(not shrine.is_destroyed and active.visible)
    shrine.can_take_damage = func() -> bool: return true
    shrine.apply_damage(35.0)
    assert(active.visible and light.visible and not collider.disabled)
    shrine.apply_damage(60.0)
    await process_frame
    await process_frame
    assert(shrine.is_destroyed)
    assert(not is_instance_valid(active) and not light.visible and collider.disabled)
    assert(shrine.get_child_count() == 3)
    shrine.apply_damage(100.0)
    assert(shrine.get_child_count() == 3)
    print("FOREST_SHRINE_REGRESSION_OK")
    quit()
