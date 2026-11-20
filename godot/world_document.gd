extends Node3D
# Persistent, independently authored world collectibles compiled from Quest Lab.
# This node owns all pickup interactions; F7 remains an isolated playtest.
const DATA_FILE := "res://world_items.json"
const PICKUP_RADIUS := 2.8
var player: CharacterBody3D
var archive: Node
var quest_runtime: Node
var entries: Array[Dictionary] = []
var status_label: Label
var status_seconds := 0.0

func _ready() -> void:
    name = "WorldDocument"
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    archive = get_parent().get_node_or_null("NoteArchive")
    quest_runtime = get_parent().get_node_or_null("QuestLabRuntime")
    _make_pickup_hud()
    if not FileAccess.file_exists(DATA_FILE):
        push_warning("WORLD_ITEMS_NOT_COMPILED")
        return
    var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_FILE))
    if not source is Dictionary or str(source.get("schema", "")) != "chernozerye.questlab.runtime-1":
        push_warning("WORLD_ITEMS_BAD_FORMAT")
        return
    var authored: Variant = source.get("world_items", [])
    if not authored is Array:
        return
    for item in authored:
        if item is Dictionary:
            _register_item(item)
    _process(0.0)
    print("WORLD_ITEMS_READY: authored=", entries.size(), " independent_of_f7=true")

func _make_pickup_hud() -> void:
    var hud := CanvasLayer.new()
    hud.name = "WorldPickupFeedback"
    hud.layer = 22
    add_child(hud)
    status_label = Label.new()
    status_label.name = "PickedUpLabel"
    status_label.anchor_left = 0.5
    status_label.anchor_right = 0.5
    status_label.anchor_top = 0.8
    status_label.anchor_bottom = 0.8
    status_label.offset_left = -310
    status_label.offset_right = 310
    status_label.offset_top = -35
    status_label.offset_bottom = 0
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.add_theme_color_override("font_color", Color("#dfc8a4"))
    status_label.add_theme_font_size_override("font_size", 14)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(status_label)
    status_label.visible = false

func _paper_material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 0.95
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat

func _box(parent: Node3D, identifier: String, dimensions: Vector3,
        at: Vector3, color: Color) -> MeshInstance3D:
    var mesh := MeshInstance3D.new()
    mesh.name = identifier
    var shape := BoxMesh.new()
    shape.size = dimensions
    mesh.mesh = shape
    mesh.position = at
    mesh.material_override = _paper_material(color)
    parent.add_child(mesh)
    return mesh

func _make_visual(item: Dictionary, node: Node3D) -> void:
    var kind := str(item.get("type", "note"))
    if kind == "note":
        var sheet := _box(node, "Paper", Vector3(0.38, 0.014, 0.27),
            Vector3(0, 0.11, 0), Color("#d1bea0"))
        sheet.rotation.y = 0.18
        for i in range(3):
            var ink := _box(node, "Ink%d" % i, Vector3(0.23, 0.002, 0.009),
                Vector3(0, 0.119, -0.06 + i * 0.055), Color("#625748"))
            ink.rotation.y = 0.18
    else:
        # Low-poly abstract key/loot placeholder until Model Lab assets are
        # linked to catalog items. No unrelated weapon models are generated.
        _box(node, "KeyShaft", Vector3(0.27, 0.055, 0.06),
            Vector3(0.045, 0.17, 0), Color("#75634b"))
        _box(node, "KeyTooth", Vector3(0.06, 0.055, 0.12),
            Vector3(0.165, 0.17, 0.045), Color("#665941"))
        var ring := MeshInstance3D.new()
        ring.name = "KeyHandle"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.052
        torus.outer_radius = 0.086
        torus.rings = 7
        torus.ring_segments = 5
        ring.mesh = torus
        ring.position = Vector3(-0.115, 0.17, 0)
        ring.rotation.x = PI * 0.5
        ring.material_override = _paper_material(Color("#78664e"))
        node.add_child(ring)
    var prompt := Label3D.new()
    prompt.name = "PickupPrompt"
    prompt.text = "E / ЧИТАТЬ" if kind == "note" else "E / ПОДОБРАТЬ"
    prompt.font_size = 29
    prompt.pixel_size = 0.003
    prompt.outline_size = 5
    prompt.modulate = Color("#e8d2b0")
    prompt.outline_modulate = Color("#192324")
    prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    prompt.no_depth_test = true
    prompt.position = Vector3(0, 0.7, 0)
    node.add_child(prompt)

