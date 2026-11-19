extends Node
# Fearless Knights of the Cordon / Pre-Alpha 0.4.0
# Playable Chapter 1 slice: return home, investigate, face an unexplained sound.
# The house is anchored to one immutable feature ID preserved in the 710-object
# survey. The furnished interior is instanced separately to avoid changing
# surveyed buildings, fences, roads or procedural roof geometry.

const MANUAL_FILE := "res://manual_layout.json"
const HOME_ID := "a2273fc9-20b5-43a9-ab41-faccdc6283b3"
const ROOM_ORIGIN := Vector3(3200.0, 0.0, 3200.0)
const INTERACT_RANGE := 2.8
const GATE_RANGE := 5.0

var player: CharacterBody3D
var view_camera: Camera3D
var home_point := Vector2.ZERO
var gate_point := Vector2.ZERO
var inside_home := false
var note_found := false
var mask_found := false
var chapter_completed := false
var journal_open := false
var objective_label: Label
var distance_label: Label
var journal_hint_label: Label
var prompt_label: Label
var message_label: Label
var journal_panel: PanelContainer
var journal_text: Label
var wood := ShaderMaterial.new()
var interior: Node3D
var porch_sound := AudioStreamPlayer3D.new()
var door_handle: Node3D
var latch_motion: Tween
var waypoint: Label3D
var focus := ""
var outside_rotation := 0.0
var _last_prompt := ""
var _last_objective := ""
var _approach_stage := 0
var _approach_triggers := 0

func _ready() -> void:
    player = get_parent().get_node_or_null("Player") as CharacterBody3D
    if player == null:
        push_error("STORY_PROLOGUE_ERROR: player missing")
        return
    view_camera = player.get_node("Camera3D") as Camera3D
    if not _locate_home():
        push_error("STORY_PROLOGUE_ERROR: surveyed home missing")
        return
    _build_interior()
    _build_hud()
    _build_waypoint()
    _say("Ноябрь 2005 года. Два года вдали от дома. Теперь Чернозёрье встречает тебя тишиной.")
    print("STORY_PROLOGUE_READY: home=", HOME_ID,
        " gate_distance=", int(player.global_position.distance_to(_gate_location())),
        " room_created=", interior != null, " state=seek_home")
    set_process(true)

func _locate_home() -> bool:
    if not FileAccess.file_exists(MANUAL_FILE):
        return false
    var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANUAL_FILE))
    if not data is Dictionary:
        return false
    var features: Array = data.get("features", [])
    var polygon := PackedVector2Array()
    for feature in features:
        if not feature is Dictionary:
            continue
        if str(feature.get("id", "")) != HOME_ID:
            continue
        if str(feature.get("type", "")) != "house":
            return false
        for raw_point in feature.get("points", []):
            if raw_point is Array and raw_point.size() >= 2:
                polygon.append(Vector2(float(raw_point[0]), float(raw_point[1])))
        break
    if polygon.size() < 3:
        return false
    for p in polygon:
        home_point += p
    home_point /= float(polygon.size())
    var distance := INF
    var closest_road := home_point
    for feature in features:
        if not feature is Dictionary or str(feature.get("type", "")) != "road":
            continue
        var raw_points: Array = feature.get("points", [])
        for i in range(raw_points.size() - 1):
            var a: Vector2 = Vector2(float(raw_points[i][0]), float(raw_points[i][1]))
            var b: Vector2 = Vector2(float(raw_points[i + 1][0]), float(raw_points[i + 1][1]))
            var projected: Vector2 = Geometry2D.get_closest_point_to_segment(home_point, a, b)
            var d: float = home_point.distance_squared_to(projected)
            if d < distance:
                distance = d
                closest_road = projected
    # An interaction at the publicly accessible road edge avoids locking the
    # chapter behind currently imperfect fence and gate placement.
    if distance == INF:
        return false
    gate_point = closest_road
    return true

func _gate_location() -> Vector3:
    return Vector3(gate_point.x, 0.30, -gate_point.y)

func _make_material(color: Color) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = 0.0
    result.roughness = 1.0
    return result

