extends SceneTree
# Physics regression independent of the large village build. Verifies that
# procedural walls and fences are solid but intentional gate gaps stay open.

func _fail(reason: String) -> void:
    push_error("COLLISION_REGRESSION_FAILED: " + reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _ray(origin: Vector3, destination: Vector3) -> Dictionary:
    var params := PhysicsRayQueryParameters3D.create(origin, destination)
    params.collision_mask = 1
    return get_root().get_world_3d().direct_space_state.intersect_ray(params)

func _run() -> void:
    var art := Node3D.new()
    art.name = "CollisionHarness"
    art.set_script(load("res://manual_art.gd"))
    get_root().add_child(art)
    var polygon := PackedVector2Array([
        Vector2(0.0, 0.0), Vector2(4.0, 0.0),
        Vector2(4.0, 4.0), Vector2(0.0, 4.0)
    ])
    art.call("_register_building_collider", polygon, 3.8)
    art.call("_register_fence_collider", Vector2(8, 0), Vector2(8, 4))
    art.call("_build_collision_bodies")
    var building := art.get_node_or_null("CollisionBuildings") as StaticBody3D
    var fence := art.get_node_or_null("CollisionFences") as StaticBody3D
    if building == null or fence == null:
        _fail("solid collision bodies were not built")
        return
    if int(art.get("_collision_building_count")) != 1:
        _fail("building count mismatch")
        return
    if int(art.get("_collision_fence_span_count")) != 1:
        _fail("fence count mismatch")
        return
    await physics_frame
    await physics_frame
    var house_hit := _ray(Vector3(2, 1.4, 2), Vector3(2, 1.4, -2))
    if house_hit.is_empty() or house_hit.get("collider") != building:
        _fail("building wall can be walked through")
        return
    var fence_hit := _ray(Vector3(6, 1.0, -2), Vector3(10, 1.0, -2))
    if fence_hit.is_empty() or fence_hit.get("collider") != fence:
        _fail("fence allows walking through visible rails")
        return
    var clear_passage := _ray(Vector3(6, 1.0, -8), Vector3(10, 1.0, -8))
    if not clear_passage.is_empty():
        _fail("unbuilt gate opening is blocked by invisible collision")
        return
    # Cosmetic action is separate from movement and has no health benefits.
    var actor := CharacterBody3D.new()
    actor.name = "PlayerCosmeticHarness"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    # Raycasts can pass while a CharacterBody's actual capsule still clips
    # through a wall. Exercise the same player shape used in the browser.
    actor.set_physics_process(false)
    # World camera configuration locates these nodes by name, not by class.
    if actor.get_node_or_null("Camera3D") == null:
        _fail("camera must have stable name for near-plane correction")
        return
    if actor.get_node_or_null("CollisionShape3D") == null:
        _fail("capsule must have stable name for clipping guard")
        return
    var capsule: CapsuleShape3D = null
    for child in actor.get_children():
        if child is CollisionShape3D:
            capsule = (child as CollisionShape3D).shape as CapsuleShape3D
            break
    if capsule == null or capsule.radius < 0.44:
        _fail("first-person capsule is too narrow to protect the camera")
        return
    actor.global_position = Vector3(2.0, 0.2, 1.5)
    await physics_frame
    if not actor.test_move(actor.global_transform, Vector3(0.0, 0.0, -3.0)):
        _fail("actual player capsule passes through building wall")
        return
    actor.global_position = Vector3(6.0, 0.2, -8.0)
    await physics_frame
    if actor.test_move(actor.global_transform, Vector3(4.0, 0.0, 0.0)):
        _fail("actual player capsule blocked by invisible gate obstacle")
        return
    var avatar := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if avatar == null:
        _fail("full-body first-person avatar missing")
        return
    var pelvis := avatar.get_node_or_null("PelvisRoot") as Node3D
    if pelvis == null:
        _fail("single pelvis root missing")
        return
    var left_leg := pelvis.get_node_or_null("LeftLeg") as Node3D
    var right_leg := pelvis.get_node_or_null("RightLeg") as Node3D
    var jacket := pelvis.get_node_or_null("LowerJacket") as MeshInstance3D
    var upper := pelvis.get_node_or_null("ChestAndShoulders") as MeshInstance3D
    if left_leg == null or right_leg == null or jacket == null or upper == null:
        _fail("coat and two legs must share same pelvis")
        return
    if not (jacket.mesh is ArrayMesh) or not (upper.mesh is ArrayMesh):
        _fail("jacket should use camera-clear vertical fabric panels")
        return
    if (jacket.mesh as ArrayMesh).get_surface_count() != 1:
        _fail("lower jacket panels were not generated")
        return
    if (upper.mesh as ArrayMesh).get_surface_count() != 1:
        _fail("upper coat panels were not generated")
        return
    if absf(left_leg.position.x + right_leg.position.x) > 0.001:
        _fail("leg placement is not symmetric")
        return
    if absf(jacket.position.z - left_leg.position.z) > 0.09:
        _fail("waist and legs use mismatched depth anchors")
        return
    if absf(left_leg.position.z) > 0.04 or absf(right_leg.position.z) > 0.04:
        _fail("hips are offset forward or backward from torso")
        return
    var left_knee := left_leg.get_node_or_null("KneeJoint/KneeFabric") as MeshInstance3D
    var right_knee := right_leg.get_node_or_null("KneeJoint/KneeFabric") as MeshInstance3D
    var left_calf := left_leg.get_node_or_null("KneeJoint/TrouserCalf") as MeshInstance3D
    var toe := left_leg.get_node_or_null("KneeJoint/AnkleJoint/BootToe") as MeshInstance3D
    if left_knee == null or right_knee == null or left_calf == null or toe == null:
        _fail("articulated thigh-knee-calf-ankle-boot geometry must remain")
        return
    var left_knee_position := pelvis.to_local(left_knee.global_position)
    var right_knee_position := pelvis.to_local(right_knee.global_position)
    var calf_position := pelvis.to_local(left_calf.global_position)
    var toe_position := pelvis.to_local(toe.global_position)
    if absf(left_knee_position.z - left_leg.position.z) > 0.06:
        _fail("resting knees protrude too far in front of hips")
        return
    if absf(calf_position.z - left_knee_position.z) > 0.09:
        _fail("resting calf leans too far away from knee")
        return
    if toe_position.z < -0.20 or toe_position.z > -0.025:
        _fail("boot toe has incorrect depth beneath the pelvis")
        return
    if absf(left_knee_position.x + right_knee_position.x) > 0.001:
        _fail("knees are asymmetric beneath hips")
        return
    var camera := actor.get_node("Camera3D") as Camera3D
    var max_coat_y := pelvis.position.y + 0.448
    if max_coat_y > camera.position.y - 0.20:
        _fail("torso occupies player eye height")
        return
    camera.rotation.x = -1.45
    # Allow the view-dependent first-person pose to settle before checking it.
    for frame in range(30):
        avatar.call("_process",0.016)
    # Procedural rig remains in memory for the scripted gestures and
    # old collision checks, but is not rendered in the actual FPS scene.
    if avatar.visible:
        _fail("old procedural coat still renders over GLB cutaway")
        return
    var imported_legs := actor.get_node_or_null("ModeledCharacter") as Node3D
    if imported_legs == null or not bool(imported_legs.get("model_loaded")):
        _fail("imported feet unavailable while looking down")
        return
    var fps_asset := imported_legs.get("first_person_body") as Node3D
    if not imported_legs.visible or fps_asset == null or not fps_asset.visible:
        _fail("standalone FPS body not active")
        return
    if fps_asset.find_child("FPTorsoShell",true,false) != null or fps_asset.find_child("FPPelvis",true,false) == null:
        _fail("camera-blocking torso remains or pelvis missing")
        return
    if not (pelvis.get_node("LeftArm") as Node3D).visible:
        _fail("side-hanging arms are hidden at downward pitch")
        return
    var boot := left_leg.get_node_or_null("KneeJoint/AnkleJoint/BootToe") as MeshInstance3D
    if boot == null:
        _fail("forward-facing boot toe is missing")
        return
    # A screen-space proxy: at extreme downward pitch the boots should
    # project visibly ABOVE the abdomen, as in the reference images.
    var foot_camera := camera.to_local(boot.global_position)
    var abdomen_camera := camera.to_local(pelvis.to_global(Vector3(0, 0.32, 0.11)))
    if foot_camera.z >= -0.22 or abdomen_camera.z >= -0.22:
        _fail("body reference points are behind the near camera plane")
        return
    var boot_vertical := foot_camera.y / -foot_camera.z
    var abdomen_vertical := abdomen_camera.y / -abdomen_camera.z
    if boot_vertical < abdomen_vertical + 0.25:
        _fail("boots do not project above the jacket at downward pitch")
        return
    camera.rotation.x = 0.0
    avatar.call("_process",0.016)
    if actor.call("_movement_speed",false) > 3.6:
        _fail("slow exploration pace lost")
        return

    var layer := CanvasLayer.new()
    layer.name = "GameplayHUD"
    get_root().add_child(layer)
    var hud := Control.new()
    hud.name = "SurvivalHUD"
    hud.set_script(load("res://gameplay_hud.gd"))
    layer.add_child(hud)
    hud.set("player",actor)
    if int(hud.get("current_health")) != 100:
        _fail("health placeholder changed")
        return
    if str(hud.call("_compass_name",90)) != "E":
        _fail("compass no longer maps direction")
        return

    var sequence := actor.get_node_or_null("Camera3D/CharacterSmoking") as Node3D
    if sequence == null:
        _fail("independent cinematic state machine missing")
        return
    hud.call("choose_slot",1)
    if actor.call("_start_character_sequence"):
        _fail("V works without inventory item selected")
        return
    hud.call("choose_slot",0)
    if not actor.call("_start_character_sequence"):
        _fail("selected item cannot start character sequence")
        return
    if actor.call("_start_character_sequence"):
        _fail("repeat activation restarted the animation")
        return
    if int(sequence.get("phase")) != 1:
        _fail("cinematic sequence did not enter initial stage")
        return
    sequence.call("_advance",3.03)
    if int(sequence.get("phase")) != 5:
        _fail("sequence did not reach automatic ambient state")
        return
    var face_prop := sequence.get("mouth_prop") as Node3D
    if not face_prop.visible:
        _fail("mouth-edge visual absent during ambient state")
        return
    if absf(face_prop.position.x) > 0.05 or face_prop.position.z < -0.19:
        _fail("ambient prop drifts into center screen instead of lip edge")
        return
    if face_prop.rotation_degrees.x > -55.0:
        _fail("ambient prop does not point forward from the face")
        return
    camera.rotation.x = -1.40
    sequence.call("_render_phase")
    if face_prop.visible:
        _fail("mouth prop floats over the torso while looking down")
        return
    camera.rotation.x = 0.0
    sequence.call("_render_phase")
    if not face_prop.visible:
        _fail("mouth prop not restored when returning to level view")
        return
    if (sequence.get("gesture") as Node3D).visible:
        _fail("gesture remains on screen during two-minute ambient state")
        return
    sequence.call("_advance",60.0)
    if absf(float(sequence.get("burn_elapsed")) - 60.0) > 0.2:
        _fail("two-minute real-time progress broken")
        return
    var paper := sequence.get("mouth_paper") as Node3D
    if paper.scale.y >= 0.8:
        _fail("ambient visual does not gradually shorten")
        return
    sequence.call("_advance",60.0)
    if int(sequence.get("phase")) != 6:
        _fail("two-minute state failed to finish")
        return
    sequence.call("_advance",1.5)
    if int(sequence.get("phase")) != 0 or int(sequence.get("completed_cycles")) != 1:
        _fail("automatic end state did not complete")
        return
    avatar.call("_process",0.016)
    if (pelvis.get_node("RightArm") as Node3D).visible:
        _fail("world-space right arm overlaps with the camera viewmodel at level gaze")
        return
    var fps_rig := actor.get_node_or_null("Camera3D/FPSViewmodel") as Node3D
    if fps_rig == null:
        _fail("camera-space arms missing after cinematic")
        return
    fps_rig.call("_process",0.016)
    if not fps_rig.visible:
        _fail("viewmodel arms failed to restore after cinematic")
        return
    if get_nodes_in_group("DiscardedScenicProps").is_empty():
        _fail("automatic final ground prop missing")
        return
    if int(hud.get("current_health")) != 100:
        _fail("cosmetic character sequence changed game health")
        return
    print("COLLISION_REGRESSION_OK: house=solid fence=solid gap=open capsule=blocked")
    print("FIRST_PERSON_HUD_REGRESSION_OK: torso=visible_looking_down legs=2 jacket=front_panels compass=NESW health=100 slots=4 boots_project_above_waist=true arms=visible legs_upright=true")
    print("CHARACTER_SEQUENCE_REGRESSION_OK: selected_slot=required staged=true burn_seconds=120 hands_clear=true auto_discard=true no_buffs=true face_occluded_lookdown=true")
    quit(0)
