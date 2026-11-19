extends Node
# QUEST LAB PLAYTEST (F6). Reads the validated, converted editor JSON.
# Opt-in so the hand-authored StoryPrologue still works unchanged by default.
const DATA_PATH := "res://questlab_runtime.json"
const REACH_RADIUS_M := 8.0
const MESSAGE_SECONDS := 3.5

var player: CharacterBody3D
var story: Node
var missions: Array = []
var selected_quest: Dictionary = {}
var preview_active := false
var quest_completed := false
var step_index := 0
var message_elapsed := 0.0
var saved_transform := Transform3D.IDENTITY
var saved_camera_pitch := 0.0
var saved_map_visible := false

var hud_layer: CanvasLayer
var objective_label: Label
var detail_label: Label
var distance_label: Label
var subtitle_label: Label

func _ready() -> void:
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    story = get_parent().get_node_or_null("StoryPrologue")
    _create_hud()
    if not FileAccess.file_exists(DATA_PATH):
        push_warning("QUESTLAB_RUNTIME_MISSING: run scripts/convert_questlab.py")
        return
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
    if not doc is Dictionary or str(doc.get("schema", "")) != "chernozerye.questlab.runtime-1":
        push_warning("QUESTLAB_RUNTIME_BAD_SCHEMA: invalid generated JSON")
        return
    var provided: Variant = doc.get("quests", [])
    if not provided is Array:
        return
    missions = provided
    var preferred := str(doc.get("selected_id", ""))
    for entry in missions:
        if entry is Dictionary and str(entry.get("id", "")) == preferred:
            selected_quest = entry
            break
    if selected_quest.is_empty() and not missions.is_empty() and missions[0] is Dictionary:
        selected_quest = missions[0]
    if not selected_quest.is_empty():
        var steps: Array = selected_quest.get("steps", [])
        print("QUESTLAB_RUNTIME_READY: quests=", missions.size(),
            " steps=", steps.size(), " key=F6")

