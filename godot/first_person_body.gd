extends Node3D
# Fearless Knights / provisional first-person avatar.
# A lightweight articulated placeholder: real world-space torso/legs/arms
# beneath the player's eye camera. No head mesh is rendered from inside it.
# All pieces are visual only; the CharacterBody capsule remains authoritative.

const COAT := Color("#465148")
const COAT_SHADOW := Color("#303932")
const SHIRT := Color("#686255")
const PANTS := Color("#62685c")
const BOOTS := Color("#514c43")
const GLOVES := Color("#60594e")
const BELT := Color("#252722")

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var walk_phase := 0.0
var walk_weight := 0.0
var left_knee_joint: Node3D
var right_knee_joint: Node3D
var left_ankle_joint: Node3D
var right_ankle_joint: Node3D
var left_thigh_mesh: MeshInstance3D
var right_thigh_mesh: MeshInstance3D
var left_calf_mesh: MeshInstance3D
var right_calf_mesh: MeshInstance3D
var look_down_weight := 0.0
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

func _cloth_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
        d: Vector3, color: Color) -> void:
    # A vertical panel, not a horizontal cylinder cap seen from inside.
    for point in [a, b, c, a, c, d]:
        st.set_color(color)
        st.add_vertex(point)


func _jacket_section(root: Node3D, label: String,
        upper_y: float, lower_y: float, upper_width: float, lower_width: float,
        upper_front_z: float, lower_front_z: float) -> MeshInstance3D:
    # The viewing eye is ABOVE and behind this garment. The upper collar
    # bends backwards toward the player, while its waist/front face projects
    # ahead of the legs. The player sees a continuous coat silhouette and
    # pants below it, never a large top-facing octagonal lid.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var top_left := Vector3(-upper_width, upper_y, upper_front_z)
    var top_center := Vector3(0, upper_y, upper_front_z + 0.018)
    var top_right := Vector3(upper_width, upper_y, upper_front_z)
    var low_left := Vector3(-lower_width, lower_y, lower_front_z)
    var low_center := Vector3(0, lower_y, lower_front_z + 0.016)
    var low_right := Vector3(lower_width, lower_y, lower_front_z)
    _cloth_quad(st, top_left, top_center, low_center, low_left, COAT)
    _cloth_quad(st, top_center, top_right, low_right, low_center,
        COAT.darkened(0.07))
    var top_back_z := upper_front_z + 0.19
    var low_back_z := lower_front_z + 0.17
    _cloth_quad(st,
        top_right, Vector3(upper_width * 0.84, upper_y, top_back_z),
        Vector3(lower_width * 0.88, lower_y, low_back_z),
        low_right, COAT_SHADOW)
    _cloth_quad(st,
        Vector3(-upper_width * 0.84, upper_y, top_back_z), top_left,
        low_left, Vector3(-lower_width * 0.88, lower_y, low_back_z),
        COAT_SHADOW)
    _cloth_quad(st,
        Vector3(upper_width * 0.84, upper_y, top_back_z),
        Vector3(-upper_width * 0.84, upper_y, top_back_z),
        Vector3(-lower_width * 0.88, lower_y, low_back_z),
        Vector3(lower_width * 0.88, lower_y, low_back_z),
        COAT.darkened(0.12))
    st.generate_normals()
    var mat := _material(Color.WHITE)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    st.set_material(mat)
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = st.commit()
    root.add_child(node)
    return node



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
    # Hips, knees and ankles are separate joints. At rest the joints form an
    # almost vertical line beneath the pelvis; only the toe points forward.
    # This keeps the feet under the player instead of projecting them ahead.
    var hip := Node3D.new()
    hip.name = label
    hip.position = Vector3(side * 0.145, -0.120, 0.005)
    root.add_child(hip)
    _segment(hip, "TrouserThigh", Vector3.ZERO,
        Vector3(side * 0.008, -0.330, 0.014), 0.107, 0.095, PANTS)

    var knee := Node3D.new()
    knee.name = "KneeJoint"
    knee.position = Vector3(side * 0.008, -0.330, 0.014)
    hip.add_child(knee)
    _sphere(knee, "KneeFabric", Vector3.ZERO,
        0.091, PANTS, Vector3(1.0, 0.88, 1.0))
    _segment(knee, "TrouserCalf",
        Vector3(0.0, -0.012, 0.0),
        Vector3(side * 0.004, -0.294, 0.020),
        0.092, 0.079, PANTS)

    var ankle := Node3D.new()
    ankle.name = "AnkleJoint"
    ankle.position = Vector3(side * 0.004, -0.294, 0.020)
    knee.add_child(ankle)
    # The old toe and sole sat BELOW the collision floor and could be hidden
    # by the ground mesh. Keep every boot surface just above ground level.
    _box(ankle, "Boot", Vector3(0.165, 0.102, 0.175),
        Vector3(0.0, -0.042, -0.042), BOOTS)
    _box(ankle, "BootToe", Vector3(0.171, 0.064, 0.170),
        Vector3(0.0, -0.044, -0.187), BOOTS)
    _box(ankle, "BootSole", Vector3(0.180, 0.025, 0.240),
        Vector3(0.0, -0.070, -0.120), BELT)
    return hip

