extends Node3D
# HELLISH FORGE — imported user-authored low-poly model, arcade-only gameplay.
# This module keeps the old six-round two-click revolver untouched.
const CAPACITY := 7
const RELOAD_SECONDS := 1.20
const VIEWMODEL_PROFILE := "res://assets/forge_pistol.viewmodel.json"
const DEFAULT_REST := Vector3(0.285, -0.225, -0.47)
const ASSET_SCENE: PackedScene = preload("res://assets/forge_pistol.glb")
const REVOLVER_AUDIO := preload("res://revolver.gd")
const PISTOL_SOUNDS := {
    "fire": preload("res://audio/pistol_shot.ogg"),
    "reload": preload("res://audio/pistol_reload.ogg"),
    "empty": preload("res://audio/pistol_empty.ogg"),
    "cock": preload("res://audio/pistol_cock.ogg"),
}
const SHOT_STREAM: AudioStream = preload("res://revolver_report.wav")
const DEFAULT_MODEL_SCALE := 1.36
const DEFAULT_BODYCAM := 0.8
const MUZZLE_HAZE_SECONDS := 0.20
# Bodycam response scales: backward shove, muzzle lift, recovery time.
const CLASS_RESPONSE := {
    "revolver": Vector3(1.16, 1.10, 1.15),
    "pistol": Vector3(0.86, 1.00, 0.85),
    "smg": Vector3(0.74, 0.82, 0.82),
    "assault": Vector3(1.14, 0.88, 1.00),
    "boltrifle": Vector3(1.43, 0.90, 1.30),
    "semirifle": Vector3(1.26, 0.86, 1.15),
    "doubleshotgun": Vector3(1.62, 1.11, 1.40),
    "pumpshotgun": Vector3(1.46, 0.98, 1.30),
}
var indoors := false
var rounds := CAPACITY
var capacity := CAPACITY
var reload_seconds := RELOAD_SECONDS
var damage := 20.0
var visual_recoil := 1.0
var shot_interval := 0.23
var weapon_weight := 1.0
var pushback := 1.0
var recovery_speed := 1.0
var inertia_strength := 1.0
var impact_strength := 1.0
var bodycam_strength := DEFAULT_BODYCAM
var bodycam_response := Vector3.ONE
var shot_impulse := 0.0
var recoil_follow := 0.0
var haze_left := 0.0
var haze_origin := Vector3.ZERO
var haze_direction := Vector3.FORWARD
var muzzle_haze: MeshInstance3D
var haze_material: StandardMaterial3D
var recoil_energy := 0.0
var recoil_pose := 0.0
var recoil_twist := 0.0
var look_lag := Vector2.ZERO
var movement_lag := Vector3.ZERO
var shot_noise := 1.0
var automatic := false
var trigger_held := false
var sound_profile := "standard"
var cooldown := 0.0
var reload_left := 0.0
var bloom := 0.0
var pending := false
var last_action := "idle"
var eye: Camera3D
var player: CharacterBody3D
var visual_holder: Node3D
var imported_model: Node3D
var model_animation: AnimationPlayer
var inventory_slot := 2
var package_override: Dictionary = {}
var model_override: PackedScene
var test_label := ""
var test_slot_label := ""
var custom_model_loaded := false
var flash_left := 0.0
var casing_port: Node3D
var spent_cases := 0
var eject_at := 0.0
var weapon_type := ""
var break_stage := 0
var casing_delay := 0.0
var cocking_clip: StringName = &""
var cocked := true
var cocking_left := 0.0
var grip_marker: Node3D
var forward_marker: Node3D
var magazine_marker: Node3D
var weapon_hand: Node3D
var rest_pose := DEFAULT_REST
var rest_angles := Vector3(0.0, deg_to_rad(9.0), 0.0)
var model_scale := DEFAULT_MODEL_SCALE
var hand_position := Vector3(0.025, -0.015, 0.035)
var hand_angles := Vector3.ZERO

func _read_vector(values: Variant, fallback: Vector3) -> Vector3:
    if not values is Array or values.size() != 3:
        return fallback
    for value in values:
        if not (value is int or value is float) or not is_finite(float(value)):
            return fallback
    return Vector3(float(values[0]), float(values[1]), float(values[2]))

func _read_local_profile() -> Dictionary:
    if not OS.has_feature("web"):
        return {}
    var raw: Variant = JavaScriptBridge.eval(
        "(() => { try { return localStorage.getItem('chernozerye.forge.game-viewmodel.v1'); } catch (_) { return null; } })()", true)
    if not raw is String or raw.length() > 16384:
        return {}
    var profile: Variant = JSON.parse_string(raw)
    if not profile is Dictionary or profile.get("format") != "chernozerye.forge.viewmodel" \
            or profile.get("version") != 1 or not profile.get("viewmodel") is Dictionary:
        return {}
    return profile["viewmodel"]

