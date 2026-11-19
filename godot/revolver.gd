extends Node3D
# Camera-space prop and arcade interaction with the first solid world surface.
const REST := Vector3(0.23, -0.19, -0.53)
const CAPACITY := 6
# Compatibility sounds keep the current online build functional until the
# project's supplied OGG assets are imported to res://audio/.
const SHOT_STREAM := preload("res://revolver_report.wav")
const COCK_STREAM := preload("res://impacts/metal.wav")
const CYLINDER_STREAM := preload("res://impacts/wood.wav")
const RELOAD_SECONDS := 1.55
var indoors := false
var rounds := CAPACITY
var cooldown := 0.0
var reload_left := 0.0
var bloom := 0.0
var pending := false
var cocked := false
var last_action := "idle"
var eye: Camera3D
var player: CharacterBody3D
var flash := OmniLight3D.new()
var report := AudioStreamPlayer.new()
var cock_audio := AudioStreamPlayer.new()
var cylinder_audio := AudioStreamPlayer.new()
var marks: Array[MeshInstance3D] = []
var impact_sounds := {
    &"soil": preload("res://impacts/soil.wav"),
    &"wood": preload("res://impacts/wood.wav"),
    &"metal": preload("res://impacts/metal.wav")
}
var cylinder: MeshInstance3D
var weapon_hand: Node3D

func _part(mesh: PrimitiveMesh, at: Vector3, tint: Color) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 0.64
    part.mesh = mesh
    part.material_override = mat
    part.position = at
    add_child(part)
    return part

func _tube(a: Vector3, b: Vector3, r1: float, r2: float, tint: Color) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.radial_segments = 8
    mesh.rings = 0
    mesh.height = a.distance_to(b)
    mesh.bottom_radius = r1
    mesh.top_radius = r2
    var part := _part(mesh, (a + b) / 2.0, tint)
    part.quaternion = Quaternion(Vector3.UP, a.direction_to(b))
    return part

func _bar(at: Vector3, size: Vector3, tint: Color) -> void:
    var mesh := BoxMesh.new()
    mesh.size = size
    _part(mesh, at, tint)

func _ready() -> void:
    eye = get_parent() as Camera3D
    player = eye.get_parent() as CharacterBody3D
    position = REST
    visible = false
    var steel := Color("#707781")
    var iron := Color("#37383d")
    _tube(Vector3(0,-0.08,0.055), Vector3(0,0,0), 0.032,0.024,Color("#69432c"))
    _tube(Vector3(0,-0.014,0.035),Vector3(0,-0.014,-0.16),0.034,0.031,iron)
    cylinder = _tube(Vector3(0,0.02,0),Vector3(0,0.02,-0.095),0.048,0.048,steel)
    _bar(Vector3(0,0.069,-0.055), Vector3(0.052,0.014,0.135),iron)
    _tube(Vector3(0,0.048,-0.11),Vector3(0,0.048,-0.39),0.025,0.021,steel)
    _tube(Vector3(0,0.019,-0.13),Vector3(0,0.019,-0.345),0.011,0.009,iron)
    _bar(Vector3(0,0.072,-0.365),Vector3(0.009,0.016,0.029), iron)
    _tube(Vector3(0,0.02,0.012),Vector3(0,0.064,0.047),0.015,0.009,iron)
    _tube(Vector3(0.12,-0.24,0.18),Vector3(0.025,-0.09,0.065),0.071,0.05,Color("#525447"))
    _tube(Vector3(0.026,-0.09,0.065),Vector3(0.016,-0.047,0.009),0.048,0.04,Color("#967866"))
    weapon_hand = Node3D.new()
    weapon_hand.set_script(preload("res://weapon_hand_viewmodel.gd"))
    weapon_hand.name = "WeaponRightHand"
    weapon_hand.set("grip_local", Vector3(0.075, -0.14, 0.12))
    add_child(weapon_hand)
    for i in range(3):
        _tube(Vector3(-0.02,-0.038-i*0.015,0.01),Vector3(0.031,-0.038-i*0.015,-0.004),0.009,0.012,Color("#846555"))
    flash.position = Vector3(0,0.05,-0.4)
    flash.light_color = Color("#ffa354")
    flash.omni_range = 5.0
    flash.visible = false
    add_child(flash)
    report.bus = &"Effects"
    report.stream = load("res://audio/revolver_shot.ogg") if ResourceLoader.exists("res://audio/revolver_shot.ogg") else SHOT_STREAM
    report.max_polyphony = 3
    report.volume_db = -3.0
    add_child(report)
    cock_audio.stream = load("res://audio/revolver_cock.ogg") if ResourceLoader.exists("res://audio/revolver_cock.ogg") else COCK_STREAM
    cock_audio.bus = &"Effects"
    cock_audio.volume_db = -5.0
    add_child(cock_audio)
    cylinder_audio.stream = load("res://audio/revolver_cylinder.ogg") if ResourceLoader.exists("res://audio/revolver_cylinder.ogg") else CYLINDER_STREAM
    cylinder_audio.bus = &"Effects"
    cylinder_audio.volume_db = -8.0
    add_child(cylinder_audio)

