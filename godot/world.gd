extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const MAP_FILE := "res://world_data.json"
var _status_label: Label

func _process(_delta: float) -> void:
    if not is_instance_valid(_status_label):
        return
    var geo := get_node_or_null("GeographyBlockoutV07")
    if geo != null and bool(geo.get("generated_ready")):
        _status_label.text = "ЧЕРНОЗЁРЬЕ 1.7 SECTOR A 3D  |  Клик — осмотр  |  WASD/ЦФЫВ — ходьба  |  M/Ь — карта"
        set_process(false)

func _ready() -> void:
    _create_ground()
    _create_lighting()
    var forest_features: Array = []
    if FileAccess.file_exists(MAP_FILE):
        var data = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
        if data is Dictionary:
            var features: Array = data.get("features", [])
            forest_features = features
            print("OSM объектов загружено: ", features.size())
            for feature in features:
                if feature.get("type", "") == "road": _add_road(feature)
                # OSM buildings are too sparse/inaccurate here; use provisional blockout instead.
    else:
        push_warning("world_data.json отсутствует — сначала выполните python scripts/fetch_osm.py")
    var geographical_blockout := Node3D.new()
    geographical_blockout.name = "GeographyBlockoutV07"
    geographical_blockout.set_script(preload("res://geography_v07.gd"))
    add_child(geographical_blockout)
    # Overture footprints are initially extruded only for the audited west sector.
    # A single batched roof/wall mesh avoids hundreds of new render nodes.
    var precise_buildings := Node3D.new()
    precise_buildings.name = "OvertureBuildingsSectorA"
    precise_buildings.set_script(preload("res://overture_3d_a.gd"))
    add_child(precise_buildings)
    _create_user_paths()
    _create_landmarks()
    _create_player()
    _create_label()
    _create_overview_map()

func _material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    return m

func _create_ground() -> void:
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(2000, 2000)
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.material_override = _material(Color("#435443"))
    add_child(instance)
    var ground := StaticBody3D.new()
    ground.position.y = -0.2
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2000, 0.4, 2000)
    collider.shape = shape
    ground.add_child(collider)
    add_child(ground)

func _create_lighting() -> void:
    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#575b69")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#b0a9a4")
    env.ambient_light_energy = 0.82
    env.fog_enabled = true
    env.fog_light_color = Color("#676976")
    env.fog_density = 0.0018
    environment.environment = env
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-12, -35, 0)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    sun.light_color = Color("#f0b69a")
    add_child(sun)

func _coord(point: Array, height: float = 0.0) -> Vector3:
    return Vector3(float(point[0]), height, -float(point[1]))

