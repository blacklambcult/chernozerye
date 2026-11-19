extends Node3D
# Camera-attached shoulder, sleeves and hands. The lower-body GLB owns
# hips and legs. These camera-space arms persist even at maximum downlook.
# The art is unarmed and deliberately low-poly; it never affects collisions.

const COAT := Color("#676655")
const COAT_SHADOW := Color("#4d4e42")
const CUFF := Color("#44463c")
const THREAD := Color("#8b8170")
const SKIN := Color("#988579")
const SKIN_SHADOW := Color("#76665e")
const DOWNLOOK_BEGIN := 0.38
const DOWNLOOK_FULL := 1.25

var right_arm: Node3D
var left_arm: Node3D
var player: CharacterBody3D
var eye: Camera3D
var idle_clock := 0.0
var stride_phase := 0.0
var stride_weight := 0.0
var look_impulse := Vector2.ZERO
var is_gesture_hidden := false
var downlook_weight := 0.0


func _mat(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.98
    mat.metallic = 0.0
    # These camera-space hands must not disappear behind a nearby wall or
    # the protagonist's own coat; no physics/depth is changed in the world.
    mat.no_depth_test = true
    mat.render_priority = 1
    return mat


func _block(parent: Node3D, label: String, size: Vector3,
        origin: Vector3, tint: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = origin
    part.material_override = _mat(tint)
    parent.add_child(part)
    return part


func _limb(parent: Node3D, label: String, from: Vector3, to: Vector3,
        near_radius: float, far_radius: float, tint: Color) -> MeshInstance3D:
    var direction := to - from
    var mesh := CylinderMesh.new()
    mesh.bottom_radius = near_radius
    mesh.top_radius = far_radius
    mesh.height = direction.length()
    mesh.radial_segments = 6
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.material_override = _mat(tint)
    part.position = (from + to) * 0.5
    part.quaternion = Quaternion(Vector3.UP, direction.normalized())
    parent.add_child(part)
    return part


func _build_arm(side: float, label: String) -> Node3D:
    var root := Node3D.new()
    root.name = label
    add_child(root)
    # Relaxed unarmed stance. Sleeves originate below/behind the near plane
    # and follow a bent elbow towards the lower corners, not straight ahead
    # as if the player were permanently aiming invisible pistols.
    var lift := 0.030 if side > 0.0 else -0.080
    var shoulder := Vector3(side * 0.470, -0.820 + lift, -0.120)
    var elbow := Vector3(side * 0.365, -0.640 + lift, -0.425)
    var wrist := Vector3(side * 0.280, -0.535 + lift, -0.720)
    _limb(root, "ShoulderYoke",
        Vector3(side * 0.520, -0.555 + lift, -0.395),
        Vector3(side * 0.395, -0.565 + lift, -0.505),
        0.123, 0.108, COAT)
    # Angled coat sleeve between shoulder and elbow.
    _limb(root, "UpperCoatSleeve", shoulder, elbow,
        0.105, 0.093, COAT)
    _limb(root, "ForearmSleeve", elbow, wrist,
        0.097, 0.074, COAT_SHADOW)
    _limb(root, "WristCuff",
        wrist + Vector3(0.0, -0.005, 0.042),
        wrist + Vector3(0.0, 0.003, -0.028),
        0.081, 0.072, CUFF)

    # Palm is a narrow tapered silhouette. Individual fingers angle downward
    # instead of forming the hard rectangular fist seen in 0.5.8.
    var palm_start := wrist + Vector3(0.0, 0.006, -0.015)
    var palm_end := wrist + Vector3(-side * 0.004, -0.014, -0.145)
    _limb(root, "Palm", palm_start, palm_end,
        0.057, 0.049, SKIN)
    _limb(root, "Knuckles",
        palm_end + Vector3(0.0, 0.005, 0.018),
        palm_end + Vector3(0.0, -0.005, -0.032),
        0.050, 0.043, SKIN_SHADOW)
    _limb(root, "Thumb",
        wrist + Vector3(-side * 0.052, -0.004, -0.064),
        wrist + Vector3(-side * 0.073, -0.032, -0.148),
        0.024, 0.017, SKIN)
    for finger in range(4):
        var finger_x := (float(finger) - 1.5) * 0.026
        var knuckle := palm_end + Vector3(finger_x, -0.006, -0.025)
        var finger_length := 0.055 if finger == 0 or finger == 3 else 0.069
        _limb(root, "Finger%d" % finger, knuckle,
            knuckle + Vector3(0.0, -0.038, -finger_length),
            0.014, 0.010, SKIN)
    # Restrained low-poly coat detailing, readable in the night palette.
    _block(root, "CoatPatch", Vector3(0.048, 0.012, 0.072),
        elbow + Vector3(0.0, 0.075, 0.015), COAT)
    _block(root, "CuffStitch", Vector3(0.035, 0.009, 0.012),
        wrist + Vector3(0, 0.075, 0.005), THREAD)
    return root


func _ready() -> void:
    name = "FPSViewmodel"
    eye = get_parent() as Camera3D
    if eye == null:
        push_error("FPS_VIEWMODEL_FAILED: must be attached to Camera3D")
        return
    player = eye.get_parent() as CharacterBody3D
    left_arm = _build_arm(-1.0, "LeftArm")
    right_arm = _build_arm(1.0, "RightArm")
    print("FPS_VIEWMODEL_READY: camera_local=true arms=2 unarmed=true lowpoly=true persistent_downlook=true shoulders=true")


func push_look_motion(relative_pixels: Vector2) -> void:
    # Momentum only, not an additional camera rotation.
    look_impulse += Vector2(
        clampf(relative_pixels.x * 0.00025, -0.028, 0.028),
        clampf(relative_pixels.y * 0.00019, -0.022, 0.022))
    look_impulse.x = clampf(look_impulse.x, -0.045, 0.045)
    look_impulse.y = clampf(look_impulse.y, -0.035, 0.035)


func _process(delta: float) -> void:
    if player == null or eye == null:
        return
    idle_clock += delta
    var sequence := eye.get_node_or_null("CharacterSmoking")
    var phase := int(sequence.get("phase")) if sequence != null else 0
    # The cinematic has its own hands during short gestures; avoid overlap.
    # The long ambient phase (5) leaves the regular idle arms visible.
    is_gesture_hidden = phase in [1, 2, 3, 4, 6, 7]
    visible = not is_gesture_hidden
    downlook_weight = smoothstep(DOWNLOOK_BEGIN, DOWNLOOK_FULL, -eye.rotation.x)

    var grounded := player.is_on_floor()
    var speed := Vector2(player.velocity.x, player.velocity.z).length()
    var target := clampf(speed / 3.35, 0.0, 1.0) if grounded else 0.0
    stride_weight = move_toward(stride_weight, target, 3.5 * delta)
    if target > 0.04:
        stride_phase = fposmod(stride_phase + delta * (5.0 + target * 2.5), TAU)
    var step := sin(stride_phase)
    var breathing := sin(idle_clock * 1.15)
    look_impulse = look_impulse.lerp(Vector2.ZERO, clampf(delta * 8.0, 0, 1))
    # Subtle breathing and reciprocal walking swing preserve readability.
    position = Vector3(-look_impulse.x * 0.65,
        0.006 * breathing + absf(step) * 0.012 * stride_weight
        + look_impulse.y * 0.5, 0.0)
    rotation = Vector3(-look_impulse.y * 0.22, -look_impulse.x * 0.28,
        step * 0.009 * stride_weight)
    right_arm.position = Vector3(
        step * 0.012 * stride_weight,
        -step * 0.013 * stride_weight,
        0.010 * cos(stride_phase) * stride_weight)
    left_arm.position = Vector3(
        -step * 0.011 * stride_weight,
        step * 0.012 * stride_weight,
        -0.010 * cos(stride_phase) * stride_weight)
    # Reveal a shoulder at each screen edge when looking at the feet.
    right_arm.position += Vector3(0.090, 0.235, -0.105) * downlook_weight
    left_arm.position += Vector3(-0.090, 0.235, -0.105) * downlook_weight