func _read_game_model() -> Dictionary:
    if not OS.has_feature("web"):
        return {}
    var raw: Variant = JavaScriptBridge.eval(
        "(() => { try { return localStorage.getItem('chernozerye.forge.game-model.v1'); } catch (_) { return null; } })()", true)
    if not raw is String or raw.length() > 2800000:
        return {}
    var data: Variant = JSON.parse_string(raw)
    return data if accepts_package(data) else {}

func accepts_package(data: Variant) -> bool:
    if not data is Dictionary or data.get("version") != 1 \
            or not data.get("glb") is String or not data.get("viewmodel") is Dictionary \
            or not data.get("gameplay") is Dictionary:
        return false
    return data["glb"].length() <= 2800000 and ["sidearm", "longarm"].has(data.get("category"))

func _make_game_model(data: Dictionary) -> Node3D:
    if data.is_empty():
        return null
    var document := GLTFDocument.new()
    var state := GLTFState.new()
    if document.append_from_buffer(Marshalls.base64_to_raw(data["glb"]), "", state) != OK:
        return null
    return document.generate_scene(state) as Node3D

func _game_number(value: Variant, fallback: float, low: float, high: float) -> float:
    if not (value is float or value is int) or not is_finite(float(value)):
        return fallback
    return clampf(float(value), low, high)

func _apply_gameplay(specs: Dictionary) -> void:
    capacity = int(_game_number(specs.get("capacity"), CAPACITY, 1, 30))
    rounds = capacity
    reload_seconds = _game_number(specs.get("reload"), RELOAD_SECONDS, 0.3, 5.0)
    damage = _game_number(specs.get("damage"), 20.0, 1, 100)
    visual_recoil = _game_number(specs.get("recoil"), 1.0, 0, 3)
    sound_profile = str(specs.get("sound", "standard"))
    shot_interval = 60.0 / _game_number(specs.get("rate"), 60.0 / 0.23, 60.0, 1200.0)
    weapon_weight = _game_number(specs.get("weight"), 1.0, 0.1, 20.0)
    pushback = _game_number(specs.get("pushback"), 1.0, 0.0, 3.0)
    recovery_speed = _game_number(specs.get("recovery"), 1.0, 0.25, 3.0)
    inertia_strength = _game_number(specs.get("inertia"), 1.0, 0.0, 3.0)
    impact_strength = _game_number(specs.get("impact"), 1.0, 0.0, 3.0)
    var previous_bodycam := _game_number(specs.get("bodycam"), DEFAULT_BODYCAM, 0.0, 1.0)
    # Earlier Forge builds saved zero even when the field was never edited.
    bodycam_strength = DEFAULT_BODYCAM if previous_bodycam == 0.0 and specs.get("bodycamProfile") != 2 else previous_bodycam
    var response_class := str(specs.get("class", ""))
    if not CLASS_RESPONSE.has(response_class):
        response_class = weapon_type
    bodycam_response = CLASS_RESPONSE.get(response_class, Vector3.ONE)
    shot_noise = _game_number(specs.get("noise"), 100.0, 0.0, 100.0) / 100.0
    if sound_profile == "silent":
        shot_noise = 0.0
    automatic = specs.get("mode") == "auto"

func _read_profile(override: Dictionary = {}) -> void:
    if not FileAccess.file_exists(VIEWMODEL_PROFILE):
        return
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(VIEWMODEL_PROFILE))
    if not parsed is Dictionary or not parsed.get("viewmodel") is Dictionary:
        push_warning("FORGE_VIEWMODEL_PROFILE_INVALID")
        return
    var local := override if not override.is_empty() else _read_local_profile()
    var settings: Dictionary = local if not local.is_empty() else parsed["viewmodel"]
    rest_pose = _read_vector(settings.get("position"), DEFAULT_REST).clamp(Vector3.ONE * -2, Vector3.ONE * 2)
    var rot := _read_vector(settings.get("rotation"), Vector3(0.0, 9.0, 0.0))
    rest_angles = Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
    var scale_value: float = float(settings.get("scale", DEFAULT_MODEL_SCALE))
    model_scale = clampf(scale_value if is_finite(scale_value) else DEFAULT_MODEL_SCALE, 0.05, 8.0)
    hand_position = _read_vector(settings.get("hand_position"),
        Vector3(0.025, -0.015, 0.035)).clamp(-Vector3.ONE, Vector3.ONE)
    var hand_rot := _read_vector(settings.get("hand_rotation"), Vector3.ZERO)
    hand_angles = Vector3(deg_to_rad(hand_rot.x),
        deg_to_rad(hand_rot.y), deg_to_rad(hand_rot.z))

var report := AudioStreamPlayer.new()
var action_audio := AudioStreamPlayer.new()
var action_sounds: Dictionary = {}
var custom_report := false
var default_sounds: Dictionary = {}
var flash := OmniLight3D.new()

