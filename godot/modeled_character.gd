extends Node3D
# Imported GLB is kept as editable, standalone 3D geometry.
# In first-person only its legs and boots render. The world-space legacy
# first-person COAT renders the chest, and camera-space arms render the hands.
# This prevents the camera from intersecting the full imported coat/backpack.

const ASSET_PATH := "res://assets/dembel_2005.glb"
const LEG_PARTS := [
    "LeftThigh", "LeftLowerLeg", "LeftBoot",
    "RightThigh", "RightLowerLeg", "RightBoot"
]

var actor: CharacterBody3D
var imported: Node3D
var model_loaded := false
var left_hip: Node3D
var right_hip: Node3D
var left_knee: Node3D
var right_knee: Node3D
var left_arm: Node3D
var right_arm: Node3D
var phase := 0.0
var gait_weight := 0.0
var visible_leg_meshes := 0
var hidden_upper_meshes := 0


func _part(part_name: String) -> Node3D:
    return imported.find_child(part_name, true, false) as Node3D


func _leg_material(name: String) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    if "Boot" in name:
        mat.albedo_color = Color("#544b3f")
    elif "LowerLeg" in name:
        mat.albedo_color = Color("#414a45")
    else:
        mat.albedo_color = Color("#586057")
    mat.roughness = 1.0
    return mat


func _restrict_to_legs() -> bool:
    # Explicit allow-list: only meshes whose identity is a thigh, lower leg
    # or boot. The jacket's large closed shell must NEVER be visible to the
    # first-person camera, even if an import adds new parts later.
    visible_leg_meshes = 0
    hidden_upper_meshes = 0
    var geometries := imported.find_children("*", "MeshInstance3D", true, false)
    for node in geometries:
        var mesh := node as MeshInstance3D
        var label := String(mesh.name)
        var show := false
        for prefix in LEG_PARTS:
            if label.begins_with(prefix):
                show = true
                break
        mesh.visible = show
        if show:
            mesh.material_override = _leg_material(label)
            visible_leg_meshes += 1
        else:
            hidden_upper_meshes += 1
    # Require actual generated meshes, not just empty pivot nodes. Keep a
    # safe fallback if a future GLB import renames the rig unexpectedly.
    return visible_leg_meshes >= 8 and hidden_upper_meshes >= 8


func _ready() -> void:
    name = "ModeledCharacter"
    actor = get_parent() as CharacterBody3D
    var source: Resource = load(ASSET_PATH)
    if not (source is PackedScene):
        push_warning("MODELED_CHARACTER_FALLBACK: GLB not available")
        visible = false
        return
    imported = (source as PackedScene).instantiate() as Node3D
    if imported == null:
        push_warning("MODELED_CHARACTER_FALLBACK: GLB scene missing")
        visible = false
        return
    add_child(imported)
    left_hip = _part("LeftLegPivot")
    right_hip = _part("RightLegPivot")
    left_knee = _part("LeftKneePivot")
    right_knee = _part("RightKneePivot")
    left_arm = _part("LeftArmPivot")
    right_arm = _part("RightArmPivot")
    var head := _part("HeadPivot")
    if left_hip == null or right_hip == null or left_knee == null or right_knee == null or head == null:
        push_warning("MODELED_CHARACTER_FALLBACK: leg joints absent")
        visible = false
        return
    head.visible = false
    if not _restrict_to_legs():
        push_warning("MODELED_CHARACTER_FALLBACK: unexpected GLB geometry")
        visible = false
        return
    model_loaded = true
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        # Keep the proven narrow first-person coat and side hands. Disable
        # ONLY its duplicate procedural legs; no change to camera/collision.
        var pelvis := legacy.get_node_or_null("PelvisRoot") as Node3D
        if pelvis != null:
            (pelvis.get_node("LeftLeg") as Node3D).visible = false
            (pelvis.get_node("RightLeg") as Node3D).visible = false
    print("MODELED_CHARACTER_READY: imported_glb=true leg_pivots=true head_hidden=true fixed_hips=true fps_legs_only=true meshes=", visible_leg_meshes)


func _process(delta: float) -> void:
    if not model_loaded or actor == null:
        return
    # The imported leg joints never move as a consequence of camera pitch.
    # Only their rotation changes during gait, and the feet stay under the
    # pelvis when the player is stationary.
    var planar := Vector2(actor.velocity.x, actor.velocity.z).length()
    var target := clampf(planar / 3.35, 0.0, 1.0) if actor.is_on_floor() else 0.0
    gait_weight = move_toward(gait_weight, target, delta * 5.0)
    if target > 0.03:
        phase = fposmod(phase + delta * (4.4 + 2.4 * target), TAU)
    var swing := sin(phase) * gait_weight
    left_hip.rotation.x = swing * 0.16
    right_hip.rotation.x = -swing * 0.16
    left_knee.rotation.x = -maxf(0.0, sin(phase)) * 0.17 * gait_weight
    right_knee.rotation.x = -maxf(0.0, -sin(phase)) * 0.17 * gait_weight
    if left_arm != null and right_arm != null:
        left_arm.rotation.x = -swing * 0.085
        right_arm.rotation.x = swing * 0.085
