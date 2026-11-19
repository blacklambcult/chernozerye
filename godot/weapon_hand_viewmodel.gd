extends Node3D
# Shared first-person right hand for the legacy revolver and Forge assets.
# Camera-only stylized game geometry, never used as collision.
const SLEEVE := Color("#545849")
const SLEEVE_SHADE := Color("#3c4239")
const CUFF := Color("#393d36")
const SKIN := Color("#a18a7c")
const SKIN_SHADE := Color("#847065")

# Where the rendered prop's primary hand marker sits in its camera-local root.
var grip_local := Vector3.ZERO

func _material(tint: Color) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.roughness = 0.94
    material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.no_depth_test = true
    material.render_priority = -1
    return material

func _segment(label: String, start: Vector3, finish: Vector3,
        radius: float, end_radius: float, tint: Color) -> void:
    var length := start.distance_to(finish)
    if length < 0.001:
        return
    var mesh := CylinderMesh.new()
    mesh.radial_segments = 6
    mesh.rings = 0
    mesh.height = length
    mesh.bottom_radius = radius
    mesh.top_radius = end_radius
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = _material(tint)
    instance.position = (start + finish) * 0.5
    instance.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
    add_child(instance)

func _ready() -> void:
    name = "WeaponRightHand"
    var grip := grip_local
    var wrist := grip + Vector3(0.052, -0.062, 0.071)
    var cuff := grip + Vector3(0.087, -0.130, 0.136)
    var elbow := grip + Vector3(0.215, -0.385, 0.285)
    var upper := grip + Vector3(0.275, -0.555, 0.410)
    _segment("Sleeve", upper, elbow, 0.095, 0.076, SLEEVE)
    _segment("Forearm", elbow, cuff, 0.082, 0.060, SLEEVE_SHADE)
    _segment("Cuff", cuff + Vector3(0.013, -0.020, 0.026),
        cuff + Vector3(-0.015, 0.022, -0.018), 0.072, 0.068, CUFF)
    _segment("Palm", wrist, grip + Vector3(0.005, -0.023, 0.013),
        0.058, 0.045, SKIN)
    _segment("Thumb", wrist + Vector3(-0.043, 0.008, -0.017),
        grip + Vector3(-0.045, -0.012, -0.063), 0.025, 0.018, SKIN)
    # Four short polygonal fingers sit along the lower edge of the grip.
    for i in range(4):
        var x := (float(i) - 1.5) * 0.023
        _segment("Finger%d" % i, grip + Vector3(x, -0.018, 0.028),
            grip + Vector3(x - 0.008, -0.084, -0.028),
            0.016, 0.012, SKIN_SHADE)
