extends Node3D
# Pre-Alpha 0.6.7: first person deliberately has NO body mesh.
# The complete GLB is instantiated exclusively for the F4 inspection camera.
# FPS hands and scripted interactions remain under Camera3D.
# Do NOT instantiate dembel_fp.glb here, even as a hidden node, so no
# future update/visibility handoff can place the pelvis in the camera.

const FULL_ASSET_PATH := "res://assets/dembel_full.glb"

var actor: CharacterBody3D
var full_body: Node3D
var first_person_body: Node3D = null
var model_loaded := false
var _load_attempted := false
var inspection_mode := false

var full_left_hip: Node3D
var full_right_hip: Node3D
var full_left_knee: Node3D
var full_right_knee: Node3D
var stride_phase := 0.0
var gait_weight := 0.0


func _part(name: String) -> Node3D:
    return full_body.find_child(name, true, false) as Node3D


func _tint(name: String) -> Color:
    if "BootSole" in name:
        return Color("#332f29")
    if "Boot" in name:
        return Color("#584e40")
    if "Thigh" in name:
        return Color("#596356")
    if "LowerLeg" in name:
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
    if "Shirt" in name:
        return Color("#686b56")
    if "Sleeve" in name or "Coat" in name or "Torso" in name:
        return Color("#71705d")
    return Color("#777360")


func _ready() -> void:
    actor = get_parent() as CharacterBody3D
    # The old scripted avatar is retained ONLY as an invisible compatibility
    # node for cinematic effects. It must never render during gameplay or F4.
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        legacy.visible = false
        legacy.set_process(false)
    print("MODELED_CHARACTER_DEFERRED: full_body=f4_only")


func _load_full_body() -> bool:
    if _load_attempted:
        return model_loaded
    _load_attempted = true
    var source := load(FULL_ASSET_PATH)
    if not (source is PackedScene):
        push_warning("MODELED_CHARACTER_F4_UNAVAILABLE: full GLB import failed")
        return false
    full_body = (source as PackedScene).instantiate() as Node3D
    if full_body == null:
        push_warning("MODELED_CHARACTER_F4_UNAVAILABLE: no full GLB scene")
        return false
    full_body.name = "FullCharacter"
    add_child(full_body)
    full_left_hip = _part("LeftLegPivot")
    full_right_hip = _part("RightLegPivot")
    full_left_knee = _part("LeftKneePivot")
    full_right_knee = _part("RightKneePivot")
    if full_left_hip == null or full_right_hip == null or full_left_knee == null or full_right_knee == null:
        full_body.visible = false
        push_warning("MODELED_CHARACTER_F4_UNAVAILABLE: missing full-body pivots")
        return false
    if _part("WinterCoat") == null or _part("Head") == null:
        full_body.visible = false
        push_warning("MODELED_CHARACTER_F4_UNAVAILABLE: incomplete full body")
        return false
    for n in full_body.find_children("*", "MeshInstance3D", true, false):
        var mesh := n as MeshInstance3D
        var material := StandardMaterial3D.new()
        material.albedo_color = _tint(String(mesh.name))
        material.roughness = 1.0
        material.vertex_color_use_as_albedo = false
        material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
        mesh.material_override = material
    full_body.visible = false
    model_loaded = true
    print("MODELED_CHARACTER_READY: fps_body=disabled full_body=f4_only fps_arms=independent")
    return true


func set_inspection_mode(enabled: bool) -> bool:
    if enabled and not _load_full_body():
        return false
    inspection_mode = enabled
    if full_body != null:
        full_body.visible = inspection_mode
    return true


func _process(delta: float) -> void:
    if actor == null:
        return
    # Defense in depth: even if another script toggles the legacy avatar
    # or full GLB, never let either show in first-person gameplay.
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null and legacy.visible:
        legacy.visible = false
    if full_body != null:
        full_body.visible = inspection_mode and model_loaded
    if not model_loaded:
        return
    # Retain modest gait articulation in the F4 inspector only.
    if not inspection_mode:
        return
    var speed := Vector2(actor.velocity.x, actor.velocity.z).length()
    var target := clampf(speed / 3.35, 0.0, 1.0) if actor.is_on_floor() else 0.0
    gait_weight = move_toward(gait_weight, target, delta * 5.0)
    if target > 0.03:
        stride_phase = fposmod(stride_phase + delta * (4.4 + 2.4 * target), TAU)
    var swing := sin(stride_phase) * gait_weight
    full_left_hip.rotation.x = swing * 0.15
    full_right_hip.rotation.x = -swing * 0.15
    full_left_knee.rotation.x = -maxf(0.0, swing) * 0.16
    full_right_knee.rotation.x = -maxf(0.0, -swing) * 0.16
