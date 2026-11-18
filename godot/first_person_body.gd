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

func _leg(side: float, label: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = label
    pivot.position = Vector3(side * 0.165, 0.80, -0.045)
    add_child(pivot)
    _sphere(pivot, "HipJoint", Vector3.ZERO, 0.16, PANTS)
    _segment(pivot, "TrouserThigh", Vector3.ZERO,
        Vector3(side * 0.016, -0.39, -0.027), 0.148, 0.125, PANTS)
    _sphere(pivot, "Knee", Vector3(side * 0.016, -0.40, -0.026),
        0.128, PANTS)
    _segment(pivot, "TrouserCalf", Vector3(side * 0.016, -0.42, -0.026),
        Vector3(side * 0.025, -0.69, -0.036), 0.12, 0.105, PANTS)
    _box(pivot, "Boot", Vector3(0.23, 0.17, 0.35),
        Vector3(side * 0.025, -0.725, -0.12), BOOTS)
    _box(pivot, "BootSole", Vector3(0.245, 0.055, 0.37),
        Vector3(side * 0.025, -0.80, -0.12), BELT)
    return pivot

func _arm(side: float, label: String) -> Node3D:
    var pivot := Node3D.new()
    pivot.name = label
    # Shift shoulders backward and below the eye. Previously these spheres
    # filled the image when the user looked down into the body.
    pivot.position = Vector3(side * 0.295, 1.155, 0.20)
    add_child(pivot)
    _sphere(pivot, "Shoulder", Vector3.ZERO, 0.105, COAT)
    _segment(pivot, "Sleeve", Vector3.ZERO,
        Vector3(side * 0.065, -0.29, -0.04), 0.105, 0.088, COAT)
    _sphere(pivot, "Elbow", Vector3(side * 0.065, -0.29, -0.04),
        0.09, COAT_SHADOW)
    _segment(pivot, "LowerSleeve",
        Vector3(side * 0.065, -0.30, -0.04),
        Vector3(side * 0.09, -0.51, -0.16), 0.088, 0.066, COAT)
    _sphere(pivot, "Hand", Vector3(side * 0.09, -0.565, -0.185),
        0.072, GLOVES, Vector3(1.0, 1.18, 0.75))
    for n in range(3):
        _segment(pivot, "Finger" + str(n),
            Vector3(side * 0.09 + (float(n) - 1.0) * 0.035,
                -0.615, -0.20),
            Vector3(side * 0.09 + (float(n) - 1.0) * 0.035,
                -0.674, -0.22), 0.017, 0.012, GLOVES)
    return pivot

func _ready() -> void:
    name = "FirstPersonFullBody"
    # Eye at y=1.55, z=0. The chest is narrow, flat and behind the
    # camera rather than a giant green torso intersecting the viewing cone.
    # Visible when looking straight down: the waist of an ordinary coat,
    # trousers and shoes. No plated vest, collar, or separate chest pockets.
    _tapered_coat(self, "ChestAndShoulders",
        Vector3(0.0, 1.075, 0.25), 0.37, 0.215, 0.235)
    _box(self, "LowerJacket", Vector3(0.43, 0.215, 0.21),
        Vector3(0.0, 0.81, 0.235), COAT)
    _box(self, "CoatHem", Vector3(0.455, 0.038, 0.23),
        Vector3(0.0, 0.700, 0.235), COAT_SHADOW)
    # A thin vertical fabric seam, not a belt buckle or armor plate.
    _box(self, "CoatSeam", Vector3(0.015, 0.20, 0.012),
        Vector3(0.0, 0.835, 0.121), COAT_SHADOW)
    left_leg = _leg(-1.0, "LeftLeg")
    right_leg = _leg(1.0, "RightLeg")
    left_arm = _arm(-1.0, "LeftArm")
    right_arm = _arm(1.0, "RightArm")
    print("FIRST_PERSON_BODY_READY: torso=true legs=2 arms=2 helmet=false prototype=true camera_clearance=true")

func set_right_hand_occupied(value: bool) -> void:
    hide_right_hand = value
    if right_arm != null:
        right_arm.visible = not value

func _process(delta: float) -> void:
    var actor := get_parent() as CharacterBody3D
    if actor == null:
        return
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
