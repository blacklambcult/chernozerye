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
    var chest := fp.find_child("FPTorsoShell",true,false) as MeshInstance3D
    var waist := fp.find_child("FPWaistInner",true,false) as MeshInstance3D
    var pelvis := fp.find_child("FPPelvis",true,false) as MeshInstance3D
    if chest == null or waist == null or pelvis == null:
        _fail("FPS asset has no closed midsection")
        return
    if chest.mesh.get_faces().size() < 90:
        _fail("FPS torso is still a flat panel")
        return
    for mesh in [chest,waist,pelvis]:
        var mat := mesh.material_override as StandardMaterial3D
        if mat == null or mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
            _fail("FPS body material is transparent")
            return
    if fp.find_child("Head",true,false) != null or fp.find_child("SidorCanvasSack",true,false) != null:
        _fail("camera-safe FPS mesh has head/backpack")
        return
    var left := fp.find_child("LeftLegPivot",true,false) as Node3D
    var right := fp.find_child("RightLegPivot",true,false) as Node3D
    if left == null or right == null or absf(left.position.x+right.position.x)>0.001:
        _fail("left/right hips are incorrect")
        return
    var left_rest := left.position
    var right_rest := right.position
    var camera := player.get_node("Camera3D") as Camera3D
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
    print("MODELED_CHARACTER_REGRESSION_OK: two_glbs=true solid_torso=true closed_pelvis=true separate_f4=true stable_legs=true legacy_hidden=true")
    quit(0)