func _ready() -> void:
    name = "ForgePistol"
    eye = get_parent() as Camera3D
    if eye == null:
        push_error("FORGE_PISTOL_CAMERA_MISSING")
        return
    player = eye.get_parent() as CharacterBody3D
    var package := package_override if not package_override.is_empty() else _read_game_model()
    package_override = {}
    var custom := model_override.instantiate() as Node3D if model_override != null else _make_game_model(package)
    custom_model_loaded = custom != null
    if custom != null:
        var slot: Variant = package.get("slot", 3)
        if (slot is int or slot is float) and slot >= 3 and slot <= 10 and floorf(float(slot)) == float(slot):
            inventory_slot = int(slot) - 1
        _read_profile(package["viewmodel"])
        var weapon_class: String = str(package["gameplay"].get("class", package.get("weaponType", "")))
        weapon_type = str(package.get("weaponType", weapon_class))
        match weapon_class if not weapon_class.is_empty() else weapon_type:
            "pistol": default_sounds = PISTOL_SOUNDS
            "revolver": default_sounds = REVOLVER_AUDIO.DEFAULT_SOUNDS
        _apply_gameplay(package["gameplay"])
        cocking_clip = { "revolver": &"CockHammer", "pistol": &"RackSlide", "smg": &"RackBolt" }.get(weapon_class, &"")
        cocking_clip = {
            "assault": &"RackBolt", "semirifle": &"RackBolt",
            "boltrifle": &"CycleBolt", "pumpshotgun": &"PumpAction",
            "doubleshotgun": &""
        }.get(weapon_type, cocking_clip)
        if weapon_type == "doubleshotgun":
            capacity = 2
            rounds = capacity
            automatic = false
        cocked = cocking_clip != &"CockHammer"
        print("FORGE_GAME_MODEL_READY: ", str(package.get("name", "")))
    else:
        _read_profile()
        bodycam_response = CLASS_RESPONSE["pistol"]
        default_sounds = PISTOL_SOUNDS
    position = rest_pose
    rotation = rest_angles
    visual_holder = Node3D.new()
    visual_holder.name = "ForgePistolVisual"
    # Forge exports a metric scene. This is a viewmodel-only scale adjustment,
    # leaving the uploaded GLB's mesh and marker coordinates untouched.
    visual_holder.scale = Vector3.ONE * model_scale
    add_child(visual_holder)
    imported_model = custom if custom != null else ASSET_SCENE.instantiate() as Node3D
    visual_holder.add_child(imported_model)
    if custom != null:
        var players := imported_model.find_children("*", "AnimationPlayer", true, false)
        if not players.is_empty():
            model_animation = players[0] as AnimationPlayer
            if model_override != null:
                # Packaged scenes may share animation resources between instances.
                # Copy clips before modifying Fire or adding repair tracks.
                for library_name in model_animation.get_animation_library_list():
                    var source := model_animation.get_animation_library(library_name)
                    var library := AnimationLibrary.new()
                    for clip_name in source.get_animation_list():
                        library.add_animation(clip_name, source.get_animation(clip_name).duplicate())
                    model_animation.remove_animation_library(library_name)
                    model_animation.add_animation_library(library_name, library)
            _tune_fire_body_tracks()
            if weapon_type == "doubleshotgun":
                _repair_break_action_clips()
            else:
                _complete_revolver_pivot_tracks()
    casing_port = imported_model.find_child("EjectionPort", true, false) as Node3D
    grip_marker = imported_model.find_child("HF_GRIP_PRIMARY", true, false) as Node3D
    forward_marker = imported_model.find_child("HF_FORWARD", true, false) as Node3D
    magazine_marker = imported_model.find_child("HF_MAGAZINE", true, false) as Node3D
    # Procedural Weapon Generator exports its native Godot socket names.
    # The grip pivot is already at Weapon_Body origin, while MuzzlePoint can
    # directly drive the existing flash position.
    if forward_marker == null:
        forward_marker = imported_model.find_child("MuzzlePoint", true, false) as Node3D
    # Position the actual author-supplied hand marker over the camera hand.
    var grip := Vector3.ZERO if custom != null else Vector3(0.0, 0.634, 0.3523)
    if grip_marker != null:
        grip = imported_model.to_local(grip_marker.global_position)
    imported_model.position = -grip
    # Hand is attached at the exact same camera-local origin as the author
    # supplied grip marker, instead of floating behind the visual prop.
    var arms_glb: Variant = package.get("armsGlb")
    if arms_glb is String and not arms_glb.is_empty() and arms_glb.length() <= 2666668:
        weapon_hand = _make_game_model({"glb": arms_glb})
        if weapon_hand != null and weapon_hand.find_child("WeaponAttachPoint", true, false) == null:
            weapon_hand.free()
            weapon_hand = null
    if weapon_hand == null:
        weapon_hand = Node3D.new()
        weapon_hand.set_script(preload("res://weapon_hand_viewmodel.gd"))
        weapon_hand.set("grip_local", Vector3.ZERO)
    weapon_hand.name = "WeaponRightHand"
    weapon_hand.position = hand_position
    weapon_hand.rotation = hand_angles
    add_child(weapon_hand)
    flash.position = Vector3(0.0, 0.11, -0.51)
    if forward_marker != null:
        flash.position = to_local(forward_marker.global_position)
    flash.light_color = Color("#ffb84d")
    flash.omni_range = 2.8
    flash.light_energy = 3.0
    flash.visible = false
    add_child(flash)
    _add_flash_cone(0.036, 0.12, 5, Color("#ffd275"))
    _add_flash_cone(0.024, 0.09, 4, Color.WHITE)
    if bodycam_strength > 0.0:
        _add_muzzle_haze()
    report.stream = SHOT_STREAM
    _load_action_sounds(package.get("sounds", {}))
    custom_report = action_sounds.has("fire")
    action_sounds = default_sounds.merged(action_sounds, true)
    if action_sounds.has("fire"):
        report.stream = action_sounds["fire"]
    report.bus = &"Effects"
    report.volume_db = -5.0
    report.max_polyphony = 3
    add_child(report)
    action_audio.bus = &"Effects"
    action_audio.max_polyphony = 3
    add_child(action_audio)
    visible = false
    print("FORGE_PISTOL_READY: model=uploaded_glb capacity=", capacity, " grip_marker=",
        grip_marker != null, " forward_marker=", forward_marker != null,
        " magazine_marker=", magazine_marker != null,
        " model_scale=", model_scale, " hand_visible=", weapon_hand != null)

