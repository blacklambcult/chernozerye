extends CharacterBody3D

const SPEED := 3.35
const SPRINT_SPEED := 5.15
const WALK_ACCELERATION := 9.0
const WALK_FRICTION := 12.0
const JUMP := 4.5
const MOUSE_SENS := 0.002

var camera: Camera3D
var status_label: Label
var last_event := "none"
var pressed := {"w": false, "a": false, "s": false, "d": false, "m": false}
var map_open := false
var controls_locked := false
var mouse_sensitivity := MOUSE_SENS
# Narrative character animation is isolated from player movement and stats.
var _avatar: Node3D
var _modeled_character: Node3D
var _viewmodel: Node3D
var _inspection_camera: Camera3D
var _inspection_hint: Label
var _inspection_light: SpotLight3D
var _inspect_enabled := false
var _character_sequence: Node3D

func set_controls_locked(value: bool) -> void:
    controls_locked = value
    pressed = {"w": false, "a": false, "s": false, "d": false, "m": false}
    if controls_locked:
        velocity.x = 0.0
        velocity.z = 0.0

func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.position.y = 1.55
    # A near plane of 0.05 made subpixel roof layers flicker in GL Compatibility.
    camera.near = 0.22
    camera.far = 2300.0
    camera.current = true
    add_child(camera)
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
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
    _avatar = Node3D.new()
    _avatar.name = "FirstPersonFullBody"
    _avatar.set_script(preload("res://first_person_body.gd"))
    add_child(_avatar)
    # No first-person body rendering. Keep this hidden compatibility node
    # for scripted cinematics only, never as a fallback for the model.
    _avatar.visible = false
    _avatar.set_process(false)
    _modeled_character = Node3D.new()
    _modeled_character.name = "ModeledCharacter"
    _modeled_character.set_script(preload("res://modeled_character.gd"))
    add_child(_modeled_character)
    _viewmodel = Node3D.new()
    _viewmodel.name = "FPSViewmodel"
    _viewmodel.set_script(preload("res://fps_viewmodel.gd"))
    camera.add_child(_viewmodel)
    _character_sequence = Node3D.new()
    _character_sequence.name = "CharacterSmoking"
    _character_sequence.set_script(preload("res://character_smoking.gd"))
    camera.add_child(_character_sequence)
    # F4 inspection: camera faces the actual complete imported GLB from
    # three metres away. It is never used for first-person gameplay.
    _inspection_camera = Camera3D.new()
    _inspection_camera.name = "CharacterInspectionCamera"
    _inspection_camera.position = Vector3(0.0, 1.62, -3.20)
    _inspection_camera.near = 0.12
    _inspection_camera.far = 2300.0
    _inspection_camera.fov = 55.0
    add_child(_inspection_camera)
    _inspection_camera.look_at(global_position + Vector3(0, 1.04, 0), Vector3.UP)
    _inspection_camera.current = false
    _inspection_light = SpotLight3D.new()
    _inspection_light.name = "InspectionLight"
    _inspection_light.light_energy = 3.2
    _inspection_light.spot_range = 6.0
    _inspection_light.spot_angle = 50.0
    _inspection_camera.add_child(_inspection_light)
    _inspection_light.visible = false
    _inspection_hint = Label.new()
    _inspection_hint.name = "InspectionHint"
    _inspection_hint.text = "F4 — ВЕРНУТЬСЯ В ИГРУ    /    ДЕМБЕЛЬ, 2005"
    _inspection_hint.position = Vector2(24, 94)
    _inspection_hint.add_theme_color_override("font_color", Color("#e7dfce"))
    _inspection_hint.visible = false
    hud.add_child(_inspection_hint)
    var pause_overlay := CanvasLayer.new()
    pause_overlay.name = "PauseOverlay"
    pause_overlay.set_script(preload("res://pause_overlay.gd"))
    add_child(pause_overlay)

func _toggle_model_inspection() -> void:
    if _modeled_character == null or not bool(_modeled_character.get("model_loaded")):
        return
    if not _inspect_enabled and controls_locked:
        return
    _inspect_enabled = not _inspect_enabled
    _modeled_character.call("set_inspection_mode", _inspect_enabled)
    _inspection_camera.current = _inspect_enabled
    camera.current = not _inspect_enabled
    _inspection_light.visible = _inspect_enabled
    _inspection_hint.visible = _inspect_enabled
    _viewmodel.visible = not _inspect_enabled
    _viewmodel.set_process(not _inspect_enabled)
    _character_sequence.visible = not _inspect_enabled
    set_controls_locked(_inspect_enabled)
    if _inspect_enabled:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    print("CHARACTER_INSPECTION_MODE:", _inspect_enabled)


func _start_character_sequence() -> bool:
    if _character_sequence == null:
        return false
    var hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
    var slot := -1
    if hud != null:
        slot = int(hud.get("selected_slot"))
    return bool(_character_sequence.call("start_if_selected",slot,controls_locked))


func _matches(event: InputEventKey, latin: int, cyrillic: String) -> bool:
    return event.physical_keycode == latin or event.keycode == latin or (event.unicode != 0 and char(event.unicode).to_lower() == cyrillic)

func _input(event: InputEvent) -> void:
    if event is InputEventKey:
        var inspect_key := event as InputEventKey
        if inspect_key.pressed and not inspect_key.echo and (inspect_key.keycode == KEY_F4 or inspect_key.physical_keycode == KEY_F4):
            _toggle_model_inspection()
            return
    if _inspect_enabled:
        return
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
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
        if _viewmodel != null:
            _viewmodel.call("push_look_motion", event.relative)
        last_event = "mouse movement"
    elif event is InputEventKey:
        var key := event as InputEventKey
        last_event = "keycode=%s physical=%s unicode=%s pressed=%s" % [key.keycode, key.physical_keycode, key.unicode, key.pressed]
        if _matches(key, KEY_W, "ц"): pressed["w"] = key.pressed
        if _matches(key, KEY_A, "ф"): pressed["a"] = key.pressed
        if _matches(key, KEY_S, "ы"): pressed["s"] = key.pressed
        if _matches(key, KEY_D, "в"): pressed["d"] = key.pressed
        if _matches(key, KEY_M, "ь"): pressed["m"] = key.pressed
        if key.pressed and not key.echo and key.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
            var survival_hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
            if survival_hud != null:
                survival_hud.call("choose_slot", int(key.physical_keycode) - KEY_1)
        if key.pressed and not key.echo and (key.keycode == KEY_V or key.physical_keycode == KEY_V):
            _start_character_sequence()
        if key.pressed and not key.echo and (key.keycode == KEY_F3 or key.physical_keycode == KEY_F3):
            status_label.visible = not status_label.visible

func _movement_speed(sprinting: bool) -> float:
    return SPRINT_SPEED if sprinting else SPEED


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
    var speed := _movement_speed(Input.is_key_pressed(KEY_SHIFT))
    var desired := direction * speed
    var acceleration := WALK_FRICTION if direction.length_squared() < 0.01 else WALK_ACCELERATION
    velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
    move_and_slide()
    if is_instance_valid(status_label):
        status_label.text = "INPUT DIAGNOSTICS 0.6\nLast: %s\nAxis: %s | Pos: (%.1f, %.1f)\nMouse: %s\nClick on game, then press W / M" % [last_event, str(axis), position.x, position.z, str(Input.mouse_mode)]
