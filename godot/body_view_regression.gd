extends SceneTree
# Actual perspective checks at maximum downward pitch: a visible flag alone
# does not mean trousers and boots appear on screen or above the terrain.

func _fail(message: String) -> void:
    push_error("BODY_VIEW_REGRESSION_FAILED: " + message)
    quit(1)


func _projected_height(eye: Camera3D, world_point: Vector3) -> float:
    var local := eye.to_local(world_point)
    if local.z >= -eye.near:
        return -100.0
    return local.y / -local.z


func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var eye := actor.get_node("Camera3D") as Camera3D
    var rig := actor.get_node("FirstPersonFullBody") as Node3D
    var pelvis := rig.get_node("PelvisRoot") as Node3D
    var left := pelvis.get_node("LeftLeg") as Node3D
    var right := pelvis.get_node("RightLeg") as Node3D
    var left_knee := left.get_node("KneeJoint") as Node3D
    var right_knee := right.get_node("KneeJoint") as Node3D
    var left_toe := left.get_node("KneeJoint/AnkleJoint/BootToe") as MeshInstance3D
    var right_toe := right.get_node("KneeJoint/AnkleJoint/BootToe") as MeshInstance3D
    var left_sole := left.get_node("KneeJoint/AnkleJoint/BootSole") as MeshInstance3D

    # Below-ground boot geometry is invisible in the actual world.
    var sole_floor := actor.to_local(left_sole.global_position).y - (left_sole.mesh as BoxMesh).size.y * 0.5
    if sole_floor < 0.005:
        _fail("boot sole is buried below ground plane")
        return
    eye.rotation.x = -1.45
    for frame in range(30):
        rig.call("_process", 0.016)

    # Compare against the REAL coat waist seam, not an arbitrary high
    # abdomen reference. Screen vertical is proportional to y / -z.
    var jacket_seam := pelvis.to_global(Vector3(0.0, 0.120, -0.018))
    var seam_height := _projected_height(eye, jacket_seam)
    var left_toe_height := _projected_height(eye, left_toe.global_position)
    var right_toe_height := _projected_height(eye, right_toe.global_position)
    if left_toe_height < seam_height + 0.13 or right_toe_height < seam_height + 0.13:
        _fail("both boot toes must project visibly above the coat waist")
        return
    if _projected_height(eye, left_knee.global_position) < seam_height + 0.035:
        _fail("knees remain obscured by the coat in the look-down pose")
        return
    var a := eye.to_local(left_toe.global_position)
    var b := eye.to_local(right_toe.global_position)
    if absf(a.x / -a.z - b.x / -b.z) < 0.14:
        _fail("the two boots overlap into a single silhouette")
        return

    eye.rotation.x = 0.0
    for frame in range(30):
        rig.call("_process", 0.016)
    if absf(left_knee.position.z - 0.014) > 0.01 or absf(right_knee.position.z - 0.014) > 0.01:
        _fail("knees remain pushed forward in normal forward view")
        return
    print("BODY_VIEW_REGRESSION_OK: soles_above_ground=true knees_visible=true two_boots_distinct=true coat_clearance=true upright_restored=true")
    quit(0)


func _initialize() -> void:
    call_deferred("_run")