func _solid_box(label: String, location: Vector3, dimensions: Vector3,
        color: Color, solid: bool = true) -> Node3D:
    var node: Node3D
    if solid:
        node = StaticBody3D.new()
        var collider := CollisionShape3D.new()
        var collision_shape := BoxShape3D.new()
        collision_shape.size = dimensions
        collider.shape = collision_shape
        node.add_child(collider)
    else:
        node = Node3D.new()
    node.name = label
    node.position = location
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    mesh_node.mesh = mesh
    mesh_node.material_override = _make_material(color)
    if label in ["Старые половицы", "Бревенчатая стена", "Старая стена", "Старый стол", "Потолок"]:
        mesh_node.material_override = wood
    node.add_child(mesh_node)
    interior.add_child(node)
    return node

func _story_marker(label: String, at: Vector3, color: Color,
        size: int = 28) -> Label3D:
    var marker := Label3D.new()
    marker.name = "StoryMarker"
    marker.text = label
    marker.position = at
    marker.font_size = size
    marker.pixel_size = 0.0045
    marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    marker.modulate = color
    marker.outline_size = 7
    marker.no_depth_test = false
    return marker

func _build_interior() -> void:
    wood.shader = preload("res://cabin_wood.gdshader")
    interior = Node3D.new()
    interior.name = "ChildhoodHomeInterior"
    interior.position = ROOM_ORIGIN
    interior.visible = false
    add_child(interior)
    _solid_box("Старые половицы", Vector3(0, -0.20, 0),
        Vector3(9.0, 0.4, 8.0), Color("#3d3731"))
    _solid_box("Потолок", Vector3(0, 3.65, 0),
        Vector3(9.0, 0.30, 8.0), Color("#302f2b"))
    for x in [-4.50, 4.50]:
        _solid_box("Бревенчатая стена", Vector3(float(x), 1.7, 0),
            Vector3(0.25, 3.50, 8.25), Color("#4b4139"))
    for z in [-4.05, 4.05]:
        _solid_box("Старая стена", Vector3(0, 1.7, float(z)),
            Vector3(9.1, 3.50, 0.25), Color("#514238"))
    for i in range(8):
        var x: float = -3.90 + float(i) * 1.10
        _solid_box("Изношенные доски", Vector3(x, 0.016, 0),
            Vector3(0.06, 0.025, 7.8), Color("#2d2926"), false)
    # A simple physical interior prototype, not a finished architectural model.
    _solid_box("Старый стол", Vector3(-2.1, 0.67, -0.55),
        Vector3(1.75, 0.13, 1.25), Color("#5d4c40"))
    for x in [-2.78, -1.43]:
        for z in [-1.00, -0.13]:
            _solid_box("Ножка стола", Vector3(float(x), 0.34, float(z)),
                Vector3(0.13, 0.65, 0.13), Color("#4c3a30"))
    _solid_box("Брошенная записка", Vector3(-2.1, 0.75, -0.55),
        Vector3(0.54, 0.025, 0.38), Color("#99917d"), false)
    _solid_box("Перевёрнутый стул", Vector3(2.0, 0.45, 0),
        Vector3(0.8, 0.85, 0.67), Color("#514438"))
    _solid_box("Старая печь", Vector3(3.0, 1.08, -2.8),
        Vector3(1.65, 2.15, 1.45), Color("#676762"))
    var pot := StaticBody3D.new()
    pot.name = "Глиняный горшок"
    pot.position = Vector3(2.63,2.39,-2.56)
    var pot_mesh := SphereMesh.new()
    pot_mesh.radial_segments = 9
    pot_mesh.rings = 4
    pot_mesh.radius = 0.24
    pot_mesh.height = 0.46
    var pottery := MeshInstance3D.new()
    pottery.mesh = pot_mesh
    pottery.material_override = _make_material(Color("#ab6440"))
    pot.add_child(pottery)
    var pot_shape := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 0.24
    pot_shape.shape = sphere
    pot.add_child(pot_shape)
    pot.add_to_group("breakable_pottery")
    interior.add_child(pot)
    _build_mask()
    _solid_box("Дверная рама", Vector3(0, 1.16, 3.85),
        Vector3(1.35, 2.3, 0.13), Color("#2b2824"), false)
    # A recessed-looking frosted sash on the west wall lights the writing surface.
    var glass := _solid_box("Матовое окно", Vector3(-4.34, 1.85, -0.55),
        Vector3(0.08, 1.24, 1.60), Color("#82969c"), false)
    var pane := glass.get_child(0) as MeshInstance3D
    var pane_material := pane.material_override as StandardMaterial3D
    pane_material.emission_enabled = true
    pane_material.emission = Color("#597382")
    for height in [1.19, 1.85, 2.51]:
        _solid_box("Оконный переплёт", Vector3(-4.27, height, -0.55),
            Vector3(0.14, 0.075, 1.78), Color("#403a31"), false)
    for depth in [-1.39, -0.55, 0.29]:
        _solid_box("Оконная стойка", Vector3(-4.27, 1.85, depth),
            Vector3(0.14, 1.38, 0.08), Color("#403a31"), false)
    _solid_box("Свеча", Vector3(-2.74,0.85,-0.89), Vector3(0.07,0.23,0.07), Color("#b9a580"), false)
    var wick := _solid_box("Огонёк", Vector3(-2.74,0.995,-0.89), Vector3(0.032,0.07,0.032), Color("#ffcd70"), false)
    var flame := (wick.get_child(0) as MeshInstance3D).material_override as StandardMaterial3D
    flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var glow := OmniLight3D.new()
    glow.position = Vector3(-2.74,1.13,-0.89)
    glow.omni_range = 4.0
    glow.light_color = Color("#ffa653")
    glow.light_energy = 2.5
    interior.add_child(glow)
    var daylight := OmniLight3D.new()
    daylight.position = Vector3(-3.85, 1.88, -0.55)
    daylight.light_color = Color("#bdced9")
    daylight.light_energy = 1.25
    daylight.omni_range = 4.6
    interior.add_child(daylight)
    for i in range(3):
        _solid_box("Выцветшие строки", Vector3(-2.16, 0.766, -0.64 + i * 0.068),
            Vector3(0.29 - i * 0.035, 0.004, 0.018), Color("#574f45"), false)
    door_handle = _solid_box("Дверная ручка", Vector3(0.46, 1.02, 3.73),
        Vector3(0.17, 0.065, 0.12), Color("#827760"), false)
    door_handle.get_child(0).position.x = 0.07
    porch_sound.name = "Шаги за дверью"
    porch_sound.position = Vector3(0.3, 0.65, 4.7)
    porch_sound.stream = preload("res://porch_steps.wav")
    porch_sound.unit_size = 5.0
    interior.add_child(porch_sound)
    var light := OmniLight3D.new()
    light.name = "Остывшая комната"
    light.position = Vector3(0, 3.1, 0.3)
    light.light_color = Color("#a3a9af")
    light.light_energy = 0.58
    light.omni_range = 10.0
    light.shadow_enabled = false
    interior.add_child(light)

