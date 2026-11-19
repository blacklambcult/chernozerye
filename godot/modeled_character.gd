extends Node3D
# Separate meshes: camera-safe volumetric body and complete F4 character.
# No per-mesh cutaway filtering, no geometry animated by camera pitch.

const FULL_ASSET_PATH := "res://assets/dembel_full.glb"
const FPS_ASSET_PATH := "res://assets/dembel_fp.glb"
# The camera sits at the FRONT of the hero's head; the torso sits behind
# the eyes. Offset ONLY the first-person visual asset, not the camera,
# collider, interaction ray or external F4 inspection model.
const FPS_BODY_BACK_OFFSET := 0.24

var actor: CharacterBody3D
var full_body: Node3D
var first_person_body: Node3D
var model_loaded := false
var inspection_mode := false

var left_hip: Node3D
var right_hip: Node3D
var left_knee: Node3D
var right_knee: Node3D
var full_left_hip: Node3D
var full_right_hip: Node3D
var full_left_knee: Node3D
var full_right_knee: Node3D
var stride_phase := 0.0
var gait_weight := 0.0


func _part(root: Node3D, name: String) -> Node3D:
    return root.find_child(name, true, false) as Node3D


func _tint(name: String) -> Color:
    if "BootSole" in name:
        return Color("#332f29")
    if "Boot" in name:
        return Color("#584e40")
    if "Thigh" in name or "Pelvis" in name:
        return Color("#596356")
    if "LowerLeg" in name or "Calf" in name or "Crotch" in name:
        return Color("#465048")
    if "Pocket" in name or "Canvas" in name or "Sidor" in name:
        return Color("#84755d")
    if "Button" in name or "Buckle" in name or "Lace" in name:
        return Color("#ac9d7f")
    if "Head" in name or "Neck" in name or "Nose" in name or "Hand" in name:
        return Color("#a48b79")
    if "Hair" in name or "Eyebrow" in name:
        return Color("#413c33")
    if "Belt" in name or "Strap" in name:
        return Color("#6e563e")
    if "Lining" in name or "Seam" in name:
        return Color("#545848")
    if "Shirt" in name:
        return Color("#686b56")
    if "Sleeve" in name or "Coat" in name or "Torso" in name:
        return Color("#71705d")
    return Color("#777360")


func _opaque_materials(root: Node3D) -> int:
    var count := 0
    for n in root.find_children("*", "MeshInstance3D", true, false):
        var mesh := n as MeshInstance3D
        var mat := StandardMaterial3D.new()
        mat.albedo_color = _tint(String(mesh.name))
        mat.roughness = 1.0
        mat.vertex_color_use_as_albedo = false
        mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mesh.material_override = mat
        count += 1
    return count


func _fallback(reason: String) -> void:
    push_warning("MODELED_CHARACTER_FALLBACK: "+reason)
    model_loaded = false
    visible = false
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        legacy.visible = true


func _ready() -> void:
    actor = get_parent() as CharacterBody3D
    var fps_source := load(FPS_ASSET_PATH)
    var full_source := load(FULL_ASSET_PATH)
    if not (fps_source is PackedScene) or not (full_source is PackedScene):
        _fallback("separate GLBs failed to import")
        return
    first_person_body = (fps_source as PackedScene).instantiate() as Node3D
    full_body = (full_source as PackedScene).instantiate() as Node3D
    if first_person_body == null or full_body == null:
        _fallback("invalid GLB scene roots")
        return
    first_person_body.name = "FPSCharacter"
    full_body.name = "FullCharacter"
    add_child(first_person_body)
    add_child(full_body)
    # At zero offset the viewer looks vertically into the coat's open
    # collar, turning its 8-sided rim into an enormous central polygon.
    # With the visual body behind the eyes, jacket stays along the lower
    # edge and both boots remain farther ahead in downward projection.
    first_person_body.position.z = FPS_BODY_BACK_OFFSET
    left_hip = _part(first_person_body,"LeftLegPivot")
    right_hip = _part(first_person_body,"RightLegPivot")
    left_knee = _part(first_person_body,"LeftKneePivot")
    right_knee = _part(first_person_body,"RightKneePivot")
    full_left_hip = _part(full_body,"LeftLegPivot")
    full_right_hip = _part(full_body,"RightLegPivot")
    full_left_knee = _part(full_body,"LeftKneePivot")
    full_right_knee = _part(full_body,"RightKneePivot")
    if left_hip == null or right_hip == null or left_knee == null or right_knee == null or full_left_hip == null or full_right_hip == null:
        _fallback("imported GLB is missing pivots")
        return
    if _part(first_person_body,"FPTorsoShell") == null or _part(first_person_body,"FPPelvis") == null or _part(first_person_body,"FPShirtLining") == null:
        _fallback("fps body has no opaque waist / torso")
        return
    if _part(first_person_body,"Head") != null or _part(first_person_body,"SidorCanvasSack") != null:
        _fallback("FPS scene contains head or backpack")
        return
    if _part(full_body,"WinterCoat") == null or _part(full_body,"Head") == null:
        _fallback("full body lost head or coat")
        return
    if _opaque_materials(first_person_body) < 22:
        _fallback("fps has too few body meshes")
        return
    _opaque_materials(full_body)
    first_person_body.visible = true
    full_body.visible = false
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        legacy.visible = false
    model_loaded = true
    print("MODELED_CHARACTER_READY: separate_glb=true solid_fps_torso=true opaque_pelvis=true full_f4=true legacy_hidden=true camera_forward_of_torso=true")


func set_inspection_mode(enabled: bool) -> void:
    if not model_loaded:
        return
    inspection_mode = enabled
    first_person_body.visible = not enabled
    full_body.visible = enabled


func _process(delta: float) -> void:
    if not model_loaded or actor == null:
        return
    var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
    var target := clampf(speed/3.35,0.0,1.0) if actor.is_on_floor() else 0.0
    gait_weight = move_toward(gait_weight,target,delta*5.0)
    if target > 0.03:
        stride_phase = fposmod(stride_phase + delta*(4.4+2.4*target),TAU)
    var swing := sin(stride_phase)*gait_weight
    for pivot in [left_hip,full_left_hip]:
        pivot.rotation.x = swing*.15
    for pivot in [right_hip,full_right_hip]:
        pivot.rotation.x = -swing*.15
    for joint in [left_knee,full_left_knee]:
        joint.rotation.x = -maxf(0.0,swing)*.16
    for joint in [right_knee,full_right_knee]:
        joint.rotation.x = -maxf(0.0,-swing)*.16