func _add_flash_cone(radius: float, length: float, sides: int, color: Color) -> void:
    var cone := CylinderMesh.new()
    cone.top_radius = 0.0
    cone.bottom_radius = radius
    cone.height = length
    cone.radial_segments = sides
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = color
    var instance := MeshInstance3D.new()
    instance.mesh = cone
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    instance.rotation.x = -PI / 2.0
    instance.position.z = -0.06
    flash.add_child(instance)

func _add_muzzle_haze() -> void:
    var gradient := Gradient.new()
    gradient.offsets = PackedFloat32Array([0.0, 0.80, 1.0])
    gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.08), Color(1, 1, 1, 0)])
    var texture := GradientTexture2D.new()
    texture.width = 32
    texture.height = 32
    texture.gradient = gradient
    texture.fill = GradientTexture2D.FILL_RADIAL
    texture.fill_from = Vector2(0.5, 0.5)
    texture.fill_to = Vector2(1.0, 0.5)
    haze_material = StandardMaterial3D.new()
    haze_material.albedo_texture = texture
    haze_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    haze_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    haze_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    haze_material.billboard_keep_scale = true
    var quad := QuadMesh.new()
    quad.size = Vector2.ONE
    muzzle_haze = MeshInstance3D.new()
    muzzle_haze.top_level = true
    muzzle_haze.mesh = quad
    muzzle_haze.material_override = haze_material
    muzzle_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    muzzle_haze.hide()
    add_child(muzzle_haze)

func equip(value: bool) -> void:
    visible = value
    if not value:
        pending = false
        trigger_held = false
        reload_left = 0.0
        eject_at = 0.0
        casing_delay = 0.0
        if weapon_type in ["pistol", "smg", "assault", "semirifle"]:
            spent_cases = 0
        break_stage = 0
        if cocking_left > 0.0 or cocking_clip == &"CockHammer":
            cocked = false
        cocking_left = 0.0
        flash.visible = false
        recoil_energy = 0.0
        recoil_pose = 0.0
        recoil_twist = 0.0
        shot_impulse = 0.0
        recoil_follow = 0.0
        haze_left = 0.0
        if muzzle_haze != null:
            muzzle_haze.hide()
        look_lag = Vector2.ZERO
        movement_lag = Vector3.ZERO
        flash_left = 0.0
        last_action = "holstered"
        if model_animation != null:
            model_animation.stop()
            model_animation.clear_queue()
            model_animation.speed_scale = 1.0
            if model_animation.has_animation(&"RESET"):
                model_animation.play(&"RESET")
                model_animation.advance(0.0)

func _tune_fire_body_tracks() -> void:
    if bodycam_strength == 0.0 or not model_animation.has_animation(&"Fire"):
        return
    var root := model_animation.get_node_or_null(model_animation.root_node)
    if root == null:
        return
    var body := imported_model.find_child("Weapon_Body", true, false)
    if body == null:
        return
    var fire := model_animation.get_animation(&"Fire")
    var path := root.get_path_to(body)
    # Keep each generator clip's neutral pose and animated internal parts.
    for type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
        var track := fire.find_track(path, type)
        if track < 0 or fire.track_get_key_count(track) == 0:
            continue
        var first: Variant = fire.track_get_key_value(track, 0)
        for key in range(1, fire.track_get_key_count(track)):
            var value: Variant = fire.track_get_key_value(track, key)
            var pose: Variant = value.lerp(first, bodycam_strength) if type == Animation.TYPE_POSITION_3D \
                else value.slerp(first, bodycam_strength)
            fire.track_set_key_value(track, key, pose)

