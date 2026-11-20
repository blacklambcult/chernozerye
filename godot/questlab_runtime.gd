extends Node
# QUEST LAB PLAYTEST — F6 original authored mission, F7 interaction test.
# Opt-in, isolated and reversible: the original prologue stays unchanged.
const DATA_PATH := "res://questlab_runtime.json"
const DEMO_PATH := "res://questlab_interactions_demo.json"
const MARKER_SCRIPT = preload("res://questlab_playtest_marker.gd")
const REACH_RADIUS_M := 8.0
const INTERACTION_RADIUS_M := 3.0
const MESSAGE_SECONDS := 3.5

var snapshot_mode := false
var player: CharacterBody3D
var story: Node
var note_archive: Node
var pending_document_id := ""
var missions: Array = []
var selected_quest: Dictionary = {}
var authored_quest: Dictionary = {}
var demo_quest: Dictionary = {}
var demo_active := false
var collected_items: Array[String] = []
var marker_root: Node3D
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
    note_archive = get_parent().get_node_or_null("NoteArchive")
    if note_archive != null:
        note_archive.reader_closed.connect(_on_document_closed)
    _create_hud()
    if snapshot_mode:
        if not activate_preview():
            hud_layer.visible = true
            objective_label.text = "Снимок Studio: квест не поддерживается в этой версии"
        return
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
    authored_quest = selected_quest
    _load_demo()
    if not selected_quest.is_empty():
        var steps: Array = selected_quest.get("steps", [])
        print("QUESTLAB_RUNTIME_READY: quests=", missions.size(),
            " steps=", steps.size(), " key=F6 demo=F7")

func _load_demo() -> void:
    if not FileAccess.file_exists(DEMO_PATH):
        return
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEMO_PATH))
    if not doc is Dictionary or str(doc.get("schema", "")) != "chernozerye.questlab.runtime-1":
        push_warning("QUESTLAB_DEMO_BAD_SCHEMA")
        return
    var entries: Variant = doc.get("quests", [])
    if entries is Array and not entries.is_empty() and entries[0] is Dictionary:
        demo_quest = entries[0]
        print("QUESTLAB_INTERACTION_DEMO_READY: steps=", (demo_quest.get("steps", []) as Array).size())


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

func activate_preview(use_demo: bool = false) -> bool:
    if preview_active or player == null:
        return false
    if use_demo:
        if demo_quest.is_empty():
            return false
    elif authored_quest.is_empty():
        return false
    if story != null and (story.get("inside_home") == true or story.get("journal_open") == true):
        return false
    if player.get("controls_locked") == true:
        return false
    selected_quest = demo_quest if use_demo else authored_quest
    demo_active = use_demo
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
    collected_items.clear()
    pending_document_id = ""
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
        " spawn=", spawn, " demo=", demo_active)
    return true

func deactivate_preview() -> void:
    if not preview_active:
        return
    preview_active = false
    pending_document_id = ""
    if note_archive != null and note_archive.call("is_open"):
        note_archive.call("close_all")
    _clear_marker()
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
    selected_quest = authored_quest
    demo_active = false
    print("QUESTLAB_PLAYTEST_EXITED: restored=true")

func _clear_marker() -> void:
    if marker_root != null:
        remove_child(marker_root)
        marker_root.queue_free()
        marker_root = null

func _spawn_marker(step: Dictionary) -> void:
    _clear_marker()
    if not step.get("target_world") is Array:
        return
    if not ["reach", "interact", "collect"].has(str(step.get("type", ""))):
        return
    marker_root = Node3D.new()
    marker_root.set_script(MARKER_SCRIPT)
    marker_root.call("configure", step)
    add_child(marker_root)
    marker_root.global_position = _world_point(step["target_world"])
    print("QUESTLAB_MARKER_SPAWNED: type=", step.get("type", ""),
        " id=", step.get("object_id", ""), " source=", step.get("target_source", "free_point"))

func _exit_hint() -> String:
    if snapshot_mode:
        return "Снимок Studio"
    return "F7 — выход из теста" if demo_active else "F6 — выход из теста"

func _distance_to_target() -> float:
    var at := get_target_world()
    return Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()

