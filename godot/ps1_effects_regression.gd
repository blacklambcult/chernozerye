extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var world := Node3D.new()
    root.add_child(world)
    var camera := Camera3D.new()
    world.add_child(camera)
    camera.position = Vector3(0, 0.8, 4)
    camera.look_at(Vector3.ZERO)
    camera.make_current()
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-40, -25, 0)
    world.add_child(sun)
    var fx: Node = load("res://ps1_effects.gd").new()
    fx.name = "PS1Effects"
    var grade := ShaderMaterial.new()
    grade.shader = preload("res://retro_grade.gdshader")
    fx.grade_material = grade
    world.add_child(fx)
    var meshes: Array[MeshInstance3D] = []
    for i in 5:
        var mesh := MeshInstance3D.new()
        mesh.mesh = BoxMesh.new()
        var material := StandardMaterial3D.new()
        material.albedo_color = Color("#f1ae66")
        if i == 1:
            material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
            material.billboard_keep_scale = true
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            material.no_depth_test = true
        elif i == 2:
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
        mesh.material_override = material
        if i == 3:
            var wood := ShaderMaterial.new()
            wood.shader = load("res://cabin_wood.gdshader")
            mesh.material_override = wood
        mesh.position = Vector3((i - 1.5) * 1.1, 0, 0)
        if i < 4:
            mesh.add_to_group(&"ps1_jitter_foliage")
        else:
            mesh.name = "Road"
            mesh.scale = Vector3(4, 0.01, 12)
        world.add_child(mesh)
        meshes.append(mesh)
    var player := CharacterBody3D.new()
    world.add_child(player)
    var pause := preload("res://pause_overlay.gd").new()
    player.add_child(pause)
    var jitter := pause.find_child("PS1Jitter", true, false) as CheckButton
    var pixels := pause.find_child("PS1Pixels", true, false) as CheckButton
    var strength := pause.find_child("PS1PixelStrength", true, false) as HSlider
    assert(jitter != null and pixels != null and strength != null)
    assert(strength.value == 55.0)
    strength.value = 0
    assert(fx.pixel_strength == 0.0)
    assert(grade.get_shader_parameter("ps1_pixel_strength") == 0.0)
    strength.value = 100
    assert(grade.get_shader_parameter("ps1_pixel_strength") == 1.0)
    assert(not jitter.button_pressed and not pixels.button_pressed)
    jitter.button_pressed = true
    assert(fx.jitter_enabled and not fx.pixels_enabled)
    pixels.button_pressed = true
    assert(fx.pixels_enabled and grade.get_shader_parameter("ps1_pixels_enabled"))
    await process_frame
    await process_frame
    assert(meshes[0].material_override is ShaderMaterial)
    assert(meshes[1].material_override is StandardMaterial3D)
    assert(meshes[2].material_override is StandardMaterial3D)
    assert(meshes[3].material_override is ShaderMaterial)
    assert(meshes[4].material_override is StandardMaterial3D)
    var late_mesh := MeshInstance3D.new()
    late_mesh.mesh = BoxMesh.new()
    late_mesh.add_to_group(&"ps1_jitter_foliage")
    world.add_child(late_mesh)
    await process_frame
    await process_frame
    assert(late_mesh.get_surface_override_material(0) is ShaderMaterial)
    jitter.button_pressed = false
    assert(meshes[0].material_override is StandardMaterial3D)
    assert(late_mesh.get_surface_override_material(0) == null)
    assert(not fx.jitter_enabled and fx.pixels_enabled)
    pixels.button_pressed = false
    assert(not fx.pixels_enabled)
    print("PS1_EFFECTS_REGRESSION_OK")
    quit()
