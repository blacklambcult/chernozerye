extends Node3D

const PLAYER_SCRIPT = preload("res://player.gd")
const LOGO_DATA = preload("res://logo_data.gd")
const MAP_FILE := "res://world_data.json"
const MANUAL_FILE := "res://manual_layout.json"
const GAME_TITLE := "Fearless Knights of the Cordon"
const GAME_STAGE := "Pre-Alpha 0.6.9"
const MANUAL_CAMERA_NEAR := 0.16
const MANUAL_CAMERA_FAR := 250.0
const SEASON := "NOVEMBER"
const GAME_HUD_TITLE := "FEARLESS KNIGHTS OF THE CORDON / PRE-ALPHA 0.6.9 · ЧЕРНОЗЁРЬЕ · 710 ОБЪЕКТОВ"
var manual_mode := false
var manual_button: Button
var _status_label: Label
var _night_environment: Environment
var _sun_light: DirectionalLight3D
var _day_ground_material: Material
var _manual_ground_material: StandardMaterial3D

func _process(_delta: float) -> void:
    # Never replace the title after the default village has been selected.
    if manual_mode:
        set_process(false)
        return
    if not is_instance_valid(_status_label):
        return
    var geo := get_node_or_null("GeographyBlockoutV07")
    if geo != null and bool(geo.get("generated_ready")):
        _status_label.text = GAME_HUD_TITLE
        set_process(false)

func _ready() -> void:
    _create_ground()
    _create_lighting()
    _create_retro_grade()
    var forest_features: Array = []
    var road_group := Node3D.new()
    road_group.name = "OSMRoadMeshes"
    add_child(road_group)
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
    var manual_scene := Node3D.new()
    manual_scene.name = "ManualSurvey"
    manual_scene.set_script(preload("res://manual_geo.gd"))
    add_child(manual_scene)
    _create_user_paths()
    _create_landmarks()
    _create_player()
    _create_brand_watermark()
    _create_overview_map()
    _create_gameplay_hud()
    # Load the manual 710-object village from the first playable frame.
    # The original sector/preview buttons are no longer part of the player HUD.
    _activate_default_village()
    _create_november_snow()
    _create_story_prologue()
    _create_questlab_runtime()

func _create_story_prologue() -> void:
    var story := Node.new()
    story.name = "StoryPrologue"
    story.set_script(preload("res://story_prologue.gd"))
    add_child(story)


func _create_questlab_runtime() -> void:
    # F6 opens a Quest Lab playtest. Default StoryPrologue remains intact.
    var quest_runtime := Node.new()
    quest_runtime.name = "QuestLabRuntime"
    quest_runtime.set_script(preload("res://questlab_runtime.gd"))
    add_child(quest_runtime)


func _create_november_snow() -> void:
    # CPUParticles3D works in the GL Compatibility Web renderer. Follow the
    # player but keep local_coords=false so falling flakes do not teleport
    # with footsteps. No accumulating snow: November is still wet and muddy.
    var player := get_node_or_null("Player") as CharacterBody3D
    if player == null:
        push_warning("November snow skipped: Player missing")
        return
    var snow := CPUParticles3D.new()
    snow.name = "NovemberSnow"
    snow.amount = 340
    snow.lifetime = 11.0
    snow.preprocess = 11.0
    snow.explosiveness = 0.0
    snow.randomness = 0.62
    snow.local_coords = false
    snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    snow.emission_box_extents = Vector3(24.0, 8.0, 24.0)
    snow.position = Vector3(0.0, 13.0, 0.0)
    snow.direction = Vector3(0.14, -1.0, 0.09)
    snow.spread = 13.0
    snow.initial_velocity_min = 0.50
    snow.initial_velocity_max = 1.05
    snow.gravity = Vector3(0.07, -0.36, 0.03)
    snow.scale_amount_min = 0.65
    snow.scale_amount_max = 1.12
    snow.visibility_aabb = AABB(Vector3(-40.0, -28.0, -40.0),
        Vector3(80.0, 50.0, 80.0))
    var flake := QuadMesh.new()
    flake.size = Vector2(0.047, 0.072)
    var snow_material := StandardMaterial3D.new()
    snow_material.albedo_color = Color(0.84, 0.88, 0.91, 0.78)
    snow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    snow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    snow_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    snow_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    snow_material.no_depth_test = false
    snow_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    flake.material = snow_material
    snow.mesh = flake
    player.add_child(snow)
    snow.emitting = true
    print("NOVEMBER_SNOW_READY: cpu=true amount=", snow.amount,
        " follow_player=true drift=light")


