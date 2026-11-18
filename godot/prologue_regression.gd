extends SceneTree
# Standalone story progression regression; does not load the huge 3D village.
# Uses the same converted 314-object manual layout available in the web CI.

func _fail(reason: String) -> void:
    push_error("PROLOGUE_REGRESSION_FAILED: " + reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    var root := Node3D.new()
    root.name = "PrologueHarness"
    get_root().add_child(root)
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(-789.7, 0.22, -268.6)
    root.add_child(player)
    var story := Node.new()
    story.name = "StoryPrologue"
    story.set_script(load("res://story_prologue.gd"))
    root.add_child(story)
    if story.get("interior") == null:
        _fail("room was not built")
        return
    if story.get("waypoint") == null:
        _fail("home waypoint missing")
        return
    var gate: Vector2 = story.get("gate_point")
    if gate.distance_to(Vector2(-789.7, 268.6)) > 170.0:
        _fail("selected home is too far from start position")
        return
    story.call("_enter_home")
    if not bool(story.get("inside_home")):
        _fail("interact E cannot enter home")
        return
    var room := Vector3(3200.0, 0.0, 3200.0)
    player.global_position = room + Vector3(-2.1, 0.25, -0.55)
    story.call("_interact")
    if not bool(story.get("note_found")):
        _fail("note not interactable")
        return
    player.global_position = room + Vector3(0, 0.25, -3.35)
    story.call("_interact")
    if not bool(story.get("mask_found")):
        _fail("mask not interactable")
        return
    player.global_position = room + Vector3(0, 0.25, 3.65)
    story.call("_interact")
    if bool(story.get("inside_home")) or not bool(story.get("chapter_completed")):
        _fail("prologue does not complete when leaving after both clues")
        return
    var home_point: Vector2 = story.get("home_point")
    if not home_point.is_finite():
        _fail("invalid surveyed house center")
        return
    print("PROLOGUE_REGRESSION_OK: surveyed_home=true room=true note=true mask=true exit=true")
    quit(0)
