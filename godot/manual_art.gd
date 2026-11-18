extends Node3D
# CHERNOZERYE 3.9 / ROAD, ENTRY AND ROOF STABILIZATION
# All spatial placements derive from the user's manual GeoJSON features.
# Decorative features are deterministic and never modify the survey geometry.

const IZBA_VARIANTS = preload("res://izba_variants.gd")
const WOOD_TONES := ["#454941", "#51473e", "#3b4039", "#4e433c", "#43463d", "#525047"]
const ROOF_TONES := ["#282e31", "#373432", "#30383a", "#403933"]
const DOOR_COLOR := Color("#24221f")
const FRAME_COLOR := Color("#73796d")
const WINDOW_COLOR := Color("#131a1f")
const WINDOW_LIT := Color("#b9a16a")
const WINDOW_OTHERWORLDLY_BLUE := Color("#83aed0")
const WINDOW_OTHERWORLDLY_GREEN := Color("#77bdab")
const FENCE_COLOR := Color("#494840")
const POST_COLOR := Color("#3e3c36")
const RUT_COLOR := Color("#383029")

# Hand-surveyed geometry remains fixed; clearance affects decorative objects only.
var _roads: Array = []
# Batched double-sided static collision surfaces for the manual village.
var _building_collision_faces := PackedVector3Array()
var _fence_collision_faces := PackedVector3Array()
var _yard_collision_faces := PackedVector3Array()
var _collision_building_count := 0
var _collision_fence_span_count := 0
var _collision_yard_count := 0
var _plot_edges: Array = []
var _entrance_routes: Array = []
var _fronts_facing_road := 0
var _reserved_gate_sections := 0
var _fence_panels_skipped := 0
var _fence_panels_total := 0
var _fence_panels_relocated := 0
var _fence_short_spans_recovered := 0
var _fence_joints_joined := 0
var _last_fence_endpoint := Vector2(INF, INF)
var _first_fence_endpoint := Vector2(INF, INF)
var _last_fence_post := Vector2(INF, INF)
var _yard_positions_rejected := 0
var _roof_joints_sealed := 0
var _detail_batches: Dictionary = {}
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lights_placed: int = 0
var _house_ordinal := 0
var _current_house_light_kind := ""
var _house_light_claimed := false
var _warm_windows := 0
var _otherworldly_windows := 0
var _dark_houses := 0
var _new_boarded_windows := 0
var _sealed_entries := 0
var _eerie_motes := 0
var _warm_houses := 0
var _anomalous_houses := 0
var _anomaly_lamps: Array[OmniLight3D] = []
var _anomaly_clock := 0.0
var _street_lights := 0
var _street_lamp_heads := 0
var _balcony_count := 0
var _fence_posts: PackedVector3Array = PackedVector3Array()
var _fence_rails: PackedVector3Array = PackedVector3Array()
var _fence_wire_mesh: PackedVector3Array = PackedVector3Array()
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
var _building_bounds: Array[Rect2] = []
var _plot_props_count := 0
var _flower_patches := 0
var _front_walkways := 0
var _chimney_smoke_sources: Array[Vector3] = []
var _chimneys_smoking := 0
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
var _yard_counts := [0, 0, 0, 0, 0, 0, 0]
var _clipped_log_segments := 0

func _process(delta: float) -> void:
    # Barely perceptible asynchronous pulsing is reserved for the two anomalies.
    # Dark windows stay dark, so the effect is unmistakably out of place.
    _anomaly_clock += delta
    for i in range(_anomaly_lamps.size()):
        var lamp := _anomaly_lamps[i]
        if is_instance_valid(lamp):
            var wave := sin(_anomaly_clock * (0.72 + float(i) * 0.19) + float(i) * 2.7)
            lamp.light_energy = 0.39 + wave * 0.08


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
        var pmin := Vector2(INF, INF)
        var pmax := Vector2(-INF, -INF)
        for p in points:
            pmin = pmin.min(p)
            pmax = pmax.max(p)
        _building_bounds.append(Rect2(pmin, pmax - pmin))
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
        var kind: String = str(item.get("type", ""))
        if kind in ["road", "path"]:
            var road_points := _local_points(item.get("points", []))
            var width := 3.8 if kind == "road" else 1.6
            for i in range(road_points.size() - 1):
                _roads.append([road_points[i], road_points[i + 1], width])
        elif kind == "plot":
            var plot_points := _local_points(item.get("points", []))
            if plot_points.size() >= 3:
                for i in range(plot_points.size()):
                    _plot_edges.append([plot_points[i], plot_points[(i + 1) % plot_points.size()]])
    # Roads and building footprints are known now: reserve safe approaches before
    # either garden props or fence panels are placed.
    _build_entrance_routes(features)
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
    _build_collision_bodies()
    _create_solid_mesh(_fence_posts, Color("#423b35"), "Забор / столбы")
    _create_solid_mesh(_fence_rails, Color("#48433d"), "Забор / рейки")
    _create_solid_mesh(_fence_wire_mesh, Color("#4c6759"), "Старая зелёная рабица")
    _create_solid_mesh(_fence_slats, Color("#3a3b35"), "Забор / обветшавший штакетник")
    _create_solid_mesh(_yard_details, Color("#48443b"), "Старый деревенский быт / ящики и дрова")
    _create_solid_mesh(_road_ruts, RUT_COLOR, "Дорога / земляные колеи")
    _create_solid_mesh(_overhead_wires, Color("#242d2d"), "Старые кабели / провисшие линии")
    _create_chimney_smoke()
    print("ABANDONED_VILLAGE_LIGHTS_READY: houses=", _house_ordinal,
        " dark=", _dark_houses, " warm_houses=", _warm_houses,
        " anomalous_houses=", _anomalous_houses,
        " warm_windows=", _warm_windows,
        " otherworldly_windows=", _otherworldly_windows)
    print("ABANDONMENT_FACADE_READY: boarded_windows=", _new_boarded_windows,
        " sealed_entries=", _sealed_entries, " anomaly_motes=", _eerie_motes)
    print("MANUAL_UTILITY_READY: poles=", _utility_pole_count,
        " lamp_heads=", _street_lamp_heads, " warm_lights=", _street_lights,
        " balconies=", _balcony_count,
        " flower_patches=", _flower_patches, " walks=", _front_walkways,
        " chimney_smoke=", _chimneys_smoking)
    _create_forest_assets()
    print("VILLAGE_COLLISION_READY: buildings=", _collision_building_count,
        " fence_spans=", _collision_fence_span_count,
        " large_yard_props=", _collision_yard_count,
        " collision_bodies=3")
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
        " firewood=", _yard_counts[3], " scrap=", _yard_counts[4],
        " benches=", _yard_counts[5], " collapsed_gate=", _yard_counts[6])
    print("VILLAGE_FENCE_JOINTS_READY: bridged=", _fence_joints_joined,
        " short_spans_recovered=", _fence_short_spans_recovered,
        " entrance_routes=", _entrance_routes.size(),
        " gate_sections_reserved=", _reserved_gate_sections)
    print("VILLAGE_CLEARANCE_READY: rejected_fence_panels=", _fence_panels_skipped,
        " total_fence_panels=", _fence_panels_total,
        " relocated_fence_panels=", _fence_panels_relocated,
        " rejected_yard_positions=", _yard_positions_rejected,
        " sealed_roof_joints=", _roof_joints_sealed)


