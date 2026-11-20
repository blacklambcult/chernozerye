extends Node3D
# Persistent, independently authored world collectibles compiled from Quest Lab.
# This node owns all pickup interactions; F7 remains an isolated playtest.
const DATA_FILE := "res://world_items.json"
const PICKUP_RADIUS := 2.8
var player: CharacterBody3D
var archive: Node
var quest_runtime: Node
var entries: Array[Dictionary] = []
func _ready() -> void:
    name = "WorldDocument"
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    archive = get_parent().get_node_or_null("NoteArchive")
    quest_runtime = get_parent().get_node_or_null("QuestLabRuntime")
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
    _validate_live_spawn()
    _process(0.0)
    print("WORLD_ITEMS_READY: authored=", entries.size(), " independent_of_f7=true")

func _validate_live_spawn() -> void:
    # Prior releases placed loot at the obsolete OSM spawn (130,-82) even
    # though the world now starts in the surveyed sector (-789.7,-268.6).
    # Check the ACTUAL spawned player, not a simulated old test position.
    if player == null:
        push_error("WORLD_ITEM_SPAWN_GUARD_FAILED: player not found")
        return
    var nearby := 0
    var nearest := INF
    for entry in entries:
        var at: Vector3 = entry["position"]
        var delta_pos := Vector2(at.x-player.global_position.x,
            at.z-player.global_position.z)
        var distance := delta_pos.length()
        nearest = minf(nearest, distance)
        if distance <= 27.0:
            nearby += 1
    if nearby < 3 or nearest > 10.0:
        push_error("WORLD_ITEM_SPAWN_GUARD_FAILED: nearest=%.1f nearby=%d at=%s"
            % [nearest, nearby, str(player.global_position)])
    else:
        print("WORLD_ITEM_SPAWN_GUARD_READY: within_27m=", nearby,
            " nearest=", snappedf(nearest, 0.1), " start=", player.global_position)

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
    prompt.no_depth_test = false
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

func quest_summary() -> Dictionary:
    var summary := {"total": 0, "collected": 0, "target": null}
    for entry in entries:
        if entry["type"] != "note":
            continue
        summary["total"] += 1
        if _is_collected(entry):
            summary["collected"] += 1
        elif summary["target"] == null:
            summary["target"] = entry["position"]
    return summary

func _process(_delta: float) -> void:
    var nearby := _nearest_collectible(10.0)
    for entry in entries:
        var node := entry["node"] as Node3D
        node.visible = not _is_collected(entry)
        var prompt := node.get_node("PickupPrompt") as Label3D
        prompt.visible = node.visible and nearby.get("id") == entry["id"]
        if prompt.visible:
            var at: Vector3 = entry["position"]
            var offset := at - player.global_position
            var distance := Vector2(offset.x, offset.z).length()
            if distance > PICKUP_RADIUS:
                prompt.text = str(entry["title"])
            else:
                prompt.text = "E / ЧИТАТЬ" if entry["type"] == "note" else "E / ПОДОБРАТЬ"

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
