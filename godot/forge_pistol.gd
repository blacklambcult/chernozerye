extends Node3D
# HELLISH FORGE — imported user-authored low-poly model, arcade-only gameplay.
# This module keeps the old six-round two-click revolver untouched.
const CAPACITY := 7
const RELOAD_SECONDS := 1.20
const VIEWMODEL_PROFILE := "res://assets/forge_pistol.viewmodel.json"
const DEFAULT_REST := Vector3(0.285, -0.225, -0.47)
const ASSET_SCENE: PackedScene = preload("res://assets/forge_pistol.glb")
const SHOT_STREAM: AudioStream = preload("res://revolver_report.wav")
var indoors := false
var rounds := CAPACITY
var capacity := CAPACITY
var reload_seconds := RELOAD_SECONDS
var damage := 20.0
var visual_recoil := 1.0
var shot_interval := 0.23
var weapon_weight := 1.0
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
var casing_port: Node3D
var spent_cases := 0
var eject_at := 0.0
var cocking_clip: StringName = &""
var cocked := true
var cocking_left := 0.0
var grip_marker: Node3D
var forward_marker: Node3D
var magazine_marker: Node3D
var weapon_hand: Node3D
var rest_pose := DEFAULT_REST
var rest_angles := Vector3(0.0, deg_to_rad(9.0), 0.0)
var model_scale := 0.26
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
    if not data is Dictionary or data.get("version") != 1 \
            or not data.get("glb") is String or not data.get("viewmodel") is Dictionary \
            or not data.get("gameplay") is Dictionary:
        return {}
    if not ["sidearm", "longarm"].has(data.get("category")):
        return {}
    return data

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
    var scale_value: float = float(settings.get("scale", 0.26))
    model_scale = clampf(scale_value if is_finite(scale_value) else 0.26, 0.05, 8.0)
    hand_position = _read_vector(settings.get("hand_position"),
        Vector3(0.025, -0.015, 0.035)).clamp(-Vector3.ONE, Vector3.ONE)
    var hand_rot := _read_vector(settings.get("hand_rotation"), Vector3.ZERO)
    hand_angles = Vector3(deg_to_rad(hand_rot.x),
        deg_to_rad(hand_rot.y), deg_to_rad(hand_rot.z))

var report := AudioStreamPlayer.new()
var flash := OmniLight3D.new()

func _ready() -> void:
    name = "ForgePistol"
    eye = get_parent() as Camera3D
    if eye == null:
        push_error("FORGE_PISTOL_CAMERA_MISSING")
        return
    player = eye.get_parent() as CharacterBody3D
    var package := _read_game_model()
    var custom := _make_game_model(package)
    if custom != null:
        _read_profile(package["viewmodel"])
        _apply_gameplay(package["gameplay"])
        var weapon_class: String = str(package["gameplay"].get("class", package.get("weaponType", "")))
        cocking_clip = { "revolver": &"CockHammer", "pistol": &"RackSlide", "smg": &"RackBolt" }.get(weapon_class, &"")
        cocked = cocking_clip != &"CockHammer"
        print("FORGE_GAME_MODEL_READY: ", str(package.get("name", "")))
    else:
        _read_profile()
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
    weapon_hand = Node3D.new()
    weapon_hand.set_script(preload("res://weapon_hand_viewmodel.gd"))
    weapon_hand.name = "WeaponRightHand"
    weapon_hand.set("grip_local", Vector3.ZERO)
    weapon_hand.position = hand_position
    weapon_hand.rotation = hand_angles
    add_child(weapon_hand)
    flash.position = Vector3(0.0, 0.11, -0.51)
    if forward_marker != null:
        flash.position = visual_holder.to_local(forward_marker.global_position)
    flash.light_color = Color("#ffba75")
    flash.omni_range = 4.0
    flash.light_energy = 3.0
    flash.visible = false
    add_child(flash)
    report.stream = SHOT_STREAM
    report.bus = &"Effects"
    report.volume_db = -5.0
    report.max_polyphony = 3
    add_child(report)
    visible = false
    print("FORGE_PISTOL_READY: model=uploaded_glb capacity=7 one_click=true grip_marker=",
        grip_marker != null, " forward_marker=", forward_marker != null,
        " magazine_marker=", magazine_marker != null,
        " model_scale=", model_scale, " hand_visible=", weapon_hand != null)

func equip(value: bool) -> void:
    visible = value
    if not value:
        pending = false
        trigger_held = false
        reload_left = 0.0
        eject_at = 0.0
        if cocking_left > 0.0 or cocking_clip == &"CockHammer":
            cocked = false
        cocking_left = 0.0
        flash.visible = false
        last_action = "holstered"
        if model_animation != null:
            model_animation.stop()
            model_animation.clear_queue()
            model_animation.speed_scale = 1.0
            if model_animation.has_animation(&"RESET"):
                model_animation.play(&"RESET")
                model_animation.advance(0.0)

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