func _collision_wall(faces: PackedVector3Array,
        a: Vector3, b: Vector3, floor_height: float, top_height: float) -> void:
    if a.distance_squared_to(b) < 0.01 or top_height <= floor_height:
        return
    var p := Vector3(a.x, floor_height, a.z)
    var q := Vector3(b.x, floor_height, b.z)
    var r := Vector3(b.x, top_height, b.z)
    var t := Vector3(a.x, top_height, a.z)
    _push_tri(faces, p, q, r)
    _push_tri(faces, p, r, t)


func _register_building_collider(points: PackedVector2Array, height: float) -> void:
    # Match the same footprint used to render actual walls, not invisible blockout.
    for i in range(points.size()):
        var a: Vector2 = points[i]
        var b: Vector2 = points[(i + 1) % points.size()]
        _collision_wall(_building_collision_faces, _pt(a, 0.0),
            _pt(b, 0.0), 0.02, height)
    _collision_building_count += 1


func _register_fence_collider(a: Vector2, b: Vector2) -> void:
    _collision_wall(_fence_collision_faces, _pt(a, 0.0),
        _pt(b, 0.0), 0.08, 1.40)
    _collision_fence_span_count += 1


func _build_collision_body(faces: PackedVector3Array, label: String) -> void:
    if faces.is_empty():
        return
    var body := StaticBody3D.new()
    body.name = label
    body.collision_layer = 1
    body.collision_mask = 1
    var shape := ConcavePolygonShape3D.new()
    shape.set_faces(faces)
    shape.backface_collision = true
    var collider := CollisionShape3D.new()
    collider.shape = shape
    body.add_child(collider)
    add_child(body)


func _build_collision_bodies() -> void:
    _build_collision_body(_building_collision_faces, "CollisionBuildings")
    _build_collision_body(_fence_collision_faces, "CollisionFences")
    _build_collision_body(_yard_collision_faces, "CollisionYardProps")


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
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
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
            # Slate's one-texel scratches and strong random pixel noise caused
            # moire/crawling every time the camera moved. Preserve broad weathering
            # while making the roof texture strictly low-frequency and mip-safe.
            var offset := rng.randf_range(-0.025, 0.015) if rooftop else rng.randf_range(-0.095, 0.038)
            if rooftop:
                match wall_style:
                    0: # Slate rows, with muted wide corrugations.
                        if y % 16 < 3: offset -= 0.055
                        if x % 18 < 3: offset -= 0.026
                    1: # Faded rusty iron panels.
                        if x % 17 < 4: offset -= 0.060
                        if y % 27 < 3: offset -= 0.029
                    2: # Broad timber planks.
                        if x % 20 < 4: offset -= 0.068
                        if y % 24 < 3: offset -= 0.030
                    3: # Broad irregular repairs, no individual hot pixels.
                        if (int(x / 18) + int(y / 18)) % 4 == 0: offset -= 0.060
                    4: # Wavy old asbestos sheets.
                        if x % 16 < 4: offset -= 0.058
                        if y % 24 < 3: offset -= 0.038
                offset += 0.010 * sin(float(x) * 0.17 + float(y) * 0.08)
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
    img.generate_mipmaps()
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
        "window_eerie_blue": WINDOW_OTHERWORLDLY_BLUE,
        "window_eerie_green": WINDOW_OTHERWORLDLY_GREEN,
        "frame": FRAME_COLOR,
        "door": DOOR_COLOR,
        "rotted_plank": Color("#49433b"),
        "cracked_pane": Color("#333f43"),
        "lintel": Color("#52473f"),
        "chimney": Color("#704a3e"),
        "chimney_cap": Color("#34383a"),
        "path_stone": Color("#68665d"),
        "board": Color("#50493e"),
        "porch": Color("#4b433b"),
        "lamp": Color("#df9c52"),
        "lamp_shade": Color("#55463a"),
        "lamp_glass": Color("#f9c96f"),
        "lamp_glass_off": Color("#343a3b"),
        "bench_wood": Color("#536c70"),
        "bench_dark": Color("#363a37"),
        "flower_stem": Color("#5b5c47"),
        "flower_pink": Color("#75616a"),
        "flower_white": Color("#a6a297"),
        "flower_leaf": Color("#48483d"),
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
        "soil": Color("#392e28"),
        "bed_edge": Color("#534839"),
        "sprout": Color("#50503b"),
        "greenhouse_glass": Color("#526a63"),
        "greenhouse_frame": Color("#7a8276"),
        "greenhouse_roof": Color("#687970"),
        "woodpile": Color("#514336"),
        "wood_end": Color("#77705b"),
        "yard_tin": Color("#525c5d"),
        "yard_rust": Color("#6b4a39"),
        "yard_tool": Color("#767c72"),
        "yard_tire": Color("#232624"),
        "fallen_planks": Color("#4d473d"),
        "rusted_gate": Color("#444a47"),
        "panel_patch": Color("#464943"),
        "carving": Color("#5c6259"),
        "cross_board": Color("#494238"),
        "porch_deck": Color("#50483f"),
        "annex_dark": Color("#303632"),
        "pole": Color("#413b35"),
        "crossarm": Color("#343531"),
        "gable_planks": Color("#3b4748"),
        "corner_timber": Color("#393a36")
    }
    for key in _detail_batches.keys():
        var verts: PackedVector3Array = _detail_batches[key]
        if key in ["window_lit", "window_eerie_blue", "window_eerie_green", "lamp_glass"]:
            var tint: Color = colors[key] if colors.has(key) else Color("#ffcf79")
            var lit_mat := _material(tint)
            lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            var arrays := []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = verts
            var mesh := ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            var lit_node := MeshInstance3D.new()
            lit_node.name = "Вечерний свет окон и уличных фонарей"
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

func _road_surface_gap(p: Vector2) -> float:
    # Clearance to the rendered road edge (roads 5.1 m, footpaths 1.6 m).
    var best := INF
    for seg in _roads:
        var nearest := Geometry2D.get_closest_point_to_segment(p, seg[0], seg[1])
        best = minf(best, p.distance_to(nearest) - float(seg[2]) * 0.5)
    return best


func _plot_boundary_gap(p: Vector2) -> float:
    var best := INF
    for edge in _plot_edges:
        var nearest := Geometry2D.get_closest_point_to_segment(p, edge[0], edge[1])
        best = minf(best, p.distance_to(nearest))
    return best


func _fence_point_clear(p: Vector2) -> bool:
    return _road_surface_gap(p) >= 0.23 and _clear_of_buildings(p, 0.42)


func _fence_span_clear(a: Vector2, b: Vector2,
        polygon: PackedVector2Array) -> bool:
    for t in [0.06, 0.50, 0.94]:
        var p := a.lerp(b, t)
        if not Geometry2D.is_point_in_polygon(p, polygon) or not _fence_point_clear(p):
            return false
        if _entry_zone_conflict(p, 0.12):
            return false
    return true


func _entry_clear(mid: Vector3, tangent: Vector3, outward: Vector3,
        extension: float, half_width: float) -> bool:
    for side in [-1.0, 0.0, 1.0]:
        var test: Vector3 = mid + outward * extension + tangent * float(side) * half_width
        var p := Vector2(test.x, -test.z)
        if _road_surface_gap(p) < 0.48 or _plot_boundary_gap(p) < 0.38:
            return false
        if not _clear_of_buildings(p, 0.35):
            return false
    return true


func _entrance_route_distance(p: Vector2, extra: float = 0.0) -> float:
    # A greenhouse's clearance radius must also expand the spatial prefilter.
    # Otherwise its centre is missed despite its walls blocking the doorstep.
    var best := INF
    for route in _entrance_routes:
        var bounds: Rect2 = route["bounds"]
        if not bounds.grow(extra).has_point(p):
            continue
        var closest := Geometry2D.get_closest_point_to_segment(
            p, route["start"], route["end"])
        best = minf(best, p.distance_to(closest))
    return best


