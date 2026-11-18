extends Node3D
# Cinematic, entirely cosmetic sequence for an adult fictional protagonist.
# No character stats, relief, buffs, refills or recovery are associated with it.
# All props are deliberately unbranded and low-poly.

enum Phase { IDLE, PACK, RETRIEVE, LIGHT_CUT, MOVE_TO_FACE, BURN, LOWER, DISCARD }

const BURN_SECONDS := 120.0
const MAX_STUBS := 6
var phase: Phase = Phase.IDLE
var phase_elapsed := 0.0
var burn_elapsed := 0.0
var completed_cycles := 0
var initiated_cycles := 0
var player: CharacterBody3D
var body: Node3D
var gesture: Node3D
var hand: Node3D
var pack: Node3D
var lighter: Node3D
var hand_prop: Node3D
var mouth_prop: Node3D
var mouth_paper: Node3D
var embers: MeshInstance3D
var smoke: CPUParticles3D
var active_visual := false

func _material(tint: Color, unlit: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.95
    if unlit:
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return mat

func _box(parent: Node3D, title: String, size: Vector3,
        position: Vector3, tint: Color) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = mesh
    node.position = position
    node.material_override = _material(tint)
    parent.add_child(node)
    return node

func _tube(parent: Node3D, title: String, from: Vector3, to: Vector3,
        radius: float, tint: Color) -> MeshInstance3D:
    var direction := to - from
    var mesh := CylinderMesh.new()
    mesh.height = direction.length()
    mesh.bottom_radius = radius
    mesh.top_radius = radius
    mesh.radial_segments = 8
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = mesh
    node.position = (from + to) * 0.5
    node.quaternion = Quaternion(Vector3.UP, direction.normalized())
    node.material_override = _material(tint)
    parent.add_child(node)
    return node

func _prop(root: Node3D, title: String) -> Node3D:
    var prop := Node3D.new()
    prop.name = title
    root.add_child(prop)
    _tube(prop, "BrownFilter", Vector3(0,-0.047,0),
        Vector3(0,-0.009,0), 0.008, Color("#987454"))
    _tube(prop, "Paper", Vector3(0,-0.009,0),
        Vector3(0,0.086,0), 0.008, Color("#e0dcd1"))
    _box(prop, "DimEmber", Vector3(0.018,0.009,0.018),
        Vector3(0,0.090,0), Color("#b44732"))
    return prop

func _ready() -> void:
    name = "CharacterSmoking"
    player = get_parent().get_parent() as CharacterBody3D
    body = player.get_node_or_null("FirstPersonFullBody")
    gesture = Node3D.new()
    gesture.name = "CinematicHands"
    gesture.visible = false
    add_child(gesture)
    # A simple single bent-sleeve shape is more legible than a giant
    # articulated mitten placed directly on the lens.
    _tube(gesture, "RightSleeve", Vector3(0.55,-0.79,-0.32),
        Vector3(0.38,-0.54,-0.66), 0.068, Color("#47433c"))
    hand = Node3D.new()
    hand.name = "RightHand"
    gesture.add_child(hand)
    var palm_mesh := CapsuleMesh.new()
    palm_mesh.radius = 0.038
    palm_mesh.height = 0.106
    palm_mesh.radial_segments = 8
    var palm := MeshInstance3D.new()
    palm.name = "Palm"
    palm.mesh = palm_mesh
    palm.material_override = _material(Color("#84786b"))
    hand.add_child(palm)
    _tube(hand, "Index", Vector3(0.020,0.027,-0.009),
        Vector3(0.019,0.085,-0.028), 0.011, Color("#84786b"))
    _tube(hand, "Middle", Vector3(-0.020,0.027,-0.009),
        Vector3(-0.020,0.085,-0.028), 0.011, Color("#84786b"))
    hand_prop = _prop(hand,"HeldProp")
    hand_prop.position = Vector3(0,0.079,-0.039)

    pack = Node3D.new()
    pack.name = "PackVisual"
    pack.position = Vector3(0.32,-0.53,-0.69)
    add_child(pack)
    _box(pack,"UnbrandedPack",Vector3(0.115,0.17,0.038),
        Vector3.ZERO,Color("#b5afa5"))
    _box(pack,"PaperBand",Vector3(0.117,0.036,0.040),
        Vector3(0,-0.018,-0.001),Color("#7d6658"))
    pack.visible = false

    lighter = Node3D.new()
    lighter.name = "LighterVisual"
    lighter.position = Vector3(-0.16,-0.42,-0.70)
    add_child(lighter)
    _box(lighter,"SmallProp",Vector3(0.050,0.095,0.030),
        Vector3.ZERO,Color("#666962"))
    _box(lighter,"BriefAmberHighlight",Vector3(0.020,0.014,0.020),
        Vector3(0,0.060,0),Color("#c68c50"))
    lighter.visible = false

    mouth_prop = Node3D.new()
    mouth_prop.name = "NearFaceProp"
    mouth_prop.position = Vector3(0.105,-0.145,-0.30)
    mouth_prop.rotation_degrees = Vector3(67.0,0.0,-32.0)
    add_child(mouth_prop)
    mouth_paper = _prop(mouth_prop,"FadingProp")
    embers = mouth_paper.get_node("DimEmber") as MeshInstance3D
    mouth_prop.visible = false
    smoke = CPUParticles3D.new()
    smoke.name = "SparseAmbientSmoke"
    smoke.position = Vector3(0.0,0.10,0.0)
    smoke.amount = 3
    smoke.lifetime = 1.6
    smoke.direction = Vector3(0,1,0)
    smoke.spread = 15.0
    smoke.initial_velocity_min = 0.05
    smoke.initial_velocity_max = 0.13
    smoke.gravity = Vector3(0,0.045,0)
    smoke.local_coords = false
    var quad := QuadMesh.new()
    quad.size = Vector2(0.012,0.012)
    var sm := _material(Color(0.68,0.70,0.71,0.10),true)
    sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    sm.cull_mode = BaseMaterial3D.CULL_DISABLED
    quad.material = sm
    smoke.mesh = quad
    mouth_prop.add_child(smoke)
    smoke.emitting = false
    _render_phase()
    print("CHARACTER_SEQUENCE_READY: cosmetic=true selected_slot_required=true duration=120 states=8")

func _phase_length() -> float:
    match phase:
        Phase.PACK: return 0.75
        Phase.RETRIEVE: return 0.70
        Phase.LIGHT_CUT: return 0.82
        Phase.MOVE_TO_FACE: return 0.75
        Phase.BURN: return BURN_SECONDS
        Phase.LOWER: return 0.70
        Phase.DISCARD: return 0.75
    return 0.0

func _set_phase(next_phase: Phase) -> void:
    phase = next_phase
    phase_elapsed = 0.0
    if phase == Phase.BURN:
        if body != null:
            body.call("set_right_hand_occupied",false)
    elif phase == Phase.IDLE:
        if body != null:
            body.call("set_right_hand_occupied",false)
    elif body != null:
        body.call("set_right_hand_occupied",true)
    if phase == Phase.IDLE:
        completed_cycles += 1
        _spawn_discarded_prop()
    _render_phase()

func start_if_selected(selected_slot: int, controls_locked: bool) -> bool:
    if phase != Phase.IDLE or selected_slot != 0 or controls_locked:
        return false
    var world := player.get_parent()
    var story := world.get_node_or_null("StoryPrologue")
    if story != null and bool(story.get("journal_open")):
        return false
    var map := world.get_node_or_null("MapOverlay") as CanvasLayer
    if map != null and map.visible:
        return false
    initiated_cycles += 1
    burn_elapsed = 0.0
    _set_phase(Phase.PACK)
    print("CHARACTER_SEQUENCE_STARTED: cosmetic=true count=",initiated_cycles)
    return true

func _advance(delta: float) -> void:
    var remaining := maxf(0.0,delta)
    var transitions := 0
    while remaining > 0.0 and phase != Phase.IDLE and transitions < 10:
        var span := _phase_length()
        var available := maxf(0.0,span-phase_elapsed)
        var step := minf(available,remaining)
        phase_elapsed += step
        remaining -= step
        if phase == Phase.BURN:
            burn_elapsed = minf(BURN_SECONDS,burn_elapsed+step)
        if phase_elapsed >= span - 0.00001:
            transitions += 1
            match phase:
                Phase.PACK: _set_phase(Phase.RETRIEVE)
                Phase.RETRIEVE: _set_phase(Phase.LIGHT_CUT)
                Phase.LIGHT_CUT: _set_phase(Phase.MOVE_TO_FACE)
                Phase.MOVE_TO_FACE: _set_phase(Phase.BURN)
                Phase.BURN: _set_phase(Phase.LOWER)
                Phase.LOWER: _set_phase(Phase.DISCARD)
                Phase.DISCARD: _set_phase(Phase.IDLE)
        elif step <= 0.0:
            break
    _render_phase()

func _process(delta: float) -> void:
    _advance(delta)

func _render_phase() -> void:
    gesture.visible = phase in [Phase.PACK,Phase.RETRIEVE,
        Phase.LIGHT_CUT,Phase.MOVE_TO_FACE,Phase.LOWER,Phase.DISCARD]
    pack.visible = phase in [Phase.PACK,Phase.RETRIEVE]
    lighter.visible = phase == Phase.LIGHT_CUT
    mouth_prop.visible = phase == Phase.BURN
    hand_prop.visible = phase in [Phase.RETRIEVE,Phase.LIGHT_CUT,
        Phase.MOVE_TO_FACE,Phase.LOWER,Phase.DISCARD]
    if gesture.visible:
        # One cinematic silhouette; never keep the arm up during the
        # two-minute ambient state.
        var t := clampf(phase_elapsed/maxf(0.01,_phase_length()),0,1)
        hand.position = Vector3(0.38,-0.56,-0.63)
        if phase == Phase.MOVE_TO_FACE:
            hand.position = hand.position.lerp(Vector3(0.14,-0.20,-0.36),
                smoothstep(0.0,1.0,t))
        elif phase == Phase.LOWER:
            hand.position = Vector3(0.14,-0.20,-0.36).lerp(
                Vector3(0.35,-0.58,-0.65),smoothstep(0.0,1.0,t))
        elif phase == Phase.DISCARD:
            hand.position = Vector3(0.34,-0.55,-0.63).lerp(
                Vector3(0.55,-0.77,-0.73),smoothstep(0.0,1.0,t))
        hand.rotation = Vector3(-0.12,-0.25,-0.24)
        if phase == Phase.MOVE_TO_FACE:
            hand.rotation.y = -0.35
    smoke.emitting = phase == Phase.BURN
    if phase == Phase.BURN:
        var portion := clampf(burn_elapsed/BURN_SECONDS,0,1)
        mouth_paper.scale.y = lerpf(1.0,0.28,portion)
        var ember_color := Color("#ac4834").lerp(Color("#ce6940"),
            0.18 + 0.13 * sin(burn_elapsed * 1.4))
        embers.material_override = _material(ember_color,true)
    else:
        mouth_paper.scale.y = 1.0

func _spawn_discarded_prop() -> void:
    # One tiny transient scenic prop at foot level. No collectible or reuse.
    if player == null or not is_instance_valid(player):
        return
    var world := player.get_parent()
    if world == null or world is SceneTree:
        return
    var all_stubs := get_tree().get_nodes_in_group("DiscardedScenicProps")
    if all_stubs.size() >= MAX_STUBS:
        all_stubs[0].queue_free()
    var remnant := Node3D.new()
    remnant.name = "ScenicDiscard"
    remnant.add_to_group("DiscardedScenicProps")
    world.add_child(remnant)
    var edge := player.global_transform.basis.x * 0.55
    var front := -player.global_transform.basis.z * 0.40
    remnant.global_position = player.global_position + edge + front + Vector3(0,0.028,0)
    _box(remnant,"DiscardedPaper",Vector3(0.013,0.013,0.047),
        Vector3.ZERO,Color("#8c8072"))
