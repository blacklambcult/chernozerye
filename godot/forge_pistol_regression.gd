extends SceneTree
# Smoke test the exact Forge GLB and a seven-round single-click arcade cycle.
func _fail(why: String) -> void:
    push_error("FORGE_PISTOL_REGRESSION_FAILED: " + why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var pistol: Node3D = actor.get("forge_pistol")
    var revolver: Node3D = actor.get("revolver")
    if pistol == null or not pistol.has_node("ForgePistolVisual"):
        _fail("uploaded Forge model missing from camera")
        return
    if pistol.get("grip_marker") == null or pistol.get("forward_marker") == null \
            or pistol.get("magazine_marker") == null:
        _fail("GLB anchor nodes were not imported")
        return
    var pistol_hand := pistol.get_node_or_null("WeaponRightHand") as Node3D
    var revolver_hand := revolver.get_node_or_null("WeaponRightHand") as Node3D
    if pistol_hand == null or revolver_hand == null:
        _fail("camera-space holding hand missing from either weapon")
        return
    if pistol_hand.find_children("*", "MeshInstance3D", true, false).size() < 8:
        _fail("pistol wrist and fingers do not have visible geometry")
        return
    if revolver_hand.find_children("*", "MeshInstance3D", true, false).size() < 8:
        _fail("revolver wrist and fingers do not have visible geometry")
        return
    if not is_equal_approx(float(pistol.get("model_scale")), 0.32):
        _fail("pistol remains at its old undersized viewmodel scale")
        return
    if (pistol.position - Vector3(0.285, -0.225, -0.47)).length() > 0.001:
        _fail("Forge camera-relative pose was not loaded")
        return
    if (pistol_hand.position - Vector3(-0.01, 0.06, -0.01)).length() > 0.001:
        _fail("new author-positioned viewmodel hand was not applied")
        return
    if (pistol.rotation - Vector3(0.0, deg_to_rad(9.0), 0.0)).length() > 0.001:
        _fail("new author-selected rotation did not load")
        return
    var model := pistol.get("imported_model") as Node3D
    if model.find_children("*", "MeshInstance3D", true, false).size() < 10:
        _fail("uploaded GLB has lost its author-designed visual parts")
        return
    if int(pistol.get("rounds")) != 7 or pistol.visible:
        _fail("pistol did not start holstered with 7 rounds")
        return
    pistol.call("equip", true)
    if revolver.visible or not pistol_hand.is_visible_in_tree():
        _fail("pistol holding hand hidden or legacy revolver unexpectedly visible")
        return
    var rest_pose: Vector3 = pistol.get("rest_pose")
    for count in range(7):
        pistol.set("cooldown", 0.0)
        pistol.call("request_shot")
        if not bool(pistol.get("pending")) or str(pistol.get("last_action")) != "fire":
            _fail("one click must queue an immediate game shot")
            return
        pistol.call("_shoot")
        if int(pistol.get("rounds")) != 6-count or bool(pistol.get("pending")):
            _fail("each click must consume exactly one of seven rounds")
            return
        if count == 0:
            pistol.call("_physics_process", 1.0 / 60.0)
            if pistol.position.z <= rest_pose.z or float(pistol.get("recoil_pose")) <= 0.0:
                _fail("shot did not push the viewmodel backward")
                return
            for frame in range(90):
                pistol.call("_physics_process", 1.0 / 60.0)
            if absf(pistol.position.z - rest_pose.z) > 0.001:
                _fail("viewmodel did not settle back after recoil")
                return
    pistol.set("cooldown", 0.0)
    pistol.call("request_shot")
    if bool(pistol.get("pending")):
        _fail("an empty magazine accepted a shot")
        return
    pistol.call("reload")
    if float(pistol.get("reload_left")) <= 0.0:
        _fail("reload did not begin")
        return
    pistol.call("_physics_process", 2.0)
    if int(pistol.get("rounds")) != 7:
        _fail("reload did not refill seven rounds")
        return
    for clip in [&"CockHammer", &"RackSlide", &"RackBolt"]:
        pistol.set("cocking_clip", clip)
        pistol.set("rounds", 1)
        pistol.call("reload")
        pistol.call("_physics_process", 2.0)
        pistol.call("request_shot")
        if pistol.get("pending"):
            _fail("unprepared weapon queued a shot after reload")
            return
        pistol.call("cock")
        pistol.call("request_shot")
        if pistol.get("pending"):
            _fail("weapon fired before cocking completed")
            return
        pistol.call("_physics_process", 1.0)
        pistol.call("request_shot")
        if not pistol.get("pending"):
            _fail("prepared weapon did not accept a shot")
            return
        pistol.call("_shoot")
        if bool(pistol.get("cocked")) != (clip != &"CockHammer"):
            _fail("wrong readiness state after shot")
            return
        pistol.call("_physics_process", 1.0)
    pistol.set("weapon_type", "doubleshotgun")
    pistol.set("cocking_clip", &"")
    pistol.set("rounds", 0)
    pistol.set("capacity", 2)
    pistol.call("reload")
    pistol.call("_physics_process", 1.0)
    pistol.call("insert_shells")
    pistol.call("_physics_process", 1.0)
    pistol.call("request_shot")
    if pistol.get("pending") or pistol.get("rounds") != 0:
        _fail("break-action weapon became ready while open")
        return
    pistol.call("reload")
    pistol.call("_physics_process", 1.0)
    pistol.call("request_shot")
    if not pistol.get("pending") or pistol.get("rounds") != 2:
        _fail("break-action weapon did not become ready after closing")
        return
    # Mimic an older GLB with a hinge, but no exported shell meshes or Fire hinge track.
    var hinge := Node3D.new()
    hinge.name = "BarrelPivot"
    model.add_child(hinge)
    var animator := AnimationPlayer.new()
    model.add_child(animator)
    var clips := AnimationLibrary.new()
    animator.add_animation_library(&"", clips)
    var insertion := Animation.new()
    insertion.length = 0.88
    var hinge_track := insertion.add_track(Animation.TYPE_ROTATION_3D)
    insertion.track_set_path(hinge_track, ^"BarrelPivot")
    insertion.rotation_track_insert_key(hinge_track, 0.0, Quaternion(Vector3.RIGHT, -0.72))
    clips.add_animation(&"InsertShells", insertion)
    clips.add_animation(&"Fire", Animation.new())
    pistol.set("model_animation", animator)
    pistol.call("_repair_break_action_clips")
    animator.play(&"InsertShells")
    animator.seek(0.2, true)
    var shell := hinge.get_node_or_null("ReloadShell_L") as Node3D
    if shell == null or shell.scale.x < 0.9 or is_zero_approx(hinge.rotation.x):
        _fail("older GLB did not show the animated insertion shell")
        return
    animator.play(&"Fire")
    animator.advance(0.0)
    if not is_zero_approx(hinge.rotation.x) or shell.scale.x > 0.01:
        _fail("Fire did not restore the closed pose")
        return
    var body := Node3D.new()
    body.name = "Weapon_Body"
    model.add_child(body)
    var fire := animator.get_animation(&"Fire")
    var body_track := fire.add_track(Animation.TYPE_POSITION_3D)
    fire.track_set_path(body_track, ^"Weapon_Body")
    fire.position_track_insert_key(body_track, 0.0, Vector3.ZERO)
    fire.position_track_insert_key(body_track, 0.05, Vector3.BACK * 0.04)
    pistol.call("_apply_gameplay", {"bodycam": 1.0})
    pistol.call("_tune_fire_body_tracks")
    if not Vector3(fire.track_get_key_value(body_track, 1)).is_zero_approx() \
            or not is_zero_approx(hinge.rotation.x):
        _fail("bodycam must remove the baked body kick and keep the closed hinge")
        return
    pistol.set("cooldown", 0.0)
    pistol.call("_shoot")
    var eye := actor.get("camera") as Camera3D
    if is_zero_approx(eye.v_offset) or float(pistol.get("shot_impulse")) <= 0.0:
        _fail("bodycam shot did not kick the camera and the weapon")
        return
    for frame in range(90):
        actor.call("_physics_process", 1.0 / 60.0)
        pistol.call("_physics_process", 1.0 / 60.0)
    if absf(eye.v_offset) > 0.0001 or absf(pistol.position.z - rest_pose.z) > 0.001:
        _fail("bodycam offset and viewmodel thrust must settle")
        return
    var wav := Marshalls.raw_to_base64(FileAccess.get_file_as_bytes("res://revolver_report.wav"))
    var sounds := {}
    for action in ["fire", "cock", "reload", "empty"]:
        sounds[action] = {"format": "wav", "data": wav}
    pistol.call("_load_action_sounds", sounds)
    var imported_sounds: Dictionary = pistol.get("action_sounds")
    if imported_sounds.size() != 4:
        _fail("custom WAV sounds were not decoded for all four actions")
        return
    pistol.call("equip", false)
    revolver.call("equip", true)
    if int(revolver.get("rounds")) != 6 or not revolver_hand.is_visible_in_tree():
        _fail("original six-round revolver or its holding hand was changed")
        return
    for weapon_class in ["revolver", "pistol", "smg", "assault", "boltrifle", "semirifle", "doubleshotgun", "pumpshotgun"]:
        pistol.call("_apply_gameplay", {"class": weapon_class, "bodycam": 0.0})
        if not is_equal_approx(float(pistol.get("bodycam_strength")), 0.8) \
                or Vector3(pistol.get("bodycam_response")).is_equal_approx(Vector3.ONE):
            _fail("old weapon profiles must inherit a class-specific Bodycam response")
            return
    pistol.call("_apply_gameplay", {"bodycam": 0.0, "bodycamProfile": 2})
    if not is_zero_approx(float(pistol.get("bodycam_strength"))):
        _fail("an explicit off setting in the current profile must be respected")
        return
    var comparison_actor := CharacterBody3D.new()
    comparison_actor.set_script(load("res://player.gd"))
    comparison_actor.set("comparison_loadout", true)
    get_root().add_child(comparison_actor)
    var slots: Dictionary = comparison_actor.get("forge_weapons")
    if slots.size() != 2 or not slots.has(2) or not slots.has(3) \
            or bool(comparison_actor.get("revolver").visible):
        _fail("comparison inventory must contain only Forge weapons in slots 3 and 4")
        return
    for index in [2, 3]:
        var weapon: Node3D = slots[index]
        var comparison_clips := weapon.get("model_animation") as AnimationPlayer
        if weapon.get("weapon_type") != "revolver" or weapon.get("rounds") != 6 \
                or weapon.get("casing_port") == null or weapon.get("forward_marker") == null \
                or weapon.get("cocking_clip") != &"CockHammer" or comparison_clips == null \
                or not comparison_clips.has_animation(&"Fire") or not comparison_clips.has_animation(&"Reload"):
            _fail("generated comparison revolver missing clips, markers or profile")
            return
        if not is_equal_approx(float(weapon.get("bodycam_strength")), 0.0 if index == 2 else 0.8):
            _fail("comparison revolvers must use different bodycam profile values")
            return
    var test_revolver: Node3D = slots[3]
    test_revolver.call("equip", true)
    test_revolver.call("cock")
    test_revolver.call("_physics_process", 1.0)
    test_revolver.call("_shoot")
    test_revolver.call("_physics_process", 1.0 / 60.0)
    if not (test_revolver.get("muzzle_haze") as MeshInstance3D).visible:
        _fail("Bodycam muzzle haze must appear after firing")
        return
    test_revolver.call("equip", false)
    if (test_revolver.get("muzzle_haze") as MeshInstance3D).visible:
        _fail("holstered weapons must clear their muzzle effect")
        return
    var standard := slots[2].get("model_animation") as AnimationPlayer
    var bodycam := slots[3].get("model_animation") as AnimationPlayer
    var standard_fire := standard.get_animation(&"Fire")
    var bodycam_fire := bodycam.get_animation(&"Fire")
    var track := standard_fire.find_track(
        standard.get_node(standard.root_node).get_path_to(
            slots[2].get("imported_model").find_child("Weapon_Body")), Animation.TYPE_POSITION_3D)
    if standard_fire == bodycam_fire or track < 0 \
            or Vector3(standard_fire.track_get_key_value(track, 1)).length() <= \
                Vector3(bodycam_fire.track_get_key_value(track, 1)).length():
        _fail("compare original and reduced baked body motion without shared animation mutation")
        return
    print("FORGE_PISTOL_REGRESSION_OK: uploaded_glb=true anchors=3 parts>=10 capacity=7 one_click=true reload=true original_revolver=true hands=2 fp_profile=true")
    quit(0)