func _activate_default_village() -> void:
    if not manual_mode:
        _toggle_manual_preview()
    print("FEARLESS_KNIGHTS_STARTUP_READY: title=", GAME_TITLE,
        " version=", GAME_STAGE, " manual_mode=", manual_mode)

func _material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    m.specular = 0.0
    m.metallic = 0.0
    m.clearcoat_enabled = false
    m.rim_enabled = false
    m.anisotropy_enabled = false
    m.emission_enabled = false
    return m

func _create_ground() -> void:
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(2600, 2600)
    var instance := MeshInstance3D.new()
    instance.mesh = mesh
    instance.name = "BaseGround"
    instance.material_override = _create_ground_material()
    _day_ground_material = instance.material_override
    add_child(instance)
    var ground := StaticBody3D.new()
    ground.set_meta("impact_surface", &"soil")
    ground.position.y = -0.2
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(2600, 0.4, 2600)
    collider.shape = shape
    ground.add_child(collider)
    add_child(ground)

func _create_ground_material() -> StandardMaterial3D:
    # Subtle, irregular soil instead of enormous visible repeated pixel squares.
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 19950328
    for y in range(128):
        for x in range(128):
            var broad := sin(float(x) * 0.092) * cos(float(y) * 0.085) * 0.014
            var mottled := sin(float(x * 3 + y) * 0.13) * 0.009
            var fine := rng.randf_range(-0.009, 0.009)
            var tone := clampf(0.21 + broad + mottled + fine, 0.15, 0.27)
            img.set_pixel(x, y, Color(tone * 0.88, tone * 0.93, tone * 0.75))
    img.generate_mipmaps()
    var mat := _material(Color("#b8c1b5"))
    mat.albedo_texture = ImageTexture.create_from_image(img)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.uv1_scale = Vector3(10.0, 10.0, 1.0)
    return mat

func _create_manual_ground_material() -> StandardMaterial3D:
    # November: soaked brown-grey earth, almost no summer green. Geography
    # and ground collisions remain unchanged; only color varies spatially.
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = 19961007
    for y in range(128):
        for x in range(128):
            var broad := sin(float(x) * 0.11) * cos(float(y) * 0.07) * 0.055
            var swirls := sin(float(x) * 0.28 + float(y) * 0.17) * 0.027
            var noise := rng.randf_range(-0.032, 0.032)
            var value := clampf(0.39 + broad * 0.7 + swirls * 0.65 + noise * 0.6, 0.31, 0.48)
            img.set_pixel(x, y, Color(value * 0.96, value * 0.87, value * 0.74))
    # Small clusters of shale and broken straw repeat seamlessly across the soil.
    for fleck in range(180):
        var origin := Vector2i(rng.randi_range(0, 127), rng.randi_range(0, 127))
        var straw := fleck % 4 == 0
        var pigment := Color("#77644c") if straw else Color("#5c544c")
        for dx in range(rng.randi_range(2, 5)):
            var x := (origin.x + dx) % 128
            var y := (origin.y + (dx / 2 if straw else 0)) % 128
            img.set_pixel(x, y, img.get_pixel(x, y).lerp(pigment, 0.65))
    img.generate_mipmaps()
    var mat := _material(Color("#98968c"))
    mat.albedo_texture = ImageTexture.create_from_image(img)
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
    mat.uv1_scale = Vector3(520.0, 520.0, 1.0)
    return mat

