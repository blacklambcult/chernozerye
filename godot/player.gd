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
# Optional period-appropriate adult character animation. Visual-only: no
# health, focus, combat or PTSD modifiers. Not a gameplay reward or treatment.
var _idle_smoke_timer := 0.0
var _idle_smoke_duration := 5.3
var _smoke_prop: Node3D
var _smoke_particles: CPUParticles3D
var _smoke_animation_count := 0
var _avatar: Node3D
var _gesture_upper: MeshInstance3D
var _gesture_lower: MeshInstance3D
var _gesture_elbow: MeshInstance3D
var _gesture_hand: Node3D

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
    _build_character_idle_prop()

func _appearance_material(color: Color, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.6
    return mat

func _view_segment(parent: Node3D, title: String, a: Vector3, b: Vector3,
        r0: float, r1: float, tint: Color) -> MeshInstance3D:
    var vector := b - a
    var tube := CylinderMesh.new()
    tube.height = vector.length()
    tube.bottom_radius = r0
    tube.top_radius = r1
    tube.radial_segments = 9
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = tube
    node.material_override = _appearance_material(tint)
    node.position = (a + b) * 0.5
    node.quaternion = Quaternion(Vector3.UP, vector.normalized())
    parent.add_child(node)
    return node

func _view_round(parent: Node3D, title: String,
        at: Vector3, radius: float, color: Color,
        proportions: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 9
    shape.rings = 5
    var mesh_node := MeshInstance3D.new()
    mesh_node.name = title
    mesh_node.mesh = shape
    mesh_node.material_override = _appearance_material(color)
    mesh_node.position = at
    mesh_node.scale = proportions
    parent.add_child(mesh_node)
    return mesh_node

func _build_character_idle_prop() -> void:
    # Separate articulated arm viewmodel with independent shoulder, elbow and
    # wrist locations; avoids sliding the whole straight limb across the frame.
    _smoke_prop = Node3D.new()
    _smoke_prop.name = "AdultCharacterIdleProp"
    _smoke_prop.visible = false
    camera.add_child(_smoke_prop)
    _gesture_upper = _view_segment(_smoke_prop, "UpperArmSleeve",
        Vector3(0.46, -0.72, 0.12), Vector3(0.54, -0.69, -0.31),
        0.088, 0.076, Color("#48443f"))
    _gesture_lower = _view_segment(_smoke_prop, "BentForearmSleeve",
        Vector3(0.54, -0.69, -0.31), Vector3(0.40, -0.66, -0.65),
        0.077, 0.058, Color("#48443f"))
    _gesture_elbow = _view_round(_smoke_prop, "ElbowJoint",
        Vector3(0.54, -0.69, -0.31), 0.075, Color("#353330"))
    _gesture_hand = Node3D.new()
    _gesture_hand.name = "AnimatedHand"
    _gesture_hand.position = Vector3(0.40, -0.66, -0.65)
    _smoke_prop.add_child(_gesture_hand)
    # The palm faces inward toward the character while the two raised fingers
    # are separated around the decorative prop. This is only an animation.
    var palm := MeshInstance3D.new()
    palm.name = "Palm"
    var palm_mesh := BoxMesh.new()
    palm_mesh.size = Vector3(0.085, 0.092, 0.047)
    palm.mesh = palm_mesh
    palm.material_override = _appearance_material(Color("#756a5c"))
    _gesture_hand.add_child(palm)
    _view_round(_gesture_hand, "Thumb",
        Vector3(0.053, 0.0, -0.004), 0.022,
        Color("#756a5c"), Vector3(0.8, 1.12, 0.75))
    # Named fingers for the animation rig and automated pose checks.
    _view_segment(_gesture_hand, "IndexFinger",
        Vector3(0.022, 0.035, -0.012),
        Vector3(0.022, 0.099, -0.045),
        0.011, 0.009, Color("#756a5c"))
    _view_segment(_gesture_hand, "MiddleFinger",
        Vector3(-0.022, 0.035, -0.012),
        Vector3(-0.022, 0.098, -0.045),
        0.011, 0.009, Color("#756a5c"))
    _view_segment(_gesture_hand, "RingFinger",
        Vector3(-0.052, 0.032, -0.012),
        Vector3(-0.055, 0.071, 0.002),
        0.010, 0.008, Color("#756a5c"))
    _view_segment(_gesture_hand, "LittleFinger",
        Vector3(-0.069, 0.015, 0.006),
        Vector3(-0.065, 0.050, 0.018),
        0.008, 0.007, Color("#756a5c"))

    var cigarette := Node3D.new()
    cigarette.name = "PeriodCharacterProp"
    # Centered between the index and middle fingers. Its visible tip points
    # outwards, away from the camera/face when the arm is raised.
    cigarette.position = Vector3(0.0, 0.086, -0.050)
    _gesture_hand.add_child(cigarette)
    var pointing_out := Vector3(0.43, 0.24, -0.87).normalized()
    _view_segment(cigarette, "BrownFilter",
        pointing_out * -0.018, pointing_out * 0.027,
        0.0085, 0.0085, Color("#916b4d"))
    _view_segment(cigarette, "WhitePaper",
        pointing_out * 0.027, pointing_out * 0.145,
        0.008, 0.008, Color("#eee8dc"))
    var ember := _view_round(cigarette, "RedEmber",
        pointing_out * 0.155, 0.011, Color("#b95231"),
        Vector3(1.0, 0.62, 1.0))
    ember.material_override = _appearance_material(Color("#b95231"), true)
    _smoke_particles = CPUParticles3D.new()
    _smoke_particles.name = "FaintCharacterSmoke"
    _smoke_particles.position = pointing_out * 0.168
    _smoke_particles.amount = 4
    _smoke_particles.lifetime = 1.15
    _smoke_particles.randomness = 0.65
    _smoke_particles.local_coords = true
    _smoke_particles.direction = Vector3(0, 1.0, 0)
    _smoke_particles.spread = 24.0
    _smoke_particles.initial_velocity_min = 0.10
    _smoke_particles.initial_velocity_max = 0.22
    _smoke_particles.gravity = Vector3(0.0, 0.02, 0.0)
    _smoke_particles.emitting = false
    var smoke_quad := QuadMesh.new()
    smoke_quad.size = Vector2(0.028, 0.028)
    var smoke_mat := _appearance_material(Color(0.75, 0.77, 0.77, 0.13))
    smoke_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    smoke_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    smoke_quad.material = smoke_mat
    _smoke_particles.mesh = smoke_quad
    cigarette.add_child(_smoke_particles)
    _apply_idle_pose(0.0)


func _orient_arm_segment(limb: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    var axis := b - a
    if axis.length_squared() < 0.0001:
        return
    limb.position = (a + b) * 0.5
    limb.quaternion = Quaternion(Vector3.UP, axis.normalized())
    var geo := limb.mesh as CylinderMesh
    limb.scale.y = axis.length() / maxf(geo.height, 0.01)


func _apply_idle_pose(weight: float) -> void:
    # Shoulder is fixed near the character. Elbow stays bent while the hand
    # follows an arc to the lower center of the view (face height), not forward
    # in a straight line. All numbers are viewmodel-relative, not mechanics.
    if _gesture_upper == null or _gesture_lower == null or _gesture_hand == null:
        return
    var t := clampf(weight, 0.0, 1.0)
    # A fixed shoulder; elbow remains at the player's right side while the
    # hand travels up toward face height. Both segments bend independently.
    var shoulder := Vector3(0.46, -0.70, 0.16)
    var elbow := Vector3(0.54, -0.70, -0.30).lerp(
        Vector3(0.48, -0.48, -0.32), t)
    var wrist := Vector3(0.40, -0.66, -0.65).lerp(
        Vector3(0.115, -0.135, -0.285), t)
    _orient_arm_segment(_gesture_upper, shoulder, elbow)
    _orient_arm_segment(_gesture_lower, elbow, wrist)
    _gesture_elbow.position = elbow
    _gesture_hand.position = wrist
    # Local palm normal +Z turns toward the viewer's face at full extension;
    # the free end of the decorative prop stays oriented out and to the right.
    _gesture_hand.rotation.y = -0.40 * t
    _gesture_hand.rotation.z = -0.20 * t
    _gesture_hand.rotation.x = -0.10 * t

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
    _apply_idle_pose(0.0)
    _smoke_prop.visible = true
    _smoke_particles.emitting = false
    if _avatar != null:
        _avatar.call("set_right_hand_occupied", true)
    _smoke_animation_count += 1
    print("CHARACTER_IDLE_READY: cosmetic=true buffs=0 count=", _smoke_animation_count)

func _process(delta: float) -> void:
    if _idle_smoke_timer <= 0.0:
        return
    _idle_smoke_timer = maxf(0.0, _idle_smoke_timer - delta)
    if _smoke_prop == null:
        return
    var elapsed := _idle_smoke_duration - _idle_smoke_timer
    var t := clampf(elapsed / _idle_smoke_duration, 0.0, 1.0)
    var pose := 1.0
    if t < 0.34:
        pose = smoothstep(0.0, 0.34, t)
    elif t > 0.69:
        pose = 1.0 - smoothstep(0.69, 1.0, t)
    # Jointed IK-like visual pose with a fixed shoulder and bending elbow.
    _apply_idle_pose(pose)
    _smoke_particles.emitting = t > 0.35 and t < 0.80
    if _idle_smoke_timer <= 0.0:
        _smoke_particles.emitting = false
        _smoke_prop.visible = false
        if _avatar != null:
            _avatar.call("set_right_hand_occupied", false)

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
        if key.pressed and not key.echo and key.physical_keycode in [KEY_1, KEY_2, KEY_3, KEY_4]:
            var survival_hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
            if survival_hud != null:
                survival_hud.call("choose_slot", int(key.physical_keycode) - KEY_1)
        if key.pressed and not key.echo and (key.keycode == KEY_V or key.physical_keycode == KEY_V):
            _start_character_idle()
        if key.pressed and not key.echo and (key.keycode == KEY_F3 or key.physical_keycode == KEY_F3):
            status_label.visible = not status_label.visible
        if key.pressed and key.keycode == KEY_ESCAPE:
            Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