func _entry_zone_conflict(p: Vector2, extra: float = 0.0) -> bool:
    return _entrance_route_distance(p, extra) < 1.10 + extra


func _build_entrance_routes(features: Array) -> void:
    _entrance_routes.clear()
    for item in features:
        if not item is Dictionary or str(item.get("type", "")) != "house":
            continue
        var polygon := _local_points(item.get("points", []))
        if polygon.size() < 3:
            continue
        var front := _building_front_edge(polygon)
        var a := polygon[front]
        var b := polygon[(front + 1) % polygon.size()]
        if a.distance_to(b) <= 3.3:
            continue
        var side := (b - a).normalized()
        var outward := Vector2(side.y, -side.x)
        if _signed_area(polygon) < 0.0:
            outward *= -1.0
        var mid := (a + b) * 0.5
        var start := mid + outward * 0.40
        var road_dist := _nearest_road_distance(mid)
        var max_distance := clampf(road_dist + 1.0, 2.8, 24.0)
        var finish := mid + outward * max_distance
        var lo := start.min(finish) - Vector2(1.6, 1.6)
        var hi := start.max(finish) + Vector2(1.6, 1.6)
        _entrance_routes.append({
            "start": start, "end": finish, "bounds": Rect2(lo, hi - lo)
        })
    print("VILLAGE_ENTRANCES_READY: reserved=", _entrance_routes.size(),
        " road_facing=", _fronts_facing_road)


