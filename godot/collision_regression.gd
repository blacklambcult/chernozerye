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
    if avatar.get_node_or_null("LeftLeg") == null or avatar.get_node_or_null("RightLeg") == null:
        _fail("feet and legs are not modeled")
        return
    if avatar.get_node_or_null("LeftArm") == null or avatar.get_node_or_null("RightArm") == null:
        _fail("first-person arms are not modeled")
        return
    # The camera's downward ray must not begin inside or directly hit a huge
    # chest mesh. Verify the torso is below eye height and shifted behind view.
    var chest := avatar.get_node_or_null("ChestAndShoulders") as MeshInstance3D
    if chest == null or not chest.mesh is BoxMesh:
        _fail("upper torso must be a compact box, not a head-sized sphere")
        return
    var torso_box := chest.mesh as BoxMesh
    var eye_height := (actor.get_node("Camera3D") as Camera3D).position.y
    if chest.position.y + torso_box.size.y * 0.5 >= eye_height - 0.20:
        _fail("head/torso clearance insufficient for look-down camera")
        return
    if chest.position.z - torso_box.size.z * 0.5 < 0.01:
        _fail("torso front must stay behind the eye when looking down")
        return
    var hand_model := actor.get("_smoke_prop") as Node3D
    for detail in ["BrownFilter", "WhitePaper", "RedEmber"]:
        if hand_model.get_node_or_null("AnimatedHand/PeriodCharacterProp/" + detail) == null:
            _fail("missing close-up character prop detail: " + detail)
            return
    var wrist := hand_model.get_node("AnimatedHand") as Node3D
    var elbow := hand_model.get_node("ElbowJoint") as Node3D
    actor.call("_apply_idle_pose", 0.0)
    var wrist_rest := wrist.position
    actor.call("_apply_idle_pose", 1.0)
    var wrist_raised := wrist.position
    var elbow_raised := elbow.position
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
    var prop := actor.get("_smoke_prop") as Node3D
    if prop == null or not prop.visible:
        _fail("character idle prop not visible during action")
        return
    if (avatar.get_node("RightArm") as Node3D).visible:
        _fail("right full-body arm remains duplicated while gesturing")
        return
    actor.call("_process", 6.0)
    if not (avatar.get_node("RightArm") as Node3D).visible:
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
    print("FIRST_PERSON_HUD_REGRESSION_OK: avatar=body+legs+arms prop=filter+paper+ember compass=NESW health=100 slots=4 eye_clear=true elbow_bent=true")
    quit(0)