func _register_item(data: Dictionary) -> void:
    var id := str(data.get("id", ""))
    var kind := str(data.get("type", ""))
    var coords: Variant = data.get("position_world", null)
    if id.is_empty() or not ["note", "item"].has(kind) \
            or not coords is Array or coords.size() != 3:
        push_warning("WORLD_ITEM_SKIPPED: malformed entry")
        return
    for existing in entries:
        if str(existing.get("id", "")) == id:
            push_warning("WORLD_ITEM_DUPLICATE: " + id)
            return
    var at := Vector3(float(coords[0]), float(coords[1]), float(coords[2]))
    var instance := Node3D.new()
    instance.name = "Collectible_" + id
    instance.position = at
    _make_visual(data, instance)
    add_child(instance)
    entries.append({
        "id": id,
        "type": kind,
        "title": str(data.get("title", "")),
        "body": str(data.get("body", "")),
        "node": instance,
        "position": at
    })

func _is_collected(entry: Dictionary) -> bool:
    if archive == null:
        return false
    var id := str(entry.get("id", ""))
    if entry.get("type", "") == "note":
        return archive.call("has_document", id)
    return archive.call("has_item", id)

func _can_pickup() -> bool:
    return player != null and archive != null \
        and archive.call("is_open") == false \
        and player.get("controls_locked") != true \
        and (quest_runtime == null or quest_runtime.get("preview_active") != true)

func _nearest_collectible() -> Dictionary:
    if not _can_pickup():
        return {}
    var nearest: Dictionary = {}
    var best := PICKUP_RADIUS * PICKUP_RADIUS
    for entry in entries:
        if _is_collected(entry):
            continue
        var at: Vector3 = entry["position"]
        var dx := player.global_position.x - at.x
        var dz := player.global_position.z - at.z
        var distance2 := dx * dx + dz * dz
        if distance2 <= best:
            best = distance2
            nearest = entry
    return nearest

func _process(delta: float) -> void:
    if status_seconds > 0.0:
        status_seconds = maxf(0.0, status_seconds - delta)
        if status_label != null:
            status_label.visible = status_seconds > 0.0
    var nearest := _nearest_collectible()
    for entry in entries:
        var node := entry["node"] as Node3D
        var in_quest: bool = quest_runtime != null and quest_runtime.get("preview_active") == true
        node.visible = not _is_collected(entry) and not in_quest
        var label := node.get_node_or_null("PickupPrompt") as Label3D
        if label != null:
            label.visible = node.visible and not nearest.is_empty() \
                and nearest.get("id") == entry.get("id")

func _collect_nearest() -> bool:
    var entry := _nearest_collectible()
    if entry.is_empty():
        return false
    var id := str(entry["id"])
    var title := str(entry["title"])
    var body := str(entry["body"])
    var success := false
    if entry["type"] == "note":
        success = archive.call("collect_and_read", id, title, body, "World / Quest Lab")
    else:
        success = archive.call("collect_item", id, title, body, "World / Quest Lab")
        if success and status_label != null:
            status_label.text = "ПРЕДМЕТ ПОДОБРАН / " + title + "     ·     J — ЖУРНАЛ"
            status_seconds = 3.0
            status_label.visible = true
    if success:
        (entry["node"] as Node3D).visible = false
        print("WORLD_ITEM_COLLECTED: id=", id, " type=", entry["type"])
    return success

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var code := key.physical_keycode
    var letter := char(key.unicode).to_lower() if key.unicode != 0 else ""
    if code != KEY_E and key.keycode != KEY_E and letter != "у":
        return
    if _collect_nearest():
        get_viewport().set_input_as_handled()