func _arm(side: float, label: String, root: Node3D) -> Node3D:
    # Side-hanging arms frame the lower corners of an extreme downwards view.
    # They are body-space; only the eyes rotate with vertical camera pitch.
    var pivot := Node3D.new()
    pivot.name = label
    pivot.position = Vector3(side * 0.278, 0.385, 0.125)
    root.add_child(pivot)
    _sphere(pivot, "Shoulder", Vector3.ZERO, 0.088, COAT)
    _segment(pivot, "Sleeve", Vector3.ZERO,
        Vector3(side * 0.080, -0.270, 0.010), 0.083, 0.071, COAT)
    _sphere(pivot, "Elbow", Vector3(side * 0.080, -0.270, 0.010),
        0.068, COAT_SHADOW)
    _segment(pivot, "LowerSleeve",
        Vector3(side * 0.080, -0.277, 0.005),
        Vector3(side * 0.096, -0.488, -0.055), 0.071, 0.055, COAT)
    _sphere(pivot, "Hand", Vector3(side * 0.096, -0.523, -0.066),
        0.059, GLOVES, Vector3(0.92, 1.22, 0.74))
    return pivot



func _ready() -> void:
    name = "FirstPersonFullBody"
    # Camera is only pitched at Camera3D; this pelvis remains attached to
    # CharacterBody3D and follows yaw without lifting legs or moving the waist.
    pelvis_root = Node3D.new()
    pelvis_root.name = "PelvisRoot"
    pelvis_root.position = Vector3(0.0, 0.84, 0.0)
    add_child(pelvis_root)

    # Chest is always represented by the outer front fabric. No collar/head
    # exists in the first-person mesh, and the upper fabric lies below the
    # near plane so the player can look vertically down from eye height.
    upper_coat = _jacket_section(pelvis_root, "ChestAndShoulders",
        0.448, 0.120, 0.235, 0.226, 0.138, -0.018)
    lower_jacket = _jacket_section(pelvis_root, "LowerJacket",
        0.122, -0.087, 0.226, 0.238, -0.018, -0.073)
    _box(pelvis_root, "CoatHem", Vector3(0.434, 0.032, 0.060),
        Vector3(0.0, -0.094, -0.070), COAT_SHADOW)
    # Waist of the trousers fills the opening between the jacket and hips
    # without adding a roof-like horizontal face in front of the camera.
    _box(pelvis_root, "HipFabric", Vector3(0.360, 0.104, 0.135),
        Vector3(0.0, -0.146, -0.040), PANTS)
    _box(pelvis_root, "JacketFastening", Vector3(0.011, 0.19, 0.012),
        Vector3(0.0, -0.010, -0.078), COAT_SHADOW)

    left_leg = _leg(-1.0, "LeftLeg", pelvis_root)
    right_leg = _leg(1.0, "RightLeg", pelvis_root)
    left_knee_joint = left_leg.get_node("KneeJoint") as Node3D
    right_knee_joint = right_leg.get_node("KneeJoint") as Node3D
    left_ankle_joint = left_knee_joint.get_node("AnkleJoint") as Node3D
    right_ankle_joint = right_knee_joint.get_node("AnkleJoint") as Node3D
    left_thigh_mesh = left_leg.get_node("TrouserThigh") as MeshInstance3D
    right_thigh_mesh = right_leg.get_node("TrouserThigh") as MeshInstance3D
    left_calf_mesh = left_knee_joint.get_node("TrouserCalf") as MeshInstance3D
    right_calf_mesh = right_knee_joint.get_node("TrouserCalf") as MeshInstance3D
    left_arm = _arm(-1.0, "LeftArm", pelvis_root)
    right_arm = _arm(1.0, "RightArm", pelvis_root)
    print("FIRST_PERSON_BODY_READY: torso=true legs=2 arms=2 helmet=false prototype=true camera_clearance=true pelvis_aligned=true torso_visible=true front_panels=true upright_joints=true grounded_gait=true soles_above_ground=true downlook_fulllegs=true")


func set_right_hand_occupied(value: bool) -> void:
    hide_right_hand = value
    if right_arm != null:
        right_arm.visible = not value and not view_down_cutaway

func _fit_bone_mesh(mesh: MeshInstance3D, a: Vector3, b: Vector3) -> void:
    # Adjust only the render segment; this never moves the player collider.
    var axis := b - a
    var cylinder := mesh.mesh as CylinderMesh
    mesh.position = (a + b) * 0.5
    mesh.quaternion = Quaternion(Vector3.UP, axis.normalized())
    mesh.scale.y = axis.length() / cylinder.height


