extends Node3D
# HELLISH FORGE — imported user-authored low-poly model, arcade-only gameplay.
# This module keeps the old six-round two-click revolver untouched.
const CAPACITY := 7
const RELOAD_SECONDS := 1.20
const REST := Vector3(0.245, -0.245, -0.58)
const ASSET_SCENE: PackedScene = preload("res://assets/forge_pistol.glb")
const SHOT_STREAM: AudioStream = preload("res://revolver_report.wav")
var indoors := false
var rounds := CAPACITY
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
var report := AudioStreamPlayer.new()
var flash := OmniLight3D.new()

func _ready() -> void:
    name = "ForgePistol"
    eye = get_parent() as Camera3D
    if eye == null:
        push_error("FORGE_PISTOL_CAMERA_MISSING")
        return
    player = eye.get_parent() as CharacterBody3D
    position = REST
    visual_holder = Node3D.new()
    visual_holder.name = "ForgePistolVisual"
    # Forge exports a metric scene. This is a viewmodel-only scale adjustment,
    # leaving the uploaded GLB's mesh and marker coordinates untouched.
    visual_holder.scale = Vector3.ONE * 0.165
    add_child(visual_holder)
    imported_model = ASSET_SCENE.instantiate() as Node3D
    visual_holder.add_child(imported_model)
    grip_marker = imported_model.find_child("HF_GRIP_PRIMARY", true, false) as Node3D
    forward_marker = imported_model.find_child("HF_FORWARD", true, false) as Node3D
    magazine_marker = imported_model.find_child("HF_MAGAZINE", true, false) as Node3D
    # Position the actual author-supplied hand marker over the camera hand.
    var grip := Vector3(0.0, 0.634, 0.3523)
    if grip_marker != null:
        grip = imported_model.to_local(grip_marker.global_position)
    imported_model.position = -grip
    flash.position = Vector3(0.0, 0.11, -0.51)
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
        " magazine_marker=", magazine_marker != null)

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
    if visible and rounds < CAPACITY and reload_left <= 0.0:
        pending = false
        reload_left = RELOAD_SECONDS
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
    report.play()
    if player != null:
        player.call("emit_noise", 1.0)
        player.call("kick_view")
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
            rounds = CAPACITY
    if pending:
        pending = false
        if player != null and player.get("controls_locked") != true and eye.current \
                and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _shoot()
    var kick := maxf(0.0, cooldown - 0.12) / 0.11
    var reload_t := sin(PI * reload_left / RELOAD_SECONDS)
    position = REST + Vector3(0.0, -0.11 * reload_t, 0.045 * kick)
    rotation = Vector3(0.24 * kick, 0.12, -0.20 * reload_t)
    flash.visible = cooldown > 0.18