func _complete_revolver_pivot_tracks() -> void:
    var root := model_animation.get_node_or_null(model_animation.root_node)
    if root == null or imported_model.find_child("CylinderPivot", true, false) == null:
        return
    for pivot_name in ["CylinderPivot", "HammerPivot"]:
        var pivot := imported_model.find_child(pivot_name, true, false) as Node3D
        if pivot == null:
            continue
        var path := root.get_path_to(pivot)
        for name in model_animation.get_animation_list():
            var clip := model_animation.get_animation(name)
            for channel in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
                if clip.find_track(path, channel) >= 0:
                    continue
                var index := clip.add_track(channel)
                clip.track_set_path(index, path)
                if channel == Animation.TYPE_POSITION_3D:
                    clip.position_track_insert_key(index, 0.0, pivot.position)
                else:
                    clip.rotation_track_insert_key(index, 0.0, pivot.quaternion)

func _repair_break_action_clips() -> void:
    var hinge := imported_model.find_child("BarrelPivot", true, false) as Node3D
    var root := model_animation.get_node_or_null(model_animation.root_node)
    if hinge == null or root == null:
        return
    var path := root.get_path_to(hinge)
    for name in model_animation.get_animation_list():
        var clip := model_animation.get_animation(name)
        if clip.find_track(path, Animation.TYPE_ROTATION_3D) >= 0:
            continue
        var index := clip.add_track(Animation.TYPE_ROTATION_3D)
        clip.track_set_path(index, path)
        clip.rotation_track_insert_key(index, 0.0, hinge.quaternion)
    if not model_animation.has_animation(&"InsertShells"):
        return
    var chambers: Array[Vector3] = []
    for child in hinge.get_children():
        if child is MeshInstance3D and absf(child.position.z - 0.001) < 0.0005:
            chambers.append(child.position)
    if chambers.size() != 2:
        chambers = [Vector3(-0.016, 0.040, 0.001), Vector3(0.016, 0.040, 0.001)]
    var insertion := model_animation.get_animation(&"InsertShells")
    for i in range(2):
        var shell_name := "ReloadShell_L" if i == 0 else "ReloadShell_R"
        var shell := hinge.get_node_or_null(NodePath(shell_name)) as Node3D
        if shell == null:
            shell = Node3D.new()
            shell.name = shell_name
            hinge.add_child(shell)
            for is_rim in [false, true]:
                var part := MeshInstance3D.new()
                var mesh := CylinderMesh.new()
                mesh.top_radius = 0.012 if is_rim else 0.0105
                mesh.bottom_radius = mesh.top_radius
                mesh.height = 0.014 if is_rim else 0.056
                mesh.radial_segments = 8
                var material := StandardMaterial3D.new()
                material.albedo_color = Color("#bb8948") if is_rim else Color("#a6261f")
                part.mesh = mesh
                part.material_override = material
                part.rotation.x = PI / 2.0
                part.position.z = 0.009 if is_rim else -0.022
                shell.add_child(part)
        var shell_path := root.get_path_to(shell)
        var hidden_scale := Vector3.ONE * 0.001
        shell.scale = hidden_scale
        var start := 0.04 if i == 0 else 0.34
        var end := 0.42 if i == 0 else 0.78
        if insertion.find_track(shell_path, Animation.TYPE_POSITION_3D) < 0:
            var index := insertion.add_track(Animation.TYPE_POSITION_3D)
            insertion.track_set_path(index, shell_path)
            var chamber := chambers[i]
            insertion.position_track_insert_key(index, start, Vector3(chamber.x, chamber.y, 0.14))
            insertion.position_track_insert_key(index, end, Vector3(chamber.x, chamber.y, -0.018))
        for name in model_animation.get_animation_list():
            var clip := model_animation.get_animation(name)
            if clip.find_track(shell_path, Animation.TYPE_SCALE_3D) >= 0:
                continue
            var index := clip.add_track(Animation.TYPE_SCALE_3D)
            clip.track_set_path(index, shell_path)
            clip.scale_track_insert_key(index, 0.0, hidden_scale)
            if clip == insertion:
                clip.scale_track_insert_key(index, start - 0.01, hidden_scale)
                clip.scale_track_insert_key(index, start, Vector3.ONE)
                clip.scale_track_insert_key(index, end, Vector3.ONE)
                clip.scale_track_insert_key(index, end + 0.02, hidden_scale)

