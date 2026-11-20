extends Node3D
# One persistent world collectible sourced from the *compiled* Quest Lab JSON.
# Its coordinates and text share the exact same source as the F7 playtest.
const DATA_FILE := "res://questlab_interactions_demo.json"
const INTERACT_RADIUS := 2.8
var player: CharacterBody3D
var archive: Node
var quest_runtime: Node
var document_id := ""
var document_title := ""
var document_body := ""
var note_root: Node3D
var hint: Label3D
var has_document_data := false

func _ready() -> void:
    name = "WorldDocument"
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    archive = get_parent().get_node_or_null("NoteArchive")
    quest_runtime = get_parent().get_node_or_null("QuestLabRuntime")
    _load_from_quest()
    if not has_document_data:
        push_warning("WORLD_DOCUMENT_DATA_MISSING")
        return
    _build_note()
    _process(0.0)
    print("WORLD_DOCUMENT_READY: id=", document_id,
        " has_archive=", archive != null)

func _load_from_quest() -> void:
    if not FileAccess.file_exists(DATA_FILE):
        return
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
    if not data is Dictionary:
        return
    for quest in data.get("quests", []):
        if not quest is Dictionary:
            continue
        for step in quest.get("steps", []):
            if not step is Dictionary or str(step.get("type", "")) != "collect":
                continue
            var note: Variant = step.get("document", null)
            var loc: Variant = step.get("target_world", null)
            if not note is Dictionary or not loc is Array or loc.size() != 3:
                continue
            document_id = str(step.get("object_id", ""))
            if document_id.is_empty():
                document_id = str(step.get("id", ""))
            document_title = str(note.get("title", ""))
            document_body = str(note.get("body", ""))
            if document_id.is_empty() or document_title.is_empty() or document_body.is_empty():
                continue
            global_position = Vector3(float(loc[0]), float(loc[1]), float(loc[2]))
            has_document_data = true
            return

func _build_note() -> void:
    note_root = Node3D.new()
    note_root.name = "SurveyedVillagePaper"
    add_child(note_root)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#bba889")
    material.roughness = 0.94
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    var paper := MeshInstance3D.new()
    paper.name = "WorldPaperMesh"
    var page := BoxMesh.new()
    page.size = Vector3(0.36, 0.012, 0.26)
    paper.mesh = page
    paper.material_override = material
    paper.rotation.y = -0.27
    paper.position.y = 0.16
    note_root.add_child(paper)
    var mark := MeshInstance3D.new()
    mark.name = "InkOnPaper"
    var stripe := BoxMesh.new()
    stripe.size = Vector3(0.22, 0.002, 0.011)
    mark.mesh = stripe
    var ink := StandardMaterial3D.new()
    ink.albedo_color = Color("#554a3d")
    mark.material_override = ink
    mark.position = Vector3(-0.017, 0.169, -0.025)
    mark.rotation.y = -0.27
    note_root.add_child(mark)
    hint = Label3D.new()
    hint.name = "WorldNotePrompt"
    hint.text = "E / ПОДНЯТЬ ЗАПИСКУ"
    hint.font_size = 28
    hint.pixel_size = 0.003
    hint.outline_size = 5
    hint.modulate = Color("#ddcaab")
    hint.outline_modulate = Color("#151e1f")
    hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    hint.no_depth_test = true
    hint.position = Vector3(0, 0.62, 0)
    note_root.add_child(hint)

func _can_read_now() -> bool:
    if not has_document_data or archive == null or player == null:
        return false
    if archive.call("has_document", document_id):
        return false
    if archive.call("is_open"):
        return false
    if quest_runtime != null and quest_runtime.get("preview_active") == true:
        return false
    if player.get("controls_locked") == true:
        return false
    var diff := player.global_position - global_position
    return Vector2(diff.x, diff.z).length() <= INTERACT_RADIUS

func _process(_delta: float) -> void:
    if not has_document_data or note_root == null or archive == null:
        return
    var in_quest := quest_runtime != null and quest_runtime.get("preview_active") == true
    note_root.visible = not archive.call("has_document", document_id) and not in_quest
    hint.visible = note_root.visible and _can_read_now()

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey or not has_document_data:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var code := key.physical_keycode
    var letter := char(key.unicode).to_lower() if key.unicode != 0 else ""
    if code != KEY_E and key.keycode != KEY_E and letter != "у":
        return
    if _can_read_now() and archive.call("collect_and_read",
            document_id, document_title, document_body, "Geo Lab / village"):
        note_root.visible = false
        print("WORLD_DOCUMENT_COLLECTED: id=", document_id)
        get_viewport().set_input_as_handled()
