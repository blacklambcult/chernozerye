extends CharacterBody3D
## Чернозёрье: first reusable NPC controller. Non-graphic hit reactions and detachable costume props.
## Optional model: res://assets/npc/cultist_modular.glb (falls back to procedural silhouette).

@export var patrol_radius := 4.0
@export var walk_speed := 0.85
@export var notice_distance := 13.0
@export var hit_points := 100.0

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _player: Node3D
var _visual: Node3D
var _head: Node3D
var _parts: Dictionary = {}
var _zone_health := {"head": 35.0, "torso": 100.0, "leftArm": 35.0, "rightArm": 35.0, "leftLeg": 45.0, "rightLeg": 45.0}
var _state := "idle"
var _state_timer := 0.0
var _step_clock := 0.0
var _stagger_time := 0.0
var _notice_cooldown := 0.0
var _base_pose: Dictionary = {}
var _base_position: Dictionary = {}
var _has_joint_rig := false
var _animation_time := 0.0
var _gait_blend := 0.0
var _robe_pivot: Node3D
var _robe_rest := Vector3.ZERO
var _cloth_sway := 0.0
var _ambient_pose := "rest"
var _pose_time := 0.0
var _pose_mix := 0.0
var _pose_index := 0
const AMBIENT_POSES := ["rest", "prayer", "look_around", "adjust_robe"]
var _ambience: Node3D

func _ready() -> void:
    name = "CultistNPC"
    add_to_group("chernozerye_npc")
    _home = global_position
    _player = get_tree().get_first_node_in_group("player") as Node3D
    if _player == null:
        _player = get_parent().get_node_or_null("Player") as Node3D
    var collider := CollisionShape3D.new()
    var shape := CapsuleShape3D.new()
    shape.radius = 0.33
    shape.height = 1.7
    collider.shape = shape
    collider.position.y = 0.9
    add_child(collider)
    _visual = Node3D.new()
    _visual.name = "Visual"
    # Retro screen grading remains active; do not replace NPC vertex-color materials with the generic jitter shader.
    _visual.add_to_group(&"ps1_jitter_stable")
    add_child(_visual)
    _build_visual()
    _ambience = preload("res://cultist_ambience.gd").new()
    _ambience.name = "CultistAmbience"
    add_child(_ambience)
    # Character collider is for locomotion, while dedicated hitboxes receive rays.
    # Raycast should never pick the whole capsule instead of a named body zone.
    collision_layer = 0
    collision_mask = 1
    _build_hit_zones()
    for key in ["leftArm", "rightArm", "leftLeg", "rightLeg", "leftShin", "rightShin", "leftFoot", "rightFoot"]:
        if _parts.has(key):
            var limb := _parts[key] as Node3D
            _base_pose[key] = limb.rotation
            _base_position[key] = limb.position
    _choose_target()