func interact_selected() -> bool:
    if not preview_active or quest_completed or player == null:
        return false
    if not pending_document_id.is_empty():
        return false
    if player.get("controls_locked") == true:
        return false
    var current := _current_step()
    var kind := str(current.get("type", ""))
    if not ["interact", "collect"].has(kind) or not has_target():
        return false
    if _distance_to_target() > INTERACTION_RADIUS_M:
        return false
    if kind == "collect":
        var item_id := str(current.get("object_id", ""))
        if item_id.is_empty():
            item_id = str(current.get("id", ""))
        var document: Variant = current.get("document")
        if document is Dictionary and not str(document.get("body", "")).is_empty() \
                and note_archive != null:
            var paper_title := str(document.get("title", "Записка"))
            var paper_body := str(document.get("body", ""))
            if not note_archive.call("collect_and_read", item_id, paper_title,
                    paper_body, "Quest Lab / " + str(selected_quest.get("id", ""))):
                return false
            pending_document_id = item_id
            if not collected_items.has(item_id):
                collected_items.append(item_id)
            print("QUESTLAB_ITEM_COLLECTED_AND_OPENED: id=", item_id)
            # Closing the reader with E completes this objective.
            return true
        if not collected_items.has(item_id):
            collected_items.append(item_id)
        print("QUESTLAB_ITEM_COLLECTED: id=", item_id)
    else:
        print("QUESTLAB_OBJECT_INTERACTED: id=", current.get("object_id", ""),
            " step=", current.get("id", ""))
    _advance_step()
    return true

func _on_document_closed(id: String) -> void:
    if preview_active and not pending_document_id.is_empty() and id == pending_document_id:
        pending_document_id = ""
        print("QUESTLAB_DOCUMENT_READ: id=", id)
        _advance_step()

func _show_current_step() -> void:
    _clear_marker()
    var step := _current_step()
    if step.is_empty():
        quest_completed = true
        objective_label.text = "QUEST LAB / ЗАДАНИЕ ЗАВЕРШЕНО"
        detail_label.text = str(selected_quest.get("title", ""))
        distance_label.text = _exit_hint() + " · собрано: %d" % collected_items.size()
        print("QUESTLAB_PLAYTEST_COMPLETE: quest=", selected_quest.get("id", ""))
        return
    var steps: Array = selected_quest.get("steps", [])
    objective_label.text = "QUEST LAB / " + str(selected_quest.get("title", ""))
    detail_label.text = "%d/%d  %s" % [step_index + 1, steps.size(), str(step.get("title", ""))]
    distance_label.text = _exit_hint()
    # Document contents never appear as subtitles; only the task instruction.
    subtitle_label.text = str(step.get("text", ""))
    message_elapsed = 0.0
    _spawn_marker(step)

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
            distance_label.text = "Для задачи не задана точка · " + _exit_hint()
            return
        var at := get_target_world()
        var horizontal := Vector2(player.global_position.x - at.x, player.global_position.z - at.z).length()
        distance_label.text = "До цели: %d м     ·     %s" % [int(ceil(horizontal)), _exit_hint()]
        if horizontal <= REACH_RADIUS_M:
            _advance_step()
    elif step_type == "message":
        message_elapsed += delta
        distance_label.text = "Сообщение · " + _exit_hint()
        if message_elapsed >= MESSAGE_SECONDS:
            _advance_step()
    elif step_type == "interact" or step_type == "collect":
        if not has_target():
            distance_label.text = "Назначь объект или точку в Quest Lab · " + _exit_hint()
            return
        var horizontal := _distance_to_target()
        var kind := str(step.get("object_type", "")).to_upper()
        var object_hint := " · GEO LAB / " + kind if str(step.get("target_source", "")) == "geo_lab_id" else ""
        if horizontal <= INTERACTION_RADIUS_M:
            var action := "E — ВЗЯТЬ И ПРОЧИТАТЬ" if step_type == "collect" \
                and step.get("document") is Dictionary else "E — ПОДОБРАТЬ" if step_type == "collect" else "E — ОСМОТРЕТЬ"
            distance_label.text = action + object_hint + "     ·     " + _exit_hint()
        else:
            distance_label.text = "До цели: %d м%s     ·     %s" % [int(ceil(horizontal)), object_hint, _exit_hint()]
    else:
        distance_label.text = "Тип шага не поддерживается · " + _exit_hint()

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var f6 := key.physical_keycode == KEY_F6 or key.keycode == KEY_F6
    var f7 := key.physical_keycode == KEY_F7 or key.keycode == KEY_F7
    if (f6 or f7) and not snapshot_mode:
        if preview_active:
            deactivate_preview()
        else:
            activate_preview(f7)
        get_viewport().set_input_as_handled()
    elif preview_active and (key.physical_keycode == KEY_E or key.keycode == KEY_E):
        if note_archive != null and note_archive.call("is_open"):
            return
        if interact_selected():
            get_viewport().set_input_as_handled()