func _eject_cases() -> void:
    var count := spent_cases
    spent_cases = 0
    if casing_port == null:
        return
    var world := get_tree().current_scene
    if world == null:
        return
    for index in range(count):
        var casing := MeshInstance3D.new()
        var mesh := CylinderMesh.new()
        mesh.top_radius = 0.005
        mesh.bottom_radius = 0.006
        mesh.height = 0.027
        mesh.radial_segments = 6
        casing.mesh = mesh
        var brass := StandardMaterial3D.new()
        brass.albedo_color = Color("#bb8948")
        casing.material_override = brass
        casing.top_level = true
        world.add_child(casing)
        casing.global_position = casing_port.global_position + eye.global_basis.y * (0.005 * index)
        var origin := casing.position
        var direction := eye.global_basis.x
        if weapon_type in ["assault", "semirifle", "smg"] or cocking_clip == &"CockHammer":
            direction = -direction
        elif weapon_type == "doubleshotgun":
            direction = eye.global_basis.z
        var drift := direction * randf_range(0.16, 0.34)
        if weapon_type in ["doubleshotgun", "pumpshotgun"]:
            casing.scale = Vector3(1.5, 1.65, 1.5)
            brass.albedo_color = Color("#a63f31")
        var tween := casing.create_tween()
        tween.tween_method(func(t: float) -> void:
            casing.position = origin + drift * t + Vector3.UP * (0.38 * t - 1.8 * t * t)
            casing.rotation = Vector3(t * 12.0, t * 8.0, t * 5.0), 0.0, 1.0, 0.8)
        tween.tween_callback(casing.queue_free)

func _play_model_clips(clips: Array[StringName], seconds: float) -> void:
    if model_animation == null:
        return
    var duration := 0.0
    for clip in clips:
        if not model_animation.has_animation(clip):
            return
        var action := model_animation.get_animation(clip)
        # Godot imports some GLTF actions (such as CycleBolt) as loops.
        action.loop_mode = Animation.LOOP_NONE
        duration += action.length
    if duration <= 0.0:
        return
    model_animation.stop()
    model_animation.clear_queue()
    model_animation.speed_scale = duration / seconds
    model_animation.play(clips[0], 0.0)
    for index in range(1, clips.size()):
        model_animation.queue(clips[index])
    model_animation.advance(0.0)

func _load_action_sounds(sounds: Variant) -> void:
    if not sounds is Dictionary:
        return
    for action in ["fire", "cock", "reload", "empty"]:
        var sound: Variant = sounds.get(action)
        if not sound is Dictionary or not sound.get("data") is String:
            continue
        if sound["data"].length() > 699052:
            continue
        var bytes := Marshalls.base64_to_raw(sound["data"])
        if bytes.is_empty() or bytes.size() > 512 * 1024:
            continue
        var stream: AudioStream
        match sound.get("format"):
            "wav": stream = AudioStreamWAV.load_from_buffer(bytes)
            "ogg": stream = AudioStreamOggVorbis.load_from_buffer(bytes)
            "mp3": stream = AudioStreamMP3.load_from_buffer(bytes)
        if stream != null:
            action_sounds[action] = stream

func _play_action_sound(action: String) -> void:
    if action_sounds.has(action):
        action_audio.stream = action_sounds[action]
        action_audio.volume_db = -7.0 if action_audio.stream == default_sounds.get(action) else 0.0
        action_audio.play()

func cock() -> void:
    if not visible or cocking_clip == &"" or cocked or (rounds <= 0 and spent_cases == 0 and cocking_clip != &"CockHammer") \
            or reload_left > 0.0 or cooldown > 0.0 or cocking_left > 0.0:
        return
    trigger_held = false
    pending = false
    cocking_left = 0.35
    _play_action_sound("cock")
    if model_animation != null and model_animation.has_animation(cocking_clip):
        cocking_left = maxf(0.05, model_animation.get_animation(cocking_clip).length)
        _play_model_clips([cocking_clip], cocking_left)
    if spent_cases > 0 and cocking_clip in [&"CycleBolt", &"PumpAction"]:
        casing_delay = cocking_left * (0.34 / 0.78 if cocking_clip == &"CycleBolt" else 0.22 / 0.56)

func request_shot() -> void:
    if not visible or break_stage != 0 or reload_left > 0.0 or cooldown > 0.0:
        return
    if cocking_clip == &"CockHammer" and not cocked:
        trigger_held = false
        return
    if rounds <= 0:
        trigger_held = false
        if cocking_clip == &"CockHammer":
            cocked = false
            last_action = "dry_fire"
            if model_animation != null and model_animation.assigned_animation == cocking_clip:
                model_animation.seek(0.0, true)
                model_animation.pause()
        _play_action_sound("empty")
        return
    if not cocked:
        trigger_held = false
        return
    pending = true
    last_action = "fire"

func reload() -> void:
    if weapon_type == "doubleshotgun":
        _toggle_break_action()
        return
    if visible and rounds < capacity and reload_left <= 0.0 and cocking_left <= 0.0:
        pending = false
        trigger_held = false
        if cocking_clip != &"" and cocking_clip != &"PumpAction":
            cocked = false
        reload_left = reload_seconds
        if cocking_clip == &"CockHammer" and spent_cases > 0:
            eject_at = reload_seconds * (1.0 - 0.34 / 1.38)
        last_action = "reload"
        _play_action_sound("reload")
        if model_animation != null:
            if model_animation.has_animation(&"ReloadMag"):
                _play_model_clips([&"ReloadMag"], reload_seconds)
            elif model_animation.has_animation(&"BreakOpen"):
                _play_model_clips([&"BreakOpen", &"InsertShells", &"CloseBarrel"], reload_seconds)
            elif model_animation.has_animation(&"LoadShells"):
                _play_model_clips([&"LoadShells"], reload_seconds)
            else:
                _play_model_clips([&"Reload"], reload_seconds)