func _make_piece(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = part_name
    part.mesh = mesh
    part.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 1.0
    part.material_override = mat
    parent.add_child(part)
    return part

func _build_visual() -> void:
    var model_path := "res://assets/npc/cultist_modular.glb"
    if ResourceLoader.exists(model_path):
        var packed := load(model_path) as PackedScene
        if packed != null:
            var model := packed.instantiate() as Node3D
            if model != null:
                model.name = "CultistModel"
                # The authored v0.8 mesh is 2.68 m in source Z-up units.
                # At 0.69 scale it stands ~1.85 m, matching the NPC collider.
                model.scale = Vector3.ONE * 0.69
                # Trimesh source is Z-up with the face pointing toward -Y.
                # First convert Z-up to Godot Y-up; then turn the front toward
                # the controller's -Z forward axis (without flipping the feet).
                model.rotation.x = -PI * 0.5
                var facing := Node3D.new()
                facing.name = "ModelFacingCorrection"
                facing.rotation.y = PI
                _visual.add_child(facing)
                facing.add_child(model)
                # Build a parented pose rig over the authored GLB groups:
                # thigh -> shin -> foot, plus arms and head.
                # Parent pivots are placed in original Z-up model coordinates.
                var joint_origins := {
                    "head": Vector3(0, 0, 2.23),
                    "leftArm": Vector3(-0.42, 0, 1.94),
                    "rightArm": Vector3(0.42, 0, 1.94),
                    "leftLeg": Vector3(-0.195, 0, 0.78),
                    "rightLeg": Vector3(0.195, 0, 0.78),
                    "leftShin": Vector3(-0.195, 0, 0.46),
                    "rightShin": Vector3(0.195, 0, 0.46),
                    "leftFoot": Vector3(-0.195, 0, 0.16),
                    "rightFoot": Vector3(0.195, 0, 0.16)
                }
                for limb_name in joint_origins:
                    var group_name: String = limb_name.substr(0, 1).to_upper() + limb_name.substr(1)
                    var group_node := model.find_child(group_name, true, false) as Node3D
                    if group_node == null:
                        continue
                    var pivot := Node3D.new()
                    pivot.name = group_name + "GaitPivot"
                    pivot.position = joint_origins[limb_name]
                    model.add_child(pivot)
                    group_node.reparent(pivot, true)
                    _parts[limb_name] = pivot
                for side in ["left", "right"]:
                    if _parts.has(side + "Leg") and _parts.has(side + "Shin") and _parts.has(side + "Foot"):
                        var thigh := _parts[side + "Leg"] as Node3D
                        var shin := _parts[side + "Shin"] as Node3D
                        var foot := _parts[side + "Foot"] as Node3D
                        shin.reparent(thigh, true)
                        foot.reparent(shin, true)
                _setup_cloth(model)
                _parts["model"] = model
                _has_joint_rig = _parts.has("leftShin") and _parts.has("rightShin")
                _head = _parts.get("head", model) as Node3D
                return
    # Self-contained fallback: crafted in Godot, no external paid model or manual import.
    var robe := CylinderMesh.new()
    robe.top_radius = 0.31
    robe.bottom_radius = 0.60
    robe.height = 1.13
    robe.radial_segments = 9
    _make_piece(_visual, "Robe", robe, Vector3(0, 1.04, 0), Color("#171719"))
    var shoulders := BoxMesh.new()
    shoulders.size = Vector3(0.72, 0.26, 0.32)
    _make_piece(_visual, "Shoulders", shoulders, Vector3(0, 1.46, 0), Color("#1b1b1e"))
    _head = Node3D.new()
    _head.name = "HeadPivot"
    _head.position.y = 1.66
    _visual.add_child(_head)
    var hood := SphereMesh.new()
    hood.radius = 0.31
    hood.height = 0.62
    hood.radial_segments = 9
    hood.rings = 5
    _make_piece(_head, "Hood", hood, Vector3(0, 0.08, 0), Color("#0d0d11"))
    var cavity := SphereMesh.new()
    cavity.radius = 0.235
    cavity.height = 0.45
    cavity.radial_segments = 9
    cavity.rings = 6
    var dark_opening := _make_piece(_head, "HoodOpening", cavity, Vector3(0, 0.01, -0.235), Color("#09090b"))
    dark_opening.scale.z = 0.25
    var face := BoxMesh.new()
    face.size = Vector3(0.205, 0.235, 0.06)
    _make_piece(_head, "WeatheredFace", face, Vector3(0, 0.015, -0.292), Color("#554b46"))
    var eye_mesh := SphereMesh.new()
    eye_mesh.radius = 0.022
    eye_mesh.height = 0.04
    for side in [-1, 1]:
        _make_piece(_head, "GlowingEye", eye_mesh, Vector3(side * 0.07, 0.045, -0.331), Color("#9a4939"))
    var beard := CylinderMesh.new()
    beard.top_radius = 0.11
    beard.bottom_radius = 0.01
    beard.height = 0.24
    beard.radial_segments = 7
    _make_piece(_head, "Beard", beard, Vector3(0, -0.19, -0.28), Color("#272321"))
    var belt := CylinderMesh.new()
    belt.top_radius = 0.33
    belt.bottom_radius = 0.33
    belt.height = 0.045
    belt.radial_segments = 9
    _make_piece(_visual, "RopeBelt", belt, Vector3(0, 0.90, 0), Color("#655c42"))
    var sign := BoxMesh.new()
    sign.size = Vector3(0.075, 0.21, 0.012)
    _make_piece(_visual, "RedRuneVertical", sign, Vector3(0, 1.22, -0.315), Color("#8e2e29"))
    sign = BoxMesh.new()
    sign.size = Vector3(0.19, 0.055, 0.012)
    _make_piece(_visual, "RedRuneCross", sign, Vector3(0, 1.26, -0.323), Color("#8e2e29"))
    var sleeve := CylinderMesh.new()
    sleeve.top_radius = 0.17
    sleeve.bottom_radius = 0.32
    sleeve.height = 0.90
    sleeve.radial_segments = 8
    # Embroidered crimson sigil and dangling rope belt cords.
    var rune_stroke := BoxMesh.new()
    rune_stroke.size = Vector3(0.18, 0.036, 0.014)
    _make_piece(_visual, "CrimsonRuneBranch", rune_stroke, Vector3(0, 1.18, -0.325), Color("#8d2e2b"))
    var rope_strand := CylinderMesh.new()
    rope_strand.top_radius = 0.014
    rope_strand.bottom_radius = 0.02
    rope_strand.height = 0.51
    rope_strand.radial_segments = 5
    for side in [-1, 1]:
        _make_piece(_visual, "BeltCord", rope_strand, Vector3(side * 0.14, 0.64, -0.35), Color("#786c43"))
    var boot := BoxMesh.new()
    boot.size = Vector3(0.23, 0.23, 0.40)
    for side in [-1, 1]:
        var limb := Node3D.new()
        limb.name = "LeftArm" if side < 0 else "RightArm"
        limb.position = Vector3(0.42 * side, 1.38, 0)
        limb.rotation.z = -0.21 * side
        _visual.add_child(limb)
        _make_piece(limb, "BellSleeve", sleeve, Vector3(0, -0.36, 0), Color("#202024"))
        _parts["leftArm" if side < 0 else "rightArm"] = limb
        var leg := Node3D.new()
        leg.name = "LeftLeg" if side < 0 else "RightLeg"
        leg.position = Vector3(0.20 * side, 0.69, -0.04)
        var trouser := CylinderMesh.new()
        trouser.top_radius = 0.14
        trouser.bottom_radius = 0.18
        trouser.height = 0.62
        trouser.radial_segments = 7
        _make_piece(leg, "Trouser", trouser, Vector3(0, -0.28, 0), Color("#222225"))
        _visual.add_child(leg)
        _make_piece(leg, "Boot", boot, Vector3(0, -0.58, -0.07), Color("#24201e"))
        _parts["leftLeg" if side < 0 else "rightLeg"] = leg

func _build_hit_zones() -> void:
    var zone_specs := {
        "head": [Vector3(0, 1.78, 0), 0.29],
        "torso": [Vector3(0, 1.02, 0), 0.37],
        "leftArm": [Vector3(-0.49, 1.13, 0), 0.25],
        "rightArm": [Vector3(0.49, 1.13, 0), 0.25],
        "leftLeg": [Vector3(-0.2, 0.42, 0), 0.22],
        "rightLeg": [Vector3(0.2, 0.42, 0), 0.22]
    }
    for zone in zone_specs:
        var spec: Array = zone_specs[zone]
        var hitbox := StaticBody3D.new()
        hitbox.name = "Hit_" + zone
        hitbox.set_script(preload("res://npc_hitbox.gd"))
        hitbox.set("zone", zone)
        hitbox.set("controller", self)
        # Hits use a dedicated layer so the NPC locomotion body cannot collide with its own hitboxes.
        hitbox.collision_layer = 2
        hitbox.collision_mask = 0
        var shape_node := CollisionShape3D.new()
        var sphere := SphereShape3D.new()
        sphere.radius = float(spec[1])
        shape_node.shape = sphere
        shape_node.position = spec[0]
        hitbox.add_child(shape_node)
        add_child(hitbox)

func apply_damage(amount: float, zone: String = "torso") -> void:
    if _state == "down":
        return
    var key := zone if _zone_health.has(zone) else "torso"
    _zone_health[key] = maxf(0.0, float(_zone_health[key]) - amount)
    hit_points = maxf(0.0, hit_points - amount)
    _stagger_time = 0.45
    _notice_cooldown = 0.0
    _state = "alert"
    _state_timer = 1.6
    if key in ["leftArm", "rightArm"] and float(_zone_health[key]) <= 0.0 and _parts.has(key):
        # Non-graphic clothing loss: loose sleeve detaches, never body geometry.
        _detach_costume_part(_parts[key])
        _parts.erase(key)
    if hit_points <= 0.0:
        _state = "down"
        velocity = Vector3.ZERO
        var tween := create_tween()
        tween.tween_property(_visual, "rotation:z", 1.05, 0.55)

func _detach_costume_part(part: Node3D) -> void:
    if not is_instance_valid(part):
        return
    var old_transform := part.global_transform
    var dropped := part.duplicate()
    get_parent().add_child(dropped)
    dropped.global_transform = old_transform
    part.visible = false
    var tween := create_tween()
    tween.tween_property(dropped, "global_position", dropped.global_position + Vector3(0.35, -0.8, 0.25), 0.5)
    tween.parallel().tween_property(dropped, "rotation:z", 1.0, 0.5)
    tween.tween_interval(12.0)
    tween.tween_callback(Callable(dropped, "queue_free"))

func _choose_target() -> void:
    _target = _home + Vector3(randf_range(-patrol_radius, patrol_radius), 0, randf_range(-patrol_radius, patrol_radius))
    _state = "patrol"
    _state_timer = randf_range(3.0, 6.0)

func _begin_ambient_pause() -> void:
    _state = "ambient_pause"
    _ambient_pose = AMBIENT_POSES[_pose_index % AMBIENT_POSES.size()]
    _pose_index += 1
    _pose_time = 0.0
    _state_timer = randf_range(3.5, 6.5)

func _physics_process(delta: float) -> void:
    if _state == "down":
        return
    if _player == null or not is_instance_valid(_player):
        _player = get_parent().get_node_or_null("Player") as Node3D
    if not is_on_floor():
        velocity.y -= 15.0 * delta
    if _stagger_time > 0.0:
        _stagger_time -= delta
        velocity.x = move_toward(velocity.x, 0.0, delta * 8.0)
        velocity.z = move_toward(velocity.z, 0.0, delta * 8.0)
        move_and_slide()
        return
    var desired := Vector3.ZERO
    var sees_player := false
    if _player != null and global_position.distance_to(_player.global_position) < notice_distance:
        var eye := global_position + Vector3(0, 1.55, 0)
        var target_eye := _player.global_position + Vector3(0, 1.3, 0)
        var query := PhysicsRayQueryParameters3D.create(eye, target_eye, 1)
        query.exclude = [get_rid()]
        var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
        sees_player = obstruction.is_empty() or obstruction.get("collider") == _player
    if sees_player:
        _state = "alert"
        _state_timer = 2.5
        _notice_cooldown = 2.5
        desired = _player.global_position - global_position
        if desired.length() < 2.1:
            desired = Vector3.ZERO
        # Approach but stop at conversational distance, not inside the player.
    elif _state == "alert":
        _state_timer -= delta
        if _state_timer <= 0.0:
            _begin_ambient_pause()
    elif _state == "ambient_pause":
        _state_timer -= delta
        if _state_timer <= 0.0:
            _choose_target()
    else:
        desired = _target - global_position
        _state_timer -= delta
        if desired.length() < 0.9 or _state_timer <= 0.0:
            _begin_ambient_pause()
            desired = Vector3.ZERO
    desired.y = 0.0
    var speed := walk_speed * (1.25 if _state == "alert" else 1.0)
    if desired.length() > 0.35:
        var near_factor := clampf(desired.length() / 1.4, 0.25, 1.0)
        var flat := desired.normalized() * speed * near_factor
        velocity.x = move_toward(velocity.x, flat.x, 2.5 * delta)
        velocity.z = move_toward(velocity.z, flat.z, 2.5 * delta)
        _visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-flat.x, -flat.z), delta * 4.0)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 2.5 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 2.5 * delta)
    var previous := global_position
    move_and_slide()
    var displacement := global_position - previous
    var travelled := Vector2(displacement.x, displacement.z).length()
    _animate_character(delta, Vector2(displacement.x, displacement.z).length())
    if is_instance_valid(_ambience):
        _ambience.call("update_motion", delta, travelled, is_on_floor())

