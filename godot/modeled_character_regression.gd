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
    var body_offset := float(rig.get("FPS_BODY_BACK_OFFSET"))
    if absf(fp.position.z - body_offset) > 0.001 or body_offset < 0.20:
        _fail("the camera is still directly above the open coat collar")
        return
    if absf(camera.position.z) > 0.001:
        _fail("gameplay camera was moved instead of the FPS visual body")
        return
    # Test what actually projects into the screen when looking down.
    # The old checks only tested material/mesh existence and completely
    # missed a giant eight-sided collar covering the viewport center.
    camera.rotation.x = -1.45
    # AABB corner (maximum y, minimum z) is not necessarily an actual
    # vertex: our garment tapers at the collar, with a broader lower hem.
    # Project the genuine collar vertices rather than a phantom box corner.
    var arrays := chest.mesh.surface_get_arrays(0)
    var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
    var top := -100.0
    for vertex in vertices:
        top = maxf(top, vertex.y)
    var most_central_rim := -100.0
    var collar_vertices := 0
    for vertex in vertices:
        if vertex.y < top - 0.012:
            continue
        collar_vertices += 1
        var camera_point := camera.to_local(chest.to_global(vertex))
        if camera_point.z >= -camera.near:
            _fail("actual coat collar crosses the camera near plane")
            return
        most_central_rim = maxf(most_central_rim, camera_point.y / -camera_point.z)
    if collar_vertices < 6:
        _fail("imported glTF has an incomplete upper collar ring")
        return
    if most_central_rim > -0.25:
        _fail("open coat collar covers the center of downward FPS view")
        return
    var toe := fp.find_child("LeftBootToe",true,false) as MeshInstance3D
    if toe == null:
        _fail("real imported FPS boot is missing")
        return
    var camera_toe := camera.to_local(toe.global_position)
    if camera_toe.z >= -camera.near or camera_toe.y / -camera_toe.z < most_central_rim + 0.09:
        _fail("boot projects behind the coat instead of ahead of it")
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
    print("MODELED_CHARACTER_REGRESSION_OK: two_glbs=true solid_torso=true closed_pelvis=true separate_f4=true stable_legs=true legacy_hidden=true coat_below_center=true boots_ahead=true")
    quit(0)
