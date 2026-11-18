extends Node3D
# CHERNOZERYE 3.3 / VILLAGE MODULAR ART AND INHABITED YARDS
# All spatial placements derive from the user's manual GeoJSON features.
# Decorative features are deterministic and never modify the survey geometry.

const IZBA_VARIANTS = preload("res://izba_variants.gd")
const WOOD_TONES := ["#454941", "#51473e", "#3b4039", "#4e433c", "#43463d", "#525047"]
const ROOF_TONES := ["#282e31", "#373432", "#30383a", "#403933"]
const DOOR_COLOR := Color("#24221f")
const FRAME_COLOR := Color("#494943")
const WINDOW_COLOR := Color("#131a1f")
const WINDOW_LIT := Color("#a5b95c")
const FENCE_COLOR := Color("#494840")
const POST_COLOR := Color("#3e3c36")
const RUT_COLOR := Color("#423a32")

var _roads: Array = []
var _detail_batches: Dictionary = {}
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lights_placed: int = 0
var _fence_posts: PackedVector3Array = PackedVector3Array()
var _fence_rails: PackedVector3Array = PackedVector3Array()
var _fence_slats: PackedVector3Array = PackedVector3Array()
var _yard_details: PackedVector3Array = PackedVector3Array()
var _road_ruts: PackedVector3Array = PackedVector3Array()
var _overhead_wires: PackedVector3Array = PackedVector3Array()
var _utility_pole_count := 0
var _bush_positions: Array[Transform3D] = []
var _aspen_positions: Array[Transform3D] = []
var _aspen_trunks: Array[Transform3D] = []
var _building_count := 0
var _fence_count := 0
var _road_count := 0
var _feature_house_center := Vector2(INF, INF)
var _feature_house_distance := INF
var _building_polygons: Array[PackedVector2Array] = []
var _plot_props_count := 0
var _canopy_count := 0
var _lean_to_count := 0
var _roof_patch_count := 0
var _shutter_count := 0
var _floor_counts := [0, 0]
var _roof_counts := [0, 0, 0, 0, 0]
var _body_counts := [0, 0, 0, 0, 0]
var _window_counts := [0, 0, 0, 0, 0]
var _entrance_counts := [0, 0, 0, 0, 0]
var _log_courses_count := 0
var _eaves_count := 0
var _carved_count := 0
var _active_trim_key := "trim"
var _yard_counts := [0, 0, 0, 0, 0]
var _clipped_log_segments := 0

func decorate(features: Array) -> void:
    _rng.seed = 19960918
    # Choose one real, hand-surveyed building nearest the documented village spawn.
    # This is a visual showcase, not an invented new geographic footprint.
    var player_spawn_2d := Vector2(-789.7, 268.6)
    for item in features:
        if not item is Dictionary:
            continue
        var kind: String = str(item.get("type", ""))
        if kind not in ["house", "sauna", "shed"]:
            continue
        var points := _local_points(item.get("points", []))
        if points.size() < 3:
            continue
        _building_polygons.append(points)
        if kind != "house":
            continue
        var centroid := Vector2.ZERO
        for p in points:
            centroid += p
        centroid /= float(points.size())
        var dist := centroid.distance_to(player_spawn_2d)
        if dist < _feature_house_distance:
            _feature_house_distance = dist
            _feature_house_center = centroid
    for item in features:
        if not item is Dictionary:
            continue
        if str(item.get("type", "")) == "road":
            var road_points := _local_points(item.get("points", []))
            for i in range(road_points.size() - 1):
                _roads.append([road_points[i], road_points[i + 1]])
    for item in features:
        if not item is Dictionary:
            continue
        var category: String = str(item.get("type", ""))
        var polygon := _local_points(item.get("points", []))
        match category:
            "house", "sauna", "shed":
                _decorate_building(polygon, category)
            "plot":
                _decorate_fence(polygon)
            "road":
                _decorate_road(polygon)
            "forest":
                _decorate_forest(polygon)
    _flush_details()
    _create_solid_mesh(_fence_posts, Color("#423b35"), "Забор / столбы")
    _create_solid_mesh(_fence_rails, Color("#48433d"), "Забор / рейки")
    _create_solid_mesh(_fence_slats, Color("#3a3b35"), "Забор / обветшавший штакетник")
    _create_solid_mesh(_yard_details, Color("#48443b"), "Старый деревенский быт / ящики и дрова")
    _create_solid_mesh(_road_ruts, RUT_COLOR, "Дорога / земляные колеи")
    _create_solid_mesh(_overhead_wires, Color("#242d2d"), "Старые кабели / провисшие линии")
    print("MANUAL_UTILITY_READY: poles=", _utility_pole_count)
    _create_forest_assets()
    print("MANUAL_ART_READY: buildings=", _building_count,
        " plots=", _fence_count, " roads=", _road_count, " lamps=", _lights_placed)
    print("MANUAL_VILLAGE_DETAIL_READY: canopies=", _canopy_count,
        " plot_props=", _plot_props_count, " crooked_fences=", _fence_count)
    print("MANUAL_FACADE_READY: lean_tos=", _lean_to_count,
        " roof_patches=", _roof_patch_count, " rotten_shutters=", _shutter_count)
    print("IZBA_GENERATOR_READY: floor_counts=", _floor_counts,
        " body=", _body_counts, " roof=", _roof_counts,
        " windows=", _window_counts, " entrances=", _entrance_counts)
    print("IZBA_DETAIL_READY: log_courses=", _log_courses_count,
        " roof_eaves=", _eaves_count, " carved=", _carved_count,
        " clipped_segments=", _clipped_log_segments)
    print("VILLAGE_YARDS_READY: wells=", _yard_counts[0],
        " beds=", _yard_counts[1], " greenhouses=", _yard_counts[2],
        " firewood=", _yard_counts[3], " scrap=", _yard_counts[4])

func _local_points(raw: Array) -> PackedVector2Array:
    var points := PackedVector2Array()
    for p in raw:
        if p is Array and p.size() >= 2:
            points.append(Vector2(float(p[0]), float(p[1])))
    return points

func _pt(p: Vector2, height: float) -> Vector3:
    return Vector3(p.x, height, -p.y)

func _material(color: Color, texture: Texture2D = null) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = 1.0
    mat.metallic = 0.0
    mat.specular = 0.0
    # Explicit matte defaults: no reflective highlights, rim/clearcoat or emitted wall light.
    mat.rim_enabled = false
    mat.clearcoat_enabled = false
    mat.anisotropy_enabled = false
    mat.emission_enabled = false
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    if texture != null:
        mat.albedo_texture = texture
    return mat

