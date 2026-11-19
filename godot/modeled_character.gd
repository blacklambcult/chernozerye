extends Node3D
# Full editable GLB asset + first-person-only cutaway from the same mesh.
# No old procedural coat is rendered when imported GLB succeeds.
# F4 switches to complete imported hero for honest full-body inspection.

const ASSET_PATH := "res://assets/dembel_2005.glb"
const LEG_PARTS := ["LeftThigh", "LeftLowerLeg", "LeftBoot", "RightThigh", "RightLowerLeg", "RightBoot"]
const FIRST_PERSON_COAT_PREFIX := "FPSCoat"

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
var visible_cutaway_meshes := 0
var hidden_upper_meshes := 0
var inspection_mode := false


func _part(part_name: String) -> Node3D:
    return imported.find_child(part_name, true, false) as Node3D


func _first_person_part(label: String) -> bool:
    if label.begins_with(FIRST_PERSON_COAT_PREFIX):
        return true
    for prefix in LEG_PARTS:
        if label.begins_with(prefix):
            return true
    return false


func _make_material(label: String) -> StandardMaterial3D:
    # All full-model materials are explicit. The source GLB now has PBR too,
    # but this Godot-side fallback guarantees a coloured F4 inspector even
    # when the platform ignores vertex-color attributes.
    var color := Color("#676657")
    if label.begins_with("FPSCoat"):
        if "LowerLeft" in label or "CenterSeam" in label:
            color = Color("#484c40")
        elif "Button" in label:
            color = Color("#bbae8b")
        elif "Pocket" in label:
            color = Color("#887964")
        else:
            color = Color("#676759")
    elif "Hair" in label or "Eyebrow" in label:
        color = Color("#393630")
    elif "Head" in label or "Neck" in label or "Nose" in label or "Hand" in label or "Thumb" in label or "EyeShadow" in label:
        color = Color("#a18b7c")
    elif "BootSole" in label:
        color = Color("#2d2a27")
    elif "Boot" in label:
        color = Color("#50483d")
    elif "Thigh" in label:
        color = Color("#5a6158")
    elif "LowerLeg" in label:
        color = Color("#4a524e")
    elif "Sidor" in label or "Canvas" in label:
        color = Color("#8c7f62")
    elif "Belt" in label or "ShoulderStrap" in label:
        color = Color("#755b43")
    elif "Button" in label or "Buckle" in label or "Lace" in label:
        color = Color("#b9ae90")
    elif "Sleeve" in label or "WinterCoat" in label:
        color = Color("#757361")
    elif "Pocket" in label or "Seam" in label or "Epaulette" in label or "Cuff" in label:
        color = Color("#525347")
    elif "Shirt" in label:
        color = Color("#646b55")
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 1.0
    mat.metallic = 0.0
    mat.vertex_color_use_as_albedo = false
    if label.begins_with("FPSCoat"):
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat

func _apply_mode(inspect: bool) -> void:
    inspection_mode = inspect
    visible_leg_meshes = 0
    visible_cutaway_meshes = 0
    hidden_upper_meshes = 0
    for node in imported.find_children("*", "MeshInstance3D", true, false):
        var mesh := node as MeshInstance3D
        var label := String(mesh.name)
        var first_person := _first_person_part(label)
        mesh.visible = (not label.begins_with(FIRST_PERSON_COAT_PREFIX)) if inspect else first_person
        if mesh.visible:
            # Never discard colours in inspection mode: in 0.6.2 the
            # full-body model became a completely white silhouette.
            mesh.material_override = _make_material(label)
            if not inspect:
                if label.begins_with(FIRST_PERSON_COAT_PREFIX):
                    visible_cutaway_meshes += 1
                else:
                    visible_leg_meshes += 1
        else:
            mesh.material_override = null
            if not inspect and not first_person:
                hidden_upper_meshes += 1
    var head := _part("HeadPivot")
    if head != null:
        head.visible = inspect
    # The old procedural mesh stays in the tree solely as an API fallback
    # for earlier interaction animation and headless regression hooks.
    var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if legacy != null:
        legacy.visible = false


func set_inspection_mode(inspect: bool) -> void:
    if model_loaded:
        _apply_mode(inspect)


func _ready() -> void:
    name = "ModeledCharacter"
    actor = get_parent() as CharacterBody3D
    var source: Resource = load(ASSET_PATH)
    if not (source is PackedScene):
        push_warning("MODELED_CHARACTER_FALLBACK: GLB missing")
        visible = false
        return
    imported = (source as PackedScene).instantiate() as Node3D
    if imported == null:
        push_warning("MODELED_CHARACTER_FALLBACK: scene root missing")
        visible = false
        return
    add_child(imported)
    left_hip = _part("LeftLegPivot")
    right_hip = _part("RightLegPivot")
    left_knee = _part("LeftKneePivot")
    right_knee = _part("RightKneePivot")
    left_arm = _part("LeftArmPivot")
    right_arm = _part("RightArmPivot")
    if left_hip == null or right_hip == null or left_knee == null or right_knee == null or _part("HeadPivot") == null:
        push_warning("MODELED_CHARACTER_FALLBACK: missing GLB joints")
        visible = false
        return
    _apply_mode(false)
    if visible_leg_meshes < 8 or visible_cutaway_meshes < 8 or hidden_upper_meshes < 8:
        push_warning("MODELED_CHARACTER_FALLBACK: cutaway or legs missing")
        visible = false
        var legacy := actor.get_node_or_null("FirstPersonFullBody") as Node3D
        if legacy != null:
            legacy.visible = true
        return
    model_loaded = true
    print("MODELED_CHARACTER_READY: glb=true first_person_cutaway=true legs=true procedural_coat_hidden=true inspection_f4=true colored_materials=true compact_cutaway=true")


func _process(delta: float) -> void:
    if not model_loaded or actor == null:
        return
    # Camera pitch NEVER enters leg transforms. No leg or knee positional
    # correction is applied to create an artificial first-person pose.
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