func equip(value: bool) -> void:
    visible = value
    if not value:
        pending = false
        cocked = false
        reload_left = 0.0
        flash.visible = false
        last_action = "holstered"

func request_shot() -> void:
    if not visible or rounds <= 0 or cooldown > 0.0 or reload_left > 0.0:
        return
    if not cocked:
        # Alternating game inputs: first click raises the hammer, second fires.
        cocked = true
        last_action = "cock"
        cock_audio.pitch_scale = randf_range(0.98, 1.02)
        cock_audio.play()
    else:
        cocked = false
        last_action = "fire"
        pending = true

func reload() -> void:
    if visible and rounds < CAPACITY and reload_left <= 0:
        pending = false
        cocked = false
        last_action = "reload"
        reload_left = RELOAD_SECONDS
        cylinder_audio.pitch_scale = 1.0
        cylinder_audio.play()

func _physics_process(delta: float) -> void:
    bloom = move_toward(bloom, 0.0, delta * 1.9)
    cooldown = maxf(0, cooldown - delta)
    if not visible:
        return
    if reload_left > 0:
        reload_left = maxf(0, reload_left - delta)
        if reload_left == 0:
            rounds = CAPACITY
    if pending:
        pending = false
        if not player.get("controls_locked") and eye.current and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
            _shoot()
    var kick := maxf(0, cooldown - 0.12) / 0.12
    var reload_t := sin(PI * reload_left / RELOAD_SECONDS)
    position = REST + Vector3(0, -0.13 * reload_t + (0.012 if cocked else 0.0), kick * 0.045)
    rotation = Vector3(kick * 0.28 + (0.045 if cocked else 0.0), 0.19, -0.46 * reload_t)
    flash.visible = cooldown > 0.19

func spread_angle() -> float:
    var speed := Vector2(player.velocity.x, player.velocity.z).length()
    return deg_to_rad(0.32 + minf(speed * 0.31, 1.8) + bloom)

func _shot_direction() -> Vector3:
    var angle := randf() * TAU
    var radius := sqrt(randf()) * tan(spread_angle())
    return (eye.global_basis * Vector3(cos(angle)*radius, sin(angle)*radius, -1)).normalized()

func _shoot() -> void:
    if rounds <= 0:
        return
    pending = false
    cocked = false
    last_action = "fire"
    rounds -= 1
    cooldown = 0.24
    cylinder.rotate_object_local(Vector3.UP, PI / 3)
    flash.light_energy = 3.6
    report.volume_db = -8.0 if indoors else -3.0
    report.pitch_scale = randf_range(0.97, 1.03)
    report.play()
    player.call("emit_noise", 1.0)
    var start := eye.global_position
    var direction := _shot_direction()
    bloom = minf(2.5, bloom + 1.05)
    player.call("kick_view")
    var ray := PhysicsRayQueryParameters3D.create(start, start + direction * 90, 0xffffffff, [player.get_rid()])
    var hit := eye.get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty():
        return
    if hit.collider.is_in_group("breakable_pottery"):
        hit.collider.queue_free()
        return
    _surface_feedback(hit)

func _surface_feedback(hit: Dictionary) -> void:
    var body := hit.collider as Node3D
    var surface: StringName = body.get_meta("impact_surface", &"solid")
    var mark := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.radial_segments = 7
    mesh.top_radius = 0.035
    mesh.bottom_radius = 0.04
    mesh.height = 0.006
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#211913")
    match surface:
        &"wood":
            material.albedo_color = Color("#ac8055")
            mesh.top_radius = 0.045
        &"metal":
            material.albedo_color = Color("#b4bfbd")
            mesh.top_radius = 0.032
        &"soil":
            material.albedo_color = Color("#503727")
            mesh.top_radius = 0.082
            mesh.bottom_radius = 0.09
    mesh.material = material
    mark.mesh = mesh
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    hit.collider.add_child(mark)
    var normal: Vector3 = hit.normal
    mark.global_position = hit.position + normal * 0.005
    mark.global_basis = Basis(Quaternion(Vector3.UP, normal))
    if surface == &"wood":
        mark.scale = Vector3(0.62, 1.0, 1.9)
        # Raised log relief projects just past the building collision hull.
        if body.name == &"CollisionTimberBuildings":
            mark.global_position += normal * 0.023
    if impact_sounds.has(surface):
        var sound := AudioStreamPlayer3D.new()
        sound.bus = &"Effects"
        sound.stream = impact_sounds[surface]
        sound.unit_size = 9.0
        sound.volume_db = -4.0
        sound.pitch_scale = randf_range(0.92, 1.07)
        mark.add_child(sound)
        sound.finished.connect(sound.queue_free)
        sound.play()
    marks.append(mark)
    if marks.size() > 32:
        var oldest := marks.pop_front() as MeshInstance3D
        if is_instance_valid(oldest):
            oldest.queue_free()