func _eject_revolver_cases() -> void:
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
        var drift := -eye.global_basis.x * randf_range(0.16, 0.34)
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
        duration += model_animation.get_animation(clip).length
    if duration <= 0.0:
        return
    model_animation.stop()
    model_animation.clear_queue()
    model_animation.speed_scale = duration / seconds
    model_animation.play(clips[0], 0.0)
    for index in range(1, clips.size()):
        model_animation.queue(clips[index])
    model_animation.advance(0.0)

func cock() -> void:
    if not visible or cocking_clip == &"" or cocked or rounds <= 0 \
            or reload_left > 0.0 or cooldown > 0.0 or cocking_left > 0.0:
        return
    trigger_held = false
    pending = false
    cocking_left = 0.35
    if model_animation != null and model_animation.has_animation(cocking_clip):
        cocking_left = maxf(0.05, model_animation.get_animation(cocking_clip).length)
        _play_model_clips([cocking_clip], cocking_left)

func request_shot() -> void:
    if not visible or rounds <= 0 or reload_left > 0.0 or cooldown > 0.0:
        return
    if not cocked:
        trigger_held = false
        return
    pending = true
    last_action = "fire"

func reload() -> void:
    if visible and rounds < capacity and reload_left <= 0.0 and cocking_left <= 0.0:
        pending = false
        trigger_held = false
        if cocking_clip != &"":
            cocked = false
        reload_left = reload_seconds
        if cocking_clip == &"CockHammer" and spent_cases > 0:
            eject_at = reload_seconds * (1.0 - 0.34 / 1.38)
        last_action = "reload"
        if model_animation != null:
            if model_animation.has_animation(&"ReloadMag"):
                _play_model_clips([&"ReloadMag"], reload_seconds)
            elif model_animation.has_animation(&"BreakOpen"):
                _play_model_clips([&"BreakOpen", &"InsertShells", &"CloseBarrel"], reload_seconds)
            elif model_animation.has_animation(&"LoadShells"):
                _play_model_clips([&"LoadShells"], reload_seconds)
            else:
                _play_model_clips([&"Reload"], reload_seconds)

func spread_angle() -> float:
    var speed := Vector2(player.velocity.x, player.velocity.z).length() if player != null else 0.0
    return deg_to_rad(0.40 + minf(speed * 0.34, 2.1) + bloom)

func _shot_direction() -> Vector3:
    var angle := randf() * TAU
    var radius := sqrt(randf()) * tan(spread_angle())
    return (eye.global_basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1)).normalized()

func _shoot() -> void:
    if rounds <= 0 or reload_left > 0.0 or not cocked:
        pending = false
        return
    pending = false
    rounds -= 1
    if cocking_clip == &"CockHammer":
        cocked = false
        trigger_held = false
        spent_cases += 1
    cooldown = shot_interval
    bloom = minf(2.6, bloom + 0.78)
    last_action = "fire"
    if model_animation != null and model_animation.has_animation(&"Fire"):
        _play_model_clips([&"Fire"], minf(shot_interval, model_animation.get_animation(&"Fire").length))
    report.volume_db = -10.0 if indoors else -5.0
    report.pitch_scale = randf_range(1.06, 1.14)
    match sound_profile:
        "heavy": report.pitch_scale *= 0.78
        "muted": report.volume_db -= 12.0
    if sound_profile != "silent":
        report.play()
    if player != null:
        if shot_noise > 0.0:
            player.call("emit_noise", shot_noise)
        player.call("kick_view", visual_recoil)
    var origin := eye.global_position
    var direction := _shot_direction()
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
            legacy.call("_surface_feedback", hit)

func _physics_process(delta: float) -> void:
    cooldown = maxf(0.0, cooldown - delta)
    bloom = move_toward(bloom, 0.0, delta * 2.2)
    if not visible:
        return
    if cocking_left > 0.0:
        cocking_left = maxf(0.0, cocking_left - delta)
        if cocking_left == 0.0:
            cocked = true
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if eject_at > 0.0 and reload_left <= eject_at:
            eject_at = 0.0
            _eject_revolver_cases()
        if reload_left == 0.0:
            rounds = capacity
    if automatic and trigger_held and player != null and player.get("controls_locked") != true \
            and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        request_shot()
    if pending:
        pending = false
        if player != null and player.get("controls_locked") != true and eye.current \
                and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _shoot()
    var kick_time := minf(shot_interval, 0.11 * sqrt(weapon_weight))
    var shot_age := shot_interval - cooldown
    var kick := maxf(0.0, 1.0 - shot_age / kick_time) * visual_recoil
    var reload_t := sin(PI * reload_left / reload_seconds)
    position = rest_pose + Vector3(0.0, -0.11 * reload_t, 0.045 * kick)
    rotation = rest_angles + Vector3(0.24 * kick, 0.0, -0.20 * reload_t)
    flash.visible = cooldown > 0.0 and shot_age < 0.05
