extends Node
# Persistent, game-wide field journal. All notes use a single reader UI,
# including StoryPrologue and Quest Lab / permanent village collectibles.
signal reader_closed(document_id: String)
signal mode_changed(new_mode: String)

const SAVE_FILE := "user://chernozerye_field_documents_v1.json"
const SCHEMA := "chernozerye.field_documents"
const VERSION := 1
const GOLD := Color("#bc9872")
const PAPER := Color("#d9c4a4")
const INK := Color("#302b26")

var player: CharacterBody3D
var mode := "closed"
var current_document_id := ""
var return_to_journal := false
var collected_documents: Array[Dictionary] = []
var collected_items: Array[Dictionary] = []
var saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var previously_locked := false
var canvas: CanvasLayer
var backdrop: ColorRect
var journal_panel: PanelContainer
var reader_panel: PanelContainer
var journal_list: VBoxContainer
var item_list: VBoxContainer
var overview_label: Label
var reader_heading: Label
var reader_id_label: Label
var reader_body: RichTextLabel
var saved_status: Label

var session_only := false

func _ready() -> void:
    name = "NoteArchive"
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    if not session_only:
        _load_archive()
    _build_overlay()
    print("NOTE_ARCHIVE_READY: saved=", collected_documents.size(), " key=J reader=E")

func _style(bg: Color, border: Color, pad: int) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.border_color = border
    box.set_border_width_all(1)
    box.content_margin_left = pad
    box.content_margin_right = pad
    box.content_margin_top = pad
    box.content_margin_bottom = pad
    return box

func _text(value: String, font_size: int, tint: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", tint)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return label

func _make_button(caption: String, action: Callable) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 42)
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", PAPER)
    button.add_theme_stylebox_override("normal", _style(Color("#252826"), Color("#635747"), 9))
    button.add_theme_stylebox_override("hover", _style(Color("#3a3b33"), GOLD, 9))
    button.add_theme_stylebox_override("pressed", _style(Color("#514333"), GOLD, 9))
    button.pressed.connect(action)
    return button

func _container(content: Control) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.custom_minimum_size = Vector2(600, 430)
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    panel.add_theme_stylebox_override("panel", _style(Color("#111b1d"), Color("#77634a"), 20))
    panel.add_child(content)
    return panel

func _build_overlay() -> void:
    canvas = CanvasLayer.new()
    canvas.name = "FieldJournalOverlay"
    canvas.layer = 45
    add_child(canvas)
    backdrop = ColorRect.new()
    backdrop.name = "JournalBackdrop"
    backdrop.color = Color(0.015, 0.019, 0.018, 0.88)
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.add_child(backdrop)

    var center := CenterContainer.new()
    center.name = "ArchiveCenter"
    center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    center.mouse_filter = Control.MOUSE_FILTER_IGNORE
    backdrop.add_child(center)
    var screen := Control.new()
    screen.name = "ArchiveScreens"
    screen.custom_minimum_size = Vector2(730, 520)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    center.add_child(screen)

    var journal_stack := VBoxContainer.new()
    journal_stack.add_theme_constant_override("separation", 12)
    journal_panel = _container(journal_stack)
    journal_panel.name = "FieldJournalPanel"
    journal_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.add_child(journal_panel)
    journal_stack.add_child(_text("ПОЛЕВОЙ ЖУРНАЛ  /  ЧЕРНОЗЁРЬЕ", 20, PAPER))
    journal_stack.add_child(_text("ГЛАВА 1  •  ДОКУМЕНТЫ И СВИДЕТЕЛЬСТВА", 11, GOLD))
    overview_label = _text("Записи экспедиции", 12, Color("#afc0b8"))
    journal_stack.add_child(overview_label)
    journal_stack.add_child(_text("НАЙДЕННЫЕ ЗАПИСКИ", 12, PAPER))
    var journal_scroll := ScrollContainer.new()
    journal_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    journal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    journal_stack.add_child(journal_scroll)
    journal_list = VBoxContainer.new()
    journal_list.name = "Documents"
    journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    journal_list.add_theme_constant_override("separation", 7)
    journal_scroll.add_child(journal_list)
    journal_stack.add_child(_text("НАЙДЕННЫЕ ПРЕДМЕТЫ", 12, PAPER))
    var item_scroll := ScrollContainer.new()
    item_scroll.custom_minimum_size = Vector2(0, 75)
    item_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    journal_stack.add_child(item_scroll)
    item_list = VBoxContainer.new()
    item_list.name = "WorldItems"
    item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    item_list.add_theme_constant_override("separation", 6)
    item_scroll.add_child(item_list)
    journal_stack.add_child(_text("Выбери запись мышью или клавишами ↑ / ↓ и Enter.   J — закрыть журнал.", 11, GOLD))

    var reader_stack := VBoxContainer.new()
    reader_stack.add_theme_constant_override("separation", 10)
    reader_panel = _container(reader_stack)
    reader_panel.name = "DocumentReaderPanel"
    reader_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    reader_panel.add_theme_stylebox_override("panel", _style(Color("#c7b697"), Color("#564b38"), 26))
    screen.add_child(reader_panel)
    var kicker := _text("ЧЕРНОЗЁРЬЕ  /  ЛИЧНЫЙ АРХИВ  /  НАЙДЕННАЯ БУМАГА", 11, Color("#75634a"))
    reader_stack.add_child(kicker)
    reader_heading = _text("", 25, INK)
    reader_stack.add_child(reader_heading)
    reader_id_label = _text("", 10, Color("#776650"))
    reader_stack.add_child(reader_id_label)
    var separator := HSeparator.new()
    reader_stack.add_child(separator)
    reader_body = RichTextLabel.new()
    reader_body.name = "DocumentBody"
    reader_body.bbcode_enabled = false
    reader_body.scroll_active = true
    reader_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    reader_body.add_theme_font_size_override("normal_font_size", 19)
    reader_body.add_theme_color_override("default_color", Color("#322d26"))
    reader_body.add_theme_constant_override("line_separation", 8)
    reader_stack.add_child(reader_body)
    saved_status = _text("ДОКУМЕНТ ЗАПИСАН В ЖУРНАЛ", 11, Color("#514a3a"))
    reader_stack.add_child(saved_status)
    var close_button := _make_button("E  /  ЗАКРЫТЬ", func() -> void: close_reader())
    close_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    close_button.add_theme_color_override("font_color", Color("#d6bd99"))
    reader_stack.add_child(close_button)
    backdrop.visible = false
    journal_panel.visible = false
    reader_panel.visible = false