func _setup_cloth(model: Node3D) -> void:
    # The torso is one grouped mesh; use a subtle chest-centred pivot
    # to preserve its imported material and avoid custom WebGL shaders.
    var torso := model.find_child("Torso", true, false) as Node3D
    if torso != null:
        _robe_pivot = Node3D.new()
        _robe_pivot.name = "ClothMotionPivot"
        _robe_pivot.position = Vector3(0.0, 0.0, 1.72)
        model.add_child(_robe_pivot)
        torso.reparent(_robe_pivot, true)
        _robe_rest = _robe_pivot.rotation
    # Web compatibility: explicitly enable imported vertex colors on every
    # surface. Keep standard Godot materials instead of replacing them with
    # a custom shader, which can fail on mobile WebGL.
    for child in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := child as MeshInstance3D
        if mesh_node.mesh == null:
            continue
        mesh_node.add_to_group(&"ps1_jitter_stable")
        mesh_node.material_override = null
        for surface in range(mesh_node.mesh.get_surface_count()):
            var material := StandardMaterial3D.new()
            material.vertex_color_use_as_albedo = true
            material.albedo_color = Color.WHITE
            material.roughness = 0.96
            material.metallic = 0.0
            material.metallic_specular = 0.18
            material.cull_mode = BaseMaterial3D.CULL_DISABLED
            var arrays := mesh_node.mesh.surface_get_arrays(surface)
            var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
            if colors.is_empty():
                material.albedo_color = Color("#33312e")
                push_warning("Cultist surface missing vertex colors: " + mesh_node.name)
            mesh_node.set_surface_override_material(surface, material)

