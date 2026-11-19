extends Node3D
# Godot 4: the actual imported glTF/GLB body. The complete model follows
# player yaw only. Looking down rotates the Camera3D, never the leg pivots.
# The old procedural rig stays present but hidden as a safe fallback.

const ASSET_PATH := "res://assets/dembel_2005.glb"

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


func _part(part_name: String) -> Node3D:
    return imported.find_child(part_name, true, false) as Node3D


func _ready() -> void:
    name = "ModeledCharacter"
    actor = get_parent() as CharacterBody3D
    var source: Resource = load(ASSET_PATH)
    if not (source is PackedScene):
        push_warning("MODELED_CHARACTER_FALLBACK: imported GLB unavailable")
        visible = false
        return
    imported = (source as PackedScene).instantiate() as Node3D
    if imported == null:
        push_warning("MODELED_CHARACTER_FALLBACK: GLB has no scene root")
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
        push_warning("MODELED_CHARACTER_FALLBACK: missing joints in imported GLB")
        queue_free()
        return
    # The head is needed for an external view, but must not cover the
    # camera from inside. No model/head translation or camera offset.
    head.visible = false
    model_loaded = true
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        legacy.visible = false
    print("MODELED_CHARACTER_READY: imported_glb=true leg_pivots=true head_hidden=true fixed_hips=true")


func _process(delta: float) -> void:
    if not model_loaded or actor == null:
        return
    # No changes to positions: all joints keep their original fixed offsets.
    # Rotating the camera does not enter this function, by design.
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