func _add_road(feature: Dictionary) -> void:
    var pts: Array = feature.get("points", [])
    if pts.size() < 2: return
    var tags: Dictionary = feature.get("tags", {})
    var road_type: String = str(tags.get("highway", ""))
    var width := 6.0
    if road_type in ["footway", "path", "cycleway"]: width = 2.0
    elif road_type == "track": width = 3.5
    elif road_type in ["primary", "trunk", "motorway"]: width = 11.0
    elif road_type == "secondary": width = 8.0
    var vertices := PackedVector3Array()
    var shoulders := PackedVector3Array()
    var wheel_ruts := PackedVector3Array()
    for i in range(pts.size() - 1):
        var a := _coord(pts[i], 0.055)
        var b := _coord(pts[i+1], 0.055)
        if a.distance_to(b) < 0.001: continue
        var normal := Vector3(-(b.z-a.z), 0, b.x-a.x).normalized()
        var offset := normal * width * 0.5
        vertices.append_array(PackedVector3Array([a-offset, a+offset, b+offset, a-offset, b+offset, b-offset]))
        if road_type in ["residential", "service", "unclassified", "track"]:
            for lane in [-1.0, 1.0]:
                var center_offset: Vector3 = normal * (float(lane) * width * 0.22)
                var half_rut := normal * 0.12
                var lifted := Vector3.UP * 0.024
                wheel_ruts.append_array(PackedVector3Array([
                    a+center_offset-half_rut+lifted, a+center_offset+half_rut+lifted,
                    b+center_offset+half_rut+lifted, a+center_offset-half_rut+lifted,
                    b+center_offset+half_rut+lifted, b+center_offset-half_rut+lifted
                ]))
        if road_type not in ["trunk", "motorway", "primary"]:
            var wide := normal * (width * 0.5 + 1.4)
            var low_a := a - Vector3.UP * 0.035
            var low_b := b - Vector3.UP * 0.035
            shoulders.append_array(PackedVector3Array([low_a-wide, low_a+wide, low_b+wide, low_a-wide, low_b+wide, low_b-wide]))
    if vertices.is_empty(): return
    var arr := []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = vertices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    # Distinguish the existing georeferenced M5 trunk road from earth tracks.
    var road_color := Color("#786d57")
    if road_type in ["primary", "trunk", "motorway"]:
        road_color = Color("#505758")
    elif road_type in ["residential", "service", "secondary"]:
        road_color = Color("#918779")
    instance.material_override = _material(road_color)
    add_child(instance)
    if not shoulders.is_empty():
        var edge_arrays := []
        edge_arrays.resize(Mesh.ARRAY_MAX)
        edge_arrays[Mesh.ARRAY_VERTEX] = shoulders
        var edge_mesh := ArrayMesh.new()
        edge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, edge_arrays)
        var edge := MeshInstance3D.new()
        edge.mesh = edge_mesh
        edge.material_override = _material(Color("#55554b"))
        add_child(edge)
    if not wheel_ruts.is_empty():
        var rut_arrays := []
        rut_arrays.resize(Mesh.ARRAY_MAX)
        rut_arrays[Mesh.ARRAY_VERTEX] = wheel_ruts
        var rut_mesh := ArrayMesh.new()
        rut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rut_arrays)
        var rut_node := MeshInstance3D.new()
        rut_node.mesh = rut_mesh
        rut_node.material_override = _material(Color("#645d4f"))
        add_child(rut_node)

func _add_building(feature: Dictionary) -> void:
    var pts: Array = feature.get("points", [])
    if pts.size() < 3: return
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for p in pts:
        var v := _coord(p)
        min_x = minf(min_x, v.x)
        max_x = maxf(max_x, v.x)
        min_z = minf(min_z, v.z)
        max_z = maxf(max_z, v.z)
    var w := max_x-min_x
    var d := max_z-min_z
    if w < 0.5 or d < 0.5: return
    var height := 5.0
    var tags: Dictionary = feature.get("tags", {})
    if tags.has("height"):
        var clean := str(tags["height"]).replace("m", "").strip_edges()
        if clean.is_valid_float(): height = clampf(clean.to_float(), 2.0, 50.0)
    elif tags.has("building:levels"):
        var levels := str(tags["building:levels"])
        if levels.is_valid_float(): height = clampf(levels.to_float()*3.0, 2.0, 50.0)
    var mesh := BoxMesh.new()
    mesh.size = Vector3(w, height, d)
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.position = Vector3((min_x+max_x)*0.5, height*0.5, (min_z+max_z)*0.5)
    instance.material_override = _material(Color("#786e63"))
    add_child(instance)

func _create_player() -> void:
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.set_script(PLAYER_SCRIPT)
    # Spawn on the existing OSM village road, rather than 74 m away in an empty clearing.
    player.position = Vector3(130, 0.2, -82)
    player.rotation.y = deg_to_rad(-125.0)
    add_child(player)

func _create_label() -> void:
    var layer := CanvasLayer.new()
    var label := Label.new()
    label.text = "ЧЕРНОЗЁРЬЕ 1.6 OVERTURE AUDIT  |  Загрузка домов и леса..."
    label.position = Vector2(16, 16)
    layer.add_child(label)
    add_child(layer)
    _status_label = label

