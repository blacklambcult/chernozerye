extends SceneTree
# Headless proof that the user-authored coordinates and two reach objectives
# are playable, and that the original story HUD is restored on leaving.

func _fail(reason: String) -> void:
    push_error("QUESTLAB_REGRESSION_FAILED: " + reason)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "QuestLabTestWorld"
    get_root().add_child(root)
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.position = Vector3(6.0, 0.22, 9.0)
    root.add_child(actor)
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    actor.add_child(camera)
    var fake_story := Node.new()
    fake_story.name = "StoryPrologue"
    root.add_child(fake_story)
    fake_story.set_meta("preview_stub", true)
    var layer := CanvasLayer.new()
    layer.name = "ChapterOneHUD"
    fake_story.add_child(layer)
    var runtime := Node.new()
    runtime.name = "QuestLabRuntime"
    runtime.set_script(load("res://questlab_runtime.gd"))
    root.add_child(runtime)
    runtime.set_process(false)
    if (runtime.get("missions") as Array).size() != 1:
        _fail("exactly one authored quest expected")
        return
    var quest: Dictionary = runtime.get("selected_quest")
    if str(quest.get("title", "")) != "ВОЗВРАЩЕНИЕ НА ЧЕРНЫЙ КОРДОН":
        _fail("the uploaded quest title was not preserved")
        return
    var steps: Array = quest.get("steps", [])
    if steps.size() != 2 or str(steps[1].get("title", "")) != "Найти дом старосты":
        _fail("editor steps were not converted")
        return
    if not bool(runtime.call("activate_preview")):
        _fail("F6 playtest cannot start")
        return
    if layer.visible:
        _fail("legacy prologue HUD overlaps Quest Lab HUD")
        return
    if actor.global_position.distance_to(Vector3(-809.39, 0.22, 38.82)) > 3.0:
        _fail("initial spawn is not the user-authored Geo Lab position")
        return
    var objective := runtime.get("detail_label") as Label
    if not objective.text.contains("Добраться до Черного Кордона"):
        _fail("first quest task invisible")
        return
    var first: Dictionary = steps[0]
    var first_position: Array = first["target_world"]
    actor.global_position = Vector3(float(first_position[0]), 0.22, float(first_position[2]))
    runtime.call("_process", 0.1)
    if int(runtime.get("step_index")) != 1 or not objective.text.contains("Найти дом старосты"):
        _fail("first reach condition did not unlock the second task")
        return
    var second: Dictionary = steps[1]
    var final_position: Array = second["target_world"]
    actor.global_position = Vector3(float(final_position[0]), 0.22, float(final_position[2]))
    runtime.call("_process", 0.1)
    if not bool(runtime.get("quest_completed")):
        _fail("second reach task did not complete the imported quest")
        return
    runtime.call("deactivate_preview")
    if bool(runtime.get("preview_active")) or not layer.visible:
        _fail("F6 playtest did not restore the original prologue")
        return
    if actor.global_position.distance_to(Vector3(6.0, 0.22, 9.0)) > 0.01:
        _fail("player position was not restored")
        return
    print("QUESTLAB_REGRESSION_OK: imported=true spawn=true steps=2 sequential=true restored=true")
    quit(0)
