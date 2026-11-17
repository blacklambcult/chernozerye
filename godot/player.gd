extends CharacterBody3D

const SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP := 4.5
const MOUSE_SENS := 0.002
var camera: Camera3D

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
    # Browser pointer lock requires a user gesture. Click the game to capture the mouse.
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
            get_viewport().set_input_as_handled()
            return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * MOUSE_SENS)
        camera.rotate_x(-event.relative.y * MOUSE_SENS)
        camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
    if not is_on_floor(): velocity.y -= 17.0 * delta
    if Input.is_key_pressed(KEY_SPACE) and is_on_floor(): velocity.y = JUMP
    var axis := Vector2.ZERO
    if Input.is_physical_key_pressed(KEY_W): axis.y -= 1.0
    if Input.is_physical_key_pressed(KEY_S): axis.y += 1.0
    if Input.is_physical_key_pressed(KEY_A): axis.x -= 1.0
    if Input.is_physical_key_pressed(KEY_D): axis.x += 1.0
    var direction := (transform.basis * Vector3(axis.x, 0, axis.y)).normalized()
    var speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    move_and_slide()
