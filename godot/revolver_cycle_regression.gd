extends SceneTree
# Fictional game input regression: two presses per shot, six per cylinder.

func _fail(why: String) -> void:
    push_error("REVOLVER_CYCLE_REGRESSION_FAILED: " + why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var gun: Node3D = actor.get("revolver")
    gun.call("equip", true)
    if gun.get("cocked") or int(gun.get("rounds")) != 6:
        _fail("unexpected initial state")
        return
    if gun.get("cock_audio").stream == null or gun.get("cylinder_audio").stream == null or gun.get("report").stream == null:
        _fail("one of the supplied sound effects was not assigned")
        return
    for index in range(6):
        gun.set("cooldown", 0.0)
        gun.call("request_shot")
        if not bool(gun.get("cocked")) or bool(gun.get("pending")) or int(gun.get("rounds")) != 6 - index:
            _fail("click %d should cock only" % (index * 2 + 1))
            return
        gun.call("request_shot")
        if bool(gun.get("cocked")) or not bool(gun.get("pending")):
            _fail("click %d should queue shot" % (index * 2 + 2))
            return
        gun.call("_shoot")
        if int(gun.get("rounds")) != 5 - index or bool(gun.get("pending")):
            _fail("shot %d did not consume exactly one round" % (index + 1))
            return
    gun.set("cooldown", 0.0)
    gun.call("request_shot")
    if int(gun.get("rounds")) != 0 or bool(gun.get("pending")) or bool(gun.get("cocked")):
        _fail("empty cylinder accepted another click")
        return
    gun.call("reload")
    if float(gun.get("reload_left")) <= 0.0 or bool(gun.get("cocked")) or str(gun.get("last_action")) != "reload":
        _fail("reload did not reset hammer or start audio")
        return
    gun.call("_physics_process", 2.0)
    if int(gun.get("rounds")) != 6:
        _fail("reload did not refill the game cylinder")
        return
    print("REVOLVER_CYCLE_REGRESSION_OK: clicks=12 shots=6 reload=true sfx=true")
    quit(0)