# Trees only in OSM forest polygons, never randomly across the whole map.
func _create_forest_from_osm(features: Array) -> void:
    var polygons: Array[PackedVector2Array] = []
    var road_segments: Array = []
    var building_boxes: Array[Rect2] = []
    for feature in features:
        if not feature is Dictionary:
            continue
        var points: Array = feature.get("points", [])
        var kind: String = str(feature.get("type", ""))
        if kind == "forest" and points.size() >= 4:
            var polygon := PackedVector2Array()
            for p in points:
                polygon.append(Vector2(float(p[0]), -float(p[1])))
            polygons.append(polygon)
        elif kind == "building" and points.size() >= 3:
            var lo := Vector2(INF, INF)
            var hi := Vector2(-INF, -INF)
            for p in points:
                var q := Vector2(float(p[0]), -float(p[1]))
                lo = lo.min(q)
                hi = hi.max(q)
            building_boxes.append(Rect2(lo - Vector2(4.0, 4.0), hi - lo + Vector2(8.0, 8.0)))
        elif kind == "road" and points.size() >= 2:
            var previous := Vector2(float(points[0][0]), -float(points[0][1]))
            for i in range(1, points.size()):
                var next_point := Vector2(float(points[i][0]), -float(points[i][1]))
                road_segments.append([previous, next_point])
                previous = next_point

    if polygons.is_empty():
        print("Лесные полигоны OSM не найдены")
        return

    var random := RandomNumberGenerator.new()
    random.seed = 20261117
    var positions: Array[Vector3] = []
    for i in range(21000):
        if positions.size() >= 850:
            break
        var p := Vector2(random.randf_range(-995.0, 995.0), random.randf_range(-995.0, 995.0))
        var within_forest := false
        for polygon in polygons:
            if Geometry2D.is_point_in_polygon(p, polygon):
                within_forest = true
                break
        if not within_forest:
            continue
        # Clear the large meadow and bus-stop vicinity according to user markup.
        if _inside_meadow(p) or p.distance_to(Vector2(90.0, -20.0)) < 22.0:
            continue
        var obstructed := false
        for box in building_boxes:
            if box.has_point(p):
                obstructed = true
                break
        if obstructed:
            continue
        for segment in road_segments:
            if p.distance_to(Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])) < 5.0:
                obstructed = true
                break
        if not obstructed:
            positions.append(Vector3(p.x, 0.0, p.y))

    if positions.is_empty():
        print("На данном участке нет места для деревьев по OSM")
        return

    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.16
    trunk_mesh.bottom_radius = 0.28
    trunk_mesh.height = 3.2
    trunk_mesh.radial_segments = 6
    var crown_mesh := CylinderMesh.new()
    crown_mesh.top_radius = 0.0
    crown_mesh.bottom_radius = 1.8
    crown_mesh.height = 6.5
    crown_mesh.radial_segments = 6
    var trunks_mesh := MultiMesh.new()
    trunks_mesh.transform_format = MultiMesh.TRANSFORM_3D
    trunks_mesh.mesh = trunk_mesh
    trunks_mesh.instance_count = positions.size()
    var crowns_mesh := MultiMesh.new()
    crowns_mesh.transform_format = MultiMesh.TRANSFORM_3D
    crowns_mesh.mesh = crown_mesh
    crowns_mesh.instance_count = positions.size()
    for i in range(positions.size()):
        var scale_factor := random.randf_range(0.8, 1.3)
        var base := positions[i]
        trunks_mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), base + Vector3(0.0, 1.6 * scale_factor, 0.0)))
        crowns_mesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), base + Vector3(0.0, 5.0 * scale_factor, 0.0)))
    var trunks := MultiMeshInstance3D.new()
    trunks.multimesh = trunks_mesh
    trunks.material_override = _material(Color("#594537"))
    add_child(trunks)
    var crowns := MultiMeshInstance3D.new()
    crowns.multimesh = crowns_mesh
    crowns.material_override = _material(Color("#253e32"))
    add_child(crowns)
    print("Лес OSM: полигонов ", polygons.size(), ", деревьев ", positions.size())