func _load_archive() -> void:
    if not FileAccess.file_exists(SAVE_FILE):
        return
    var stored: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_FILE))
    if not stored is Dictionary or stored.get("schema") != SCHEMA or stored.get("version") != VERSION:
        push_warning("NOTE_ARCHIVE_SAVE_INVALID")
        return
    var found: Variant = stored.get("documents", [])
    if not found is Array:
        return
    for item in found.slice(0, 100):
        if not item is Dictionary:
            continue
        var id := str(item.get("id", ""))
        var title := str(item.get("title", ""))
        var body := str(item.get("body", ""))
        if id.is_empty() or id.length() > 120 or title.length() > 140 or body.length() > 4000:
            continue
        if title.is_empty() or body.is_empty() or has_document(id):
            continue
        collected_documents.append({"id":id,"title":title,"body":body,
            "source":str(item.get("source", "field")).left(80)})
    # Backwards compatible with earlier journal saves containing documents only.
    var found_items: Variant = stored.get("items", [])
    if found_items is Array:
        for entry in found_items.slice(0, 150):
            if not entry is Dictionary:
                continue
            var item_id := str(entry.get("id", ""))
            var item_title := str(entry.get("title", ""))
            var description := str(entry.get("description", ""))
            if item_id.is_empty() or item_id.length() > 120 or item_title.is_empty()                     or item_title.length() > 140 or description.length() > 4000 or has_item(item_id):
                continue
            collected_items.append({"id":item_id,"title":item_title,
                "description":description,"source":str(entry.get("source", "field")).left(80)})

func _save_archive() -> void:
    if session_only:
        return
    var handle := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
    if handle == null:
        push_warning("NOTE_ARCHIVE_SAVE_FAILED: " + str(FileAccess.get_open_error()))
        return
    handle.store_string(JSON.stringify({
        "schema":SCHEMA,"version":VERSION,"documents":collected_documents,
        "items":collected_items
    }, "\t") + "\n")
    handle.close()

func has_document(id: String) -> bool:
    for record in collected_documents:
        if str(record.get("id", "")) == id:
            return true
    return false

func get_document(id: String) -> Dictionary:
    for record in collected_documents:
        if str(record.get("id", "")) == id:
            return record.duplicate(true)
    return {}

func collect_document(id: String, title: String, body: String, source: String = "field") -> bool:
    if id.is_empty() or id.length() > 120 or title.is_empty() or title.length() > 140 \
            or body.is_empty() or body.length() > 4000:
        return false
    if not has_document(id):
        collected_documents.append({"id":id,"title":title,"body":body,"source":source.left(80)})
        _save_archive()
        print("FIELD_DOCUMENT_COLLECTED: id=", id, " count=", collected_documents.size())
    return true

func has_item(id: String) -> bool:
    for record in collected_items:
        if str(record.get("id", "")) == id:
            return true
    return false

func get_item(id: String) -> Dictionary:
    for record in collected_items:
        if str(record.get("id", "")) == id:
            return record.duplicate(true)
    return {}

func collect_item(id: String, title: String, description: String,
        source: String = "field") -> bool:
    if id.is_empty() or id.length() > 120 or title.is_empty()             or title.length() > 140 or description.length() > 4000:
        return false
    if not has_item(id):
        collected_items.append({"id":id,"title":title,
            "description":description,"source":source.left(80)})
        _save_archive()
        print("FIELD_ITEM_COLLECTED: id=", id, " count=", collected_items.size())
    return true

