extends SceneTree
# Body-space pose regression. This is independent of rendering and floor physics;
# it checks rig proportions and the idle/walk gait directly in headless Godot.

func _fail(message: String) -> void:
    push_error("BODY_GAIT_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var body := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if body == null:
        _fail("first-person rig missing")
        return
    var pelvis := body.get_node("PelvisRoot") as Node3D
    var left := pelvis.get_node("LeftLeg") as Node3D
    var right := pelvis.get_node("RightLeg") as Node3D
    var left_knee := left.get_node("KneeJoint") as Node3D
    var right_knee := right.get_node("KneeJoint") as Node3D
    var left_ankle := left.get_node("KneeJoint/AnkleJoint") as Node3D
    var right_ankle := right.get_node("KneeJoint/AnkleJoint") as Node3D
    var toe := left.get_node("KneeJoint/AnkleJoint/BootToe") as MeshInstance3D
    var toe_rest := pelvis.to_local(toe.global_position)
    if toe_rest.z < -0.20 or toe_rest.z > -0.025:
        _fail("boot projects too far ahead of standing body")
        return
    if absf(left.position.x + right.position.x) > 0.001:
        _fail("hip spacing is asymmetric")
        return
    body.call("_update_gait", 0.21, 3.35)
    if absf(left.rotation.x) < 0.06 or absf(left.rotation.x + right.rotation.x) > 0.01:
        _fail("hips do not alternate through the stride")
        return
    if left_knee.rotation.x > -0.04 or absf(right_knee.rotation.x) > 0.02:
        _fail("forward leg knee does not flex independently")
        return
    if absf(left_ankle.rotation.x + left.rotation.x + left_knee.rotation.x) > 0.07:
        _fail("forward boot fails to counter-rotate")
        return
    for i in range(24):
        body.call("_update_gait", 0.1, 0.0)
    if absf(left.rotation.x) > 0.02 or absf(right.rotation.x) > 0.02:
        _fail("legs do not settle when standing still")
        return
    if absf(left_knee.rotation.x) > 0.02 or absf(right_knee.rotation.x) > 0.02:
        _fail("knees remain bent after stopping")
        return
    if absf(left_ankle.rotation.x) > 0.02 or absf(right_ankle.rotation.x) > 0.02:
        _fail("boots remain tilted after stopping")
        return
    print("BODY_GAIT_REGRESSION_OK: upright_rest=true alternating_stride=true independent_knees=true level_boots=true idle_reset=true")
    quit(0)
