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
    var smoke := actor.get("_smoke_particles") as CPUParticles3D
    if smoke == null or smoke.mesh == null:
        _fail("adult character cosmetic effect missing")
        return
    var smoke_quad := smoke.mesh as QuadMesh
    if smoke_quad == null or smoke_quad.size.x > 0.05:
        _fail("cosmetic particles still cover too much of first-person view")
        return
    var avatar := actor.get_node_or_null("FirstPersonFullBody") as Node3D
    if avatar == null:
        _fail("full-body first-person avatar missing")
        return
    var pelvis := avatar.get_node_or_null("PelvisRoot") as Node3D
    if pelvis == null or pelvis.get_parent() != avatar:
        _fail("one common pelvis root must drive torso and legs")
        return
    var left_leg := pelvis.get_node_or_null("LeftLeg") as Node3D
    var right_leg := pelvis.get_node_or_null("RightLeg") as Node3D
    if left_leg == null or right_leg == null:
        _fail("both legs must be attached to the shared pelvis")
        return
    if pelvis.get_node_or_null("LeftArm") == null or pelvis.get_node_or_null("RightArm") == null:
        _fail("both arms must follow the shared body root")
        return
    if absf(left_leg.position.x + right_leg.position.x) > 0.001:
        _fail("hips should be symmetrical under the jacket")
        return
    if absf(left_leg.position.z - right_leg.position.z) > 0.001:
        _fail("legs have different depth anchors")
        return
    if left_leg.get_node_or_null("HipJoint") != null or right_leg.get_node_or_null("HipJoint") != null:
        _fail("old oversized spherical hip geometry returned")
        return
    var jacket := pelvis.get_node_or_null("LowerJacket") as MeshInstance3D
    var hip_fabric := pelvis.get_node_or_null("HipFabric") as MeshInstance3D
    if jacket == null or hip_fabric == null:
        _fail("there must be continuous jacket and pelvis geometry")
        return
    if absf(jacket.position.z - left_leg.position.z) > 0.06:
        _fail("coat and legs have disconnected depth anchors")
        return
    if absf(pelvis.position.x) > 0.001:
        _fail("pelvis is offset from the center of the player")
        return
    # The camera's downward ray must not begin inside or directly hit a huge
    # chest mesh. Verify the torso is below eye height and shifted behind view.
    var chest := pelvis.get_node_or_null("ChestAndShoulders") as MeshInstance3D
    if chest == null or not (chest.mesh is CylinderMesh):
        _fail("torso must use a taper instead of an armor-like square box")
        return
    var torso_coat := chest.mesh as CylinderMesh
    var eye_height := (actor.get_node("Camera3D") as Camera3D).position.y
    if pelvis.position.y + chest.position.y + torso_coat.height * 0.5 >= eye_height - 0.20:
        _fail("torso intrudes into look-down camera")
        return
    if pelvis.position.z + chest.position.z - torso_coat.bottom_radius * chest.scale.z < -0.085:
        _fail("torso front must stay behind the eye when looking down")
        return
    if torso_coat.radial_segments > 10:
        _fail("body model lost the simple low-poly visual language")
        return
    if pelvis.get_node_or_null("CoatSeam") != null:
        _fail("jacket center spike returned to the look-down view")
        return
    var camera := actor.get_node("Camera3D") as Camera3D
    camera.rotation.x = -1.45
    avatar.call("_process", 0.016)
    if chest.visible:
        _fail("upper coat still blocks vision at extreme downward pitch")
        return
    if (pelvis.get_node("LeftArm") as Node3D).visible:
        _fail("full-body arm obscures downward view")
        return
    if not jacket.visible or not left_leg.visible or not right_leg.visible:
        _fail("look-down cutaway hid the waist or legs")
        return
    if not (left_leg.get_node("Boot") as MeshInstance3D).visible:
        _fail("boots should remain visible while looking down")
        return
    camera.rotation.x = 0.0
    avatar.call("_process", 0.016)
    if not chest.visible or not (pelvis.get_node("LeftArm") as Node3D).visible:
        _fail("upper coat and arm did not return after raising the view")
        return
    if actor.call("_movement_speed", false) > 3.6 or actor.call("_movement_speed", true) > 5.5:
        _fail("movement speed is too fast for November exploration")
        return
    if actor.call("_movement_speed", false) < 2.8:
        _fail("movement speed became excessively slow")
        return
    var hand_model := actor.get("_smoke_prop") as Node3D
    for detail in ["BrownFilter", "WhitePaper", "RedEmber"]:
        if hand_model.get_node_or_null("AnimatedHand/PeriodCharacterProp/" + detail) == null:
            _fail("missing close-up character prop detail: " + detail)
            return
    var hand := hand_model.get_node("AnimatedHand") as Node3D
    if hand.get_node_or_null("IndexFinger") == null or hand.get_node_or_null("MiddleFinger") == null:
        _fail("separated index and middle fingers missing")
        return
    var index_finger := hand.get_node("IndexFinger") as Node3D
    var middle_finger := hand.get_node("MiddleFinger") as Node3D
    var prop := hand.get_node("PeriodCharacterProp") as Node3D
    if index_finger.position.x * middle_finger.position.x >= 0.0 or absf(prop.position.x) > 0.005:
        _fail("decorative prop must sit between index and middle fingers")
        return
    var wrist := hand_model.get_node("AnimatedHand") as Node3D
    var elbow := hand_model.get_node("ElbowJoint") as Node3D
    actor.call("_apply_idle_pose", 0.0)
    var wrist_rest := wrist.position
    actor.call("_apply_idle_pose", 1.0)
    var wrist_raised := wrist.position
    var elbow_raised := elbow.position
    var camera_view := actor.get_node("Camera3D") as Camera3D
    var toward_face := (camera_view.global_position - wrist.global_position).normalized()
    var palm_front := wrist.global_transform.basis.z.normalized()
    if palm_front.dot(toward_face) < 0.45:
        _fail("palm is not turned toward the face when raised")
        return
    var filter := prop.get_node("BrownFilter") as Node3D
    var ember := prop.get_node("RedEmber") as Node3D
    if ember.global_position.distance_to(camera_view.global_position) <= filter.global_position.distance_to(camera_view.global_position) + 0.055:
        _fail("lit end points toward the face instead of outward")
        return
    if wrist_raised.y > -0.08 or wrist_raised.z > -0.20:
        _fail("hand reached into camera instead of stopping at face height")
        return
    var palm := hand_model.get_node("AnimatedHand/Palm") as MeshInstance3D
    if palm == null or not (palm.mesh is CapsuleMesh):
        _fail("hand must have connected rounded volume, not a square slab")
        return
    var glove := palm.mesh as CapsuleMesh
    if glove.radius > 0.050 or glove.height > 0.133:
        _fail("rounded glove is too large for the first-person view")
        return
    if hand_model.get_node_or_null("AnimatedHand/WristCuff") == null:
        _fail("gesture forearm leaves an open gap at the wrist")
        return
    if wrist_raised.y - wrist_rest.y < 0.35 or wrist_raised.x > 0.25:
        _fail("hand should rise toward center/face, not stay extended ahead")
        return
    if elbow_raised.distance_to(wrist_raised) < 0.22:
        _fail("elbow must stay visibly bent")
        return
    actor.call("_start_character_idle")
    if float(actor.get("_idle_smoke_timer")) <= 0.0:
        _fail("character gesture did not start from button action")
        return
    var active_gesture := actor.get("_smoke_prop") as Node3D
    if active_gesture == null or not active_gesture.visible:
        _fail("character idle prop not visible during action")
        return
    if (pelvis.get_node("RightArm") as Node3D).visible:
        _fail("right full-body arm remains duplicated while gesturing")
        return
    actor.call("_process", 6.0)
    if not (pelvis.get_node("RightArm") as Node3D).visible:
        _fail("right arm is not restored after gesture")
        return
    var hud_layer := CanvasLayer.new()
    hud_layer.name = "HUDTestLayer"
    get_root().add_child(hud_layer)
    var hud := Control.new()
    hud.name = "SurvivalHUD"
    hud.set_script(load("res://gameplay_hud.gd"))
    hud_layer.add_child(hud)
    hud.set("player", actor)
    if int(hud.get("current_health")) != 100:
        _fail("initial health not 100")
        return
    if str(hud.call("_compass_name", 90)) != "E":
        _fail("compass cardinal directions incorrect")
        return
    hud.call("choose_slot", 2)
    if int(hud.get("selected_slot")) != 2:
        _fail("quick slot selection does not update")
        return
    print("COLLISION_REGRESSION_OK: house=solid fence=solid gap=open player_idle=cosmetic capsule=blocked view=compact")
    print("FIRST_PERSON_HUD_REGRESSION_OK: avatar=body+legs+arms prop=filter+paper+ember compass=NESW health=100 slots=4 eye_clear=true elbow_bent=true civilian_coat=true slower_walk=true pelvis_aligned=true hand_inward=true tip_outward=true lookdown_clear=true glove_rounded=true")
    quit(0)