func is_open() -> bool:
    return mode != "closed"

func is_reader_open() -> bool:
    return mode == "reader"

func _show_mode(next: String) -> void:
    if mode == next:
        return
    if mode == "closed" and next != "closed":
        saved_mouse_mode = Input.mouse_mode
        previously_locked = player != null and player.get("controls_locked") == true
    mode = next
    backdrop.visible = next != "closed"
    journal_panel.visible = next == "journal"
    reader_panel.visible = next == "reader"
    if next != "closed":
        if player != null and player.has_method("set_controls_locked"):
            player.call("set_controls_locked", true)
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    else:
        if player != null and player.has_method("set_controls_locked"):
            player.call("set_controls_locked", previously_locked)
        Input.mouse_mode = saved_mouse_mode
    mode_changed.emit(mode)

func _refresh_journal() -> void:
    for child in journal_list.get_children():
        journal_list.remove_child(child)
        child.queue_free()
    var story := get_parent().get_node_or_null("StoryPrologue")
    if story != null and story.has_method("_objective_text"):
        var text_line := str(story.call("_objective_text"))
        if story.get("mask_found") == true:
            text_line += "\nУлика: деревянная маска обнаружена в доме."
        overview_label.text = text_line
    else:
        overview_label.text = "Чернозёрье · собранные документы"
    if collected_documents.is_empty():
        journal_list.add_child(_text("Записок пока нет. Найди бумагу и нажми E.", 13, Color("#b1bbaf")))
    for i in range(collected_documents.size()):
        var note: Dictionary = collected_documents[i]
        var id := str(note["id"])
        var button := _make_button("%02d  /  %s  ↗" % [i + 1, str(note["title"])],
            func() -> void: open_document(id, true))
        journal_list.add_child(button)
    for child in item_list.get_children():
        item_list.remove_child(child)
        child.queue_free()
    if collected_items.is_empty():
        item_list.add_child(_text("Предметов пока нет.", 12, Color("#9cafa6")))
    for i in range(collected_items.size()):
        var item: Dictionary = collected_items[i]
        var id := str(item["id"])
        var button := _make_button("%02d  /  %s  ↗" % [i + 1, str(item["title"])],
            func() -> void: open_item(id))
        item_list.add_child(button)

func open_item(id: String) -> bool:
    var item := get_item(id)
    if item.is_empty():
        return false
    return_to_journal = true
    current_document_id = "item:" + id
    reader_heading.text = str(item["title"])
    reader_id_label.text = "ПРЕДМЕТ / " + id.to_upper()
    reader_body.text = str(item["description"])
    reader_body.scroll_to_line(0)
    saved_status.text = "ПРЕДМЕТ В ИНВЕНТАРЕ  ·  J — ЖУРНАЛ"
    _show_mode("reader")
    print("FIELD_ITEM_OPENED: id=", id)
    return true

func open_journal() -> void:
    if mode == "reader":
        return
    _refresh_journal()
    return_to_journal = false
    _show_mode("journal")
    for control in journal_list.get_children():
        if control is Button:
            control.grab_focus()
            break

func toggle_journal() -> void:
    if mode == "reader":
        return
    if mode == "journal":
        _show_mode("closed")
    else:
        open_journal()

func open_document(id: String, from_journal: bool = false) -> bool:
    var doc := get_document(id)
    if doc.is_empty():
        return false
    return_to_journal = from_journal or mode == "journal"
    current_document_id = id
    reader_heading.text = str(doc["title"])
    reader_id_label.text = "ДОКУМЕНТ / %s" % id.to_upper()
    reader_body.text = str(doc["body"])
    reader_body.scroll_to_line(0)
    saved_status.text = "СОХРАНЕНО В ЖУРНАЛЕ  ·  J — ЖУРНАЛ"
    _show_mode("reader")
    print("FIELD_DOCUMENT_OPENED: id=", id)
    return true

func collect_and_read(id: String, title: String, body: String,
        source: String = "field") -> bool:
    if is_open():
        return false
    if not collect_document(id, title, body, source):
        return false
    return open_document(id, false)

func close_reader() -> void:
    if mode != "reader":
        return
    var id := current_document_id
    current_document_id = ""
    var return_to_list := return_to_journal
    return_to_journal = false
    if return_to_list:
        _refresh_journal()
        _show_mode("journal")
    else:
        _show_mode("closed")
    reader_closed.emit(id)
    print("FIELD_DOCUMENT_CLOSED: id=", id)

func close_all() -> void:
    if mode == "reader":
        return_to_journal = false
        close_reader()
    elif mode == "journal":
        _show_mode("closed")

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var code := key.physical_keycode
    var letter := char(key.unicode).to_lower() if key.unicode != 0 else ""
    if mode == "reader" and (code == KEY_E or key.keycode == KEY_E or letter == "у"):
        close_reader()
        get_viewport().set_input_as_handled()
        return
    if mode == "reader":
        return
    if code == KEY_J or key.keycode == KEY_J or letter == "о":
        toggle_journal()
        get_viewport().set_input_as_handled()
