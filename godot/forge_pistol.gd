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
    model_scale = clampf(scale_value if is_finite(scale_value) else 0.26, 0.05, 3.0)
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
    grip_marker = imported_model.find_child("HF_GRIP_PRIMARY", true, false) as Node3D
    forward_marker = imported_model.find_child("HF_FORWARD", true, false) as Node3D
    magazine_marker = imported_model.find_child("HF_MAGAZINE", true, false) as Node3D
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
        reload_left = 0.0
        flash.visible = false
        last_action = "holstered"

func request_shot() -> void:
    # No separate cocking phase; each valid click queues exactly one game shot.
    if not visible or rounds <= 0 or reload_left > 0.0 or cooldown > 0.0:
        return
    pending = true
    last_action = "fire"

func reload() -> void:
    if visible and rounds < capacity and reload_left <= 0.0:
        pending = false
        reload_left = reload_seconds
        last_action = "reload"

func spread_angle() -> float:
    var speed := Vector2(player.velocity.x, player.velocity.z).length() if player != null else 0.0
    return deg_to_rad(0.40 + minf(speed * 0.34, 2.1) + bloom)

func _shot_direction() -> Vector3:
    var angle := randf() * TAU
    var radius := sqrt(randf()) * tan(spread_angle())
    return (eye.global_basis * Vector3(cos(angle) * radius, sin(angle) * radius, -1)).normalized()

func _shoot() -> void:
    if rounds <= 0 or reload_left > 0.0:
        pending = false
        return
    pending = false
    rounds -= 1
    cooldown = 0.23
    bloom = minf(2.6, bloom + 0.78)
    last_action = "fire"
    report.volume_db = -10.0 if indoors else -5.0
    report.pitch_scale = randf_range(1.06, 1.14)
    match sound_profile:
        "heavy": report.pitch_scale *= 0.78
        "muted": report.volume_db -= 12.0
    report.play()
    if player != null:
        player.call("emit_noise", 1.0)
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
    if reload_left > 0.0:
        reload_left = maxf(0.0, reload_left - delta)
        if reload_left == 0.0:
            rounds = capacity
    if pending:
        pending = false
        if player != null and player.get("controls_locked") != true and eye.current \
                and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _shoot()
    var kick := maxf(0.0, cooldown - 0.12) / 0.11 * visual_recoil
    var reload_t := sin(PI * reload_left / reload_seconds)
    position = rest_pose + Vector3(0.0, -0.11 * reload_t, 0.045 * kick)
    rotation = rest_angles + Vector3(0.24 * kick, 0.0, -0.20 * reload_t)
    flash.visible = cooldown > 0.18