func _build_mask() -> void:
    # Mirrored facets meet along a raised brow and nose ridge. Each eye is
    # cut into the topology so it stays readable in the low-resolution view.
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    surface.set_smooth_group(-1)
    var points := PackedVector3Array([
        Vector3(0,.52,.09), Vector3(.27,.44,.04), Vector3(.37,.17,.04),
        Vector3(.32,-.16,.04), Vector3(.17,-.38,.05), Vector3(0,-.53,.09),
        Vector3(0,.19,.21), Vector3(.08,.12,.17), Vector3(.29,.16,.10),
        Vector3(.20,.04,.15), Vector3(0,-.07,.26), Vector3(0,-.20,.15)])
    var faces := [[0,1,6],[1,2,8],[1,8,6],[6,8,7],[7,8,9],[8,2,3],
        [8,3,9],[9,3,4],[7,9,10],[6,7,10],[10,9,11],[11,9,4],[11,4,5]]
    for side: float in [-1.0, 1.0]:
        for i in faces.size():
            surface.set_color(Color("#291e19") if i == 4 else Color("#97724e").darkened(0.055 * (i % 4)))
            for corner in range(3):
                var index: int = faces[i][corner if side > 0 else 2 - corner]
                var vertex := points[index]
                vertex.x *= side
                surface.add_vertex(vertex)
    surface.generate_normals()
    var mask := MeshInstance3D.new()
    mask.name = "Резная маска"
    mask.position = Vector3(0, 1.86, -3.84)
    mask.mesh = surface.commit()
    var finish := StandardMaterial3D.new()
    finish.vertex_color_use_as_albedo = true
    finish.cull_mode = BaseMaterial3D.CULL_DISABLED
    mask.material_override = finish
    interior.add_child(mask)