# User-supplied approximate coordinates. These are not independently surveyed.
func _inside_meadow(p: Vector2) -> bool:
    var meadow := PackedVector2Array([
        Vector2(-410, -70), Vector2(-110, -125), Vector2(50, -175),
        Vector2(120, -290), Vector2(40, -375), Vector2(-200, -465),
        Vector2(-480, -410)
    ])
    return Geometry2D.is_point_in_polygon(p, meadow)

func _create_user_paths() -> void:
    _add_road({"points": [[130.0, 82.0], [55.0, -75.0], [0.0, -180.0]], "tags": {"highway": "path"}})
    _add_road({"points": [[110.0, -320.0], [430.0, -200.0]], "tags": {"highway": "path"}})

func _create_landmarks() -> void:
    _add_landmark(Vector2(130, 82), "ОСТАНОВКА / СТАРТ", Color("#e5c17a"))
    _add_landmark(Vector2(100, 720), "ЗАБРОШЕННЫЙ ЛАГЕРЬ", Color("#c7a0dd"))
    _add_landmark(Vector2(-260, -270), "БОЛЬШОЕ ПОЛЕ", Color("#d5d68d"))
    _add_landmark(Vector2(715, -800), "ТУРБАЗА", Color("#75c1da"))
    _add_landmark(Vector2(975, 120), "ЛОЖНЫЙ ВЫХОД", Color("#e7a1a1"))

func _add_landmark(point: Vector2, title: String, tint: Color) -> void:
    var marker := Node3D.new()
    marker.name = title
    marker.position = Vector3(point.x, 0.0, -point.y)
    add_child(marker)
    var pole := MeshInstance3D.new()
    var pole_mesh := CylinderMesh.new()
    pole_mesh.height = 2.6
    pole_mesh.top_radius = 0.075
    pole_mesh.bottom_radius = 0.075
    pole.mesh = pole_mesh
    pole.position.y = 1.3
    pole.material_override = _material(tint)
    marker.add_child(pole)
    var label3d := Label3D.new()
    label3d.text = title
    label3d.font_size = 38
    label3d.pixel_size = 0.012
    label3d.position.y = 3.1
    label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label3d.modulate = tint
    marker.add_child(label3d)

var overview_layer: CanvasLayer
var map_panel: Control
var houses_button: Button
var sector_button: Button
var osm_button: Button
var overture_button: Button
var sector_a_visit_button: Button