func _pixel_texture(tone: Color, seed: int, rooftop: bool, wall_style: int = 0) -> Texture2D:
    var key := str(seed) + "/" + str(rooftop) + "/" + str(wall_style)
    if _textures.has(key):
        return _textures[key]
    var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed
    for y in range(64):
        for x in range(64):
            var offset := rng.randf_range(-0.095, 0.038)
            if rooftop:
                match wall_style:
                    0: # Old corrugated slate
                        if y % 9 == 0: offset -= 0.11
                        if x % 11 == 0: offset -= 0.065
                    1: # Rusty iron sheets
                        if x % 7 <= 1: offset -= 0.13
                        if y % 23 == 0: offset -= 0.08
                    2: # Wooden planking
                        if x % 12 <= 1: offset -= 0.16
                        if y % 19 == 0: offset -= 0.07
                    3: # Patchy dark roofing
                        if (x / 13 + y / 9) % 4 == 0: offset -= 0.14
                    4: # Wavy asbestos sheets
                        if x % 9 < 2: offset -= 0.12
                        if y % 15 == 0: offset -= 0.12
                if y % 21 >= 17 and x % 13 < 4:
                    offset += 0.035
            else:
                match wall_style:
                    1:
                        # Coarse horizontal village log/plank cladding.
                        if y % 8 <= 1:
                            offset -= 0.16
                        if (x + (y / 8) * 13) % 28 == 0:
                            offset -= 0.075
                    2:
                        # Limewash over uneven plaster, without strong wood stripes.
                        offset = rng.randf_range(-0.070, 0.020)
                        if (x / 9 + y / 7 + seed) % 13 == 0:
                            offset -= 0.085
                    3:
                        # Old red-brick farm masonry in offset rows.
                        if y % 8 == 0:
                            offset -= 0.17
                        if (x + (8 if int(y / 8) % 2 == 0 else 0)) % 18 == 0:
                            offset -= 0.14
                    4:
                        # Salvaged mixed cladding and uneven patches of old paint.
                        if y % 11 == 0: offset -= 0.13
                        if x % 17 == 0: offset -= 0.10
                        if (x / 17 + y / 11) % 5 == 0: offset += 0.03
                    _:
                        if x % 8 == 0:
                            offset -= 0.16
                        if x % 8 == 1:
                            offset += 0.018
                        if y % 19 == 0:
                            offset -= 0.08
                if (x * 17 + y * 7 + seed) % 67 <= 2:
                    offset -= 0.16
            var shade := clampf(0.90 + offset, 0.52, 0.98)
            img.set_pixel(x, y, Color(tone.r * shade, tone.g * shade, tone.b * shade, 1.0))
    var tex := ImageTexture.create_from_image(img)
    _textures[key] = tex
    return tex