func _play_porch_steps() -> void:
    porch_sound.play()
    latch_motion = create_tween()
    latch_motion.tween_interval(4.04)
    latch_motion.tween_property(door_handle, "rotation:z", -0.50, 0.16)
    latch_motion.tween_interval(0.22)
    latch_motion.tween_property(door_handle, "rotation:z", 0.0, 0.18)

func _build_waypoint() -> void:
    waypoint = _story_marker("РОДНОЙ ДОМ", _gate_location() + Vector3.UP * 2.9,
        Color("#c3ad8a"), 32)
    waypoint.name = "SurveyedHomeWaypoint"
    get_parent().add_child(waypoint)

func _build_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "ChapterOneHUD"
    layer.layer = 20
    add_child(layer)
    objective_label = Label.new()
    objective_label.position = Vector2(18, 18)
    objective_label.add_theme_color_override("font_shadow_color", Color("#111714"))
    objective_label.add_theme_constant_override("shadow_offset_x", 1)
    objective_label.add_theme_constant_override("shadow_offset_y", 1)
    objective_label.add_theme_color_override("font_color", Color("#d4c4a9"))
    objective_label.add_theme_font_size_override("font_size", 16)
    objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(objective_label)
    # Mission distance and journal hotkey belong immediately below the quest,
    # leaving the lower-center of the screen exclusively for story subtitles.
    distance_label = Label.new()
    distance_label.name = "QuestDistanceTopLeft"
    distance_label.position = Vector2(18, 45)
    distance_label.add_theme_font_size_override("font_size", 13)
    distance_label.add_theme_color_override("font_color", Color("#d4c4a9"))
    distance_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(distance_label)
    journal_hint_label = Label.new()
    journal_hint_label.name = "JournalHintTopLeft"
    journal_hint_label.text = "[J / О] — журнал"
    journal_hint_label.position = Vector2(18, 66)
    journal_hint_label.add_theme_font_size_override("font_size", 12)
    journal_hint_label.add_theme_color_override("font_color", Color("#aeb4b0"))
    journal_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(journal_hint_label)
    prompt_label = Label.new()
    prompt_label.anchor_left = 0.5
    prompt_label.anchor_right = 0.5
    prompt_label.anchor_top = 1.0
    prompt_label.anchor_bottom = 1.0
    prompt_label.offset_left = -280.0
    prompt_label.offset_right = 280.0
    prompt_label.offset_top = -119.0
    prompt_label.offset_bottom = -91.0
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.add_theme_color_override("font_color", Color("#f0d9ab"))
    prompt_label.add_theme_font_size_override("font_size", 16)
    prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(prompt_label)
    message_label = Label.new()
    message_label.anchor_left = 0.5
    message_label.anchor_right = 0.5
    message_label.anchor_top = 1.0
    message_label.anchor_bottom = 1.0
    message_label.offset_left = -350.0
    message_label.offset_right = 350.0
    message_label.offset_top = -89.0
    message_label.offset_bottom = -35.0
    message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    message_label.add_theme_color_override("font_color", Color("#c8c9c5"))
    message_label.add_theme_font_size_override("font_size", 13)
    message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(message_label)
    journal_panel = PanelContainer.new()
    journal_panel.name = "JournalPanel"
    journal_panel.position = Vector2(16, 102)
    journal_panel.custom_minimum_size = Vector2(450, 0)
    var panel_style := StyleBoxFlat.new()
    panel_style.bg_color = Color(0.08, 0.09, 0.10, 0.94)
    panel_style.border_color = Color("#5a524a")
    panel_style.set_border_width_all(1)
    panel_style.content_margin_left = 18
    panel_style.content_margin_right = 18
    panel_style.content_margin_top = 15
    panel_style.content_margin_bottom = 15
    journal_panel.add_theme_stylebox_override("panel", panel_style)
    journal_text = Label.new()
    journal_text.custom_minimum_size = Vector2(420, 160)
    journal_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    journal_text.add_theme_font_size_override("font_size", 14)
    journal_text.add_theme_color_override("font_color", Color("#e5d6c1"))
    journal_panel.add_child(journal_text)
    layer.add_child(journal_panel)
    journal_panel.visible = false
    _update_journal()