func _create_retro_grade() -> void:
    var layer := CanvasLayer.new()
    layer.name = "RetroGrade"
    layer.layer = 0
    add_child(layer)
    var screen := ColorRect.new()
    screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var grade := ShaderMaterial.new()
    grade.shader = preload("res://retro_grade.gdshader")
    # Stronger pixel grid on objects; keep the original twilight sky gradient.
    grade.set_shader_parameter("virtual_height", 320.0)
    grade.set_shader_parameter("pixel_mix", 0.94)
    grade.set_shader_parameter("cel_strength", 0.34)
    grade.set_shader_parameter("poster_levels", 18.0)
    grade.set_shader_parameter("edge_strength", 0.14)
    screen.material = grade
    layer.add_child(screen)

func _create_lighting() -> void:
    var environment := WorldEnvironment.new()
    environment.name = "WorldEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#575b69")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#b0a9a4")
    env.ambient_light_energy = 0.82
    env.glow_enabled = false
    env.fog_enabled = true
    env.fog_light_color = Color("#676976")
    env.fog_density = 0.0018
    environment.environment = env
    _night_environment = env
    add_child(environment)
    var sun := DirectionalLight3D.new()
    sun.name = "DirectionalLight3D"
    _sun_light = sun
    sun.rotation_degrees = Vector3(-12, -35, 0)
    sun.light_energy = 1.05
    sun.light_specular = 0.0 # Matte light even when sun is enabled
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
    get_node("OSMRoadMeshes").add_child(instance)
    if not shoulders.is_empty():
        var edge_arrays := []
        edge_arrays.resize(Mesh.ARRAY_MAX)
        edge_arrays[Mesh.ARRAY_VERTEX] = shoulders
        var edge_mesh := ArrayMesh.new()
        edge_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, edge_arrays)
        var edge := MeshInstance3D.new()
        edge.mesh = edge_mesh
        edge.material_override = _material(Color("#55554b"))
        get_node("OSMRoadMeshes").add_child(edge)
    if not wheel_ruts.is_empty():
        var rut_arrays := []
        rut_arrays.resize(Mesh.ARRAY_MAX)
        rut_arrays[Mesh.ARRAY_VERTEX] = wheel_ruts
        var rut_mesh := ArrayMesh.new()
        rut_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rut_arrays)
        var rut_node := MeshInstance3D.new()
        rut_node.mesh = rut_mesh
        rut_node.material_override = _material(Color("#645d4f"))
        get_node("OSMRoadMeshes").add_child(rut_node)

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

func _create_gameplay_hud() -> void:
    var hud_layer := CanvasLayer.new()
    hud_layer.name = "GameplayHUD"
    hud_layer.layer = 18
    add_child(hud_layer)
    var ui := Control.new()
    ui.name = "SurvivalHUD"
    ui.set_script(preload("res://gameplay_hud.gd"))
    hud_layer.add_child(ui)


func _create_label() -> void:
    var layer := CanvasLayer.new()
    var label := Label.new()
    label.text = GAME_HUD_TITLE
    label.position = Vector2(16, 16)
    layer.add_child(label)
    var weather_label := Label.new()
    weather_label.name = "NovemberWeatherLabel"
    weather_label.text = "ЧЕРНОЗЁРЬЕ  /  НОЯБРЬ  /  ПОЗДНИЙ ВЕЧЕР  /  МОКРЫЙ СНЕГ  |  E: ОСМОТР  J: ЖУРНАЛ  V: ЖЕСТ"
    weather_label.position = Vector2(16, 38)
    weather_label.add_theme_color_override("font_color", Color("#aeb9bc"))
    weather_label.add_theme_font_size_override("font_size", 11)
    weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(weather_label)
    add_child(layer)
    _status_label = label

