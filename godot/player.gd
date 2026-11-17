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

func _ready() -> void:
    camera = Camera3D.new()
    camera.position.y = 1.55
    camera.current = true
    add_child(camera)
    var collision := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.height = 1.8
    shape.radius = 0.35
    collision.position.y = 0.9
    collision.shape = shape
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
        if key.pressed and not key.echo and (key.keycode == KEY_F3 or key.physical_keycode == KEY_F3):
            status_label.visible = not status_label.visible
        if key.pressed and key.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= 17.0 * delta
    if (Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP
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