func _building_front_edge(points: PackedVector2Array) -> int:
    # Choose a road-facing *accessible* facade, not merely the closest wall.
    # The wall choice is deterministic and does not change a single survey point.
    var best_index := 0
    var best_score := INF
    var clockwise := _signed_area(points) < 0.0
    for i in range(points.size()):
        var a := points[i]
        var b := points[(i + 1) % points.size()]
        var side := b - a
        var length := side.length()
        if length < 3.35:
            continue
        var mid := (a + b) * 0.5
        var outward := Vector2(side.y, -side.x).normalized()
        if clockwise:
            outward *= -1.0
        var road_distance := INF
        var nearest := Vector2.INF
        for segment in _roads:
            var foot := Geometry2D.get_closest_point_to_segment(mid, segment[0], segment[1])
            var d := mid.distance_to(foot)
            if d < road_distance:
                road_distance = d
                nearest = foot
        var score := road_distance * 0.80 - minf(length, 15.0) * 0.075
        if road_distance < INF and road_distance > 0.2:
            var facing := (nearest - mid).normalized().dot(outward)
            if facing < 0.20:
                score += 18.0 + 8.0 * (0.20 - facing)
        if _road_surface_gap(mid) < 1.0:
            score += 8.0
        # Test the two door jambs and the exterior approach along the normal.
        var tangent := side / length
        for depth in [0.85, 1.7, 2.6]:
            for across in [-0.60, 0.0, 0.60]:
                var p := mid + outward * float(depth) + tangent * float(across)
                if not _clear_of_buildings(p, 0.16):
                    score += 15.0
                if depth < 1.8 and _road_surface_gap(p) < 0.15:
                    score += 6.0
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
    # Only one lighted pane per selected house. The overwhelming majority of
    # buildings are abandoned and must remain completely dark.
    var light_kind := ""
    if floor == 0 and not _house_light_claimed and _current_house_light_kind != "":
        light_kind = _current_house_light_kind
        _house_light_claimed = true
    var half := minf(0.072, 0.74 / maxf(side_length, 0.1))
    var u0 := center_fraction - half
    var u1 := center_fraction + half
    var y := float(floor) * 3.08
    var low := 1.36 + y
    var high := 2.77 + y
    var trim := "carving" if style == 1 or style == 4 else _active_trim_key
    _wall_panel("frame", start, finish, normal, u0 - 0.017, u1 + 0.017,
        low, high, 0.115)
    var glass_key := "window"
    if light_kind == "warm":
        glass_key = "window_lit"
    elif light_kind == "eerie":
        glass_key = "window_eerie_blue" if _house_ordinal % 2 == 0 else "window_eerie_green"
    _wall_panel(glass_key,
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
    elif style == 3 and light_kind == "":
        # Boarded windows with crude, uneven boards. The anomalous window
        # has no boards, making the rare glow visible from the road.
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
    if light_kind == "" and (boarded or decay % 9 == 0):
        _wall_panel("cross_board", start, finish, normal, u0, u1,
            low + 0.47, low + 0.57, 0.198)
    # Randomly placed decayed planks are the dominant visual on empty homes.
    # Keep them behind the scarce supernatural / warm-lit windows.
    if light_kind == "" and _current_house_light_kind == "" and (
            (_house_ordinal * 17 + decay * 7 + floor * 11) % 5 <= 1):
        _wall_panel("rotted_plank", start, finish, normal,
            u0 + 0.01 * half, u1 - 0.01 * half,
            low + 0.17, low + 0.39, 0.214)
        _wall_panel("rotted_plank", start, finish, normal,
            u0 + 0.01 * half, u1 - 0.01 * half,
            low + 0.88, low + 1.09, 0.216)
        _new_boarded_windows += 1
    elif light_kind == "" and _current_house_light_kind == "" and (
            (decay * 7 + _house_ordinal) % 6 == 0):
        _wall_panel("cracked_pane", start, finish, normal,
            center_fraction - 0.003, center_fraction + 0.003,
            low + 0.21, high - 0.16, 0.205)
    if light_kind != "" and _lights_placed < 10:
        _lights_placed += 1
        var center := start.lerp(finish, center_fraction)
        var lamp := OmniLight3D.new()
        lamp.position = _pt(center, low + 0.92) + normal * 0.85
        lamp.light_specular = 0.0
        lamp.shadow_enabled = false
        if light_kind == "eerie":
            _otherworldly_windows += 1
            lamp.name = "Потустороннее свечение в покинутом доме"
            lamp.light_color = WINDOW_OTHERWORLDLY_BLUE if _house_ordinal % 2 == 0 else WINDOW_OTHERWORLDLY_GREEN
            lamp.light_energy = 0.48
            lamp.omni_range = 6.4
            _anomaly_lamps.append(lamp)
            _create_eerie_window_dust(lamp.position, _house_ordinal % 2 == 0)
        else:
            _warm_windows += 1
            lamp.name = "Редкий обитаемый дом"
            lamp.light_color = Color("#c6a772")
            lamp.light_energy = 0.23
            lamp.omni_range = 4.1
        add_child(lamp)

func _create_eerie_window_dust(location: Vector3, blue: bool) -> void:
    # Soft motes, not monsters or a bright magic effect. Exactly two emitters,
    # each bound to one of the already-surveyed anomalous homes.
    var particles := CPUParticles3D.new()
    particles.name = "RareAnomalyMotes"
    particles.position = location + Vector3.UP * 0.2
    particles.amount = 17
    particles.lifetime = 6.8
    particles.preprocess = 6.8
    particles.randomness = 0.65
    particles.local_coords = false
    particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    particles.emission_box_extents = Vector3(0.95, 0.60, 0.95)
    particles.direction = Vector3(0.10, 1.0, 0.08)
    particles.spread = 17.0
    particles.initial_velocity_min = 0.09
    particles.initial_velocity_max = 0.26
    particles.gravity = Vector3(0.01, 0.015, -0.01)
    particles.scale_amount_min = 0.45
    particles.scale_amount_max = 1.1
    var dust_mesh := QuadMesh.new()
    dust_mesh.size = Vector2(0.095, 0.095)
    var dust_mat := StandardMaterial3D.new()
    dust_mat.albedo_color = Color(0.54, 0.75, 0.85, 0.27) if blue else Color(0.48, 0.78, 0.68, 0.26)
    dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    dust_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    dust_mesh.material = dust_mat
    particles.mesh = dust_mesh
    add_child(particles)
    particles.emitting = true
    _eerie_motes += 1


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
    # Exactly two anomalous houses and ~7 sparsely occupied houses in the
    # 92-home manual survey; all others have no interior illumination.
    _current_house_light_kind = ""
    _house_light_claimed = false
    if category == "house":
        _house_ordinal += 1
        if _house_ordinal == 19 or _house_ordinal == 62:
            _current_house_light_kind = "eerie"
            _anomalous_houses += 1
        elif _house_ordinal % 13 == 5:
            _current_house_light_kind = "warm"
            _warm_houses += 1
        else:
            _dark_houses += 1
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
    _register_building_collider(points, walls_height)
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
        # Shared polygon corners instead of separate normal offsets: no split walls.
        _quad(wall_verts, wall_uvs, _pt(a, 0.12), _pt(b, 0.12),
            _pt(b, walls_height), _pt(a, walls_height))
        if category == "house":
            _decorate_wall_module(a, b, normal, walls_height, body_style,
                index + i, i == front_index, floors)
        if i == front_index and length > 3.3:
            var door_half := 0.55 / length
            _wall_panel("frame", a, b, normal, 0.5 - door_half - 0.02,
                0.5 + door_half + 0.02, 0.1, 2.23)
            _wall_panel("door", a, b, normal, 0.5 - door_half,
                0.5 + door_half, 0.12, 2.13, 0.15)
            # Some deserted houses were sealed long ago. These are facade
            # decorations only, not colliders or changes to surveyed entrances.
            if category == "house" and _current_house_light_kind == "" and index % 4 == 1:
                for plank in range(3):
                    var bottom := 0.50 + float(plank) * 0.50
                    _wall_panel("rotted_plank", a, b, normal,
                        0.5 - door_half * 1.10, 0.5 + door_half * 1.10,
                        bottom, bottom + 0.19, 0.215)
                _sealed_entries += 1
            if category == "house" and length > 7.0:
                _make_window(a, b, normal, 0.19, length, index % 5 != 1,
                    index % 11 == 0, index + i, window_style)
                _make_window(a, b, normal, 0.81, length, index % 4 != 1,
                    index % 10 == 0, index + i + 3, window_style)
            if category == "house" and floors == 2 and length > 5.0:
                _make_window(a, b, normal, 0.3, length, index % 3 != 0, false,
                    index + i + 1, window_style, 1)
                _make_window(a, b, normal, 0.7, length, index % 4 != 0, false,
                    index + i + 4, window_style, 1)
        elif category == "house" and length > 5.0:
            _make_window(a, b, normal, 0.5, length, (index + i) % 3 != 0,
                (index + i) % 11 == 0, index + i, window_style)
            if floors == 2:
                _make_window(a, b, normal, 0.5, length, (index + i) % 4 != 0, false,
                    index + i + 8, window_style, 1)
    if category == "house":
        for corner in points:
            _batch_box("corner_timber", _pt(corner, walls_height * 0.5 + 0.04),
                Vector3(0.26, walls_height - 0.08, 0.26))
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
            var front_normal := Vector3(out2d.x, 0, -out2d.y)
            _decorate_modular_entrance(front_a, front_b, front_normal, entrance_style)
            if floors == 2 and front_a.distance_to(front_b) > 6.8 and index % 2 == 0:
                _decorate_balcony(front_a, front_b, front_normal)
            # Not every home has a paved approach: retain the village's dirt yards.
            if index % 3 == 0:
                _decorate_house_walk(front_a, front_b, front_normal)
        _decorate_showcase_yard(points, front_index)

func _decorate_modular_entrance(a: Vector2, b: Vector2,
        outward: Vector3, style: int) -> void:
    # Five compact entrances that preserve the hand-surveyed foundation footprint.
    var distance := _road_surface_gap((a + b) * 0.5)
    # The entrance is optional decoration: never extrude into a street.
    var extension := minf(1.35, maxf(0.0, distance - 0.60))
    if extension < 0.90:
        return
    var axis := _pt(b, 0) - _pt(a, 0)
    var tangent := axis.normalized()
    var mid := _pt((a + b) * 0.5, 0.12)
    var wide := minf(1.25, axis.length() * 0.18)
    if not _entry_clear(mid, tangent, outward, extension, wide):
        return
    var front := mid + outward * extension
    if style == 0:
        # Bare three uneven steps.
        for n in range(3):
            var d := 0.35 + float(n) * 0.23
            var step_center := mid + outward * d + Vector3.UP * (0.16 + float(2 - n) * 0.12)
            var left := step_center - tangent * 0.82
            var right := step_center + tangent * 0.82
            _batch_quad("porch_deck", left, right,
                right + outward * 0.25, left + outward * 0.25)
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

func _decorate_house_walk(a: Vector2, b: Vector2, outward: Vector3) -> void:
    # Irregular, sparse stepping stones, never a new road or surveyed plot edge.
    var axis := _pt(b, 0.0) - _pt(a, 0.0)
    if axis.length() < 4.0:
        return
    var tangent := axis.normalized()
    var origin := _pt((a + b) * 0.5, 0.17)
    var stones := 0
    for i in range(6):
        var center := origin + outward * (1.25 + float(i) * 0.54)
        center += tangent * (0.13 * sin(float(i) * 1.67))
        var p := Vector2(center.x, -center.z)
        if _road_surface_gap(p) < 0.68:
            break
        if _plot_boundary_gap(p) < 0.26 or not _clear_of_buildings(p, 0.23):
            continue
        var half := tangent * (0.29 + 0.03 * cos(float(i) * 2.1))
        var deep := outward * 0.19
        _batch_quad("path_stone", center - half - deep, center + half - deep,
            center + half + deep, center - half + deep)
        stones += 1
    if stones > 0:
        _front_walkways += 1


func _decorate_balcony(a: Vector2, b: Vector2, outward: Vector3) -> void:
    # Compact two-storey wooden balcony like the supplied evening village concepts.
    # The floor footprint and entrance remain untouched; keep it off roads/fences.
    var tangent := (_pt(b, 0.0) - _pt(a, 0.0)).normalized()
    var back := _pt((a + b) * 0.5, 3.30) + outward * 0.10
    var front := back + outward * 0.82
    var half_width := minf(1.95, a.distance_to(b) * 0.27)
    for sign in [-1.0, 1.0]:
        var check := front + tangent * float(sign) * half_width
        var p := Vector2(check.x, -check.z)
        if _road_surface_gap(p) < 0.85 or _plot_boundary_gap(p) < 0.15:
            return
        if not _clear_of_buildings(p, 0.18):
            return
    _batch_quad("porch_deck",
        back - tangent * half_width, back + tangent * half_width,
        front + tangent * half_width, front - tangent * half_width)
    # Thick rail, two end rails and upright balusters; all geometry batched.
    var rail_y := Vector3.UP * 0.96
    _batch_quad("bench_wood", front - tangent * half_width + rail_y,
        front + tangent * half_width + rail_y,
        front + tangent * half_width + rail_y + Vector3.UP * 0.13,
        front - tangent * half_width + rail_y + Vector3.UP * 0.13)
    for i in range(9):
        var t := float(i) / 8.0
        var q := front + tangent * lerpf(-half_width, half_width, t)
        _batch_quad("porch", q - tangent * 0.055, q + tangent * 0.055,
            q + tangent * 0.055 + Vector3.UP * 0.98,
            q - tangent * 0.055 + Vector3.UP * 0.98)
    for sign in [-1.0, 1.0]:
        var rear := back + tangent * float(sign) * half_width
        var outer := front + tangent * float(sign) * half_width
        _batch_quad("bench_wood", rear + rail_y, outer + rail_y,
            outer + rail_y + Vector3.UP * 0.13,
            rear + rail_y + Vector3.UP * 0.13)
    _balcony_count += 1


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
    # Refuse an annex if its outer corners collide with another house,
    # the road surface, or a plot boundary/fence.
    for corner in [left_front, right_front]:
        var p := Vector2(corner.x, -corner.z)
        if _road_surface_gap(p) < 0.65 or _plot_boundary_gap(p) < 0.45:
            return
        if not _clear_of_buildings(p, 0.5) or _entry_zone_conflict(p, 0.8):
            return
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
    # The showcase is optional if the selected wall abuts the road. Emit
    # the audit marker either way so CI doesn't depend on a cosmetic choice.
    print("MANUAL_SHOWCASE_YARD_READY: ", centroid)
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
    # A few crooked stone slabs lead toward the porch; visual-only ground detail.
    for i in range(7):
        var slab := origin + vout * (0.65 + float(i) * 0.47)
        slab += tangent * (0.09 * sin(float(i) * 2.4))
        slab.y = 0.14
        var p := Vector2(slab.x, -slab.z)
        if _road_surface_gap(p) < 0.75 or _plot_boundary_gap(p) < 0.30:
            continue
        if not _clear_of_buildings(p, 0.20):
            continue
        _batch_quad("path_stone",
            slab - tangent * 0.33 - vout * 0.20,
            slab + tangent * 0.33 - vout * 0.20,
            slab + tangent * 0.33 + vout * 0.20,
            slab - tangent * 0.33 + vout * 0.20)
    # Modular entrance already draws steps: avoid double stairs and overlapping props.
    var stack_origin := origin + tangent * 2.25 + vout * 1.4
    var stack_p := Vector2(stack_origin.x, -stack_origin.z)
    var stack_clear := _road_surface_gap(stack_p) > 0.8
    stack_clear = stack_clear and _plot_boundary_gap(stack_p) > 0.7
    stack_clear = stack_clear and _clear_of_buildings(stack_p, 0.65)
    if stack_clear:
        for i in range(4):
            _batch_box("porch", stack_origin + tangent * float(i % 2) * 0.62 +
                Vector3.UP * (0.18 + 0.36 * float(i / 2)),
                Vector3(0.52, 0.32, 0.50))
    var lamp_origin := origin - tangent * 2.0 + vout * 2.25
    var lamp_p := Vector2(lamp_origin.x, -lamp_origin.z)
    var lamp_clear := _road_surface_gap(lamp_p) > 0.8
    lamp_clear = lamp_clear and _plot_boundary_gap(lamp_p) > 0.65
    lamp_clear = lamp_clear and _clear_of_buildings(lamp_p, 0.65)
    if lamp_clear:
        _batch_box("chimney", lamp_origin + Vector3.UP * 1.55, Vector3(0.13, 3.05, 0.13))
        _batch_box("lamp", lamp_origin + Vector3.UP * 3.05, Vector3(0.35, 0.36, 0.35))
        var light := OmniLight3D.new()
        light.name = "Старая лампа у крыльца"
        light.position = lamp_origin + Vector3.UP * 3.05
        light.light_color = Color("#e9d081")
        light.light_energy = 0.26
        light.light_specular = 0.0
        light.omni_range = 6.0
        light.shadow_enabled = false
        add_child(light)

func _roof_face(verts: PackedVector3Array, uvs: PackedVector2Array,
        a: Vector2, b: Vector2, c: Vector2, ah: float, bh: float, ch: float) -> void:
    _face(verts, uvs, _pt(a, ah), _pt(b, bh), _pt(c, ch),
        Vector2(0, 0), Vector2(a.distance_to(b) / 8.0, 0),
        Vector2(a.distance_to(c) / 8.0, 1.0))

func _roof_quad(verts: PackedVector3Array, uvs: PackedVector2Array,
        a: Vector2, b: Vector2, c: Vector2, d: Vector2,
        ah: float, bh: float, ch: float, dh: float) -> void:
    # Both triangles use a single UV frame. Resetting UV for each triangle
    # created a diagonal texture discontinuity and apparent roof shimmer.
    var u := maxf(0.25, a.distance_to(b) / 8.0)
    var v := maxf(0.25, a.distance_to(d) / 8.0)
    _face(verts, uvs, _pt(a, ah), _pt(b, bh), _pt(c, ch),
        Vector2(0.0, 0.0), Vector2(u, 0.0), Vector2(u, v))
    _face(verts, uvs, _pt(a, ah), _pt(c, ch), _pt(d, dh),
        Vector2(0.0, 0.0), Vector2(u, v), Vector2(0.0, v))


func _decorate_gable_trim(left: Vector2, right: Vector2, apex: Vector2,
        eave: float, rise: float, outward: Vector3) -> void:
    # Pale scalloped verge boards on the gable ends; the thickened boards are
    # offset 18 cm from the original roof edge to avoid coplanar flicker.
    var offset := outward * 0.18
    var l := _pt(left, eave)
    var r := _pt(right, eave)
    var peak := _pt(apex, eave + rise)
    for segment in [[l, peak], [peak, r]]:
        var p0: Vector3 = segment[0]
        var p1: Vector3 = segment[1]
        _batch_quad("trim_cream",
            p0 + offset + Vector3.UP * 0.05,
            p1 + offset + Vector3.UP * 0.05,
            p1 + offset + Vector3.DOWN * 0.10,
            p0 + offset + Vector3.DOWN * 0.10)
        # Coarse notches, not tiny high-frequency roof geometry.
        var along := (p1 - p0).normalized() * 0.10
        for notch in range(6):
            var q := p0.lerp(p1, (float(notch) + 0.5) / 6.0) + offset
            _batch_quad("trim_cream",
                q - along + Vector3.DOWN * 0.08,
                q + along + Vector3.DOWN * 0.08,
                q + along + Vector3.DOWN * 0.23,
                q - along + Vector3.DOWN * 0.23)


func _decorate_roof_patch(eave_a: Vector2, eave_b: Vector2,
        ridge_a: Vector2, ridge_b: Vector2, eave: float, rise: float) -> void:
    # Uneven patch of repaired sheet metal follows the existing roof slope.
    var low_t := 0.34
    var high_t := 0.62
    var l0 := eave_a.lerp(eave_b, 0.18).lerp(ridge_a.lerp(ridge_b, 0.18), low_t)
    var r0 := eave_a.lerp(eave_b, 0.58).lerp(ridge_a.lerp(ridge_b, 0.58), low_t)
    var r1 := eave_a.lerp(eave_b, 0.58).lerp(ridge_a.lerp(ridge_b, 0.58), high_t)
    var l1 := eave_a.lerp(eave_b, 0.18).lerp(ridge_a.lerp(ridge_b, 0.18), high_t)
    _batch_quad("roof_patch", _pt(l0, eave + rise * low_t + 0.24),
        _pt(r0, eave + rise * low_t + 0.24),
        _pt(r1, eave + rise * high_t + 0.24),
        _pt(l1, eave + rise * high_t + 0.24))
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
    # Roof bearing overlaps the wall instead of floating above it.
    var eave := base - 0.09
    if category == "house":
        _roof_joints_sealed += 1
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
            _roof_quad(v, uv, a, b, hip1, hip0,
                eave, eave, eave + rise, eave + rise)
            _roof_quad(v, uv, d, c, hip1, hip0,
                eave, eave, eave + rise, eave + rise)
            _roof_face(v, uv, a, hip0, d, eave, eave + rise, eave)
            _roof_face(v, uv, b, c, hip1, eave, eave, eave + rise)
        elif category == "house" and roof_style == 4:
            # One continuous sloping panel and end walls: recognisably a shed roof.
            _roof_quad(v, uv, a, b, c, d,
                eave + rise, eave + rise, eave, eave)
            # A single-slope roof needs timber infill below the raised side.
            _batch_quad("gable_planks", _pt(a, base - 0.10), _pt(b, base - 0.10),
                _pt(b, eave + rise), _pt(a, eave + rise))
            _batch_tri("gable_planks", _pt(d, eave), _pt(a, eave),
                _pt(a, eave + rise))
            _batch_tri("gable_planks", _pt(b, eave), _pt(c, eave),
                _pt(b, eave + rise))
        else:
            _roof_quad(v, uv, a, b, ridge1, ridge0,
                eave, eave, eave + rise, eave + rise)
            _roof_quad(v, uv, d, c, ridge1, ridge0,
                eave, eave, eave + rise, eave + rise)
            # Close both gables with solid wood so the roof reads as one building.
            _batch_tri("gable_planks", _pt(a, eave), _pt(ridge0, eave + rise), _pt(d, eave))
            _batch_tri("gable_planks", _pt(b, eave), _pt(c, eave), _pt(ridge1, eave + rise))
            if category == "house":
                var outer_a := (_pt(a, 0.0) - _pt(b, 0.0)).normalized()
                _decorate_gable_trim(a, d, ridge0, eave, rise, outer_a)
                _decorate_gable_trim(b, c, ridge1, eave, rise, -outer_a)
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
    var roof_mat := _material(Color.WHITE, tex)
    # Oblique slate roofs should use anisotropic mipmaps: nearest roof texels
    # shimmer during close camera movement despite a correctly sealed ridge.
    roof_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
    _make_textured_mesh(v, uv, roof_mat,
        category + " / modular roof " + str(roof_style))
    if category == "house" and index % 3 != 0:
        var center := Vector2.ZERO
        for p in roof_points:
            center += p
        center /= float(roof_points.size())
        var chimney_at := _pt(center + Vector2(0.5, 0.4), base + rise * 0.65 + 0.25)
        _batch_box("chimney", chimney_at, Vector3(0.70, 1.10, 0.70))
        _batch_box("chimney_cap", chimney_at + Vector3.UP * 0.62,
            Vector3(0.87, 0.16, 0.87))
        # Chimneys are mostly cold. Smoke is possible only from a few houses
        # with warm windows, never from supernatural or fully dark buildings.
        if _current_house_light_kind == "warm":
            _chimney_smoke_sources.append(chimney_at + Vector3.UP * 0.82)

func _create_chimney_smoke() -> void:
    # The village is deserted: no more than one distant hearth is burning.
    # All other physical chimneys are cold and inactive.
    var spawn := Vector3(-789.7, 0.0, -268.6)
    _chimney_smoke_sources.sort_custom(func(a: Vector3, b: Vector3) -> bool:
        return a.distance_squared_to(spawn) < b.distance_squared_to(spawn))
    var smoke_mesh := QuadMesh.new()
    smoke_mesh.size = Vector2(0.26, 0.26)
    var smoke_material := StandardMaterial3D.new()
    smoke_material.albedo_color = Color(0.61, 0.65, 0.68, 0.13)
    smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    smoke_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    smoke_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    smoke_material.cull_mode = BaseMaterial3D.CULL_DISABLED
    smoke_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
    smoke_mesh.material = smoke_material
    var smoke_limit := mini(1, _chimney_smoke_sources.size())
    for index in range(smoke_limit):
        var smoke := CPUParticles3D.new()
        smoke.name = "NovemberChimneySmoke_" + str(index)
        smoke.position = _chimney_smoke_sources[index]
        smoke.amount = 8
        smoke.lifetime = 5.5
        smoke.preprocess = 5.5
        smoke.randomness = 0.48
        smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        smoke.emission_sphere_radius = 0.13
        smoke.direction = Vector3(0.20, 1.0, 0.15)
        smoke.spread = 12.0
        smoke.initial_velocity_min = 0.34
        smoke.initial_velocity_max = 0.64
        smoke.gravity = Vector3(0.02, 0.055, 0.01)
        smoke.scale_amount_min = 0.65
        smoke.scale_amount_max = 1.55
        smoke.local_coords = false
        smoke.mesh = smoke_mesh
        add_child(smoke)
        smoke.emitting = true
        _chimneys_smoking += 1
    print("NOVEMBER_SMOKE_READY: active=", _chimneys_smoking,
        " candidates=", _chimney_smoke_sources.size(),
        " particles_per_chimney=8")


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

func _fence_wire(a: Vector3, b: Vector3) -> void:
    var thickness := Vector3.UP * 0.012
    _push_tri(_fence_wire_mesh, a - thickness, a + thickness, b + thickness)
    _push_tri(_fence_wire_mesh, a - thickness, b + thickness, b - thickness)


func _fence_chainlink(a: Vector2, b: Vector2) -> void:
    # A few green diamond-mesh sections break up the repeated post-and-rail silhouette.
    # Batched into one Web-friendly mesh and clipped by the same road/building tests.
    for i in range(4):
        var p := a.lerp(b, float(i) / 4.0)
        var q := a.lerp(b, float(i + 1) / 4.0)
        _fence_wire(_pt(p, 0.37), _pt(q, 1.24))
        _fence_wire(_pt(p, 1.24), _pt(q, 0.37))


func _fence_fit_span(a: Vector2, b: Vector2, inward: Vector2,
        polygon: PackedVector2Array) -> Array:
    # Find the smallest safe setback for a section, retaining surveyed plot lines.
    for inset in [0.18, 0.36, 0.65, 1.00, 1.45, 1.95, 2.50, 3.10, 3.80, 4.55]:
        var start := a + inward * float(inset)
        var finish := b + inward * float(inset)
        if _fence_span_clear(start, finish, polygon):
            return [start, finish, float(inset)]
    return []


func _fence_bridge_gap(a: Vector2, b: Vector2,
        polygon: PackedVector2Array) -> void:
    # Adjacent setbacks used to create conspicuous discontinuities at each
    # boundary segment. Connect only short, entirely safe stretches; never
    # close a deliberate gate or bridge across a road/building.
    var gap := a.distance_to(b)
    if gap < 0.12 or gap > 2.65:
        return
    if not _fence_span_clear(a, b, polygon):
        return
    var tangent := (b - a).normalized()
    var sideways := Vector3(-tangent.y, 0.0, -tangent.x) * 0.04
    var half_thickness := Vector3.UP * 0.085
    for height in [0.50, 1.06]:
        var v0 := _pt(a, float(height)) + sideways
        var v1 := _pt(b, float(height)) + sideways
        _push_tri(_fence_rails, v0 - half_thickness,
            v1 - half_thickness, v1 + half_thickness)
        _push_tri(_fence_rails, v0 - half_thickness,
            v1 + half_thickness, v0 + half_thickness)
    if gap > 1.55:
        _append_crooked_post(_fence_posts, (a + b) * 0.5, 1.24, Vector2(0.04, -0.02))
    _fence_chainlink(a, b)
    _register_fence_collider(a, b)
    _fence_joints_joined += 1


func _fence_draw_span(start: Vector2, finish: Vector2, ordinal: int,
        polygon: PackedVector2Array) -> void:
    if _last_fence_endpoint != Vector2(INF, INF):
        _fence_bridge_gap(_last_fence_endpoint, start, polygon)
    if _first_fence_endpoint == Vector2(INF, INF):
        _first_fence_endpoint = start
    # Adjacent panels use shared posts instead of flickering doubled geometry.
    for endpoint in range(2):
        var p: Vector2 = start if endpoint == 0 else finish
        if p.distance_to(_last_fence_post) < 0.08:
            continue
        var height := 1.35 + 0.22 * sin(float(ordinal * 13 + endpoint * 7 + _fence_count))
        var tilt := Vector2(0.10 * sin(float(ordinal * 17 + endpoint)),
            0.09 * cos(float(ordinal * 11 + _fence_count)))
        _append_crooked_post(_fence_posts, p, height, tilt)
        _last_fence_post = p
    if _fence_count % 3 == 0:
        _fence_chainlink(start, finish)
    elif _fence_count % 3 == 1:
        var slats := maxi(1, int(ceil(start.distance_to(finish) / 0.47)))
        for j in range(slats):
            if (ordinal * 7 + j * 13 + _fence_count) % 19 == 0:
                continue
            var p := start.lerp(finish, (float(j) + 0.5) / float(slats))
            var height := 1.05 + 0.27 * sin(float(ordinal * 19 + j * 17))
            _append_box_to(_fence_slats, _pt(p, height * 0.5 + 0.12),
                Vector3(0.125, height, 0.125))
    var tangent := (finish - start).normalized()
    var outward3 := Vector3(-tangent.y, 0, -tangent.x) * 0.04
    var half_thickness := Vector3.UP * 0.085
    for height in [0.50, 1.06]:
        var v0 := _pt(start, float(height)) + outward3
        var v1 := _pt(finish, float(height)) + outward3
        _push_tri(_fence_rails, v0 - half_thickness,
            v1 - half_thickness, v1 + half_thickness)
        _push_tri(_fence_rails, v0 - half_thickness,
            v1 + half_thickness, v0 + half_thickness)
    _register_fence_collider(start, finish)
    _last_fence_endpoint = finish


func _fence_break() -> void:
    _last_fence_endpoint = Vector2(INF, INF)
    _last_fence_post = Vector2(INF, INF)


func _fence_edge(a: Vector2, b: Vector2, gate_center: bool,
        polygon: PackedVector2Array) -> void:
    var length := a.distance_to(b)
    if length < 0.35:
        _fence_break()
        return
    var count := maxi(1, int(ceil(length / 1.65)))
    var tangent := (b - a) / length
    var side := 1.0 if _signed_area(polygon) > 0.0 else -1.0
    var inward := Vector2(-tangent.y, tangent.x) * side
    var gate_a := -1.0
    var gate_b := -1.0
    if gate_center and length >= 6.0:
        gate_a = length * 0.5 - 1.85
        gate_b = length * 0.5 + 1.85
    for i in range(count):
        var from_dist := length * float(i) / float(count)
        var to_dist := length * float(i + 1) / float(count)
        if gate_center and to_dist > gate_a and from_dist < gate_b:
            _fence_break()
            continue
        _fence_panels_total += 1
        var raw_start := a + tangent * from_dist
        var raw_finish := a + tangent * to_dist
        if _entry_zone_conflict(raw_start, 0.24) or _entry_zone_conflict(
                (raw_start + raw_finish) * 0.5, 0.24) or _entry_zone_conflict(raw_finish, 0.24):
            _reserved_gate_sections += 1
            _fence_break()
            continue
        var fit := _fence_fit_span(raw_start, raw_finish, inward, polygon)
        if not fit.is_empty():
            _fence_draw_span(fit[0], fit[1], i, polygon)
            if float(fit[2]) >= 0.45:
                _fence_panels_relocated += 1
            continue
        # An entire 1.65 m panel may fail near a road corner even though
        # one half can safely stand. Salvage short parts rather than leaving
        # the whole boundary blank.
        var recovered := 0
        for half in range(2):
            var p := raw_start.lerp(raw_finish, float(half) * 0.5)
            var q := raw_start.lerp(raw_finish, float(half + 1) * 0.5)
            var short_fit := _fence_fit_span(p, q, inward, polygon)
            if short_fit.is_empty():
                _fence_break()
                continue
            _fence_draw_span(short_fit[0], short_fit[1], i * 2 + half, polygon)
            if float(short_fit[2]) >= 0.45:
                _fence_panels_relocated += 1
            recovered += 1
        if recovered == 0:
            _fence_panels_skipped += 1
        else:
            _fence_short_spans_recovered += recovered


func _clear_of_buildings(p: Vector2, gap: float) -> bool:
    for j in range(_building_polygons.size()):
        var bb: Rect2 = _building_bounds[j]
        # Cheap bounding rectangle avoids hundreds of polygon tests for far houses.
        if p.x < bb.position.x - gap or p.x > bb.end.x + gap:
            continue
        if p.y < bb.position.y - gap or p.y > bb.end.y + gap:
            continue
        var footprint: PackedVector2Array = _building_polygons[j]
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
        var world_point: Vector3 = pos + basis * vertex
        current.append(world_point)
        if key in ["well_stone", "greenhouse_glass", "greenhouse_frame", "rusted_gate"]:
            _yard_collision_faces.append(world_point)
    if key in ["well_stone", "greenhouse_glass", "greenhouse_frame", "rusted_gate"]:
        _collision_yard_count += 1
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
        6:
            # Rotten timber sections, warped gate leaning on a tipped cart.
            # Low and contained inside the existing plot; does not cross roads.
            _yard_box("fallen_planks", center, Vector2(-0.65, -0.35),
                0.22, Vector3(2.2, 0.16, 0.35), rotation - 0.22)
            _yard_box("fallen_planks", center, Vector2(0.35, 0.55),
                0.18, Vector3(2.9, 0.14, 0.29), rotation + 0.28)
            _yard_box("fallen_planks", center, Vector2(0.70, -0.75),
                0.24, Vector3(1.55, 0.17, 0.26), rotation + 0.65)
            _yard_box("rusted_gate", center, Vector2(0.22, 0.12),
                0.79, Vector3(1.45, 1.37, 0.10), rotation + 0.34)
            _yard_box("yard_rust", center, Vector2(-0.85, 0.76),
                0.27, Vector3(0.37, 0.33, 0.48), rotation)
        5:
            # Weathered garden bench and a modest flower patch in the front yard.
            _yard_box("bench_wood", center, Vector2(0, 0.0),
                0.55, Vector3(1.85, 0.14, 0.55), rotation)
            _yard_box("bench_wood", center, Vector2(0, 0.33),
                1.03, Vector3(1.85, 0.84, 0.13), rotation)
            for side in [-0.72, 0.72]:
                _yard_box("bench_dark", center, Vector2(side, 0.0),
                    0.31, Vector3(0.12, 0.48, 0.48), rotation)
            for n in range(5):
                var x := -1.1 + float(n) * 0.55
                _yard_box("flower_stem", center, Vector2(x, -0.85),
                    0.28, Vector3(0.07, 0.48, 0.07), rotation)
                _yard_box("flower_pink", center, Vector2(x, -0.85),
                    0.58, Vector3(0.23, 0.17, 0.23), rotation)


func _yard_radius(kind: int) -> float:
    # Entire assembled prop fits within this radius, including its roof.
    match kind:
        0: return 1.65  # Well
        1: return 2.45  # Three raised garden beds
        2: return 2.45  # Greenhouse
        3: return 2.15  # Firewood shelter
        5: return 1.75  # Garden bench and flowers
        6: return 1.95  # Fallen gate and broken timber
        _: return 2.05  # Scrap, barrels and tools


func _yard_spot_ok(p: Vector2, polygon: PackedVector2Array,
        other: Array, kind: int) -> bool:
    var radius := _yard_radius(kind)
    if _entry_zone_conflict(p, radius + 0.45):
        return false
    if not Geometry2D.is_point_in_polygon(p, polygon):
        return false
    # Test the whole item's bounding radius instead of its centre.
    if _road_surface_gap(p) < radius + 0.45:
        return false
    if not _clear_of_buildings(p, radius + 0.45):
        return false
    if _plot_boundary_gap(p) < radius + 0.32:
        return false
    for i in range(polygon.size()):
        var q := Geometry2D.get_closest_point_to_segment(p, polygon[i],
            polygon[(i + 1) % polygon.size()])
        if p.distance_to(q) < radius + 0.32:
            return false
    for previous in other:
        if p.distance_to(previous["center"]) < radius + float(previous["radius"]) + 0.5:
            return false
    return true


func _flower_patch(p: Vector2, salt: int) -> void:
    # Pink lupins, faded white flowers and dark leaves, assembled as cheap boxes.
    for j in range(3):
        var angle := float(salt * 7 + j * 13) * 1.7
        var stem_p := p + Vector2(cos(angle), sin(angle)) * (0.12 + 0.13 * float(j))
        var height := 0.40 + 0.13 * float((salt + j) % 4)
        _batch_box("flower_stem", _pt(stem_p, height * 0.5 + 0.10),
            Vector3(0.055, height, 0.055))
        _batch_box("flower_leaf", _pt(stem_p + Vector2(0.08, 0.02), 0.24),
            Vector3(0.31, 0.16, 0.18))
        var flower_key := "flower_white" if (salt + j) % 6 == 0 else "flower_pink"
        _batch_box(flower_key, _pt(stem_p, height + 0.16),
            Vector3(0.18, 0.19, 0.17))
    _flower_patches += 1


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
    # Every fourth plot has been left completely empty for years. Other plots
    # contain only one or two remnants, never a full inhabited garden.
    var target := 0 if _fence_count % 4 == 0 else 1 + int(_fence_count % 3 == 0)
    var placed: Array = []
    var attempts := 0
    while placed.size() < target and attempts < 160:
        attempts += 1
        var p := Vector2(rng.randf_range(low.x, high.x),
            rng.randf_range(low.y, high.y))
        var debris_types: Array[int] = [6, 4, 6, 3, 5, 4, 6, 1, 2, 0, 4]
        var kind: int = debris_types[(_fence_count * 7 + placed.size() * 3) % debris_types.size()]
        var rotation := float(rng.randi_range(0, 3)) * PI * 0.5
        if not _yard_spot_ok(p, points, placed, kind):
            _yard_positions_rejected += 1
            continue
        _yard_prop(p, kind, rotation, _fence_count + attempts)
        _yard_counts[kind] += 1
        _plot_props_count += 1
        placed.append({"center": p, "radius": _yard_radius(kind)})
    # Bounded flower patches: well away from buildings, fences and road surfaces.
    # Remaining November stalks are rare; most abandoned plots have none.
    var flower_goal := 1 if _fence_count % 5 == 0 else 0
    var flowers_placed := 0
    for trial in range(flower_goal * 24):
        if flowers_placed >= flower_goal:
            break
        var p := Vector2(rng.randf_range(low.x, high.x),
            rng.randf_range(low.y, high.y))
        if not Geometry2D.is_point_in_polygon(p, points):
            continue
        if _road_surface_gap(p) < 0.72 or _plot_boundary_gap(p) < 0.70:
            continue
        if _entry_zone_conflict(p, 0.75):
            continue
        if not _clear_of_buildings(p, 0.83):
            continue
        var blocked := false
        for prop in placed:
            if p.distance_to(prop["center"]) < float(prop["radius"]) + 0.75:
                blocked = true
                break
        if blocked:
            continue
        _flower_patch(p, _fence_count * 31 + trial)
        flowers_placed += 1


func _decorate_fence(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    _fence_count += 1
    _first_fence_endpoint = Vector2(INF, INF)
    _fence_break()
    var gate_edge := 0
    var near := INF
    for i in range(points.size()):
        var distance := _nearest_road_distance((points[i] + points[(i + 1) % points.size()]) * 0.5)
        if distance < near:
            near = distance
            gate_edge = i
    for i in range(points.size()):
        _fence_edge(points[i], points[(i + 1) % points.size()], i == gate_edge, points)
    if _last_fence_endpoint != Vector2(INF, INF) and _first_fence_endpoint != Vector2(INF, INF):
        _fence_bridge_gap(_last_fence_endpoint, _first_fence_endpoint, points)
    _decorate_plot_props(points)

func _decorate_road(points: PackedVector2Array) -> void:
    if points.size() < 2:
        return
    _road_count += 1
    # manual_geo.gd owns the road ruts; do not stack a second nearly coplanar mesh.
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
            if _road_surface_gap(p) < 0.65 or _plot_boundary_gap(p) < 0.55:
                continue
            if not _clear_of_buildings(p, 0.85):
                continue
            _batch_box("pole", _pt(p, 3.05), Vector3(0.22, 6.1, 0.22))
            _batch_box("crossarm", _pt(p, 5.85), Vector3(1.3, 0.16, 0.17))
            # Old Soviet road lantern: glowing polyhedron plus a short mounting arm.
            if (_utility_pole_count + _road_count) % 2 == 0:
                var toward_road := Vector3(-perpendicular.x, 0.0, perpendicular.y)
                if roadside < 0.0:
                    toward_road *= -1.0
                var mount := _pt(p, 5.45)
                var lamp_end := mount + toward_road * 0.90
                _batch_quad("crossarm", mount + Vector3.UP * 0.06,
                    lamp_end + Vector3.UP * 0.06,
                    lamp_end - Vector3.UP * 0.06, mount - Vector3.UP * 0.06)
                _batch_box("lamp_shade", lamp_end + Vector3.DOWN * 0.25,
                    Vector3(0.56, 0.18, 0.48))
                _street_lamp_heads += 1
                # Unpowered Soviet street lamps: only two scattered survivors
                # emit dim light; the other glass housings remain black.
                var live_lamp := _street_lights < 2 and _street_lamp_heads % 7 == 4
                _batch_box("lamp_glass" if live_lamp else "lamp_glass_off",
                    lamp_end + Vector3.DOWN * 0.43,
                    Vector3(0.35, 0.25, 0.35))
                if live_lamp:
                    var lantern := OmniLight3D.new()
                    lantern.name = "Жёлтый деревенский фонарь"
                    lantern.position = lamp_end + Vector3.DOWN * 0.43
                    lantern.light_color = Color("#f3c77b")
                    lantern.light_energy = 0.27
                    lantern.light_specular = 0.0
                    lantern.omni_range = 6.0
                    lantern.shadow_enabled = false
                    add_child(lantern)
                    _street_lights += 1
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
    canopy.radius = 1.20
    canopy.height = 2.6
    canopy.radial_segments = 5
    canopy.rings = 3
    _add_instanced(canopy, _aspen_positions, Color("#4b463d"), "Осинник / ломаные кроны")
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
    _add_instanced(bush, _bush_positions, Color("#414136"), "Подлесок / репейник")