func _create_overview_map() -> void:
    overview_layer = CanvasLayer.new()
    overview_layer.name = "MapOverlay"
    overview_layer.layer = 15
    overview_layer.visible = false
    add_child(overview_layer)
    var map_root := Control.new()
    map_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overview_layer.add_child(map_root)
    map_panel = Control.new()
    map_panel.set_script(preload("res://live_map_v08.gd"))
    map_root.add_child(map_panel)
    map_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var source = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
    var features: Array = []
    if source is Dictionary:
        features = source.get("features", [])
    var overture_shapes: Array = []
    if FileAccess.file_exists("res://overture_buildings.json"):
        var extra = JSON.parse_string(FileAccess.get_file_as_string("res://overture_buildings.json"))
        if extra is Dictionary:
            overture_shapes = extra.get("buildings", [])
    map_panel.initialize(self, get_node("GeographyBlockoutV07"), get_node("Player"), features, overture_shapes)
    print("OVERTURE_LOADED: ", overture_shapes.size())
    houses_button = Button.new()
    houses_button.text = "ДОМА: ПОКАЗАТЬ"
    map_root.add_child(houses_button)
    houses_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    houses_button.offset_left = -200.0
    houses_button.offset_top = 16.0
    houses_button.offset_right = -16.0
    houses_button.offset_bottom = 58.0
    houses_button.pressed.connect(_toggle_houses)

    sector_button = Button.new()
    sector_button.text = "СЕКТОР A: ПРИБЛИЗИТЬ"
    map_root.add_child(sector_button)
    sector_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    sector_button.offset_left = -235.0
    sector_button.offset_top = 66.0
    sector_button.offset_right = -16.0
    sector_button.offset_bottom = 108.0
    sector_button.pressed.connect(_toggle_sector_a)

    osm_button = Button.new()
    osm_button.text = "КОНТУРЫ OSM: ПОКАЗАТЬ"
    map_root.add_child(osm_button)
    osm_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    osm_button.offset_left = -235.0
    osm_button.offset_top = 116.0
    osm_button.offset_right = -16.0
    osm_button.offset_bottom = 158.0
    osm_button.pressed.connect(_toggle_osm_buildings)

    overture_button = Button.new()
    overture_button.text = "OVERTURE: СКРЫТЬ"
    map_root.add_child(overture_button)
    overture_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    overture_button.offset_left = -235.0
    overture_button.offset_top = 166.0
    overture_button.offset_right = -16.0
    overture_button.offset_bottom = 208.0
    overture_button.pressed.connect(_toggle_overture_buildings)

    # Walk the mapped real-world footprint zone immediately, without a 700 m hike.
    sector_a_visit_button = Button.new()
    sector_a_visit_button.text = "ПЕРЕЙТИ К ДОМАМ СЕКТОРА A"
    map_root.add_child(sector_a_visit_button)
    sector_a_visit_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    sector_a_visit_button.offset_left = -280.0
    sector_a_visit_button.offset_right = -16.0
    sector_a_visit_button.offset_top = 216.0
    sector_a_visit_button.offset_bottom = 258.0
    sector_a_visit_button.pressed.connect(_visit_sector_a)

func _visit_sector_a() -> void:
    # Location sampled from a residential OSM road away from mapped rooftops.
    var character := get_node_or_null("Player") as CharacterBody3D
    if character == null:
        return
    character.velocity = Vector3.ZERO
    character.global_position = Vector3(-769.2, 0.22, -331.7)
    overview_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _toggle_overture_buildings() -> void:
    var visible := not bool(map_panel.get("show_overture_buildings"))
    map_panel.set("show_overture_buildings", visible)
    overture_button.text = "OVERTURE: СКРЫТЬ" if visible else "OVERTURE: ПОКАЗАТЬ"
    map_panel.queue_redraw()

func _toggle_sector_a() -> void:
    var zoom := not bool(map_panel.get("sector_a_zoom"))
    map_panel.set("sector_a_zoom", zoom)
    sector_button.text = "ВСЯ ТЕРРИТОРИЯ 2×2 КМ" if zoom else "СЕКТОР A: ПРИБЛИЗИТЬ"
    map_panel.queue_redraw()

func _toggle_osm_buildings() -> void:
    var show := not bool(map_panel.get("show_osm_buildings"))
    map_panel.set("show_osm_buildings", show)
    osm_button.text = "КОНТУРЫ OSM: СКРЫТЬ" if show else "КОНТУРЫ OSM: ПОКАЗАТЬ"
    map_panel.queue_redraw()

func _toggle_houses() -> void:
    var show := not bool(map_panel.get("show_houses"))
    map_panel.set("show_houses", show)
    houses_button.text = "ДОМА: СКРЫТЬ" if show else "ДОМА: ПОКАЗАТЬ"
    map_panel.queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_M or event.keycode == KEY_M or (event.unicode != 0 and char(event.unicode).to_lower() == "ь"):
            overview_layer.visible = not overview_layer.visible
            if overview_layer.visible:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            get_viewport().set_input_as_handled()
        elif overview_layer.visible and (event.physical_keycode == KEY_H or event.keycode == KEY_H or (event.unicode != 0 and char(event.unicode).to_lower() == "р")):
            _toggle_houses()
            get_viewport().set_input_as_handled()