func _toggle_break_action() -> void:
    if not visible or reload_left > 0.0 or cooldown > 0.0:
        return
    pending = false
    trigger_held = false
    if break_stage == 0:
        if rounds == capacity:
            return
        break_stage = 1
        reload_left = 0.56
        if spent_cases > 0:
            casing_delay = 0.26
        _play_model_clips([&"BreakOpen"], reload_left)
    else:
        break_stage = 3 if break_stage == 2 else 4
        reload_left = 0.44
        _play_model_clips([&"CloseBarrel"], reload_left)

func insert_shells() -> void:
    if not visible or weapon_type != "doubleshotgun" or break_stage != 1 or reload_left > 0.0:
        return
    break_stage = 2
    reload_left = 0.88
    _play_action_sound("reload")
    _play_model_clips([&"InsertShells"], reload_left)

func spread_angle() -> float:
    var speed := Vector2(player.velocity.x, player.velocity.z).length() if player != null else 0.0
    return deg_to_rad(0.40 + minf(speed * 0.34, 2.1) + bloom)

func _shot_direction() -> Vector3:
    var angle := randf() * TAU
    var radius := sqrt(randf()) * tan(spread_angle())
    return (eye.global_basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1)).normalized()

func add_look_motion(relative: Vector2) -> void:
    var lag := clampf(sqrt(weapon_weight), 0.65, 2.5) * inertia_strength
    look_lag = (look_lag + relative * (0.0007 * lag)).limit_length(0.13)

func _shoot() -> void:
    if rounds <= 0 or break_stage != 0 or reload_left > 0.0 or not cocked:
        pending = false
        return
    pending = false
    var direction := _shot_direction()
    rounds -= 1
    recoil_energy = minf(recoil_energy + visual_recoil, 4.5)
    var twist := randf_range(-0.035, 0.035) * visual_recoil
    recoil_twist = clampf(recoil_twist + twist, -0.16, 0.16)
    shot_impulse = minf(shot_impulse + visual_recoil * bodycam_strength, 3.0)
    haze_left = MUZZLE_HAZE_SECONDS * sqrt(bodycam_strength)
    if muzzle_haze != null:
        haze_origin = forward_marker.global_position if forward_marker != null else flash.global_position
        haze_direction = -global_basis.z.normalized()
    flash_left = lerpf(0.065, 0.048, bodycam_strength)
    if cocking_clip in [&"CockHammer", &"CycleBolt", &"PumpAction"]:
        cocked = false
        trigger_held = false
        spent_cases += 1
    elif weapon_type == "doubleshotgun":
        spent_cases += 1
    elif weapon_type in ["pistol", "smg", "assault", "semirifle"]:
        spent_cases += 1
        if casing_delay <= 0.0:
            casing_delay = minf(0.04, shot_interval * 0.5)
    cooldown = shot_interval
    bloom = minf(2.6, bloom + 0.78)
    last_action = "fire"
    if model_animation != null and model_animation.has_animation(&"Fire"):
        _play_model_clips([&"Fire"], minf(shot_interval, model_animation.get_animation(&"Fire").length))
    var bundled_revolver: bool = not custom_report and default_sounds.get("fire") == REVOLVER_AUDIO.DEFAULT_SOUNDS["fire"]
    var fixed_report := custom_report or default_sounds.has("fire")
    if bundled_revolver:
        report.stream = REVOLVER_AUDIO.ROOM_REPORT if indoors else action_sounds["fire"]
    report.volume_db = -4.0 if indoors and bundled_revolver else (-10.0 if indoors else -5.0)
    report.pitch_scale = 1.0 if fixed_report else randf_range(1.06, 1.14)
    match sound_profile:
        "heavy":
            if not fixed_report:
                report.pitch_scale *= 0.78
        "muted": report.volume_db -= 12.0
    if sound_profile != "silent":
        report.play()
    if player != null:
        if shot_noise > 0.0:
            player.call("emit_noise", shot_noise)
        player.call("kick_view", visual_recoil * (1.0 - 0.65 * bodycam_strength),
            recovery_speed, recoil_twist * (1.0 - bodycam_strength))
        if shot_impulse > 0.0 and player.has_method("kick_bodycam"):
            player.call("kick_bodycam", visual_recoil * bodycam_strength * bodycam_response.x,
                twist, recovery_speed / lerpf(1.0, bodycam_response.z, bodycam_strength))
    var origin := eye.global_position
    var excluded: Array[RID] = []
    if player != null:
        excluded.append(player.get_rid())
    var query := PhysicsRayQueryParameters3D.create(origin,
        origin + direction * 90.0, 0xffffffff, excluded)
    var hit := eye.get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return
    var collider := hit.get("collider") as Node3D
    if collider != null and collider.has_method("apply_damage"):
        collider.call("apply_damage", damage)
    if collider != null and collider.is_in_group("breakable_pottery"):
        collider.queue_free()
        return
    # Keep the existing impact effects rather than introducing a second system.
    if player != null:
        var legacy := player.get("revolver") as Node3D
        if legacy != null:
            legacy.call("_surface_feedback", hit, minf(3.0, impact_strength * (1.0 + bodycam_strength * 0.35)))

