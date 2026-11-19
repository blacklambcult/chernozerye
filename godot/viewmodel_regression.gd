extends SceneTree
# Regression of camera-space silhouette and full-body handoff. This test
# deliberately exercises the actual Player scene, not just static constants.

func _fail(message: String) -> void:
    push_error("VIEWMODEL_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.set_script(load("res://player.gd"))
    get_root().add_child(player)
    var eye := player.get_node_or_null("Camera3D") as Camera3D
    var gun: Node3D = player.get("revolver")
    if gun.visible or player.has_node("Camera3D/FPSViewmodel"):
        _fail("unarmed hands visible")
        return
    gun.call("equip", true)
    var idle: float = gun.call("spread_angle")
    player.velocity.x = 4.0
    var moving: float = gun.call("spread_angle")
    if moving <= idle or not gun.visible:
        _fail("movement or draw did not affect weapon")
        return
    for i in range(64):
        var direction: Vector3 = gun.call("_shot_direction")
        if direction.angle_to(-eye.global_basis.z) > moving + 0.0001:
            _fail("shot landed outside indicated cone")
            return
    gun.call("_shoot")
    if eye.rotation.x <= 0 or float(gun.call("spread_angle")) <= moving:
        _fail("missing recoil or spread bloom")
        return
    gun.call("equip", false)
    player.velocity = Vector3.ZERO
    for i in range(120):
        player.call("_physics_process", 1.0/60)
        gun.call("_physics_process", 1.0/60)
    if gun.visible or absf(eye.rotation.x) > 0.001 or not is_equal_approx(gun.call("spread_angle"), idle):
        _fail("unarmed view, spread or recoil did not recover")
        return
    var wind := player.get("wind") as AudioStreamPlayer
    if wind.playing:
        _fail("ambient wind loop must be silent in the village")
        return
    if (wind.stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_FORWARD:
        _fail("wind must loop")
        return
    var outdoors_db := wind.volume_db
    player.call("set_indoors", true)
    var footsteps := player.get("step_sound") as AudioStreamPlayer
    var boards := footsteps.stream
    if wind.volume_db >= outdoors_db:
        _fail("indoor wind remained exposed")
        return
    player.call("set_indoors", false)
    if boards == footsteps.stream or wind.volume_db != outdoors_db or wind.playing:
        _fail("outdoor mix was not restored or disabled wind restarted")
        return
    var previous := 0.0
    for speed: float in [player.call("_movement_speed", true, true), 3.35, 5.15]:
        player.set("noise_level", 0)
        for tick in range(100):
            player.call("_track_steps", speed / 60.0, 1.0 / 60.0)
        var strength := float(player.get("noise_level"))
        if strength <= previous or strength >= 1.0:
            _fail("step noise must increase with movement speed")
            return
        previous = strength
    print("VIEWMODEL_REGRESSION_OK: item_only=true spread=true recoil=true")
    quit(0)