func _face(verts: PackedVector3Array, uvs: PackedVector2Array, a: Vector3, b: Vector3,
        c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
    verts.append_array(PackedVector3Array([a, b, c]))
    uvs.append_array(PackedVector2Array([uv_a, uv_b, uv_c]))

func _quad(verts: PackedVector3Array, uvs: PackedVector2Array, a: Vector3,
        b: Vector3, c: Vector3, d: Vector3) -> void:
    _face(verts, uvs, a, b, c, Vector2(0, 1), Vector2(1, 1), Vector2(1, 0))
    _face(verts, uvs, a, c, d, Vector2(0, 1), Vector2(1, 0), Vector2(0, 0))

func _make_textured_mesh(verts: PackedVector3Array, uvs: PackedVector2Array,
        mat: Material, label: String) -> void:
    if verts.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _push_tri(buffer: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
    buffer.append_array(PackedVector3Array([a, b, c]))

func _batch_tri(key: String, a: Vector3, b: Vector3, c: Vector3) -> void:
    var verts: PackedVector3Array = _detail_batches.get(key, PackedVector3Array())
    verts.append_array(PackedVector3Array([a, b, c]))
    _detail_batches[key] = verts

func _batch_quad(key: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    _batch_tri(key, a, b, c)
    _batch_tri(key, a, c, d)

func _create_solid_mesh(verts: PackedVector3Array, color: Color, label: String) -> void:
    if verts.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = _material(color)
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _flush_details() -> void:
    var colors := {
        "window": WINDOW_COLOR,
        "window_lit": WINDOW_LIT,
        "frame": FRAME_COLOR,
        "door": DOOR_COLOR,
        "lintel": Color("#52473f"),
        "chimney": Color("#444442"),
        "board": Color("#50493e"),
        "porch": Color("#4b433b"),
        "lamp": Color("#df9c52"),
        "trim": Color("#6c7167"),
        "rust": Color("#604039"),
        "awning": Color("#343433"),
        "shutter": Color("#42483f"),
        "shutter_dark": Color("#2c312f"),
        "roof_patch": Color("#3b403f"),
        "lean_to": Color("#46443e"),
        "lean_to_roof": Color("#292f30"),
        "log_course": Color("#35352f"),
        "log_upper": Color("#574b40"),
        "log_front": Color("#493d35"),
        "log_lower": Color("#302c29"),
        "fascia": Color("#2e3332"),
        "muntin": Color("#383b35"),
        "trim_blue": Color("#5c7775"),
        "trim_green": Color("#62745e"),
        "trim_red": Color("#76534d"),
        "trim_cream": Color("#898778"),
        "well_stone": Color("#4b504b"),
        "well_wood": Color("#5e5441"),
        "soil": Color("#453a30"),
        "bed_edge": Color("#534839"),
        "sprout": Color("#485c3d"),
        "greenhouse_glass": Color("#526a63"),
        "greenhouse_frame": Color("#7a8276"),
        "greenhouse_roof": Color("#687970"),
        "woodpile": Color("#514336"),
        "wood_end": Color("#77705b"),
        "yard_tin": Color("#525c5d"),
        "yard_rust": Color("#6b4a39"),
        "yard_tool": Color("#767c72"),
        "yard_tire": Color("#232624"),
        "panel_patch": Color("#464943"),
        "carving": Color("#5c6259"),
        "cross_board": Color("#494238"),
        "porch_deck": Color("#50483f"),
        "annex_dark": Color("#303632"),
        "pole": Color("#413b35"),
        "crossarm": Color("#343531")
    }
    for key in _detail_batches.keys():
        var verts: PackedVector3Array = _detail_batches[key]
        if key == "window_lit":
            var lit_mat := _material(WINDOW_LIT)
            lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            var arrays := []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = verts
            var mesh := ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            var lit_node := MeshInstance3D.new()
            lit_node.name = "Редкие болезненно-зелёные окна"
            lit_node.mesh = mesh
            lit_node.material_override = lit_mat
            lit_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(lit_node)
        else:
            _create_solid_mesh(verts, colors.get(key, Color.WHITE), "Детали фасада / " + str(key))

func _signed_area(points: PackedVector2Array) -> float:
    var area := 0.0
    for i in range(points.size()):
        var a := points[i]
        var b := points[(i + 1) % points.size()]
        area += a.x * b.y - b.x * a.y
    return area * 0.5

func _nearest_road_distance(p: Vector2) -> float:
    var best := INF
    for seg in _roads:
        var nearest := Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])
        best = minf(best, p.distance_to(nearest))
    return best

func _building_front_edge(points: PackedVector2Array) -> int:
    var best_index := 0
    var best_score := INF
    for i in range(points.size()):
        var a := points[i]
        var b := points[(i + 1) % points.size()]
        var length := a.distance_to(b)
        if length < 2.5:
            continue
        var distance := _nearest_road_distance((a + b) * 0.5)
        var score := distance - minf(length, 15.0) * 0.1
        if score < best_score:
            best_score = score
            best_index = i
    return best_index

func _wall_panel(key: String, start: Vector2, finish: Vector2, normal: Vector3,
        frac0: float, frac1: float, bottom: float, top: float, extra: float = 0.12) -> void:
    var a := start.lerp(finish, frac0)
    var b := start.lerp(finish, frac1)
    var aa := _pt(a, bottom) + normal * extra
    var bb := _pt(b, bottom) + normal * extra
    var cc := _pt(b, top) + normal * extra
    var dd := _pt(a, top) + normal * extra
    _batch_quad(key, aa, bb, cc, dd)

func _make_window(start: Vector2, finish: Vector2, normal: Vector3,
        center_fraction: float, side_length: float, illuminated: bool,
        boarded: bool = false, decay: int = 0, style: int = 0, floor: int = 0) -> void:
    # Five distinct replaceable modules on the same surveyed wall, including upper-floor windows.
    var half := minf(0.072, 0.74 / maxf(side_length, 0.1))
    var u0 := center_fraction - half
    var u1 := center_fraction + half
    var y := float(floor) * 3.08
    var low := 1.36 + y
    var high := 2.77 + y
    var trim := "carving" if style == 1 or style == 4 else _active_trim_key
    _wall_panel("frame", start, finish, normal, u0 - 0.017, u1 + 0.017,
        low, high, 0.115)
    _wall_panel("window_lit" if illuminated else "window",
        start, finish, normal, u0, u1, low + 0.11, high - 0.11, 0.142)
    # Window muntins: divided, imperfect Soviet-era panes, not luminous squares.
    _wall_panel("muntin", start, finish, normal,
        center_fraction - 0.006, center_fraction + 0.006,
        low + 0.10, high - 0.10, 0.162)
    _wall_panel("muntin", start, finish, normal,
        u0, u1, low + 0.67, low + 0.74, 0.166)
    _wall_panel(trim, start, finish, normal, u0 - 0.023, u0 - 0.009,
        low - 0.06, high + 0.06, 0.169)
    _wall_panel(trim, start, finish, normal, u1 + 0.009, u1 + 0.023,
        low - 0.06, high + 0.06, 0.169)
    _wall_panel(trim, start, finish, normal, u0 - 0.026, u1 + 0.026,
        high, high + 0.125, 0.175)
    _wall_panel(trim, start, finish, normal, u0 - 0.030, u1 + 0.030,
        low - 0.11, low + 0.015, 0.176)
    if style == 1:
        # One triangular wooden crown with five square-cut ornament teeth.
        _carved_count += 1
        _batch_tri("carving",
            _pt(start.lerp(finish, u0 - 0.027), high + 0.12) + normal * 0.182,
            _pt(start.lerp(finish, center_fraction), high + 0.37) + normal * 0.182,
            _pt(start.lerp(finish, u1 + 0.027), high + 0.12) + normal * 0.182)
        # Five simple PS1 silhouette teeth suggest carved Bashkir/Volga nalichniki.
        for tooth in range(5):
            var l := lerpf(u0 - 0.028, u1 + 0.028, float(tooth) / 5.0)
            var r := lerpf(u0 - 0.028, u1 + 0.028, float(tooth + 1) / 5.0)
            _wall_panel("carving", start, finish, normal, l, r,
                high + 0.12, high + (0.29 if tooth % 2 == 0 else 0.19), 0.181)
    elif style == 2:
        # One shutter hanging beside the opening.
        _wall_panel("shutter", start, finish, normal,
            u0 - 0.080, u0 - 0.030, low - 0.04, high + 0.02, 0.191)
        _wall_panel("shutter_dark", start, finish, normal,
            u0 - 0.080, u0 - 0.030, low + 0.38, low + 0.46, 0.196)
        _shutter_count += 1
    elif style == 3:
        # Boarded windows with crude, uneven boards.
        _wall_panel("board", start, finish, normal, u0, u1,
            low + 0.26, low + 0.48, 0.195)
        _wall_panel("board", start, finish, normal, u0, u1,
            low + 0.82, low + 1.05, 0.196)
    elif style == 4:
        _carved_count += 1
        _wall_panel("carving", start, finish, normal,
            u0 - 0.034, u1 + 0.034, high + 0.13, high + 0.24, 0.182)
        _wall_panel("frame", start, finish, normal, u0 + half * 0.90,
            u0 + half * 1.12, low + 0.10, high - 0.10, 0.160)
    if boarded or decay % 9 == 0:
        _wall_panel("cross_board", start, finish, normal, u0, u1,
            low + 0.47, low + 0.57, 0.198)
    if illuminated and _lights_placed < 9:
        _lights_placed += 1
        var center := start.lerp(finish, center_fraction)
        var lamp := OmniLight3D.new()
        lamp.name = "Нездоровое свечение в окне"
        lamp.position = _pt(center, low + 0.92) + normal * 1.1
        lamp.light_color = Color("#bdc870")
        lamp.light_energy = 0.30
        lamp.light_specular = 0.0
        lamp.omni_range = 5.5
        lamp.shadow_enabled = false
        add_child(lamp)

func _raised_log(a: Vector2, b: Vector2, normal: Vector3, y: float) -> void:
    # Old horizontal timber, three PS1 facets, softer than the giant 3.2 teeth.
    var p := _pt(a, y)
    var q := _pt(b, y)
    var back := normal * 0.085
    var front := normal * 0.166
    _batch_quad("log_upper", p + back + Vector3.UP * 0.245,
        q + back + Vector3.UP * 0.245,
        q + front + Vector3.UP * 0.075,
        p + front + Vector3.UP * 0.075)
    _batch_quad("log_front", p + front + Vector3.UP * 0.075,
        q + front + Vector3.UP * 0.075,
        q + front - Vector3.UP * 0.075,
        p + front - Vector3.UP * 0.075)
    _batch_quad("log_lower", p + front - Vector3.UP * 0.075,
        q + front - Vector3.UP * 0.075,
        q + back - Vector3.UP * 0.225,
        p + back - Vector3.UP * 0.225)
    _log_courses_count += 1


func _log_openings(length: float, is_front: bool, floors: int, y: float) -> Array[Vector2]:
    # Holes in the *raised* timber face, matching window and door geometry below.
    # Crucial: v3.2 timber strips passed directly over all windows and doors.
    var openings: Array[Vector2] = []
    if is_front and y < 2.48:
        var half_door := (0.55 + 0.20) / length
        openings.append(Vector2(0.5 - half_door, 0.5 + half_door))
    var window_level := (y > 1.08 and y < 3.28)
    var upper_level := floors == 2 and (y > 4.20 and y < 6.32)
    if is_front:
        if window_level and length > 7.0:
            for center_frac in [0.19, 0.81]:
                var half_window := minf(0.072, 0.74 / length) + 0.26 / length
                openings.append(Vector2(center_frac - half_window, center_frac + half_window))
        if upper_level and length > 5.0:
            for center_frac in [0.30, 0.70]:
                var half_window := minf(0.072, 0.74 / length) + 0.26 / length
                openings.append(Vector2(center_frac - half_window, center_frac + half_window))
    elif length > 5.0 and (window_level or upper_level):
        var half_window := minf(0.072, 0.74 / length) + 0.26 / length
        openings.append(Vector2(0.5 - half_window, 0.5 + half_window))
    return openings


func _clipped_log(a: Vector2, b: Vector2, normal: Vector3,
        y: float, holes: Array[Vector2]) -> void:
    # Keep the relief on most of each surveyed wall, but remove all intervals
    # where windows, carved surrounds, doors or lintels are visible.
    var segments: Array[Vector2] = [Vector2(0.0, 1.0)]
    for hole in holes:
        var remaining: Array[Vector2] = []
        for segment in segments:
            if hole.y <= segment.x or hole.x >= segment.y:
                remaining.append(segment)
            else:
                if hole.x > segment.x + 0.004:
                    remaining.append(Vector2(segment.x, minf(hole.x, segment.y)))
                if hole.y < segment.y - 0.004:
                    remaining.append(Vector2(maxf(hole.y, segment.x), segment.y))
        segments = remaining
    for segment in segments:
        if (segment.y - segment.x) * a.distance_to(b) > 0.22:
            _raised_log(a.lerp(b, segment.x), a.lerp(b, segment.y), normal, y)
            if not holes.is_empty():
                _clipped_log_segments += 1


func _decorate_wall_module(a: Vector2, b: Vector2, normal: Vector3,
        height: float, style: int, salt: int,
        is_front: bool = false, floors: int = 1) -> void:
    match style:
        0:
            # Vertical rough corner posts (old board walls).
            _wall_panel("panel_patch", a, b, normal, 0.011, 0.023, 0.20, height, 0.098)
        1:
            # More log houses, and windows are no longer obscured by facade strips.
            var rows := int(floorf((height - 0.25) / 0.58))
            for n in range(rows):
                var y := 0.42 + float(n) * 0.58
                _clipped_log(a, b, normal, y,
                    _log_openings(a.distance_to(b), is_front, floors, y))
        2:
            # Flaked plaster remnants.
            _wall_panel("panel_patch", a, b, normal, 0.06, 0.19,
                0.25, 1.16, 0.096)
        3:
            # Mortar / brick band near the foundation.
            _wall_panel("log_course", a, b, normal, 0.01, 0.99,
                0.19, 0.33, 0.101)
        4:
            # Two mismatched salvaged planks.
            _wall_panel("panel_patch", a, b, normal, 0.13, 0.39,
                0.58, minf(height - 0.18, 1.02 + float(salt % 3) * 0.27), 0.098)


func _decorate_building(points: PackedVector2Array, category: String) -> void:
    if points.size() < 3:
        return
    _building_count += 1
    var index := _building_count
    var recipe: Dictionary = IZBA_VARIANTS.recipe(points) if category == "house" else {
        "floor_count": 1, "body": 0, "roof": 0, "window": 0, "entrance": 0
    }
    var floors: int = int(recipe["floor_count"])
    var body_style: int = int(recipe["body"])
    var roof_style: int = int(recipe["roof"])
    var window_style: int = int(recipe["window"])
    var entrance_style: int = int(recipe["entrance"])
    if category == "house":
        _floor_counts[floors - 1] += 1
        _body_counts[body_style] += 1
        _roof_counts[roof_style] += 1
        _window_counts[window_style] += 1
        _entrance_counts[entrance_style] += 1
    var walls_height := (6.52 if floors == 2 else 3.78) if category == "house" else (2.7 if category == "sauna" else 2.35)
    var wall_style := body_style if category == "house" else (1 if category == "sauna" else 0)
    # From the supplied Russian village photographs: dark logs, faded paint,
    # mint-green fences, dull blue gables, rusty metal and pale limewash.
    var tones := ["#545047", "#594735", "#6e736d", "#5b4940", "#4b5652"]
    var painted_tones := ["#50453c", "#486260", "#62665d", "#675044", "#596878", "#706544"]
    var color_index := (index * 7 + body_style * 3) % painted_tones.size()
    var tone := Color(painted_tones[color_index]) if category == "house" else Color("#39382f" if category == "sauna" else "#47413b")
    if category == "house" and body_style == 1:
        tone = Color(tones[1]) # Exposed logs, no paint on the timber crests.
    _active_trim_key = ["trim_blue", "trim_green", "trim_red", "trim_cream"][(index + body_style) % 4]
    var roof_tones := ["#3b4244", "#5c4237", "#34312e", "#3e4548", "#474640"]
    var wall_tex := _pixel_texture(tone, 8021 + body_style * 11 + index % 3, false, wall_style)
    var roof_tex := _pixel_texture(Color(roof_tones[roof_style]), 9121 + roof_style * 13, true, roof_style)
    var wall_verts := PackedVector3Array()
    var wall_uvs := PackedVector2Array()
    var signed := _signed_area(points)
    var front_index := _building_front_edge(points)
    for i in range(points.size()):
        var a := points[i]
        var b := points[(i + 1) % points.size()]
        var side := b - a
        var length := side.length()
        if length < 0.1:
            continue
        var outward_2d := Vector2(side.y, -side.x).normalized()
        if signed < 0.0:
            outward_2d *= -1.0
        var normal := Vector3(outward_2d.x, 0, -outward_2d.y)
        var offset := normal * 0.07
        _quad(wall_verts, wall_uvs, _pt(a, 0.12) + offset, _pt(b, 0.12) + offset,
            _pt(b, walls_height) + offset, _pt(a, walls_height) + offset)
        if category == "house":
            _decorate_wall_module(a, b, normal, walls_height, body_style,
                index + i, i == front_index, floors)
        if i == front_index and length > 3.3:
            var door_half := 0.55 / length
            _wall_panel("frame", a, b, normal, 0.5 - door_half - 0.02,
                0.5 + door_half + 0.02, 0.1, 2.23)
            _wall_panel("door", a, b, normal, 0.5 - door_half,
                0.5 + door_half, 0.12, 2.13, 0.15)
            if category == "house" and length > 7.0:
                _make_window(a, b, normal, 0.19, length, index % 9 == 0,
                    index % 11 == 0, index + i, window_style)
                _make_window(a, b, normal, 0.81, length, index % 13 == 0,
                    index % 10 == 0, index + i + 3, window_style)
            if category == "house" and floors == 2 and length > 5.0:
                _make_window(a, b, normal, 0.3, length, false, false,
                    index + i + 1, window_style, 1)
                _make_window(a, b, normal, 0.7, length, false, false,
                    index + i + 4, window_style, 1)
        elif category == "house" and length > 5.0:
            _make_window(a, b, normal, 0.5, length, index % 13 == 0 and i % 2 == 0,
                (index + i) % 11 == 0, index + i, window_style)
            if floors == 2:
                _make_window(a, b, normal, 0.5, length, false, false,
                    index + i + 8, window_style, 1)
    _make_textured_mesh(wall_verts, wall_uvs, _material(Color.WHITE, wall_tex),
        category + " / modular body " + str(body_style))
    _decorate_roof(points, category, walls_height, roof_tex, index, roof_style)
    if category == "house" and points.size() == 4 and index % 7 == 3:
        var rear_index := (front_index + 2) % 4
        var rear_a: Vector2 = points[rear_index]
        var rear_b: Vector2 = points[(rear_index + 1) % 4]
        if rear_a.distance_to(rear_b) > 5.0 and _nearest_road_distance((rear_a + rear_b) * 0.5) > 3.5:
            var rear_side := rear_b - rear_a
            var rear_out := Vector2(rear_side.y, -rear_side.x).normalized()
            if signed < 0.0:
                rear_out *= -1.0
            _decorate_lean_to(rear_a, rear_b, Vector3(rear_out.x, 0.0, -rear_out.y))
    if category == "house":
        var front_a: Vector2 = points[front_index]
        var front_b: Vector2 = points[(front_index + 1) % points.size()]
        if front_a.distance_to(front_b) > 3.3:
            var front_side := front_b - front_a
            var out2d := Vector2(front_side.y, -front_side.x).normalized()
            if signed < 0.0:
                out2d *= -1.0
            _decorate_modular_entrance(front_a, front_b, Vector3(out2d.x, 0, -out2d.y),
                entrance_style)
        _decorate_showcase_yard(points, front_index)

func _decorate_modular_entrance(a: Vector2, b: Vector2,
        outward: Vector3, style: int) -> void:
    # Five compact entrances that preserve the hand-surveyed foundation footprint.
    var distance := _nearest_road_distance((a + b) * 0.5)
    var extension := 0.65 if distance < 2.8 else 1.35
    var axis := _pt(b, 0) - _pt(a, 0)
    var tangent := axis.normalized()
    var mid := _pt((a + b) * 0.5, 0.12)
    var wide := minf(1.25, axis.length() * 0.18)
    var front := mid + outward * extension
    if style == 0:
        # Bare three uneven steps.
        for n in range(3):
            var d := 0.48 + float(n) * 0.27
            _batch_box("porch_deck", mid + outward * d + Vector3.UP * (0.16 + float(2 - n) * 0.12),
                Vector3(1.65, 0.19, 0.52))
    elif style == 1:
        _decorate_entry_canopy(a, b, outward)
    elif style == 2 and extension > 1.0:
        # An enclosed vestibule with a low roof and a distinct front door.
        var l0 := mid - tangent * wide + outward * 0.14
        var r0 := mid + tangent * wide + outward * 0.14
        var l1 := front - tangent * wide
        var r1 := front + tangent * wide
        _batch_quad("lean_to", l0, l1, l1 + Vector3.UP * 2.21, l0 + Vector3.UP * 2.59)
        _batch_quad("lean_to", r1, r0, r0 + Vector3.UP * 2.59, r1 + Vector3.UP * 2.21)
        _batch_quad("lean_to", l1, r1, r1 + Vector3.UP * 2.21, l1 + Vector3.UP * 2.21)
        _batch_quad("lean_to_roof", l0 + Vector3.UP * 2.63, r0 + Vector3.UP * 2.63,
            r1 + Vector3.UP * 2.29, l1 + Vector3.UP * 2.29)
        _batch_quad("door", front - tangent * 0.46 + Vector3.UP * 0.1 + outward * 0.018,
            front + tangent * 0.46 + Vector3.UP * 0.1 + outward * 0.018,
            front + tangent * 0.46 + Vector3.UP * 1.91 + outward * 0.018,
            front - tangent * 0.46 + Vector3.UP * 1.91 + outward * 0.018)
        _lean_to_count += 1
    elif style == 3:
        # Open wooden porch with deliberately uneven supporting timbers.
        _batch_box("porch_deck", front + Vector3.UP * 0.23,
            Vector3(2.15, 0.21, 1.15))
        for sign in [-1.0, 1.0]:
            _batch_quad("porch", front + tangent * sign * wide,
                front + tangent * sign * wide + outward * 0.05,
                front + tangent * sign * wide + Vector3.UP * 1.1 + outward * 0.05,
                front + tangent * sign * wide + Vector3.UP * 1.1)
    else:
        # Patchwork high awning and two stubby posts.
        _decorate_entry_canopy(a, b, outward)
        _batch_quad("roof_patch", mid - tangent * wide + Vector3.UP * 2.72,
            mid + tangent * wide + Vector3.UP * 2.72,
            front + tangent * wide + Vector3.UP * 2.42,
            front - tangent * wide + Vector3.UP * 2.42)

func _decorate_lean_to(a: Vector2, b: Vector2, outward: Vector3) -> void:
    # Small warped annex behind selected real houses; no new map footprint.
    var line := _pt(b, 0.0) - _pt(a, 0.0)
    if line.length() < 4.5:
        return
    var tangent := line.normalized()
    var mid := _pt(a.lerp(b, 0.5), 0.13)
    var left_back := mid - tangent * 1.35 + outward * 0.10
    var right_back := mid + tangent * 1.35 + outward * 0.10
    var left_front := left_back + outward * 1.65
    var right_front := right_back + outward * 1.65
    var low := Vector3.UP * 0.12
    var high_back := Vector3.UP * 2.58
    var high_front := Vector3.UP * 1.87
    _batch_quad("lean_to", left_front + low, right_front + low,
        right_front + high_front, left_front + high_front)
    _batch_quad("lean_to", left_back + low, left_front + low,
        left_front + high_front, left_back + high_back)
    _batch_quad("lean_to", right_front + low, right_back + low,
        right_back + high_back, right_front + high_front)
    _batch_quad("lean_to_roof", left_back + high_back + Vector3.UP * 0.08,
        right_back + high_back + Vector3.UP * 0.08,
        right_front + high_front + Vector3.UP * 0.08,
        left_front + high_front + Vector3.UP * 0.08)
    _lean_to_count += 1

func _decorate_entry_canopy(a: Vector2, b: Vector2, outward: Vector3) -> void:
    # A crooked sheet-metal porch awning for selected *real* house outlines.
    # Visual-only, projects less than one metre: no extra houses or map edits.
    var line := _pt(b, 0.0) - _pt(a, 0.0)
    if line.length_squared() < 0.1:
        return
    var tangent := line.normalized()
    var back := _pt((a + b) * 0.5, 2.71) + outward * 0.18
    var front := back + outward * 0.90 + Vector3.DOWN * 0.22
    _batch_quad("awning", back - tangent * 1.12, back + tangent * 1.12,
        front + tangent * 1.08, front - tangent * 1.08)
    # Bent posts are a small silhouette cue; avoid extra light sources.
    _batch_box("porch", front - tangent * 1.00 + Vector3.DOWN * 0.48,
        Vector3(0.10, 0.95, 0.10))
    _batch_box("porch", front + tangent * 1.00 + Vector3.DOWN * 0.48,
        Vector3(0.10, 0.95, 0.10))
    _canopy_count += 1

func _decorate_showcase_yard(points: PackedVector2Array, front_edge: int) -> void:
    # Only a single actual surveyed house near spawn receives the atmospheric micro-scene.
    if _feature_house_center == Vector2(INF, INF):
        return
    var centroid := Vector2.ZERO
    for p in points:
        centroid += p
    centroid /= float(points.size())
    if centroid.distance_to(_feature_house_center) > 0.15:
        return
    var a: Vector2 = points[front_edge]
    var b: Vector2 = points[(front_edge + 1) % points.size()]
    var side := b - a
    if side.length() < 4.0:
        return
    # Leave roadside clear and build a porch only if the house is set back enough.
    if _nearest_road_distance((a + b) * 0.5) < 4.5:
        return
    var orientation := 1.0 if _signed_area(points) > 0.0 else -1.0
    var outward_2d := Vector2(side.y, -side.x).normalized() * orientation
    var vout := Vector3(outward_2d.x, 0, -outward_2d.y)
    var tangent := Vector3(side.x, 0, -side.y).normalized()
    var origin := _pt((a + b) * 0.5, 0.18)
    # Three uneven timber steps, woodpile and one creaking yard lamp.
    for i in range(3):
        var delta := vout * (0.55 + float(i) * 0.58)
        var h := 0.48 - float(i) * 0.12
        var half_width := 1.10 + float(i) * 0.08
        var left := origin + delta - tangent * half_width + Vector3.UP * h
        var right := origin + delta + tangent * half_width + Vector3.UP * h
        _batch_quad("porch", left, right, right + vout * 0.42, left + vout * 0.42)
        _batch_quad("porch", left + Vector3.DOWN * 0.12, right + Vector3.DOWN * 0.12, right, left)
    # Wood crates near the front wall.
    var stack_origin := origin + tangent * 2.25 + vout * 1.4
    for i in range(4):
        _batch_box("porch", stack_origin + tangent * float(i % 2) * 0.62 +
            Vector3.UP * (0.18 + 0.36 * float(i / 2)),
            Vector3(0.52, 0.32, 0.50))
    # A dim yard lantern outside the doorway.
    var lamp_origin := origin - tangent * 2.0 + vout * 2.25
    _batch_box("chimney", lamp_origin + Vector3.UP * 1.55, Vector3(0.13, 3.05, 0.13))
    _batch_box("lamp", lamp_origin + Vector3.UP * 3.05, Vector3(0.35, 0.36, 0.35))
    var light := OmniLight3D.new()
    light.name = "Старая лампа у крыльца"
    light.position = lamp_origin + Vector3.UP * 3.05
    light.light_color = Color("#ffb46d")
    light.light_energy = 0.38
    light.light_specular = 0.0
    light.omni_range = 7.5
    light.shadow_enabled = false
    add_child(light)
    print("MANUAL_SHOWCASE_YARD_READY: ", centroid)

func _roof_face(verts: PackedVector3Array, uvs: PackedVector2Array,
        a: Vector2, b: Vector2, c: Vector2, ah: float, bh: float, ch: float) -> void:
    _face(verts, uvs, _pt(a, ah), _pt(b, bh), _pt(c, ch),
        Vector2(0, 0), Vector2(a.distance_to(b) / 5.0, 0),
        Vector2(a.distance_to(c) / 5.0, 1.0))

func _decorate_roof_patch(eave_a: Vector2, eave_b: Vector2,
        ridge_a: Vector2, ridge_b: Vector2, eave: float, rise: float) -> void:
    # Uneven patch of repaired sheet metal follows the existing roof slope.
    var low_t := 0.31
    var high_t := 0.64
    var l0 := eave_a.lerp(eave_b, 0.18).lerp(ridge_a.lerp(ridge_b, 0.18), low_t)
    var r0 := eave_a.lerp(eave_b, 0.58).lerp(ridge_a.lerp(ridge_b, 0.58), low_t)
    var r1 := eave_a.lerp(eave_b, 0.58).lerp(ridge_a.lerp(ridge_b, 0.58), high_t)
    var l1 := eave_a.lerp(eave_b, 0.18).lerp(ridge_a.lerp(ridge_b, 0.18), high_t)
    _batch_quad("roof_patch", _pt(l0, eave + rise * low_t + 0.065),
        _pt(r0, eave + rise * low_t + 0.065),
        _pt(r1, eave + rise * high_t + 0.065),
        _pt(l1, eave + rise * high_t + 0.065))
    _roof_patch_count += 1

func _decorate_roof(points: PackedVector2Array, category: String, base: float,
        tex: Texture2D, index: int, roof_style: int = 0) -> void:
    var v := PackedVector3Array()
    var uv := PackedVector2Array()
    var rise := 0.7
    if category == "house":
        match roof_style:
            0: rise = 1.72  # Traditional gable
            1: rise = 0.84  # Low slate gable
            2: rise = 2.45  # Tall pointed gable
            3: rise = 1.58  # Four-sided hip
            4: rise = 0.96  # Asymmetric lean-to
    var eave := base + 0.12
    # Visual roof only expands 0.28m beyond the unchanged manual building polygon.
    var footprint_center := Vector2.ZERO
    for p in points:
        footprint_center += p
    footprint_center /= float(maxi(1, points.size()))
    var roof_points := PackedVector2Array()
    for p in points:
        var direction := (p - footprint_center).normalized()
        roof_points.append(p + direction * (0.28 if category == "house" else 0.09))
    if roof_points.size() == 4:
        # Put the long sides on a-b and d-c, regardless of footprint rotation.
        var across_0 := roof_points[0].distance_to(roof_points[1])
        var across_1 := roof_points[1].distance_to(roof_points[2])
        var a: Vector2 = roof_points[0] if across_0 >= across_1 else roof_points[1]
        var b: Vector2 = roof_points[1] if across_0 >= across_1 else roof_points[2]
        var c: Vector2 = roof_points[2] if across_0 >= across_1 else roof_points[3]
        var d: Vector2 = roof_points[3] if across_0 >= across_1 else roof_points[0]
        var ridge0 := (a + d) * 0.5
        var ridge1 := (b + c) * 0.5
        if category == "house" and roof_style == 3:
            # Hip: short inset ridge, four visible slopes.
            var hip0 := ridge0.lerp(ridge1, 0.20)
            var hip1 := ridge0.lerp(ridge1, 0.80)
            _roof_face(v, uv, a, b, hip1, eave, eave, eave + rise)
            _roof_face(v, uv, a, hip1, hip0, eave, eave + rise, eave + rise)
            _roof_face(v, uv, d, hip0, hip1, eave, eave + rise, eave + rise)
            _roof_face(v, uv, d, hip1, c, eave, eave + rise, eave)
            _roof_face(v, uv, a, hip0, d, eave, eave + rise, eave)
            _roof_face(v, uv, b, c, hip1, eave, eave, eave + rise)
        elif category == "house" and roof_style == 4:
            # One continuous sloping panel and end walls: recognisably a shed roof.
            _roof_face(v, uv, a, b, c, eave + rise, eave + rise, eave)
            _roof_face(v, uv, a, c, d, eave + rise, eave, eave)
            _roof_face(v, uv, d, a, (d + a) * 0.5, eave, eave + rise, eave + rise * 0.5)
            _roof_face(v, uv, c, b, (c + b) * 0.5, eave, eave + rise, eave + rise * 0.5)
            _batch_quad("panel_patch", _pt(a, eave), _pt(b, eave),
                _pt(b, eave + rise), _pt(a, eave + rise))
        else:
            _roof_face(v, uv, a, b, ridge1, eave, eave, eave + rise)
            _roof_face(v, uv, a, ridge1, ridge0, eave, eave + rise, eave + rise)
            _roof_face(v, uv, d, ridge0, ridge1, eave, eave + rise, eave + rise)
            _roof_face(v, uv, d, ridge1, c, eave, eave + rise, eave)
            _roof_face(v, uv, a, ridge0, d, eave, eave + rise, eave)
            _roof_face(v, uv, b, c, ridge1, eave, eave, eave + rise)
            if category == "house" and index % 3 == 1:
                _decorate_roof_patch(a, b, ridge0, ridge1, eave, rise)
    else:
        var centroid := Vector2.ZERO
        for p in roof_points:
            centroid += p
        centroid /= float(roof_points.size())
        for i in range(roof_points.size()):
            _roof_face(v, uv, roof_points[i], roof_points[(i + 1) % roof_points.size()],
                centroid, eave, eave, eave + rise)
    # A dark fascia wraps the street-side overhang and makes roof thickness legible.
    if category == "house" and roof_style != 4:
        for edge in range(roof_points.size()):
            var p := roof_points[edge]
            var q := roof_points[(edge + 1) % roof_points.size()]
            _batch_quad("fascia", _pt(p, eave - 0.19),
                _pt(q, eave - 0.19), _pt(q, eave + 0.06),
                _pt(p, eave + 0.06))
            _eaves_count += 1
    _make_textured_mesh(v, uv, _material(Color.WHITE, tex),
        category + " / modular roof " + str(roof_style))
    if category == "house" and index % 3 != 0:
        var center := Vector2.ZERO
        for p in roof_points:
            center += p
        center /= float(roof_points.size())
        _batch_box("chimney", _pt(center + Vector2(0.5, 0.4), base + rise * 0.65 + 0.25),
            Vector3(0.7, 1.1, 0.7))

func _box_faces(verts: PackedVector3Array, center: Vector3, size: Vector3) -> void:
    var lo := center - size * 0.5
    var hi := center + size * 0.5
    var a := Vector3(lo.x, lo.y, lo.z)
    var b := Vector3(hi.x, lo.y, lo.z)
    var c := Vector3(hi.x, hi.y, lo.z)
    var d := Vector3(lo.x, hi.y, lo.z)
    var e := Vector3(lo.x, lo.y, hi.z)
    var f := Vector3(hi.x, lo.y, hi.z)
    var g := Vector3(hi.x, hi.y, hi.z)
    var h := Vector3(lo.x, hi.y, hi.z)
    for face in [[a, b, c, d], [f, e, h, g], [e, a, d, h],
            [b, f, g, c], [d, c, g, h], [e, f, b, a]]:
        _push_tri(verts, face[0], face[1], face[2])
        _push_tri(verts, face[0], face[2], face[3])

func _batch_box(key: String, center: Vector3, size: Vector3) -> void:
    var verts: PackedVector3Array = _detail_batches.get(key, PackedVector3Array())
    _box_faces(verts, center, size)
    _detail_batches[key] = verts

func _append_box_to(verts: PackedVector3Array, center: Vector3, size: Vector3) -> void:
    _box_faces(verts, center, size)

func _append_crooked_post(verts: PackedVector3Array, p: Vector2,
        height: float, tilt: Vector2) -> void:
    # Eight vertices make the whole post lean, rather than sliding an upright box.
    var foot := _pt(p, 0.12)
    var head := _pt(p + tilt, 0.12 + height)
    var xx := Vector3(0.085, 0.0, 0.0)
    var zz := Vector3(0.0, 0.0, 0.085)
    var corners := [
        foot - xx - zz, foot + xx - zz, foot + xx + zz, foot - xx + zz,
        head - xx - zz, head + xx - zz, head + xx + zz, head - xx + zz
    ]
    for face in [[0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6],
            [3, 0, 4, 7], [4, 5, 6, 7], [3, 2, 1, 0]]:
        _push_tri(verts, corners[face[0]], corners[face[1]], corners[face[2]])
        _push_tri(verts, corners[face[0]], corners[face[2]], corners[face[3]])

func _fence_edge(a: Vector2, b: Vector2, gate_center: bool) -> void:
    var length := a.distance_to(b)
    if length < 0.35:
        return
    var count := maxi(1, int(ceil(length / 2.8)))
    var tang := (b - a) / length
    var gate_a := 0.0
    var gate_b := 0.0
    if gate_center and length >= 6.0:
        gate_a = length * 0.5 - 1.85
        gate_b = length * 0.5 + 1.85
    for i in range(count + 1):
        var t := float(i) / float(count)
        var dist := length * t
        if gate_center and dist >= gate_a and dist <= gate_b:
            continue
        # Missing posts and subtly different heights break up perfect suburban grids.
        if _fence_count % 5 == 2 and (i * 11 + _fence_count) % 17 == 0:
            continue
        var p := a.lerp(b, t)
        var h := 1.40 + 0.25 * sin(float(i * 13 + _fence_count * 7))
        var tilt := Vector2(
            0.20 * sin(float(i * 19 + _fence_count)),
            0.15 * cos(float(i * 17 + _fence_count * 3)))
        _append_crooked_post(_fence_posts, p, h, tilt)
    for i in range(count):
        var from_dist := length * float(i) / float(count)
        var to_dist := length * float(i + 1) / float(count)
        var segment_mid := (from_dist + to_dist) * 0.5
        if gate_center and segment_mid >= gate_a and segment_mid <= gate_b:
            continue
        var start := a + tang * from_dist
        var finish := a + tang * to_dist
        # Some plots have an irregular full picket fence; others keep the old open rails.
        if _fence_count % 3 == 1:
            var slat_count := maxi(1, int(ceil((to_dist - from_dist) / 0.74)))
            for j in range(slat_count):
                if (i * 7 + j * 13 + _fence_count) % 17 == 0:
                    continue
                var fraction := (float(j) + 0.5) / float(slat_count)
                var center := start.lerp(finish, fraction)
                var h := 1.10 + 0.3 * sin(float(i * 19 + j * 17))
                _append_box_to(_fence_slats, _pt(center, h * 0.5 + 0.12),
                    Vector3(0.13, h, 0.13))
        for y in [0.52, 1.10]:
            # Vertical timber ribbons facing the street: older rails were
            # horizontal zero-thickness strips and nearly invisible at eye level.
            var v0 := _pt(start, y)
            var v1 := _pt(finish, y)
            var toward := Vector3(-tang.y, 0, -tang.x).normalized() * 0.04
            var down := Vector3.UP * 0.085
            _push_tri(_fence_rails, v0 + toward - down, v1 + toward - down, v1 + toward + down)
            _push_tri(_fence_rails, v0 + toward - down, v1 + toward + down, v0 + toward + down)

func _clear_of_buildings(p: Vector2, gap: float) -> bool:
    for footprint in _building_polygons:
        if Geometry2D.is_point_in_polygon(p, footprint):
            return false
        for i in range(footprint.size()):
            var q := Geometry2D.get_closest_point_to_segment(p,
                footprint[i], footprint[(i + 1) % footprint.size()])
            if p.distance_to(q) < gap:
                return false
    return true

func _yard_box(key: String, center: Vector2, offset: Vector2,
        elevation: float, size: Vector3, rotation: float) -> void:
    # Oriented 3D batch primitive; no separate MeshInstance per rake / planter.
    var faces := PackedVector3Array()
    _box_faces(faces, Vector3.ZERO, size)
    var basis := Basis(Vector3.UP, rotation)
    var pos := _pt(center, elevation) + basis * Vector3(offset.x, 0, offset.y)
    var current: PackedVector3Array = _detail_batches.get(key, PackedVector3Array())
    for vertex in faces:
        current.append(pos + basis * vertex)
    _detail_batches[key] = current


func _yard_quad(key: String, center: Vector2, rotation: float,
        a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
    var basis := Basis(Vector3.UP, rotation)
    var origin := _pt(center, 0.0)
    _batch_quad(key, origin + basis * a, origin + basis * b,
        origin + basis * c, origin + basis * d)


func _yard_prop(center: Vector2, kind: int, rotation: float, salt: int) -> void:
    match kind:
        0:
            # Rough timber well with a sloping cover, bucket, and hand crank.
            for side in [-1.0, 1.0]:
                _yard_box("well_stone", center, Vector2(side * 0.58, 0.0),
                    0.59, Vector3(0.23, 0.99, 1.34), rotation)
                _yard_box("well_stone", center, Vector2(0.0, side * 0.58),
                    0.59, Vector3(1.12, 0.99, 0.23), rotation)
                _yard_box("well_wood", center, Vector2(side * 0.75, 0.0),
                    1.43, Vector3(0.15, 2.8, 0.15), rotation)
            _yard_box("well_wood", center, Vector2.ZERO,
                2.57, Vector3(1.78, 0.15, 0.17), rotation)
            _yard_quad("yard_tin", center, rotation,
                Vector3(-1.03, 2.59, -0.96), Vector3(0, 3.03, -0.96),
                Vector3(0, 3.03, 0.96), Vector3(-1.03, 2.59, 0.96))
            _yard_quad("yard_tin", center, rotation,
                Vector3(0, 3.03, -0.96), Vector3(1.03, 2.59, -0.96),
                Vector3(1.03, 2.59, 0.96), Vector3(0, 3.03, 0.96))
            _yard_box("yard_rust", center, Vector2(0.0, 0.08),
                1.25, Vector3(0.27, 0.42, 0.30), rotation)
        1:
            # Three vegetable beds, low timber edging and sparse 90s vegetable sprouts.
            for lane in range(3):
                var x := -1.25 + float(lane) * 1.24
                _yard_box("soil", center, Vector2(x, 0),
                    0.185, Vector3(0.84, 0.22, 3.12), rotation)
                for side in [-1.0, 1.0]:
                    _yard_box("bed_edge", center, Vector2(x + side * 0.43, 0),
                        0.21, Vector3(0.095, 0.29, 3.28), rotation)
                for seedling in range(4):
                    var z := -1.15 + float(seedling) * 0.72
                    if (salt + seedling + lane) % 4 != 0:
                        _yard_box("sprout", center, Vector2(x, z), 0.49,
                            Vector3(0.23, 0.39, 0.23), rotation)
        2:
            # Low polygonal greenhouse, matte dirty glazing and real A-frame roof.
            for side in [-1.0, 1.0]:
                _yard_box("greenhouse_glass", center, Vector2(side * 1.10, 0.0),
                    1.01, Vector3(0.10, 1.72, 3.73), rotation)
            for end in [-1.0, 1.0]:
                _yard_box("greenhouse_frame", center, Vector2(0.0, end * 1.82),
                    0.99, Vector3(2.29, 1.85, 0.08), rotation)
            for z in [-1.8, 0.0, 1.8]:
                for side in [-1.0, 1.0]:
                    _yard_box("greenhouse_frame", center, Vector2(side * 1.11, z),
                        1.00, Vector3(0.12, 1.9, 0.12), rotation)
            _yard_quad("greenhouse_roof", center, rotation,
                Vector3(-1.18, 1.93, -1.95), Vector3(0, 2.65, -1.95),
                Vector3(0, 2.65, 1.95), Vector3(-1.18, 1.93, 1.95))
            _yard_quad("greenhouse_roof", center, rotation,
                Vector3(0, 2.65, -1.95), Vector3(1.18, 1.93, -1.95),
                Vector3(1.18, 1.93, 1.95), Vector3(0, 2.65, 1.95))
        3:
            # Stack of cut firewood with pale endgrain; wood shelter from old planks.
            for layer in range(3):
                for log in range(5):
                    var x := -1.34 + float(log) * 0.62
                    var z := -0.52 + float(layer % 2) * 0.14
                    _yard_box("woodpile", center, Vector2(x, z),
                        0.27 + float(layer) * 0.37,
                        Vector3(0.46, 0.34, 1.28), rotation)
                    _yard_box("wood_end", center, Vector2(x, z + 0.68),
                        0.27 + float(layer) * 0.37,
                        Vector3(0.37, 0.26, 0.08), rotation)
            _yard_box("yard_tin", center, Vector2(0.0, -0.52),
                1.41, Vector3(3.65, 0.13, 1.62), rotation)
        4:
            # Abandoned oil barrel, bent corrugated sheet, shovel, scraps, tire.
            _yard_box("yard_rust", center, Vector2(-0.79, 0.54),
                0.56, Vector3(0.62, 1.08, 0.62), rotation)
            _yard_box("yard_tin", center, Vector2(0.61, -0.10),
                0.23, Vector3(1.65, 0.12, 1.36), rotation + 0.31)
            _yard_box("woodpile", center, Vector2(0.78, 0.74),
                0.24, Vector3(1.22, 0.19, 0.24), rotation - 0.2)
            _yard_box("well_wood", center, Vector2(0.66, 1.03),
                0.89, Vector3(0.09, 1.62, 0.10), rotation + 0.25)
            _yard_box("yard_tool", center, Vector2(0.66, 1.03),
                0.17, Vector3(0.29, 0.28, 0.10), rotation + 0.25)
            _yard_box("yard_tire", center, Vector2(-0.15, -1.09),
                0.23, Vector3(0.74, 0.46, 0.65), rotation)


func _yard_spot_ok(p: Vector2, polygon: PackedVector2Array,
        other: Array[Vector2]) -> bool:
    if not Geometry2D.is_point_in_polygon(p, polygon):
        return false
    if _nearest_road_distance(p) < 4.4 or not _clear_of_buildings(p, 3.5):
        return false
    # Keep bulky objects inside the user's hand-drawn plot, not across fence lines.
    for i in range(polygon.size()):
        var q := Geometry2D.get_closest_point_to_segment(p, polygon[i],
            polygon[(i + 1) % polygon.size()])
        if p.distance_to(q) < 2.65:
            return false
    for previous in other:
        if p.distance_to(previous) < 5.0:
            return false
    return true


func _decorate_plot_props(points: PackedVector2Array) -> void:
    # No procedural houses, only household props inside the 34 surveyed plots.
    # Seed is fixed per plot to keep the same yard every time the level loads.
    if points.size() < 3:
        return
    var low := Vector2(INF, INF)
    var high := Vector2(-INF, -INF)
    for p in points:
        low = low.min(p)
        high = high.max(p)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1996001 + _fence_count * 8191
    var target := 1 + _fence_count % 3
    var placed: Array[Vector2] = []
    var attempts := 0
    while placed.size() < target and attempts < 120:
        attempts += 1
        var p := Vector2(rng.randf_range(low.x, high.x),
            rng.randf_range(low.y, high.y))
        if not _yard_spot_ok(p, points, placed):
            continue
        var kind := (_fence_count * 3 + placed.size() * 2) % 5
        var rotation := float(rng.randi_range(0, 3)) * PI * 0.5
        _yard_prop(p, kind, rotation, _fence_count + attempts)
        _yard_counts[kind] += 1
        _plot_props_count += 1
        placed.append(p)


func _decorate_fence(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    _fence_count += 1
    var gate_edge := 0
    var near := INF
    for i in range(points.size()):
        var distance := _nearest_road_distance((points[i] + points[(i + 1) % points.size()]) * 0.5)
        if distance < near:
            near = distance
            gate_edge = i
    for i in range(points.size()):
        _fence_edge(points[i], points[(i + 1) % points.size()], i == gate_edge)
    _decorate_plot_props(points)

func _decorate_road(points: PackedVector2Array) -> void:
    if points.size() < 2:
        return
    _road_count += 1
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var perpendicular := Vector2(-(b.y-a.y), (b.x-a.x)).normalized()
        for lane in [-1.0, 1.0]:
            var off: Vector2 = perpendicular * float(lane) * 1.18
            var pa := _pt(a + off, 0.134)
            var pb := _pt(b + off, 0.134)
            var side := Vector3(perpendicular.x, 0, -perpendicular.y) * 0.10
            _push_tri(_road_ruts, pa - side, pa + side, pb + side)
            _push_tri(_road_ruts, pa - side, pb + side, pb - side)
    _decorate_utility_poles(points)

func _wire_segment(a: Vector3, b: Vector3) -> void:
    # Thin vertical ribbons remain visible against the sky in the Web renderer.
    var thickness := Vector3.UP * 0.016
    _push_tri(_overhead_wires, a - thickness, a + thickness, b + thickness)
    _push_tri(_overhead_wires, a - thickness, b + thickness, b - thickness)

func _decorate_utility_poles(points: PackedVector2Array) -> void:
    # Props follow surveyed road coordinates; they are not new map objects.
    # Hard cap for fast Godot Web export and a sparsely electrified 1990s village.
    for i in range(points.size() - 1):
        if _utility_pole_count >= 35:
            return
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var length := a.distance_to(b)
        if length < 36.0:
            continue
        var direction := (b - a) / length
        var perpendicular := Vector2(-direction.y, direction.x)
        var roadside := 3.9 * (1.0 if _road_count % 3 != 0 else -1.0)
        var number := maxi(1, int(floor(length / 43.0)))
        var previous := Vector2(INF, INF)
        for j in range(number):
            if _utility_pole_count >= 35:
                return
            var p := a.lerp(b, (float(j) + 0.5) / float(number)) + perpendicular * roadside
            _batch_box("pole", _pt(p, 3.05), Vector3(0.22, 6.1, 0.22))
            _batch_box("crossarm", _pt(p, 5.85), Vector3(1.3, 0.16, 0.17))
            if previous != Vector2(INF, INF):
                var horizontal := Vector3(perpendicular.x, 0.0, -perpendicular.y)
                for offset in [-0.42, 0.42]:
                    var from_pos := _pt(previous, 5.8) + horizontal * float(offset)
                    var to_pos := _pt(p, 5.8) + horizontal * float(offset)
                    var middle := (from_pos + to_pos) * 0.5 - Vector3.UP * 0.3
                    _wire_segment(from_pos, middle)
                    _wire_segment(middle, to_pos)
            previous = p
            _utility_pole_count += 1

func _decorate_forest(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    var area := 0.0
    for i in range(points.size()):
        lo = lo.min(points[i])
        hi = hi.max(points[i])
        var q: Vector2 = points[(i + 1) % points.size()]
        area += points[i].x * q.y - q.x * points[i].y
    var amount := mini(80, int(absf(area) / 2700.0))
    var rng := RandomNumberGenerator.new()
    rng.seed = 99221 + int(absf(lo.x * 13.0 + lo.y * 7.0))
    var placed := 0
    for _trial in range(amount * 25):
        if placed >= amount:
            break
        var p := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
        if not Geometry2D.is_point_in_polygon(p, points):
            continue
        if _nearest_road_distance(p) < 13.0:
            continue
        var scale := rng.randf_range(0.7, 1.07)
        var basis := Basis().rotated(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale)
        if placed % 3 == 0:
            _aspen_positions.append(Transform3D(basis, _pt(p, 4.25 * scale)))
            _aspen_trunks.append(Transform3D(basis, _pt(p, 1.75 * scale)))
        else:
            _bush_positions.append(Transform3D(basis, _pt(p, 0.85 * scale)))
        placed += 1

func _add_instanced(mesh: Mesh, instances: Array[Transform3D], tint: Color, name: String) -> void:
    if instances.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = instances.size()
    for i in range(instances.size()):
        multi.set_instance_transform(i, instances[i])
    var node := MultiMeshInstance3D.new()
    node.name = name
    node.multimesh = multi
    var foliage_material := _material(tint)
    # The unshaded foliage stayed saturated/bright in fog; use soft diffuse instead.
    node.material_override = foliage_material
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _create_forest_assets() -> void:
    var canopy := SphereMesh.new()
    canopy.radius = 1.95
    canopy.height = 3.8
    canopy.radial_segments = 5
    canopy.rings = 3
    _add_instanced(canopy, _aspen_positions, Color("#283e36"), "Осинник / ломаные кроны")
    var aspen_trunk := CylinderMesh.new()
    aspen_trunk.top_radius = 0.13
    aspen_trunk.bottom_radius = 0.27
    aspen_trunk.height = 3.5
    aspen_trunk.radial_segments = 5
    _add_instanced(aspen_trunk, _aspen_trunks, Color("#33352f"), "Осинник / стволы")
    var bush := SphereMesh.new()
    bush.radius = 0.85
    bush.height = 1.6
    bush.radial_segments = 5
    bush.rings = 2
    _add_instanced(bush, _bush_positions, Color("#2d4237"), "Подлесок / репейник")