func _physics_process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    flash_left = maxf(0.0, flash_left - delta)
    haze_left = maxf(0.0, haze_left - delta)
    bloom = move_toward(bloom, 0.0, delta * 2.2)
    if not visible:
        return
    if casing_delay > 0.0:
        casing_delay = maxf(0.0, casing_delay - delta)
        if casing_delay == 0.0:
            _eject_cases()
    if cocking_left > 0.0:
        cocking_left = maxf(0.0, cocking_left - delta)
        if cocking_left == 0.0:
            cocked = true
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if eject_at > 0.0 and reload_left <= eject_at:
            eject_at = 0.0
            _eject_cases()
        if reload_left == 0.0:
            if weapon_type != "doubleshotgun" or break_stage == 3:
                rounds = capacity
            if break_stage >= 3:
                break_stage = 0
    if automatic and trigger_held and player != null and player.get("controls_locked") != true \
            and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        request_shot()
    if pending:
        pending = false
        if player != null and player.get("controls_locked") != true and eye.current \
                and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _shoot()
    var mass := clampf(sqrt(weapon_weight), 0.65, 2.5)
    recoil_pose = lerpf(recoil_pose, recoil_energy, 1.0 - exp(-55.0 * delta))
    recoil_energy *= exp(-15.0 * recovery_speed / mass * delta)
    recoil_twist *= exp(-13.0 * recovery_speed / mass * delta)
    look_lag *= exp(-14.0 / mass * delta)
    var movement := Vector3.ZERO
    if player != null:
        var local_speed := eye.global_basis.inverse() * player.velocity
        movement = Vector3(-local_speed.x * 0.005, -local_speed.y * 0.004, -local_speed.z * 0.003)
        movement = movement.limit_length(0.04) * inertia_strength
    movement_lag = movement_lag.lerp(movement, 1.0 - exp(-10.0 / mass * delta))
    var settle := recovery_speed / lerpf(1.0, bodycam_response.z, bodycam_strength)
    recoil_follow = lerpf(recoil_follow, shot_impulse, 1.0 - exp(-19.0 * settle * delta))
    var rebound := maxf(0.0, recoil_follow - shot_impulse * 0.8)
    var lift := (recoil_pose * lerpf(0.105, 0.075 * bodycam_response.y, bodycam_strength)
        - 0.055 * rebound) / mass
    var shove := 0.06 * recoil_pose * pushback / mass
    if bodycam_strength > 0.0:
        shove = minf(shove + 0.085 * shot_impulse * bodycam_response.x * pushback / mass, 0.19)
    var wrist_drop := (0.024 * shot_impulse - 0.012 * rebound) / mass
    shot_impulse *= exp(-32.0 * settle / sqrt(mass) * delta)
    var reload_t := sin(PI * reload_left / reload_seconds)
    position = rest_pose + movement_lag + Vector3(
        look_lag.x * 0.26, -0.11 * reload_t - recoil_pose * 0.01 - wrist_drop - look_lag.y * 0.22,
        shove)
    rotation = rest_angles + Vector3(
        lift + look_lag.y, look_lag.x, recoil_twist - 0.20 * reload_t)
    if forward_marker != null:
        flash.position = to_local(forward_marker.global_position)
    flash.visible = flash_left > 0.0
    if flash.visible and bodycam_strength > 0.0:
        var intensity := flash_left / lerpf(0.065, 0.048, bodycam_strength)
        flash.light_energy = lerpf(3.0, 6.5 * intensity * intensity, bodycam_strength)
        for shape: MeshInstance3D in flash.get_children():
            shape.scale = Vector3.ONE * lerpf(1.0, 0.3 + 0.7 * intensity, bodycam_strength)
    if muzzle_haze != null:
        muzzle_haze.visible = haze_left > 0.0
        if muzzle_haze.visible:
            var age := 1.0 - haze_left / (MUZZLE_HAZE_SECONDS * sqrt(bodycam_strength))
            muzzle_haze.global_position = haze_origin + haze_direction * (0.035 + 0.11 * age) + Vector3.UP * (0.05 * age)
            muzzle_haze.scale = Vector3.ONE * lerpf(0.065, 0.19, age)
            haze_material.albedo_color = Color(0.58, 0.61, 0.66, 0.32 * bodycam_strength * pow(1.0 - age, 2.0))
