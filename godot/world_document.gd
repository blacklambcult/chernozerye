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
var locator_label: Label
var status_seconds := 0.0
const GUIDE_RANGE := 42.0
const BEACON_RANGE := 27.0

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
    locator_label = Label.new()
    locator_label.name = "NearestWorldFind"
    locator_label.anchor_left = 0.5
    locator_label.anchor_right = 0.5
    locator_label.anchor_top = 0.72
    locator_label.anchor_bottom = 0.72
    locator_label.offset_left = -355
    locator_label.offset_right = 355
    locator_label.offset_top = -33
    locator_label.offset_bottom = 0
    locator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    locator_label.add_theme_font_size_override("font_size", 13)
    locator_label.add_theme_color_override("font_color", Color("#f3d19d"))
    locator_label.add_theme_color_override("font_shadow_color", Color("#0b1514"))
    locator_label.add_theme_constant_override("shadow_offset_x", 2)
    locator_label.add_theme_constant_override("shadow_offset_y", 2)
    locator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    locator_label.visible = false
    hud.add_child(locator_label)

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
    # The first version put a flat 38 cm paper only 11 cm above the road.
    # Elevate it to eye-search height on a modest field crate, retaining
    # the actual Quest Lab world coordinate and pickup radius.
    _box(node, "FieldCrate", Vector3(0.64, 0.43, 0.53),
        Vector3(0, 0.24, 0), Color("#493d32"))
    _box(node, "CrateTop", Vector3(0.68, 0.055, 0.57),
        Vector3(0, 0.485, 0), Color("#675143"))
    if kind == "note":
        var sheet := _box(node, "Paper", Vector3(0.38, 0.014, 0.27),
            Vector3(0, 0.527, 0), Color("#e2d0ac"))
        sheet.rotation.y = 0.18
        for i in range(3):
            var ink := _box(node, "Ink%d" % i, Vector3(0.23, 0.002, 0.009),
                Vector3(0, 0.536, -0.06 + i * 0.055), Color("#625748"))
            ink.rotation.y = 0.18
    else:
        # Low-poly abstract key/loot placeholder until Model Lab assets are
        # linked to catalog items. No unrelated weapon models are generated.
        _box(node, "KeyShaft", Vector3(0.27, 0.055, 0.06),
            Vector3(0.045, 0.58, 0), Color("#75634b"))
        _box(node, "KeyTooth", Vector3(0.06, 0.055, 0.12),
            Vector3(0.165, 0.58, 0.045), Color("#665941"))
        var ring := MeshInstance3D.new()
        ring.name = "KeyHandle"
        var torus := TorusMesh.new()
        torus.inner_radius = 0.052
        torus.outer_radius = 0.086
        torus.rings = 7
        torus.ring_segments = 5
        ring.mesh = torus
        ring.position = Vector3(-0.115, 0.58, 0)
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
    prompt.position = Vector3(0, 1.35, 0)
    node.add_child(prompt)
    var signal_mesh := MeshInstance3D.new()
    signal_mesh.name = "AmberQuestGlint"
    var glint := SphereMesh.new()
    glint.radius = 0.075
    glint.height = 0.15
    signal_mesh.mesh = glint
    signal_mesh.position = Vector3(0, 1.54, 0)
    var glow := _paper_material(Color("#f0ad66"))
    glow.emission_enabled = true
    glow.emission = Color("#faac65")
    glow.emission_energy_multiplier = 1.9
    signal_mesh.material_override = glow
    node.add_child(signal_mesh)
    var light := OmniLight3D.new()
    light.name = "FindableWarmLight"
    light.light_color = Color("#ffb97a")
    light.light_energy = 0.65
    light.omni_range = 3.7
    light.shadow_enabled = false
    light.position = Vector3(0, 1.35, 0)
    node.add_child(light)
    var beacon := Label3D.new()
    beacon.name = "DistantFindBeacon"
    beacon.text = "✦  НАХОДКА / " + ("ЗАПИСКА" if kind=="note" else "ПРЕДМЕТ")
    beacon.font_size = 38
    beacon.pixel_size = 0.004
    beacon.outline_size = 6
    beacon.modulate = Color("#f6c897")
    beacon.outline_modulate = Color("#11191a")
    beacon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    beacon.no_depth_test = true
    beacon.position = Vector3(0, 2.12, 0)
    node.add_child(beacon)

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

func _nearest_collectible(max_distance: float = PICKUP_RADIUS) -> Dictionary:
    if not _can_pickup():
        return {}
    var nearest: Dictionary = {}
    var best := max_distance * max_distance
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

func _direction_hint(entry: Dictionary) -> String:
    if player == null:
        return "↑"
    var at: Vector3 = entry["position"]
    var direction := at - player.global_position
    direction.y = 0
    if direction.length_squared() < 0.1:
        return "↑"
    direction = direction.normalized()
    var eye := player.get_node_or_null("Camera3D") as Camera3D
    var facing := -eye.global_transform.basis.z if eye != null else -player.global_transform.basis.z
    var right := eye.global_transform.basis.x if eye != null else player.global_transform.basis.x
    facing.y = 0
    right.y = 0
    var front := direction.dot(facing.normalized())
    var side := direction.dot(right.normalized())
    if front > 0.65:
        return "↑" if absf(side) < 0.32 else ("↗" if side>0 else "↖")
    if front < -0.65:
        return "↓" if absf(side) < 0.32 else ("↘" if side>0 else "↙")
    return "→" if side > 0 else "←"

func _process(delta: float) -> void:
    if status_seconds > 0.0:
        status_seconds = maxf(0.0, status_seconds - delta)
        if status_label != null:
            status_label.visible = status_seconds > 0.0
    var nearest := _nearest_collectible()
    var guide := _nearest_collectible(GUIDE_RANGE)
    if locator_label != null:
        locator_label.visible = not guide.is_empty()
        if not guide.is_empty():
            var near_at: Vector3 = guide["position"]
            var d := Vector2(player.global_position.x-near_at.x,
                player.global_position.z-near_at.z).length()
            var label_name := str(guide["title"])
            if label_name.length() > 35:
                label_name = label_name.substr(0,32) + "…"
            locator_label.text = "✦  НАХОДКА  /  " + label_name + "   " +                 _direction_hint(guide) + "  " + str(int(ceil(d))) + " м  ·  E вблизи"
    for entry in entries:
        var node := entry["node"] as Node3D
        var in_quest: bool = quest_runtime != null and quest_runtime.get("preview_active") == true
        node.visible = not _is_collected(entry) and not in_quest
        var label := node.get_node_or_null("PickupPrompt") as Label3D
        if label != null:
            label.visible = node.visible and not nearest.is_empty() \
                and nearest.get("id") == entry.get("id")
        var beacon := node.get_node_or_null("DistantFindBeacon") as Label3D
        if beacon != null:
            var at: Vector3 = entry["position"]
            var dx := player.global_position.x-at.x if player != null else 100000.0
            var dz := player.global_position.z-at.z if player != null else 100000.0
            var in_range := dx*dx+dz*dz <= BEACON_RANGE*BEACON_RANGE
            beacon.visible = node.visible and in_range and not guide.is_empty() \
                and guide.get("id")==entry.get("id")
        var light := node.get_node_or_null("FindableWarmLight") as OmniLight3D
        if light != null:
            light.visible = node.visible

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