func _create_brand_watermark() -> void:
    # Use the exact player-supplied emblem as a lightweight non-interactive HUD mark.
    var img := Image.new()
    var jpg_bytes := Marshalls.base64_to_raw(LOGO_DATA.BASE64)
    var err := img.load_jpg_from_buffer(jpg_bytes)
    if err != OK:
        push_warning("Fearless Knights of the Cordon logo could not be decoded: " + str(err))
        return
    var layer := CanvasLayer.new()
    layer.name = "BrandWatermark"
    layer.layer = 15
    add_child(layer)
    var emblem := TextureRect.new()
    emblem.name = "FearlessKnightsEmblem"
    emblem.texture = ImageTexture.create_from_image(img)
    emblem.anchor_left = 1.0
    emblem.anchor_right = 1.0
    emblem.anchor_top = 0.0
    emblem.anchor_bottom = 0.0
    emblem.offset_left = -83.0
    emblem.offset_right = -14.0
    emblem.offset_top = 12.0
    emblem.offset_bottom = 81.0
    emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
    emblem.modulate.a = 0.74
    layer.add_child(emblem)
    print("FEARLESS_KNIGHTS_LOGO_READY: original user emblem, hud=69px")

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
    houses_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    houses_button.offset_left = 16.0
    houses_button.offset_top = 151.0
    houses_button.offset_right = 235.0
    houses_button.offset_bottom = 191.0
    houses_button.pressed.connect(_toggle_houses)

    sector_button = Button.new()
    sector_button.text = "СЕКТОР A: 680 М"
    map_root.add_child(sector_button)
    sector_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    sector_button.offset_left = 16.0
    sector_button.offset_top = 199.0
    sector_button.offset_right = 235.0
    sector_button.offset_bottom = 239.0
    sector_button.pressed.connect(_toggle_sector_a)

    osm_button = Button.new()
    osm_button.text = "КОНТУРЫ OSM: ПОКАЗАТЬ"
    map_root.add_child(osm_button)
    osm_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    osm_button.offset_left = 16.0
    osm_button.offset_top = 247.0
    osm_button.offset_right = 235.0
    osm_button.offset_bottom = 287.0
    osm_button.pressed.connect(_toggle_osm_buildings)

    overture_button = Button.new()
    overture_button.text = "OVERTURE: СКРЫТЬ"
    map_root.add_child(overture_button)
    overture_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    overture_button.offset_left = 16.0
    overture_button.offset_top = 295.0
    overture_button.offset_right = 235.0
    overture_button.offset_bottom = 335.0
    overture_button.pressed.connect(_toggle_overture_buildings)

    # Walk the mapped real-world footprint zone immediately, without a 700 m hike.
    sector_a_visit_button = Button.new()
    sector_a_visit_button.text = "ПЕРЕЙТИ В 3D СЕКТОРА A"
    map_root.add_child(sector_a_visit_button)
    sector_a_visit_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
    sector_a_visit_button.offset_left = 16.0
    sector_a_visit_button.offset_right = 280.0
    sector_a_visit_button.offset_top = 343.0
    sector_a_visit_button.offset_bottom = 391.0
    sector_a_visit_button.pressed.connect(_visit_sector_a)

func _create_quick_navigation() -> void:
    # A second, always-visible entry point avoids hunting for a map-only control.
    var action_layer := CanvasLayer.new()
    action_layer.name = "SectorAQuickNav"
    action_layer.layer = 8
    add_child(action_layer)
    var action_button := Button.new()
    action_button.text = "ПЕРЕЙТИ В СЕКТОР A (3D)"
    action_button.position = Vector2(16.0, 75.0)
    action_button.size = Vector2(246.0, 38.0)
    action_button.tooltip_text = "Переместиться на нанесённую в OSM улицу рядом с новыми контурами зданий"
    action_button.pressed.connect(_visit_sector_a)
    action_layer.add_child(action_button)