func _say(line: String) -> void:
    if message_label != null:
        message_label.text = line

func _objective_text() -> String:
    if chapter_completed:
        return "Глава 1 / Следующий шаг: разобраться в тайне Чернозёрья"
    if inside_home:
        if not note_found:
            return "Глава 1 / Осмотреть оставленные вещи"
        if not mask_found:
            return "Глава 1 / Осмотреть красный угол"
        return "Глава 1 / Вернуться к входной двери"
    return "Глава 1 / Найти родной дом"

func _update_journal() -> void:
    if journal_text == null:
        return
    var lines := "ЖУРНАЛ / ГЛАВА 1. ВОЗВРАЩЕНИЕ\n\n"
    lines += _objective_text() + "\n\n"
    lines += "2005 год. Демобилизация. Чернозёрье оказалось пустым.\n"
    if note_found:
        lines += "\n• Записка: люди уходили поспешно, оставив вещи."
    if mask_found:
        lines += "\n• Маска: неизвестный предмет появился на месте иконы."
    if chapter_completed:
        lines += "\n• Снаружи раздавались тяжёлые шаги. Ответов пока нет."
    lines += "\n\n[J / О] — закрыть журнал."
    journal_text.text = lines

func _target_position(id: String) -> Vector3:
    match id:
        "note":
            return ROOM_ORIGIN + Vector3(-2.1, 0.765, -0.55)
        "mask":
            return ROOM_ORIGIN + Vector3(0, 1.86, -3.72)
        "exit":
            return ROOM_ORIGIN + Vector3(0, 1.16, 3.76)
    return _gate_location()

func _home_bearing() -> String:
    # Text instead of arrow glyphs: the built-in Godot Web font does not
    # contain all Unicode arrow characters and renders them as square boxes.
    # Indicates a rough bearing, not an obstacle-free path.
    if player == null:
        return "НЕТ ДАННЫХ"
    var delta := _gate_location() - player.global_position
    delta.y = 0.0
    if delta.length_squared() < 0.01:
        return "ЗДЕСЬ"
    var front := -player.global_transform.basis.z
    var right := player.global_transform.basis.x
    if absf(delta.dot(front)) >= absf(delta.dot(right)):
        return "ПРЯМО" if delta.dot(front) >= 0.0 else "НАЗАД"
    return "СПРАВА" if delta.dot(right) >= 0.0 else "СЛЕВА"


func _update_approach() -> void:
    if player == null or inside_home or chapter_completed:
        return
    var distance := player.global_position.distance_to(_gate_location())
    if _approach_stage == 0 and distance <= 38.0:
        _approach_stage = 1
        _approach_triggers += 1
        _say("Знакомые избы едва различимы в тумане. Но ни дыма, ни голосов.")
        print("STORY_APPROACH_READY: stage=first_houses")
    elif _approach_stage == 1 and distance <= 13.0:
        _approach_stage = 2
        _approach_triggers += 1
        _say("Где-то здесь был мой двор. Ни лая Найды, ни шагов за окном.")
        print("STORY_APPROACH_READY: stage=home_yard")


