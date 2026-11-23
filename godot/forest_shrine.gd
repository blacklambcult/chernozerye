extends StaticBody3D

var _health := 90.0
var _active_model: Node3D
var _ruins: PackedScene
var _collision: CollisionShape3D
var _light: OmniLight3D


func install(active: PackedScene, ruins: PackedScene, color: Color) -> void:
    _ruins = ruins
    set_meta("impact_surface", &"stone")
    _active_model = active.instantiate() as Node3D
    add_child(_active_model)
    var bounds := AABB()
    for mesh: MeshInstance3D in _active_model.find_children("*", "MeshInstance3D", true, false):
        var local := global_transform.affine_inverse() * mesh.global_transform
        var mesh_bounds: AABB = local * mesh.get_aabb()
        bounds = mesh_bounds if bounds.size == Vector3.ZERO else bounds.merge(mesh_bounds)
    var shape := BoxShape3D.new()
    shape.size = bounds.size.max(Vector3(0.8, 1.0, 0.8))
    _collision = CollisionShape3D.new()
    _collision.shape = shape
    _collision.position = bounds.get_center()
    add_child(_collision)
    _light = OmniLight3D.new()
    _light.position = Vector3(0.0, 1.35, 0.0)
    _light.light_color = color
    _light.light_energy = 0.65
    _light.omni_range = 7.0
    add_child(_light)
    var players := _active_model.find_children("*", "AnimationPlayer", true, false)
    if not players.is_empty():
        var player := players[0] as AnimationPlayer
        if player.has_animation("Ritual_Idle"):
            player.get_animation("Ritual_Idle").loop_mode = Animation.LOOP_LINEAR
            player.play("Ritual_Idle")


func apply_damage(amount: float) -> void:
    if _health <= 0.0 or amount <= 0.0:
        return
    _health -= amount
    if _health > 0.0:
        return
    _active_model.hide()
    _active_model.queue_free()
    _light.hide()
    _collision.set_deferred("disabled", true)
    add_child(_ruins.instantiate())
