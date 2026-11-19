extends Node3D
# Camera-space prop and arcade interaction with the first solid world surface.
const REST := Vector3(0.23, -0.19, -0.53)
const CAPACITY := 6
var rounds := CAPACITY
var cooldown := 0.0
var reload_left := 0.0
var pending := false
var eye: Camera3D
var player: CharacterBody3D
var flash := OmniLight3D.new()
var report := AudioStreamPlayer.new()
var marks: Array[MeshInstance3D] = []
var cylinder: MeshInstance3D

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
    for i in range(3):
        _tube(Vector3(-0.02,-0.038-i*0.015,0.01),Vector3(0.031,-0.038-i*0.015,-0.004),0.009,0.012,Color("#846555"))
    flash.position = Vector3(0,0.05,-0.4)
    flash.light_color = Color("#ffa354")
    flash.omni_range = 5.0
    flash.visible = false
    add_child(flash)
    report.stream = preload("res://revolver_report.wav")
    report.volume_db = -9.0
    add_child(report)

func equip(value: bool) -> void:
    visible = value
    if not value:
        pending = false
        reload_left = 0.0
        flash.visible = false

func request_shot() -> void:
    if visible and rounds > 0 and cooldown <= 0 and reload_left <= 0:
        pending = true

func reload() -> void:
    if visible and rounds < CAPACITY and reload_left <= 0:
        pending = false
        reload_left = 0.95

func _physics_process(delta: float) -> void:
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
    position = REST + Vector3(0, -0.13 * sin(PI * reload_left / 0.95), kick * 0.045)
    rotation = Vector3(kick * 0.28,0.19,-0.46 * sin(PI * reload_left / 0.95))
    flash.visible = cooldown > 0.19

func _shoot() -> void:
    rounds -= 1
    cooldown = 0.24
    cylinder.rotate_object_local(Vector3.UP, PI / 3)
    flash.light_energy = 3.6
    report.play()
    var start := eye.global_position
    var ray := PhysicsRayQueryParameters3D.create(start, start - eye.global_basis.z * 90, 0xffffffff, [player.get_rid()])
    var hit := eye.get_world_3d().direct_space_state.intersect_ray(ray)
    if hit.is_empty():
        return
    if hit.collider.is_in_group("breakable_pottery"):
        hit.collider.queue_free()
        return
    var mark := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.radial_segments = 7
    mesh.top_radius = 0.035
    mesh.bottom_radius = 0.04
    mesh.height = 0.006
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#211913")
    mesh.material = material
    mark.mesh = mesh
    mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    hit.collider.add_child(mark)
    var normal: Vector3 = hit.normal
    mark.global_position = hit.position + normal * 0.005
    mark.global_basis = Basis(Quaternion(Vector3.UP, normal))
    marks.append(mark)
    if marks.size() > 32:
        var oldest := marks.pop_front() as MeshInstance3D
        if is_instance_valid(oldest):
            oldest.queue_free()
