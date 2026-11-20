extends SceneTree
# New F7 interaction/collection playtest must be isolated from the F6
# user-authored mission and must restore the original world on exit.
func _fail(why: String) -> void:
    push_error("QUESTLAB_INTERACTION_REGRESSION_FAILED: " + why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var root := Node3D.new()
    root.name = "QuestLabInteractionWorld"
    get_root().add_child(root)
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.position = Vector3(13.0, 0.22, 19.0)
    root.add_child(actor)
    var camera := Camera3D.new()
    camera.name = "Camera3D"
    actor.add_child(camera)
    var story := Node.new()
    story.name = "StoryPrologue"
    root.add_child(story)
    var old_hud := CanvasLayer.new()
    old_hud.name = "ChapterOneHUD"
    story.add_child(old_hud)
    var runtime := Node.new()
    runtime.name = "QuestLabRuntime"
    runtime.set_script(load("res://questlab_runtime.gd"))
    root.add_child(runtime)
    runtime.set_process(false)
    var demo: Dictionary = runtime.get("demo_quest")
    if str(demo.get("id", "")) != "quest-interaction-demo":
        _fail("compiled F7 demo missing")
        return
    var demo_steps: Array = demo.get("steps", [])
    if demo_steps.size() != 3 or str(demo_steps[0].get("type", "")) != "interact" \
            or str(demo_steps[1].get("type", "")) != "collect":
        _fail("F7 demo has wrong step types")
        return
    if str(demo_steps[0].get("object_id", "")) != "4499fe7a-c031-469c-aac4-96636c23eea8" \
            or str(demo_steps[0].get("target_source", "")) != "geo_lab_id" \
            or str(demo_steps[0].get("object_type", "")) != "house":
        _fail("interact target was not resolved against a surveyed Geo Lab house")
        return
    if not bool(runtime.call("activate_preview", true)):
        _fail("F7 did not activate test mission")
        return
    if old_hud.visible:
        _fail("original HUD visible during playtest")
        return
    var info := runtime.get("detail_label") as Label
    var marker := runtime.get("marker_root") as Node3D
    if marker == null or marker.get_node_or_null("PreviewOnlyVisual") == null \
            or marker.get("linked_object") != true:
        _fail("real Geo Lab house locator missing")
        return
    if bool(runtime.call("interact_selected")) or int(runtime.get("step_index")) != 0:
        _fail("interaction works from outside allowed range")
        return
    var first: Array = demo_steps[0]["target_world"]
    actor.global_position = Vector3(float(first[0]), 0.22, float(first[2]))
    if not bool(runtime.call("interact_selected")) or int(runtime.get("step_index")) != 1:
        _fail("E does not advance interact step")
        return
    if not info.text.contains("Подобрать записку возле дома"):
        _fail("collect step title not visible")
        return
    if (runtime.get("collected_items") as Array).size() != 0:
        _fail("interacting incorrectly awarded a collectible")
        return
    marker = runtime.get("marker_root") as Node3D
    if marker == null or marker.get_node_or_null("PreviewOnlyVisual/QuestNote") == null:
        _fail("collectable note did not spawn")
        return
    var next: Array = demo_steps[1]["target_world"]
    actor.global_position = Vector3(float(next[0]) + 20.0, 0.22, float(next[2]))
    if bool(runtime.call("interact_selected")) or int(runtime.get("step_index")) != 1:
        _fail("item can be collected from a distance")
        return
    actor.global_position = Vector3(float(next[0]), 0.22, float(next[2]))
    if not bool(runtime.call("interact_selected")) or int(runtime.get("step_index")) != 2:
        _fail("E does not pick up item")
        return
    if (runtime.get("collected_items") as Array).size() != 1:
        _fail("note was not recorded in temporary playtest inventory")
        return
    if runtime.get("marker_root") != null:
        _fail("collect marker persisted after collection")
        return
    runtime.call("_process", 4.0)
    if not bool(runtime.get("quest_completed")):
        _fail("message after collectible did not finish")
        return
    runtime.call("deactivate_preview")
    if bool(runtime.get("preview_active")) or not old_hud.visible:
        _fail("F7 did not restore the original HUD")
        return
    if actor.global_position.distance_to(Vector3(13.0, 0.22, 19.0)) > 0.001:
        _fail("F7 did not restore starting player transform")
        return
    if not bool(runtime.call("activate_preview")):
        _fail("F6 mission was broken after F7")
        return
    if str((runtime.get("selected_quest") as Dictionary).get("title", "")) != \
            "ВОЗВРАЩЕНИЕ НА ЧЕРНЫЙ КОРДОН":
        _fail("original user-authored mission was replaced")
        return
    runtime.call("deactivate_preview")
    print("QUESTLAB_INTERACTION_REGRESSION_OK: f7=true marker=true interact=true collect=true distance_guard=true message=true original_f6=true restored=true geo_link=true")
    quit(0)
