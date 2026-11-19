extends SceneTree

func _fail(message: String) -> void:
    push_error("MODELED_CHARACTER_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var rig := actor.get_node_or_null("ModeledCharacter") as Node3D
    if rig == null or not bool(rig.get("model_loaded")):
        _fail("actual imported character GLB not loaded")
        return
    var root := rig.get("imported") as Node3D
    var head := root.find_child("HeadPivot", true, false) as Node3D
    var left := root.find_child("LeftLegPivot", true, false) as Node3D
    var right := root.find_child("RightLegPivot", true, false) as Node3D
    if head == null or head.visible or left == null or right == null:
        _fail("head clip protection or leg joints missing")
        return
    var left_at_rest := left.position
    var right_at_rest := right.position
    if absf(left.position.x + right.position.x) > 0.001:
        _fail("legs have asymmetric standing pivots")
        return
    if absf(left.position.z - right.position.z) > 0.001:
        _fail("one leg protrudes forward of the other")
        return
    var eye := actor.get_node("Camera3D") as Camera3D
    eye.rotation.x = -1.45
    for frame in range(30):
        rig.call("_process",0.016)
    if left.position.distance_to(left_at_rest) > 0.001 or right.position.distance_to(right_at_rest) > 0.001:
        _fail("looking down modifies the position of a leg")
        return
    if (actor.get_node("FirstPersonFullBody") as Node3D).visible:
        _fail("procedural body is still rendered over imported GLB")
        return
    print("MODELED_CHARACTER_REGRESSION_OK: loaded=true legs_under_hips=true head_hidden=true camera_independent=true legacy_hidden=true")
    quit(0)
