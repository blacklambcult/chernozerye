extends SceneTree
# Regression of camera-space silhouette and full-body handoff. This test
# deliberately exercises the actual Player scene, not just static constants.

func _fail(message: String) -> void:
    push_error("VIEWMODEL_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.set_script(load("res://player.gd"))
    get_root().add_child(player)
    var eye := player.get_node_or_null("Camera3D") as Camera3D
    var rig := player.get_node_or_null("Camera3D/FPSViewmodel") as Node3D
    var body := player.get_node_or_null("FirstPersonFullBody") as Node3D
    if eye == null or rig == null or body == null:
        _fail("camera / viewmodel / world-body not instantiated")
        return
    if rig.get_parent() != eye:
        _fail("viewmodel does not follow camera pitch and yaw")
        return
    var left := rig.get_node_or_null("LeftArm") as Node3D
    var right := rig.get_node_or_null("RightArm") as Node3D
    if left == null or right == null:
        _fail("both hands and coat sleeves must exist")
        return
    for arm in [left, right]:
        if arm.get_node_or_null("UpperCoatSleeve") == null or arm.get_node_or_null("ForearmSleeve") == null or arm.get_node_or_null("WristCuff") == null or arm.get_node_or_null("Palm") == null:
            _fail("missing articulated sleeve, cuff or palm")
            return
        if arm.get_node_or_null("Finger0") == null or arm.get_node_or_null("Thumb") == null:
            _fail("hands lack their low-poly finger silhouette")
            return
        var palm := arm.get_node("Palm") as MeshInstance3D
        var local := eye.to_local(palm.global_position)
        if local.z > -eye.near or absf(local.x / -local.z) > 0.85 or local.y / -local.z < -0.95:
            _fail("hand is clipped or positioned outside the FPS viewport")
            return
    rig.call("_process",0.016)
    body.call("_process",0.016)
    if not rig.visible:
        _fail("FPS arms are missing at level camera pitch")
        return
    var pelvis := body.get_node("PelvisRoot") as Node3D
    if (pelvis.get_node("LeftArm") as Node3D).visible:
        _fail("duplicate world-space arms visible with viewmodel")
        return
    rig.call("push_look_motion",Vector2(80.0,-35.0))
    rig.call("_process",0.016)
    if rig.position.length() <= 0.002:
        _fail("mouse look motion did not reach viewmodel sway")
        return
    for pitch in [-0.70,-0.90,-1.45]:
        eye.rotation.x = pitch
        rig.call("_process",0.016)
        body.call("_process",0.016)
        if not rig.visible or body.visible:
            _fail("FPS arms vanish or old body appears at pitch %s" % pitch)
            return
    if float(rig.get("downlook_weight")) < 0.99:
        _fail("maximum downlook pose not active")
        return
    for arm in [left,right]:
        if arm.get_node_or_null("ShoulderYoke") != null or arm.get_node_or_null("CoatPatch") != null:
            _fail("camera still contains oversized shoulder blocks")
            return
        var sleeve := arm.get_node("UpperCoatSleeve") as MeshInstance3D
        var palm := arm.get_node("Palm") as MeshInstance3D
        for part in [sleeve,palm]:
            var local := eye.to_local(part.global_position)
            if local.z >= -eye.near or absf(local.y / -local.z) > 1.17 or absf(local.x / -local.z) > 1.40:
                _fail("sleeve/hand outside downward screen")
                return
        var upper_mesh := sleeve.mesh as CylinderMesh
        if upper_mesh == null or maxf(upper_mesh.bottom_radius,upper_mesh.top_radius) > 0.07:
            _fail("oversized upper sleeve remains")
            return
        for cap in [-upper_mesh.height * 0.5, upper_mesh.height * 0.5]:
            var camera_cap := eye.to_local(sleeve.to_global(Vector3(0,cap,0)))
            if camera_cap.z > -eye.near - 0.085:
                _fail("sleeve intersects the camera clipping plane")
                return
    eye.rotation.x = 0.0
    rig.call("_process",0.016)
    body.call("_process",0.016)
    if not rig.visible or (pelvis.get_node("LeftArm") as Node3D).visible:
        _fail("FPS hands fail to return when looking up")
        return
    var sequence := eye.get_node_or_null("CharacterSmoking") as Node3D
    sequence.call("_set_phase",1)
    rig.call("_process",0.016)
    if rig.visible:
        _fail("camera-space hands conflict with scripted character gesture")
        return
    sequence.call("_set_phase",5)
    rig.call("_process",0.016)
    if not rig.visible:
        _fail("viewmodel does not recover in ambient phase")
        return
    print("VIEWMODEL_REGRESSION_OK: hands=2 coat_sleeves=true lowpoly=true camera_space=true persistent_downlook=true shoulder_blocks_absent=true cinematic_safe=true mouse_sway=true")
    quit(0)