func _make_label(at: Vector2, color: Color, font_size: int) -> Label:
    var label := Label.new()
    label.position = at
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color("#0c1214"))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.add_theme_font_size_override("font_size", font_size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_layer.add_child(label)
    return label

func _create_hud() -> void:
    hud_layer = CanvasLayer.new()
    hud_layer.name = "QuestLabPlaytestHUD"
    hud_layer.layer = 21
    add_child(hud_layer)
    objective_label = _make_label(Vector2(18, 18), Color("#eac6a3"), 16)
    detail_label = _make_label(Vector2(18, 46), Color("#d8d1bd"), 13)
    distance_label = _make_label(Vector2(18, 68), Color("#a8bdb8"), 12)
    subtitle_label = _make_label(Vector2.ZERO, Color("#efdfc5"), 14)
    subtitle_label.anchor_left = 0.5
    subtitle_label.anchor_right = 0.5
    subtitle_label.anchor_top = 1.0
    subtitle_label.anchor_bottom = 1.0
    subtitle_label.offset_left = -340.0
    subtitle_label.offset_right = 340.0
    subtitle_label.offset_top = -84.0
    subtitle_label.offset_bottom = -36.0
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud_layer.visible = false

func _world_point(value: Variant) -> Vector3:
    if not value is Array or value.size() != 3:
        return Vector3.ZERO
    return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _current_step() -> Dictionary:
    if not preview_active or quest_completed:
        return {}
    var steps: Array = selected_quest.get("steps", [])
    if step_index < 0 or step_index >= steps.size():
        return {}
    var current: Variant = steps[step_index]
    return current if current is Dictionary else {}

func has_target() -> bool:
    var entry := _current_step()
    return not entry.is_empty() and entry.get("target_world") is Array

func get_target_world() -> Vector3:
    var entry := _current_step()
    return _world_point(entry.get("target_world", null)) if not entry.is_empty() else Vector3.ZERO

func activate_preview() -> bool:
    if preview_active or player == null or selected_quest.is_empty():
        return false
    if story != null and (bool(story.get("inside_home")) or bool(story.get("journal_open"))):
        return false
    if bool(player.get("controls_locked")):
        return false
    saved_transform = player.global_transform
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    saved_camera_pitch = camera.rotation.x if camera != null else 0.0
    var overlay := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
    saved_map_visible = overlay != null and overlay.visible
    if overlay != null:
        overlay.visible = false
    if story != null:
        story.set_process(false)
        story.set_process_unhandled_input(false)
        var old_hud := story.get_node_or_null("ChapterOneHUD") as CanvasLayer
        if old_hud != null:
            old_hud.visible = false
    preview_active = true
    quest_completed = false
    step_index = 0
    message_elapsed = 0.0
    var spawn := _world_point(selected_quest.get("spawn_world", null))
    player.velocity = Vector3.ZERO
    player.global_position = spawn
    player.rotation.y = deg_to_rad(-float(selected_quest.get("spawn_bearing", 0.0)))
    if camera != null:
        camera.rotation.x = 0.0
    hud_layer.visible = true
    _show_current_step()
    print("QUESTLAB_PLAYTEST_STARTED: quest=", selected_quest.get("id", ""),
        " spawn=", spawn)
    return true

func deactivate_preview() -> void:
    if not preview_active:
        return
    preview_active = false
    hud_layer.visible = false
    player.velocity = Vector3.ZERO
    player.global_transform = saved_transform
    var camera := player.get_node_or_null("Camera3D") as Camera3D
    if camera != null:
        camera.rotation.x = saved_camera_pitch
    var overlay := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
    if overlay != null:
        overlay.visible = saved_map_visible
    if story != null:
        story.set_process(true)
        story.set_process_unhandled_input(true)
        var old_hud := story.get_node_or_null("ChapterOneHUD") as CanvasLayer
        if old_hud != null:
            old_hud.visible = true
        if story.has_method("_update_focus"):
            story.call("_update_focus")
    print("QUESTLAB_PLAYTEST_EXITED: restored=true")

func _show_current_step() -> void:
    var step := _current_step()
    if step.is_empty():
        quest_completed = true
        objective_label.text = "QUEST LAB / ЗАДАНИЕ ЗАВЕРШЕНО"
        detail_label.text = str(selected_quest.get("title", ""))
        distance_label.text = "F6 — вернуться к прежнему прологу"
        print("QUESTLAB_PLAYTEST_COMPLETE: quest=", selected_quest.get("id", ""))
        return
    var steps: Array = selected_quest.get("steps", [])
    objective_label.text = "QUEST LAB / " + str(selected_quest.get("title", ""))
    detail_label.text = "%d/%d  %s" % [step_index + 1, steps.size(), str(step.get("title", ""))]
    distance_label.text = "F6 — выйти из теста"
    subtitle_label.text = str(step.get("text", ""))
    message_elapsed = 0.0

func _advance_step() -> void:
    step_index += 1
    _show_current_step()

func _process(delta: float) -> void:
    if not preview_active or quest_completed or player == null:
        return
    var step := _current_step()
    if step.is_empty():
        return
    var step_type := str(step.get("type", ""))
    if step_type == "reach":
        if not has_target():
            distance_label.text = "Для задачи не задана точка · F6 — выход"
            return
        var at := get_target_world()
        var horizontal := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
        distance_label.text = "До цели: %d м     ·     F6 — выход" % int(ceil(horizontal))
        if horizontal <= REACH_RADIUS_M:
            _advance_step()
    elif step_type == "message":
        message_elapsed += delta
        distance_label.text = "Сообщение · F6 — выход"
        if message_elapsed >= MESSAGE_SECONDS:
            _advance_step()
    else:
        distance_label.text = "Этот тип условия пока не исполняется · F6 — выход"

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.physical_keycode == KEY_F6 or key.keycode == KEY_F6:
        if preview_active:
            deactivate_preview()
        else:
            activate_preview()
        get_viewport().set_input_as_handled()
