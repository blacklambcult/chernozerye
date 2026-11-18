extends CharacterBody3D

const SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP := 4.5
const MOUSE_SENS := 0.002

var camera: Camera3D
var status_label: Label
var last_event := "none"
var pressed := {"w": false, "a": false, "s": false, "d": false, "m": false}
var map_open := false
var controls_locked := false
# Optional period-appropriate adult character animation. Visual-only: no
# health, focus, combat or PTSD modifiers. Not a gameplay reward or treatment.
var _idle_smoke_timer := 0.0
var _idle_smoke_duration := 5.3
var _smoke_prop: Node3D
var _smoke_particles: CPUParticles3D
var _smoke_animation_count := 0

func set_controls_locked(value: bool) -> void:
    controls_locked = value
    pressed = {"w": false, "a": false, "s": false, "d": false, "m": false}
    if controls_locked:
        velocity.x = 0.0
        velocity.z = 0.0

func _ready() -> void:
    camera = Camera3D.new()
    camera.position.y = 1.55
    # A near plane of 0.05 made subpixel roof layers flicker in GL Compatibility.
    camera.near = 0.22
    camera.far = 2300.0
    camera.current = true
    add_child(camera)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.height = 1.8
    shape.radius = 0.46
    collision.position.y = 0.9
    collision.shape = shape
    floor_snap_length = 0.18
    safe_margin = 0.015
    add_child(collision)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var hud := CanvasLayer.new()
    hud.layer = 30
    add_child(hud)
    status_label = Label.new()
    status_label.position = Vector2(14, 48)
    status_label.add_theme_color_override("font_color", Color("#fcf1bb"))
    status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    status_label.add_theme_constant_override("shadow_offset_x", 1)
    status_label.add_theme_constant_override("shadow_offset_y", 1)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(status_label)
    status_label.visible = false
    _build_character_idle_prop()

func _build_character_idle_prop() -> void:
    _smoke_prop = Node3D.new()
    _smoke_prop.name = "AdultCharacterIdleProp"
    _smoke_prop.visible = false
    camera.add_child(_smoke_prop)
    var sleeve := MeshInstance3D.new()
    var sleeve_mesh := BoxMesh.new()
    sleeve_mesh.size = Vector3(0.085, 0.20, 0.13)
    sleeve.mesh = sleeve_mesh
    sleeve.position = Vector3(0.39, -0.68, -1.10)
    var cloth := StandardMaterial3D.new()
    cloth.albedo_color = Color("#3a3932")
    cloth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sleeve.material_override = cloth
    _smoke_prop.add_child(sleeve)
    var hand := MeshInstance3D.new()
    var glove_mesh := BoxMesh.new()
    glove_mesh.size = Vector3(0.10, 0.075, 0.085)
    hand.mesh = glove_mesh
    hand.position = Vector3(0.39, -0.54, -1.10)
    var glove_mat := StandardMaterial3D.new()
    glove_mat.albedo_color = Color("#5a5448")
    glove_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    hand.material_override = glove_mat
    _smoke_prop.add_child(hand)
    var cigarette := MeshInstance3D.new()
    cigarette.name = "PeriodCharacterProp"
    var stick := CylinderMesh.new()
    stick.top_radius = 0.007
    stick.bottom_radius = 0.007
    stick.height = 0.115
    cigarette.mesh = stick
    cigarette.position = Vector3(0.39, -0.445, -1.13)
    cigarette.rotation_degrees.z = -30.0
    var paper := StandardMaterial3D.new()
    paper.albedo_color = Color("#b8b2a5")
    paper.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    cigarette.material_override = paper
    _smoke_prop.add_child(cigarette)
    _smoke_particles = CPUParticles3D.new()
    _smoke_particles.name = "FaintCharacterSmoke"
    _smoke_particles.position = Vector3(0.37, -0.38, -1.14)
    _smoke_particles.amount = 4
    _smoke_particles.lifetime = 1.15
    _smoke_particles.randomness = 0.7
    _smoke_particles.direction = Vector3(0.15, 1.0, 0.12)
    _smoke_particles.spread = 23.0
    _smoke_particles.initial_velocity_min = 0.12
    _smoke_particles.initial_velocity_max = 0.27
    _smoke_particles.gravity = Vector3(0.0, 0.06, 0.0)
    _smoke_particles.emitting = false
    var smoke_quad := QuadMesh.new()
    smoke_quad.size = Vector2(0.038, 0.038)
    var smoke_mat := StandardMaterial3D.new()
    smoke_mat.albedo_color = Color(0.70, 0.72, 0.73, 0.12)
    smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    smoke_quad.material = smoke_mat
    _smoke_particles.mesh = smoke_quad
    _smoke_prop.add_child(_smoke_particles)