func _create_manual_navigation() -> void:
    var layer := CanvasLayer.new()
    layer.name = "ManualPreviewControls"
    layer.layer = 8
    add_child(layer)
    manual_button = Button.new()
    manual_button.text = "РУЧНАЯ РАЗМЕТКА · 710 ОБЪЕКТОВ"
    manual_button.position = Vector2(16.0, 121.0)
    manual_button.size = Vector2(276.0, 42.0)
    manual_button.tooltip_text = "Показать отдельно дороги, дома, участки и лес из загруженного GeoJSON"
    manual_button.pressed.connect(_toggle_manual_preview)
    layer.add_child(manual_button)

func _toggle_manual_preview() -> void:
    manual_mode = not manual_mode
    var manual := get_node_or_null("ManualSurvey") as Node3D
    var geo := get_node_or_null("GeographyBlockoutV07") as Node3D
    var overture := get_node_or_null("OvertureBuildingsSectorA") as Node3D
    var osm_roads := get_node_or_null("OSMRoadMeshes") as Node3D
    if manual != null:
        manual.visible = manual_mode
    if geo != null:
        geo.visible = not manual_mode
    if overture != null:
        overture.visible = not manual_mode
    if osm_roads != null:
        osm_roads.visible = not manual_mode
    if manual_button != null:
        manual_button.text = "ВЕРНУТЬ СТАРУЮ МЕСТНОСТЬ" if manual_mode else "РУЧНАЯ РАЗМЕТКА · 710 ОБЪЕКТОВ"
    var terrain := get_node_or_null("BaseGround") as MeshInstance3D
    if terrain != null:
        if manual_mode and _manual_ground_material == null:
            _manual_ground_material = _create_manual_ground_material()
        terrain.material_override = _manual_ground_material if manual_mode else _day_ground_material
    # The procedural WorldEnvironment/Light nodes had no explicit names in older builds.
    # Hold direct references so toggling scenes always changes the actual light and sky.
    if _night_environment != null:
        if manual_mode and _night_environment.sky == null:
            var dusk := ProceduralSkyMaterial.new()
            dusk.sky_top_color = Color("#080f1d")
            dusk.sky_horizon_color = Color("#333949")
            dusk.ground_horizon_color = dusk.sky_horizon_color
            dusk.ground_bottom_color = Color("#1b222c")
            dusk.sky_curve = 0.15
            dusk.sun_angle_max = 0.0
            var sky := Sky.new()
            sky.sky_material = dusk
            _night_environment.sky = sky
        _night_environment.background_mode = Environment.BG_SKY if manual_mode else Environment.BG_COLOR
        # Godot Compatibility Web: artistic depth fog, not unsupported volumetric fog.
        _night_environment.background_color = Color("#303441") if manual_mode else Color("#575b69")
        _night_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
        _night_environment.ambient_light_color = Color("#8e9fac") if manual_mode else Color("#b0a9a4")
        _night_environment.ambient_light_energy = 0.57 if manual_mode else 0.82
        _night_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED if manual_mode else Environment.REFLECTION_SOURCE_BG
        _night_environment.glow_enabled = false
        _night_environment.tonemap_exposure = 1.01 if manual_mode else 1.0
        _night_environment.fog_enabled = true
        _night_environment.fog_mode = Environment.FOG_MODE_DEPTH if manual_mode else Environment.FOG_MODE_EXPONENTIAL
        _night_environment.fog_light_color = Color("#343e51") if manual_mode else Color("#676976")
        _night_environment.fog_light_energy = 0.50 if manual_mode else 1.0
        _night_environment.fog_sky_affect = 0.33 if manual_mode else 1.0
        _night_environment.fog_sun_scatter = 0.0
        _night_environment.fog_aerial_perspective = 0.0
        _night_environment.fog_density = 0.88 if manual_mode else 0.0018
        _night_environment.fog_depth_begin = 28.0 if manual_mode else 24.0
        _night_environment.fog_depth_end = 165.0 if manual_mode else 118.0
        _night_environment.fog_depth_curve = 1.3
        _night_environment.fog_height = 0.8 if manual_mode else 0.0
        _night_environment.fog_height_density = 0.017 if manual_mode else 0.0
    if _sun_light != null:
        _sun_light.light_energy = 0.62 if manual_mode else 1.05
        _sun_light.light_specular = 0.0
        _sun_light.light_color = Color("#90abdc") if manual_mode else Color("#f0b69a")
        # The shadow map produced hard triangular streaks across the road and low-poly trees.
        _sun_light.shadow_enabled = not manual_mode
    if manual_mode:
        print("MANUAL_NO_GLARE_READY: ambient=0.57, moon=0.62, fog_light=0.50, exposure=1.01")
    print("MANUAL_NIGHT_READY: ", manual_mode,
        " fog=", _night_environment.fog_mode if _night_environment != null else "MISSING_ENV",
        " glow=", _night_environment.glow_enabled if _night_environment != null else "MISSING_ENV",
        " bg=", _night_environment.background_color if _night_environment != null else "MISSING_ENV")

    if map_panel != null:
        map_panel.set("show_manual", manual_mode)
        map_panel.queue_redraw()
    for control in [houses_button, sector_button, osm_button, overture_button, sector_a_visit_button]:
        if control != null:
            control.visible = not manual_mode
    if is_instance_valid(_status_label):
        _status_label.text = GAME_HUD_TITLE
    var character := get_node_or_null("Player") as CharacterBody3D
    if character != null:
        character.velocity = Vector3.ZERO
        character.global_position = Vector3(-789.7, 0.22, -268.6) if manual_mode else Vector3(130.0, 0.22, -82.0)
        # The old 0.60 m near plane extended beyond the 0.46 m player capsule
        # and visibly sliced walls/windows even though collisions were working.
        # Keep the near plane well INSIDE the capsule, and shorten the far plane
        # instead to limit roof Z-fighting in Compatibility/WebGL.
        var player_camera := character.get_node_or_null("Camera3D") as Camera3D
        if player_camera != null:
            player_camera.near = MANUAL_CAMERA_NEAR if manual_mode else 0.25
            player_camera.far = MANUAL_CAMERA_FAR if manual_mode else 2300.0
            if manual_mode:
                var capsule := character.get_node_or_null("CollisionShape3D") as CollisionShape3D
                var shape: CapsuleShape3D = null
                if capsule != null:
                    shape = capsule.shape as CapsuleShape3D
                var radius: float = shape.radius if shape != null else 0.0
                if radius <= player_camera.near + 0.20:
                    push_error("CAMERA_CLIP_GUARD_FAILED: camera near plane too far into walls")
                print("CAMERA_CLIP_GUARD_READY: near=", player_camera.near,
                    " far=", player_camera.far, " radius=", radius)
    overview_layer.visible = false
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

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
    var zoom := bool(map_panel.get("sector_a_zoom"))
    var detailed := bool(map_panel.get("neighborhood_zoom"))
    if not zoom:
        map_panel.set("sector_a_zoom", true)
        map_panel.set("neighborhood_zoom", false)
        sector_button.text = "УЛИЦЫ A: 300 М"
    elif not detailed:
        map_panel.set("neighborhood_zoom", true)
        sector_button.text = "ВСЯ КАРТА 2×2 КМ"
    else:
        map_panel.set("sector_a_zoom", false)
        map_panel.set("neighborhood_zoom", false)
        sector_button.text = "СЕКТОР A: 680 М"
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
            var prologue := get_node_or_null("StoryPrologue")
            if prologue != null and (bool(prologue.get("inside_home")) or bool(prologue.get("journal_open"))):
                return
            overview_layer.visible = not overview_layer.visible
            if overview_layer.visible:
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
            get_viewport().set_input_as_handled()
        elif overview_layer.visible and (event.physical_keycode == KEY_H or event.keycode == KEY_H or (event.unicode != 0 and char(event.unicode).to_lower() == "р")):
            _toggle_houses()
            get_viewport().set_input_as_handled()