func _animate_character(delta: float, distance: float) -> void:
    _animation_time += delta
    _pose_time += delta
    _pose_mix = lerpf(_pose_mix, 1.0 if _state == "ambient_pause" else 0.0, 1.0 - exp(-delta * 3.0))
    var speed_now := distance / maxf(delta, 0.0001)
    _gait_blend = lerpf(_gait_blend, clampf(speed_now / 0.65, 0.0, 1.0), 1.0 - exp(-delta * 5.0))
    _step_clock = fmod(_step_clock + distance * 9.5, TAU)
    _visual.position.y = 0.0
    var ease := 1.0 - exp(-delta * 9.0)
    _cloth_sway = lerpf(_cloth_sway, sin(_step_clock - 0.65) * 0.019 * _gait_blend, 1.0 - exp(-delta * 3.6))
    if is_instance_valid(_robe_pivot):
        _robe_pivot.rotation.y = _robe_rest.y + _cloth_sway
        _robe_pivot.rotation.x = _robe_rest.x + sin(_animation_time * 1.7) * 0.004 + cos(_step_clock * 2.0 - 0.5) * 0.008 * _gait_blend
    if _head != null and _head != _parts.get("model"):
        var scan := sin(_animation_time * 0.73) * 0.19 * (1.0 - _gait_blend)
        if _has_joint_rig:
            var head_yaw := scan
            var head_pitch := 0.035 + sin(_animation_time * 1.7) * 0.018
            if _ambient_pose == "prayer":
                head_pitch = lerpf(head_pitch, -0.19, _pose_mix)
                head_yaw *= 1.0 - _pose_mix
            elif _ambient_pose == "look_around":
                head_yaw += sin(_pose_time * 1.1) * 0.32 * _pose_mix
            elif _ambient_pose == "adjust_robe":
                head_pitch -= 0.10 * _pose_mix
            _head.rotation.z = lerp_angle(_head.rotation.z, head_yaw, ease)
            _head.rotation.x = lerpf(_head.rotation.x, head_pitch, ease)
        else:
            _head.rotation.y = lerp_angle(_head.rotation.y, scan, ease)
    for limb_name in ["leftArm", "rightArm", "leftLeg", "rightLeg", "leftShin", "rightShin", "leftFoot", "rightFoot"]:
        if not _parts.has(limb_name) or not is_instance_valid(_parts[limb_name]):
            continue
        var limb := _parts[limb_name] as Node3D
        var phase := _step_clock + (PI if limb_name.begins_with("right") else 0.0)
        var base: Vector3 = _base_pose.get(limb_name, Vector3.ZERO)
        var bend := 0.0
        if limb_name.ends_with("Arm"):
            bend = -sin(phase - 0.32) * 0.17 * _gait_blend + sin(_animation_time * 1.6) * 0.014
            var sleeve_angle := cos(phase - 0.45) * 0.025 * _gait_blend
            if _has_joint_rig:
                var side_sign := -1.0 if limb_name.begins_with("left") else 1.0
                if _ambient_pose == "prayer":
                    bend -= 0.27 * _pose_mix
                    sleeve_angle -= side_sign * 0.15 * _pose_mix
                elif _ambient_pose == "adjust_robe":
                    bend -= (0.13 + 0.065 * sin(_pose_time * 2.2 + phase)) * _pose_mix
                    sleeve_angle -= side_sign * 0.09 * _pose_mix
                elif _ambient_pose == "rest":
                    sleeve_angle += side_sign * 0.025 * _pose_mix
            limb.rotation.y = lerpf(limb.rotation.y, base.y + sleeve_angle, ease)
        elif limb_name.ends_with("Leg"):
            bend = sin(phase) * 0.28 * _gait_blend
        elif limb_name.ends_with("Shin"):
            bend = maxf(0.0, -sin(phase)) * 0.36 * _gait_blend
        elif limb_name.ends_with("Foot"):
            bend = (-sin(phase) * 0.28 - maxf(0.0, -sin(phase)) * 0.36) * _gait_blend
        limb.rotation.x = lerpf(limb.rotation.x, base.x + bend, ease)