func _start_character_idle() -> void:
    if controls_locked or _idle_smoke_timer > 0.0 or _smoke_prop == null:
        return
    var story := get_parent().get_node_or_null("StoryPrologue")
    if story != null and bool(story.get("journal_open")):
        return
    var map := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
    if map != null and map.visible:
        return
    _idle_smoke_timer = _idle_smoke_duration
    _smoke_prop.visible = true
    _smoke_particles.emitting = true
    _smoke_animation_count += 1
    print("CHARACTER_IDLE_READY: cosmetic=true buffs=0 count=", _smoke_animation_count)


func _process(delta: float) -> void:
    if _idle_smoke_timer <= 0.0:
        return
    _idle_smoke_timer = maxf(0.0, _idle_smoke_timer - delta)
    if _smoke_prop != null:
        # Brief understated hand movement: no instructional lighting sequence.
        var elapsed := _idle_smoke_duration - _idle_smoke_timer
        _smoke_prop.position.y = 0.01 * sin(elapsed * 2.1)
        _smoke_prop.rotation.z = 0.03 * sin(elapsed * 1.4)
        if _idle_smoke_timer <= 0.0:
            _smoke_particles.emitting = false
            _smoke_prop.visible = false


func _matches(event: InputEventKey, latin: int, cyrillic: String) -> bool:
    return event.physical_keycode == latin or event.keycode == latin or (event.unicode != 0 and char(event.unicode).to_lower() == cyrillic)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # GUI buttons need the click; never capture mouse before their pressed event.
        if get_viewport().gui_get_hovered_control() is Button:
            return
        var map_overlay := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
        if map_overlay != null and map_overlay.visible:
            return # Let the on-map buttons receive clicks without capturing the pointer.
        last_event = "mouse click"
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENS)
        camera.rotate_x(-event.relative.y * MOUSE_SENS)
        camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
        last_event = "mouse movement"
    elif event is InputEventKey:
        var key := event as InputEventKey
        last_event = "keycode=%s physical=%s unicode=%s pressed=%s" % [key.keycode, key.physical_keycode, key.unicode, key.pressed]
        if _matches(key, KEY_W, "ц"): pressed["w"] = key.pressed
        if _matches(key, KEY_A, "ф"): pressed["a"] = key.pressed
        if _matches(key, KEY_S, "ы"): pressed["s"] = key.pressed
        if _matches(key, KEY_D, "в"): pressed["d"] = key.pressed
        if _matches(key, KEY_M, "ь"): pressed["m"] = key.pressed
        if key.pressed and not key.echo and (key.keycode == KEY_V or key.physical_keycode == KEY_V):
            _start_character_idle()
        if key.pressed and not key.echo and (key.keycode == KEY_F3 or key.physical_keycode == KEY_F3):
            status_label.visible = not status_label.visible
        if key.pressed and key.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 17.0 * delta
    if (Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP
    if controls_locked:
        velocity.x = 0.0
        velocity.z = 0.0
        move_and_slide()
        return
    var axis := Vector2.ZERO
    if pressed["w"] or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W): axis.y -= 1.0
    if pressed["s"] or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S): axis.y += 1.0
    if pressed["a"] or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A): axis.x -= 1.0
    if pressed["d"] or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D): axis.x += 1.0
    var direction := (transform.basis * Vector3(axis.x, 0.0, axis.y)).normalized()
    var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    move_and_slide()
    if is_instance_valid(status_label):
        status_label.text = "INPUT DIAGNOSTICS 0.6\nLast: %s\nAxis: %s | Pos: (%.1f, %.1f)\nMouse: %s\nClick on game, then press W / M" % [last_event, str(axis), position.x, position.z, str(Input.mouse_mode)]
