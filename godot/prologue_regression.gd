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
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    camera.position.y = 1.55
    player.add_child(camera)
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
    var waypoint := story.get("waypoint") as Label3D
    if waypoint.visible or waypoint.text != "":
        _fail("floating surveyed-home text must never be drawn")
        return
    # Layout: quest, distance and journal top-left; subtitles bottom-center.
    var distance := story.get("distance_label") as Label
    var journal_hint := story.get("journal_hint_label") as Label
    var subtitles := story.get("message_label") as Label
    var interaction := story.get("prompt_label") as Label
    if distance == null or journal_hint == null or subtitles == null or interaction == null:
        _fail("mission HUD labels missing")
        return
    if distance.position.y > 55.0 or journal_hint.position.y > 85.0:
        _fail("distance and journal must stay below top-left quest")
        return
    if subtitles.anchor_left != 0.5 or subtitles.anchor_top != 1.0:
        _fail("subtitle text must remain bottom-center")
        return
    var gate: Vector2 = story.get("gate_point")
    var bearing: String = story.call("_home_bearing")
    if bearing not in ["ПРЯМО", "НАЗАД", "СПРАВА", "СЛЕВА", "ЗДЕСЬ"]:
        _fail("Missing directional clue to home")
        return
    if gate.distance_to(Vector2(-789.7, 268.6)) > 170.0:
        _fail("selected home is too far from start position")
        return
    # Check that the escalating prose plays once at each approach distance.
    var gate_world := Vector3(gate.x, 0.22, -gate.y)
    player.position = gate_world + Vector3(20.0, 0.0, 0.0)
    story.call("_update_approach")
    story.call("_update_approach")
    if int(story.get("_approach_triggers")) != 1:
        _fail("first homecoming cue does not fire once")
        return
    player.position = gate_world + Vector3(8.0, 0.0, 0.0)
    story.call("_update_approach")
    story.call("_update_approach")
    if int(story.get("_approach_triggers")) != 2:
        _fail("yard homecoming cue does not fire once")
        return
    story.call("_update_focus")
    if str(distance.text).contains("ПРЯМО") or str(distance.text).contains("НАЗАД"):
        _fail("distance line must not duplicate compass direction")
        return
    if not str(journal_hint.text).contains("журнал"):
        _fail("journal hotkey missing at top-left")
        return
    story.call("_enter_home")
    if not bool(story.get("inside_home")):
        _fail("interact E cannot enter home")
        return
    var room := Vector3(3200.0, 0.0, 3200.0)
    player.global_position = room + Vector3(-2.1, 0.25, 0.65)
    camera.look_at(camera.global_position + Vector3.BACK)
    story.call("_interact")
    if bool(story.get("note_found")):
        _fail("note can be read while facing away")
        return
    camera.look_at(story.call("_target_position", "note"))
    story.call("_interact")
    if not bool(story.get("note_found")):
        _fail("note not interactable")
        return
    player.global_position = room + Vector3(0, 0.25, -2.35)
    camera.look_at(story.call("_target_position", "mask"))
    story.call("_interact")
    var porch := story.get("porch_sound") as AudioStreamPlayer3D
    if not porch.playing or porch.position.z <= 4.05:
        _fail("porch cue must start beyond the door")
        return
    var first_motion: Tween = story.get("latch_motion")
    story.call("_interact")
    if first_motion != story.get("latch_motion"):
        _fail("looking at the mask twice replayed the porch cue")
        return
    if not bool(story.get("mask_found")):
        _fail("mask not interactable")
        return
    player.global_position = room + Vector3(0, 0.25, 2.1)
    camera.look_at(story.call("_target_position", "exit"))
    story.call("_interact")
    if bool(story.get("inside_home")) or not bool(story.get("chapter_completed")):
        _fail("prologue does not complete when leaving after both clues")
        return
    if porch.playing or first_motion.is_valid():
        _fail("porch cue continued after leaving")
        return
    if waypoint.visible or waypoint.text != "":
        _fail("floating surveyed-home label reappeared after exit")
        return
    var home_point: Vector2 = story.get("home_point")
    if not home_point.is_finite():
        _fail("invalid surveyed house center")
        return
    print("PROLOGUE_REGRESSION_OK: surveyed_home=true room=true note=true mask=true exit=true cues=2 bearing=readable")
    quit(0)