func _update_focus() -> void:
    focus = ""
    if player == null:
        return
    var hint := ""
    var top_left_info := ""
    if not inside_home:
        var distance := player.global_position.distance_to(_gate_location())
        if chapter_completed:
            top_left_info = "Чернозёрье · исследование продолжается"
        else:
            top_left_info = "До родного дома: %d м" % int(distance)
        if distance <= GATE_RANGE:
            focus = "enter"
            hint = "[E / У] Войти в родной дом"
    else:
        top_left_info = "Родной дом · внутри"
        var candidates := []
        if not note_found:
            candidates.append("note")
        if not mask_found:
            candidates.append("mask")
        candidates.append("exit")
        var best_alignment := cos(deg_to_rad(28.0))
        for key in candidates:
            var to_target := _target_position(key) - view_camera.global_position
            if to_target.length_squared() > INTERACT_RANGE * INTERACT_RANGE:
                continue
            var alignment := -view_camera.global_basis.z.dot(to_target.normalized())
            if alignment > best_alignment and view_camera.current:
                focus = str(key)
                best_alignment = alignment
        match focus:
            "note":
                hint = "[E / У] Осмотреть записку"
            "mask":
                hint = "[E / У] Осмотреть деревянную маску"
            "exit":
                hint = "[E / У] Выйти на улицу"
            _:
                hint = ""
    if distance_label != null and distance_label.text != top_left_info:
        distance_label.text = top_left_info
    if prompt_label != null and hint != _last_prompt:
        prompt_label.text = hint
        _last_prompt = hint
    var obj := _objective_text()
    if objective_label != null and obj != _last_objective:
        objective_label.text = obj
        _last_objective = obj

func _process(_delta: float) -> void:
    _update_approach()
    _update_focus()

func _enter_home() -> void:
    if player == null:
        return
    outside_rotation = player.rotation.y
    inside_home = true
    interior.visible = true
    waypoint.visible = false
    player.global_position = ROOM_ORIGIN + Vector3(0, 0.25, 2.10)
    player.rotation.y = 0.0
    player.velocity = Vector3.ZERO
    var map_layer := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
    if map_layer != null:
        map_layer.visible = false
    _say("Печь давно остыла. Вещи оставлены в беспорядке. На столе лежит бумага.")
    print("STORY_ENTER_HOME: state=investigate")
    _update_journal()
    _update_focus()

func _leave_home() -> void:
    if player == null:
        return
    porch_sound.stop()
    if latch_motion != null:
        latch_motion.kill()
    door_handle.rotation.z = 0.0
    inside_home = false
    interior.visible = false
    player.global_position = _gate_location() + Vector3.UP * 0.12
    player.rotation.y = outside_rotation
    player.velocity = Vector3.ZERO
    if note_found and mask_found and not chapter_completed:
        chapter_completed = true
        _say("За дверью слышались шаги. Теперь ясно: здесь произошло нечто большее, чем отъезд жителей.")
        print("STORY_CHAPTER_ONE_COMPLETE: clues=2 mysterious_presence=true")
    elif not chapter_completed:
        _say("Дом всё ещё хранит ответы. Нужно вернуться и осмотреть его внимательнее.")
    waypoint.visible = not chapter_completed
    _update_journal()
    _update_focus()

func _interact() -> void:
    if journal_open:
        return
    _update_focus()
    match focus:
        "enter":
            _enter_home()
        "note":
            note_found = true
            _say("Записка выцвела от сырости. Вещи бросили внезапно, будто собирались вернуться.")
            print("STORY_CLUE_FOUND: note")
            _update_journal()
        "mask":
            mask_found = true
            _play_porch_steps()
            _say("В красном углу висит чужая деревянная маска. Снаружи вдруг скрипнули доски крыльца.")
            print("STORY_CLUE_FOUND: mask")
            _update_journal()
        "exit":
            _leave_home()

func _toggle_journal() -> void:
    journal_open = not journal_open
    if journal_panel != null:
        journal_panel.visible = journal_open
    if player != null and player.has_method("set_controls_locked"):
        player.call("set_controls_locked", journal_open)
    if journal_open:
        _update_journal()
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
    if not event is InputEventKey:
        return
    var key := event as InputEventKey
    if not key.pressed or key.echo:
        return
    var code := key.physical_keycode
    var text_key := char(key.unicode).to_lower() if key.unicode != 0 else ""
    if code == KEY_J or key.keycode == KEY_J or text_key == "о":
        _toggle_journal()
        get_viewport().set_input_as_handled()
    elif code == KEY_E or key.keycode == KEY_E or text_key == "у":
        _interact()
        get_viewport().set_input_as_handled()