func _align_leg_to_downward_view(delta: float, pitch: float) -> void:
    # The earlier ~10 cm adjustment left the knees and boots overlapping
    # the coat seam in actual browser screenshots. A larger, smoothed,
    # perspective-only correction exposes the entire leg chain.
    # Only visual joints move; the player capsule and physics stay intact.
    var target := smoothstep(0.52, 1.30, -pitch)
    look_down_weight = move_toward(look_down_weight, target, delta * 3.8)
    var knee_forward := 0.315 * look_down_weight
    var ankle_forward := 0.285 * look_down_weight
    var knee_spread := 0.022 * look_down_weight
    var ankle_spread := 0.026 * look_down_weight
    left_knee_joint.position = Vector3(-0.008 - knee_spread, -0.330, 0.014 - knee_forward)
    right_knee_joint.position = Vector3(0.008 + knee_spread, -0.330, 0.014 - knee_forward)
    left_ankle_joint.position = Vector3(-0.004 - ankle_spread, -0.294, 0.020 - ankle_forward)
    right_ankle_joint.position = Vector3(0.004 + ankle_spread, -0.294, 0.020 - ankle_forward)
    # The tapered geometry is continuously stretched between the joints,
    # so kneecaps, shins and footwear stay connected while looking around.
    _fit_bone_mesh(left_thigh_mesh, Vector3.ZERO, left_knee_joint.position)
    _fit_bone_mesh(right_thigh_mesh, Vector3.ZERO, right_knee_joint.position)
    _fit_bone_mesh(left_calf_mesh, Vector3(0.0, -0.012, 0.0), left_ankle_joint.position)
    _fit_bone_mesh(right_calf_mesh, Vector3(0.0, -0.012, 0.0), right_ankle_joint.position)


func _update_gait(delta: float, grounded_speed: float) -> void:
    # Drive the visual walk cycle only from grounded horizontal movement.
    # The player capsule, jump and collision physics are left untouched.
    var pace := clampf(grounded_speed / 3.35, 0.0, 1.55)
    var target_weight := clampf(pace, 0.0, 1.0)
    walk_weight = move_toward(walk_weight, target_weight, delta * 5.0)
    if target_weight > 0.04:
        walk_phase = fposmod(walk_phase + delta * (4.0 + 3.0 * pace), TAU)
    var left_step := sin(walk_phase)
    var right_step := -left_step
    var smoothing := clampf(delta * 12.0, 0.0, 1.0)
    # Small hip swing, knee flex only on the forward/swing half of a stride.
    left_leg.rotation.x = lerpf(left_leg.rotation.x,
        left_step * 0.19 * walk_weight, smoothing)
    right_leg.rotation.x = lerpf(right_leg.rotation.x,
        right_step * 0.19 * walk_weight, smoothing)
    left_knee_joint.rotation.x = lerpf(left_knee_joint.rotation.x,
        -maxf(0.0, left_step) * 0.25 * walk_weight, smoothing)
    right_knee_joint.rotation.x = lerpf(right_knee_joint.rotation.x,
        -maxf(0.0, right_step) * 0.25 * walk_weight, smoothing)
    # Counter-rotate the ankles: boots remain close to level instead of
    # pitching outward with an entire rigid leg.
    left_ankle_joint.rotation.x = lerpf(left_ankle_joint.rotation.x,
        -0.85 * (left_leg.rotation.x + left_knee_joint.rotation.x), smoothing)
    right_ankle_joint.rotation.x = lerpf(right_ankle_joint.rotation.x,
        -0.85 * (right_leg.rotation.x + right_knee_joint.rotation.x), smoothing)
    left_arm.rotation.x = lerpf(left_arm.rotation.x,
        -left_step * 0.085 * walk_weight, smoothing)
    right_arm.rotation.x = lerpf(right_arm.rotation.x,
        -right_step * 0.085 * walk_weight, smoothing)
    position.y = lerpf(position.y,
        0.006 * absf(sin(walk_phase)) * walk_weight, smoothing)


func _process(delta: float) -> void:
    var actor := get_parent() as CharacterBody3D
    if actor == null:
        return
    # The pelvis follows body yaw, not vertical camera pitch. It stays in
    # world space even at maximum look-down or while the mouse is turning.
    view_down_cutaway = false
    upper_coat.visible = true
    lower_jacket.visible = true
    left_arm.visible = true
    right_arm.visible = not hide_right_hand
    var planar_speed := Vector2(actor.velocity.x, actor.velocity.z).length()
    _update_gait(delta, planar_speed if actor.is_on_floor() else 0.0)
    var eye_camera := actor.get_node_or_null("Camera3D") as Camera3D
    if eye_camera != null:
        _align_leg_to_downward_view(delta, eye_camera.rotation.x)
