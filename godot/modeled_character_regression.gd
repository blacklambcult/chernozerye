extends SceneTree
# The first-person mesh must be from the actual GLB, not the hidden legacy
# procedural torso. F4 must expose the complete GLB for visual inspection.

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
    var old_body := actor.get_node("FirstPersonFullBody") as Node3D
    if rig == null or not bool(rig.get("model_loaded")) or old_body.visible:
        _fail("GLB first-person mode failed to replace procedural torso")
        return
    var root := rig.get("imported") as Node3D
    var head := root.find_child("HeadPivot", true, false) as Node3D
    var left := root.find_child("LeftLegPivot", true, false) as Node3D
    var right := root.find_child("RightLegPivot", true, false) as Node3D
    if head == null or head.visible or left == null or right == null:
        _fail("head clip protection or leg joints missing")
        return
    var original_left := left.position
    var original_right := right.position
    if absf(original_left.x + original_right.x) > 0.001:
        _fail("asymmetric leg pivots")
        return
    var cutaway := 0
    var legs := 0
    for node in root.find_children("*","MeshInstance3D",true,false):
        var part := node as MeshInstance3D
        var label := String(part.name)
        if label.begins_with("FPSCoat") and part.visible:
            cutaway += 1
        elif ("Thigh" in label or "LowerLeg" in label or "Boot" in label) and part.visible:
            legs += 1
        elif part.visible:
            _fail("upper full-body mesh visible in first-person: " + label)
            return
    if cutaway < 8 or legs < 8:
        _fail("imported cutaway or boots are missing")
        return
    var left_front := root.find_child("FPSCoatUpperLeft",true,false) as MeshInstance3D
    var crop_box := left_front.mesh.get_aabb()
    var crop_min := left_front.to_global(crop_box.position)
    var crop_max := left_front.to_global(crop_box.position + crop_box.size)
    var crop_top := maxf(crop_min.y, crop_max.y) - actor.global_position.y
    if crop_top > 1.11:
        _fail("first-person chest reaches too close to the camera and becomes a giant triangle")
        return
    var eye := actor.get_node("Camera3D") as Camera3D
    for pitch in [0.0, -0.5, -1.0, -1.45]:
        eye.rotation.x = pitch
        for frame in range(20):
            rig.call("_process", 0.016)
        if left.position.distance_to(original_left) > 0.001 or right.position.distance_to(original_right) > 0.001:
            _fail("leg pivots shift when looking down")
            return
    # Inspect F4 switches to FULL original model and dedicated third-person
    # camera with appropriate nearby fill light.
    actor.call("_toggle_model_inspection")
    if not bool(actor.get("_inspect_enabled")) or not head.visible:
        _fail("F4 does not show complete model")
        return
    if not (actor.get_node("CharacterInspectionCamera") as Camera3D).current:
        _fail("F4 does not activate inspection camera")
        return
    var coat := root.find_child("WinterCoat",true,false) as MeshInstance3D
    var face := root.find_child("Head",true,false) as MeshInstance3D
    var boot := root.find_child("LeftBootToe",true,false) as MeshInstance3D
    if coat == null or not coat.visible or face == null or boot == null:
        _fail("complete protagonist is not visible in inspector")
        return
    for piece in [coat, face, boot]:
        var material := piece.material_override as StandardMaterial3D
        if material == null or material.albedo_color.r > 0.98 and material.albedo_color.g > 0.98 and material.albedo_color.b > 0.98:
            _fail("the model inspector has white/unassigned materials")
            return
    actor.call("_toggle_model_inspection")
    if bool(actor.get("_inspect_enabled")) or head.visible or old_body.visible:
        _fail("F4 exit did not restore clean first-person mesh")
        return
    print("MODELED_CHARACTER_REGRESSION_OK: glb=true coat_cutaway=true full_coat_hidden=true stable_legs=true inspect_f4=true legacy_hidden=true colored_materials=true compact_cutaway=true")
    quit(0)
