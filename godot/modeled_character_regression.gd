extends SceneTree
# Checks two actual GLB scene instances rather than inspecting cutaway flags.

func _fail(message: String) -> void:
    push_error("MODELED_CHARACTER_REGRESSION_FAILED: "+message)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.set_script(load("res://player.gd"))
    get_root().add_child(player)
    var rig := player.get_node("ModeledCharacter") as Node3D
    var legacy := player.get_node("FirstPersonFullBody") as Node3D
    if not bool(rig.get("model_loaded")):
        _fail("standalone FPS and F4 GLBs missing")
        return
    var fp := rig.get("first_person_body") as Node3D
    var full := rig.get("full_body") as Node3D
    if fp == null or full == null or fp == full:
        _fail("assets must be separate nodes")
        return
    if not fp.visible or full.visible or legacy.visible:
        _fail("old body visible or FPS asset missing")
        return
    for banned in ["FPTorsoShell","FPShirtLining","FPWaistInner","Head","SidorCanvasSack"]:
        if fp.find_child(banned,true,false) != null:
            _fail("camera-blocking upper mesh present: " + banned)
            return
    for name in ["FPPelvis","FPCrotch","FPCoatHemL","FPCoatHemR"]:
        var piece := fp.find_child(name,true,false) as MeshInstance3D
        if piece == null:
            _fail("lower-body geometry missing: " + name)
            return
        var mat := piece.material_override as StandardMaterial3D
        if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
            _fail("pelvis or coat hem is transparent")
            return
    if player.get_node_or_null("Camera3D/FPSViewmodel/LeftArm/ShoulderYoke") == null:
        _fail("camera-space shoulders missing")
        return
    var left := fp.find_child("LeftLegPivot",true,false) as Node3D
    var right := fp.find_child("RightLegPivot",true,false) as Node3D
    if left == null or right == null or absf(left.position.x+right.position.x)>0.001:
        _fail("left/right hips are incorrect")
        return
    var left_rest := left.position
    var right_rest := right.position
    var camera := player.get_node("Camera3D") as Camera3D
    var body_offset := float(rig.get("FPS_BODY_BACK_OFFSET"))
    if absf(fp.position.z - body_offset) > 0.001 or absf(body_offset) > 0.10:
        _fail("lower body is not aligned below the eyes")
        return
    if absf(camera.position.z) > 0.001:
        _fail("gameplay camera was moved")
        return
    for n in fp.find_children("*","MeshInstance3D",true,false):
        var mesh := n as MeshInstance3D
        var aabb := mesh.get_aabb()
        var upper := mesh.to_global(Vector3(0,aabb.position.y+aabb.size.y,0)).y - player.global_position.y
        if upper > 0.96:
            _fail("upper coat geometry can obstruct the camera: " + String(mesh.name))
            return
    camera.rotation.x = -1.45
    var toe := fp.find_child("LeftBootToe",true,false) as MeshInstance3D
    var pelvis := fp.find_child("FPPelvis",true,false) as MeshInstance3D
    var camera_toe := camera.to_local(toe.to_global(toe.mesh.get_aabb().get_center()))
    var camera_pelvis := camera.to_local(pelvis.to_global(pelvis.mesh.get_aabb().get_center()))
    if camera_toe.z >= -camera.near or camera_pelvis.z >= -camera.near:
        _fail("leg geometry behind the camera")
        return
    if camera_toe.y / -camera_toe.z < camera_pelvis.y / -camera_pelvis.z + 0.04:
        _fail("boot is hidden behind pelvis at steep downward view")
        return
    for pitch in [0.0,-0.5,-1.0,-1.45]:
        camera.rotation.x = pitch
        for step in range(24):
            rig.call("_process",0.016)
        if left.position.distance_to(left_rest)>0.001 or right.position.distance_to(right_rest)>0.001:
            _fail("camera pitch moved leg joints")
            return
    player.call("_toggle_model_inspection")
    if fp.visible or not full.visible or not (player.get_node("CharacterInspectionCamera") as Camera3D).current:
        _fail("F4 does not display only full GLB")
        return
    if full.find_child("Head",true,false) == null or full.find_child("WinterCoat",true,false) == null:
        _fail("F4 model missing head or coat")
        return
    player.call("_toggle_model_inspection")
    if not fp.visible or full.visible or legacy.visible:
        _fail("F4 return failed")
        return
    print("MODELED_CHARACTER_REGRESSION_OK: two_glbs=true lower_only=true opaque_pelvis=true separate_f4=true stable_legs=true legacy_hidden=true no_high_coat=true boots_ahead=true")
    quit(0)
