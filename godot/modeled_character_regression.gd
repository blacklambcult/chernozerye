extends SceneTree
# Protect actual rendered first-person view; old test only checked pivot
# stability and missed the full coat that covered the whole viewport.

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
    if absf(left.position.x + right.position.x) > 0.001 or absf(left.position.z - right.position.z) > 0.001:
        _fail("leg pivots asymmetric or improperly placed")
        return

    # The imported coat used to fill the full screen with white/gray triangles.
    # Check the RENDERED mesh allow-list, not just joint names/visibilities.
    var visible_count := 0
    var hidden_count := 0
    for node in root.find_children("*", "MeshInstance3D", true, false):
        var part := node as MeshInstance3D
        var label := String(part.name)
        var leg_part := false
        for prefix in rig.LEG_PARTS:
            if label.begins_with(prefix):
                leg_part = true
                break
        if part.visible:
            visible_count += 1
            if not leg_part:
                _fail("non-leg imported mesh can cover the first-person camera: " + label)
                return
        else:
            hidden_count += 1
    if visible_count < 8 or hidden_count < 8:
        _fail("mesh mask failed to isolate lower body")
        return
    var old_body := actor.get_node("FirstPersonFullBody") as Node3D
    var old_pelvis := old_body.get_node("PelvisRoot") as Node3D
    if not old_body.visible:
        _fail("verified first-person coat disappeared")
        return
    if not (old_pelvis.get_node("LowerJacket") as MeshInstance3D).visible:
        _fail("first-person jacket is missing")
        return
    if (old_pelvis.get_node("LeftLeg") as Node3D).visible or (old_pelvis.get_node("RightLeg") as Node3D).visible:
        _fail("duplicate legacy legs remain visible")
        return

    var eye := actor.get_node("Camera3D") as Camera3D
    for pitch in [0.0,-0.50,-1.0,-1.45]:
        eye.rotation.x = pitch
        for frame in range(30):
            rig.call("_process",0.016)
            old_body.call("_process",0.016)
        if left.position.distance_to(left_at_rest) > 0.001 or right.position.distance_to(right_at_rest) > 0.001:
            _fail("looking down moves the actual leg joints")
            return
        if (old_pelvis.get_node("LeftLeg") as Node3D).visible:
            _fail("procedural leg became visible at pitch %s" % pitch)
            return
    print("MODELED_CHARACTER_REGRESSION_OK: loaded=true legs_under_hips=true head_hidden=true camera_independent=true legacy_coat_visible=true coat_occlusion_blocked=true")
    quit(0)
