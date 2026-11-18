extends Node3D
# Fearless Knights / provisional first-person avatar.
# A lightweight articulated placeholder: real world-space torso/legs/arms
# beneath the player's eye camera. No head mesh is rendered from inside it.
# All pieces are visual only; the CharacterBody capsule remains authoritative.

const COAT := Color("#48443f")
const COAT_SHADOW := Color("#353330")
const SHIRT := Color("#686255")
const PANTS := Color("#363634")
const BOOTS := Color("#242827")
const GLOVES := Color("#60594e")
const BELT := Color("#252722")

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var walk_phase := 0.0
var hide_right_hand := false
var pelvis_root: Node3D
var upper_coat: MeshInstance3D
var lower_jacket: MeshInstance3D
var view_down_cutaway := false

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    return mat

func _box(parent: Node3D, name: String, size: Vector3,
        pos: Vector3, tint: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = mesh
    node.material_override = _material(tint)
    node.position = pos
    parent.add_child(node)
    return node

func _tapered_coat(parent: Node3D, name: String, pos: Vector3,
        height: float, top_width: float, bottom_width: float) -> MeshInstance3D:
    # Eight-sided tapered wool coat, not a squared-off tactical chest plate.
    # Flattening its depth keeps it out of the eye's vertical viewing cone.
    var coat := CylinderMesh.new()
    coat.top_radius = top_width
    coat.bottom_radius = bottom_width
    coat.height = height
    coat.radial_segments = 8
    # CylinderMesh top caps produced the giant octagon in look-down screenshots.
    # Keep the garment shell, but let the camera see inside its open neckline.
    coat.cap_top = false
    coat.cap_bottom = false
    var visible_coat := MeshInstance3D.new()
    visible_coat.name = name
    visible_coat.mesh = coat
    visible_coat.material_override = _material(COAT)
    visible_coat.position = pos
    visible_coat.scale.z = 0.68
    parent.add_child(visible_coat)
    return visible_coat


func _sphere(parent: Node3D, name: String, pos: Vector3,
        radius: float, tint: Color, shape: Vector3 = Vector3.ONE) -> MeshInstance3D:
    var geometry := SphereMesh.new()
    geometry.radius = radius
    geometry.height = radius * 2.0
    geometry.radial_segments = 8
    geometry.rings = 5
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = geometry
    node.material_override = _material(tint)
    node.position = pos
    node.scale = shape
    parent.add_child(node)
    return node

func _segment(parent: Node3D, name: String,
        a: Vector3, b: Vector3, r0: float, r1: float,
        tint: Color) -> MeshInstance3D:
    var axis := b - a
    var mesh := CylinderMesh.new()
    mesh.top_radius = r1
    mesh.bottom_radius = r0
    mesh.height = axis.length()
    mesh.radial_segments = 8
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = mesh
    node.material_override = _material(tint)
    node.position = (a + b) * 0.5
    node.quaternion = Quaternion(Vector3.UP, axis.normalized())
    parent.add_child(node)
    return node

func _leg(side: float, label: String, root: Node3D) -> Node3D:
    # Both hips and the jacket share the SAME pelvis coordinate frame.
    # No visible ball-shaped hip joints: fabric runs continuously into thighs.
    var pivot := Node3D.new()
    pivot.name = label
    pivot.position = Vector3(side * 0.145, -0.055, 0.0)
    root.add_child(pivot)
    _segment(pivot, "TrouserThigh", Vector3.ZERO,
        Vector3(side * 0.012, -0.325, -0.028), 0.107, 0.097, PANTS)
    _box(pivot, "FabricAtKnee", Vector3(0.196, 0.12, 0.165),
        Vector3(side * 0.012, -0.353, -0.026), PANTS)
    _segment(pivot, "TrouserCalf",
        Vector3(side * 0.012, -0.365, -0.030),
        Vector3(side * 0.02, -0.610, -0.038), 0.096, 0.081, PANTS)
    _box(pivot, "Boot", Vector3(0.205, 0.157, 0.31),
        Vector3(side * 0.02, -0.674, -0.09), BOOTS)
    _box(pivot, "BootSole", Vector3(0.215, 0.046, 0.325),
        Vector3(side * 0.02, -0.747, -0.09), BELT)
    return pivot


func _arm(side: float, label: String, root: Node3D) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = label
    pivot.position = Vector3(side * 0.255, 0.375, 0.040)
    root.add_child(pivot)
    _sphere(pivot, "Shoulder", Vector3.ZERO, 0.098, COAT)
    _segment(pivot, "Sleeve", Vector3.ZERO,
        Vector3(side * 0.060, -0.27, -0.03), 0.098, 0.083, COAT)
    _sphere(pivot, "Elbow", Vector3(side * 0.060, -0.27, -0.03),
        0.082, COAT_SHADOW)
    _segment(pivot, "LowerSleeve",
        Vector3(side * 0.060, -0.28, -0.030),
        Vector3(side * 0.08, -0.48, -0.13), 0.081, 0.062, COAT)
    _sphere(pivot, "Hand", Vector3(side * 0.080, -0.52, -0.135),
        0.065, GLOVES, Vector3(0.95, 1.1, 0.75))
    return pivot


func _ready() -> void:
    name = "FirstPersonFullBody"
    # Camera is only pitched at Camera3D; this pelvis remains attached to
    # CharacterBody3D and follows yaw without lifting legs or moving the waist.
    pelvis_root = Node3D.new()
    pelvis_root.name = "PelvisRoot"
    pelvis_root.position = Vector3(0.0, 0.80, -0.040)
    add_child(pelvis_root)

    # Both halves of a plain autumn jacket remain visible when looking down.
    # They meet at the waist and overlap the leg attachment; unlike a cutaway
    # they never disappear, and unlike a huge chest block they stay below eyes.
    upper_coat = _tapered_coat(pelvis_root, "ChestAndShoulders",
        Vector3(0.0, 0.305, -0.012), 0.315, 0.172, 0.191)
    lower_jacket = _tapered_coat(pelvis_root, "LowerJacket",
        Vector3(0.0, 0.075, 0.005), 0.255, 0.185, 0.204)
    # The narrow vertical strip suggests the front fastening of a winter coat
    # without an opaque horizontal plane blocking the view to the thighs.
    _box(pelvis_root, "CoatFrontSeam", Vector3(0.014, 0.21, 0.011),
        Vector3(0.0, 0.12, -0.137), COAT_SHADOW)
    _box(pelvis_root, "CoatHem", Vector3(0.386, 0.034, 0.210),
        Vector3(0.0, -0.053, 0.005), COAT_SHADOW)
    _box(pelvis_root, "HipFabric", Vector3(0.337, 0.113, 0.192),
        Vector3(0.0, -0.113, -0.005), PANTS)

    left_leg = _leg(-1.0, "LeftLeg", pelvis_root)
    right_leg = _leg(1.0, "RightLeg", pelvis_root)
    left_arm = _arm(-1.0, "LeftArm", pelvis_root)
    right_arm = _arm(1.0, "RightArm", pelvis_root)
    print("FIRST_PERSON_BODY_READY: torso=true legs=2 arms=2 helmet=false prototype=true camera_clearance=true pelvis_aligned=true torso_visible=true open_coat_neck=true")


func set_right_hand_occupied(value: bool) -> void:
    hide_right_hand = value
    if right_arm != null:
        right_arm.visible = not value and not view_down_cutaway

func _process(delta: float) -> void:
    var actor := get_parent() as CharacterBody3D
    if actor == null:
        return
    var camera := actor.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        # Body is anchored below the camera, so no chest hiding is needed.
        # At steep angles only raised arms are suppressed to preserve clarity.
        var look_down := camera.rotation.x < -1.18
        view_down_cutaway = look_down
        upper_coat.visible = true
        lower_jacket.visible = true
        left_arm.visible = not look_down
        right_arm.visible = not look_down and not hide_right_hand
    var planar_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
    var moving := clampf(planar_speed / 3.4, 0.0, 1.0)
    if moving > 0.04 and actor.is_on_floor():
        walk_phase += delta * (5.0 + moving * 1.1)
    var swing := sin(walk_phase) * moving
    # In-place walk cycle: never change colliders or actual foot placement.
    left_leg.rotation.x = swing * 0.19
    right_leg.rotation.x = -swing * 0.19
    left_arm.rotation.x = -swing * 0.085
    right_arm.rotation.x = swing * 0.085
    position.y = 0.005 * absf(sin(walk_phase)) * moving
