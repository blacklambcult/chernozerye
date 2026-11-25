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
var _plot_edge_cells: Dictionary = {}
const CLEARANCE_CELL_SIZE := 16.0
var _entrance_routes: Array = []
var _entrance_cells: Dictionary = {}
var _road_clearance_cells: Dictionary = {}
var _fronts_facing_road := 0
var _reserved_gate_sections := 0
var _fence_panels_skipped := 0
var _fence_panels_total := 0
var _fence_panels_relocated := 0
var _fence_short_spans_recovered := 0
var _fence_joints_joined := 0
var _last_fence_endpoint := Vector2(INF, INF)
var _first_fence_endpoint := Vector2(INF, INF)
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
var _yard_details: PackedVector3Array = PackedVector3Array()
var _road_ruts: PackedVector3Array = PackedVector3Array()
var _overhead_wires: PackedVector3Array = PackedVector3Array()
var _utility_pole_count := 0
var _building_count := 0
var _fence_count := 0
var _road_count := 0
var _feature_house_center := Vector2(INF, INF)
var _feature_house_distance := INF
var _building_polygons: Array[PackedVector2Array] = []
var _building_bounds: Array[Rect2] = []
var _building_cells: Dictionary = {}
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
var _timber_faces := PackedVector3Array()
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


const STATIC_GRID := preload("res://static_triangle_grid.gd")
const YARD_RENDER_CELL_SIZE := 256.0
const STUDIO_VILLAGE := preload("res://generated_village.gd")
var cultist_totem_site := Vector2.INF
var _studio_village: Node3D
var _studio_fence_profile := 0
var _plot_polygons: Array[PackedVector2Array] = []
var _plot_cells: Dictionary = {}
var _road_clearance: Array[Rect2] = []
var _house_approaches: Array[Dictionary] = []
var _reserved_building_space: Array[PackedVector2Array] = []
var _reserved_building_bounds: Array[Rect2] = []
var _reserved_building_cells: Dictionary = {}
var _fence_cells: Dictionary = {}
var _yard_objects: Array = []
var _yard_object_cells: Dictionary = {}
var _placed_plots: Array[PackedVector2Array] = []
var _fence_duplicates := 0
var _approaches_blocked := 0

func decorate(features: Array, vegetation_batches: Dictionary, profile_startup := false) -> void:
    var phase_start := Time.get_ticks_usec()
    _studio_village = STUDIO_VILLAGE.new()
    _studio_village.name = "StudioVillage"
    add_child(_studio_village)
    _studio_village.prepare(features)
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
                var a := road_points[i]
                var b := road_points[i + 1]
                _register_road_segment(a, b, width)
        elif kind == "car":
            var car := _local_points(item.get("points", []))
            if not car.is_empty():
                var p := car[0]
                _track_building(PackedVector2Array([p + Vector2(-1,-2), p + Vector2(1,-2),
                    p + Vector2(1,2), p + Vector2(-1,2)]))
        elif kind == "plot":
            var plot_points := _local_points(item.get("points", []))
            if plot_points.size() >= 3:
                _index_clearance(_plot_cells, _polygon_bounds(plot_points), _plot_polygons.size())
                _plot_polygons.append(plot_points)
                for i in range(plot_points.size()):
                    var a := plot_points[i]
                    var b := plot_points[(i + 1) % plot_points.size()]
                    _index_clearance(_plot_edge_cells, Rect2(a.min(b), (a - b).abs()), _plot_edges.size())
                    _plot_edges.append([a, b])
    for item in features:
        if not item is Dictionary:
            continue
        var category: String = str(item.get("type", ""))
        if category in ["house", "sauna", "shed"]:
            _place_studio_building(_local_points(item.get("points", [])), category, str(item.get("id", "")))
    var buildings_end := Time.get_ticks_usec()
    _reserve_placed_entrances()
    var entrances_end := Time.get_ticks_usec()
    for item in features:
        if not item is Dictionary:
            continue
        var category: String = str(item.get("type", ""))
        var polygon := _local_points(item.get("points", []))
        match category:
            "plot":
                _decorate_fence(polygon)
            "road":
                _decorate_road(polygon)
    var fences_end := Time.get_ticks_usec()
    _choose_cultist_totem_site()
    var total_plots := _fence_count
    for i in _placed_plots.size():
        _fence_count = i + 1
        _decorate_plot_props(_placed_plots[i])
    _fence_count = total_plots
    print("VILLAGE_ACCESS_READY: homes=", _house_approaches.size(), " segments=", _entrance_routes.size(),
        " blocked=", _approaches_blocked, " merged_fence_spans=", _fence_duplicates)
    _add_yard_vegetation(vegetation_batches)
    var placement_end := Time.get_ticks_usec()
    _studio_village.finish()
    var batches_end := Time.get_ticks_usec()
    _flush_details()
    var collisions_start := Time.get_ticks_usec()
    _build_collision_bodies()
    var collisions_end := Time.get_ticks_usec()
    if profile_startup:
        print("STARTUP_PROFILE: phase=village_buildings ms=%.3f" % ((buildings_end - phase_start) / 1000.0))
        print("STARTUP_PROFILE: phase=village_entrances ms=%.3f" % ((entrances_end - buildings_end) / 1000.0))
        print("STARTUP_PROFILE: phase=village_fences_and_roads ms=%.3f" % ((fences_end - entrances_end) / 1000.0))
        print("STARTUP_PROFILE: phase=village_yards ms=%.3f" % ((placement_end - fences_end) / 1000.0))
        print("STARTUP_PROFILE: phase=village_placement ms=%.3f" % ((placement_end - phase_start) / 1000.0))
        print("STARTUP_PROFILE: phase=village_model_load_and_batches ms=%.3f" % ((batches_end - placement_end) / 1000.0))
        print("STARTUP_PROFILE: phase=village_collisions ms=%.3f" % ((collisions_end - collisions_start) / 1000.0))
    _create_solid_mesh(_yard_details, Color("#48443b"), "Старый деревенский быт / ящики и дрова")
    _create_solid_mesh(_road_ruts, RUT_COLOR, "Дорога / земляные колеи")
    _create_solid_mesh(_overhead_wires, Color("#242d2d"), "Старые кабели / провисшие линии")
    _create_chimney_smoke()
    print("MANUAL_UTILITY_READY: poles=", _utility_pole_count,
        " lamp_heads=", _street_lamp_heads, " warm_lights=", _street_lights,
        " balconies=", _balcony_count,
        " flower_patches=", _flower_patches, " walks=", _front_walkways,
        " chimney_smoke=", _chimneys_smoking)
    print("VILLAGE_COLLISION_READY: buildings=", _collision_building_count,
        " fence_spans=", _collision_fence_span_count,
        " large_yard_props=", _collision_yard_count,
        " collision_bodies=3")
    print("MANUAL_ART_READY: buildings=", _building_count,
        " plots=", _fence_count, " roads=", _road_count, " lamps=", _lights_placed)
    print("MANUAL_VILLAGE_DETAIL_READY: canopies=", _canopy_count,
        " plot_props=", _plot_props_count, " crooked_fences=", _fence_count)
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
        a: Vector3, b: Vector3, floor_height: float, top_height: float,
        thickness: float = 0.0) -> void:
    if a.distance_squared_to(b) < 0.01 or top_height <= floor_height:
        return
    var p := Vector3(a.x, floor_height, a.z)
    var q := Vector3(b.x, floor_height, b.z)
    var r := Vector3(b.x, top_height, b.z)
    var t := Vector3(a.x, top_height, a.z)
    if thickness <= 0.0:
        # Each fence collider mirrors an actually built span, leaving reserved
        # gate sections fully open. Avoid thousands of expensive extra solids.
        _push_tri(faces, p, q, r)
        _push_tri(faces, p, r, t)
        return
    # Old walls were zero-thickness planes. A first-person capsule could get
    # extremely close to extruded log details; robust closed physical volumes
    # keep the camera outside even when sliding along building corners.
    var edge := (q - p).normalized()
    var side := Vector3(-edge.z, 0.0, edge.x) * (thickness * 0.5)
    var pf := p + side
    var qf := q + side
    var rf := r + side
    var tf := t + side
    var pb := p - side
    var qb := q - side
    var rb := r - side
    var tb := t - side
    _push_tri(faces, pf, qf, rf)
    _push_tri(faces, pf, rf, tf)
    _push_tri(faces, qb, pb, tb)
    _push_tri(faces, qb, tb, rb)
    _push_tri(faces, pb, pf, tf)
    _push_tri(faces, pb, tf, tb)
    _push_tri(faces, qf, qb, rb)
    _push_tri(faces, qf, rb, rf)
    _push_tri(faces, tf, rf, rb)
    _push_tri(faces, tf, rb, tb)
    _push_tri(faces, pb, qb, qf)
    _push_tri(faces, pb, qf, pf)


func _register_building_collider(points: PackedVector2Array, height: float, timber: bool = false) -> void:
    # Match the same footprint used to render actual walls, not invisible blockout.
    for i in range(points.size()):
        var a: Vector2 = points[i]
        var b: Vector2 = points[(i + 1) % points.size()]
        _collision_wall(_timber_faces if timber else _building_collision_faces, _pt(a, 0.0),
            _pt(b, 0.0), 0.02, height, 0.30)
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
    if label == "CollisionTimberBuildings":
        body.set_meta("impact_surface", &"wood")
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
    _build_collision_body(_timber_faces, "CollisionTimberBuildings")
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
                # Staggered damp bands beneath the lower edges of the sheets.
                var course := (y + 4 * int(x / 32)) % 32
                offset -= 0.055 * (1.0 - smoothstep(0.0, 7.0, float(course)))
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
                if wall_style == 0 or wall_style == 1:
                    var across := y if wall_style == 1 else x
                    var along := x if wall_style == 1 else y
                    var bow := sin(TAU * along / 64.0 + float(int(across / 8)))
                    offset += 0.036 * sin((across + bow) * PI * 0.5)
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

func _create_solid_mesh(verts: PackedVector3Array, color: Color, label: String,
        timber: bool = false) -> void:
    if verts.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    var material := _material(color)
    if timber:
        # Follow the course of each log, including diagonally oriented houses.
        var uvs := PackedVector2Array()
        uvs.resize(verts.size())
        for i in range(0, verts.size(), 3):
            var normal := (verts[i + 1] - verts[i]).cross(verts[i + 2] - verts[i])
            var tangent := Vector3.UP.cross(normal).normalized()
            if tangent.x < 0 or (is_zero_approx(tangent.x) and tangent.z < 0):
                tangent = -tangent
            for j in range(i, i + 3):
                uvs[j] = Vector2(verts[j].dot(tangent) / 3.4, verts[j].y / 1.6)
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        material.albedo_texture = preload("res://textures/weathered_timber.png")
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
        material.albedo_color = Color(color.r * 1.98, color.g * 2.12, color.b * 2.30)
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = material
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
        "log_upper": Color("#554a40"),
        "log_front": Color("#493d35"),
        "log_lower": Color("#423931"),
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
    if _detail_batches.is_empty():
        return
    var palette := Image.create(_detail_batches.size(), 1, false, Image.FORMAT_RGB8)
    var shaded := {}
    var unshaded := {}
    var slot := 0
    for key: String in _detail_batches:
        var verts: PackedVector3Array = _detail_batches[key]
        var tint: Color = colors.get(key, Color.WHITE)
        if key.begins_with("log_"):
            _create_solid_mesh(verts, tint, "Детали фасада / " + key, true)
            continue
        var lit := key in ["window_lit", "window_eerie_blue", "window_eerie_green", "lamp_glass"]
        palette.set_pixel(slot, 0, tint)
        var batches: Dictionary = unshaded if lit else shaded
        var uv := Vector2((float(slot) + 0.5) / palette.get_width(), 0.5)
        for i in range(0, verts.size(), 3):
            var a := verts[i]
            var b := verts[i + 1]
            var c := verts[i + 2]
            var cell := STATIC_GRID.cell_for_triangle(a, b, c, YARD_RENDER_CELL_SIZE)
            var batch: Dictionary = batches.get_or_add(cell, {"vertices": [], "uvs": []})
            batch.vertices.append(a)
            batch.vertices.append(b)
            batch.vertices.append(c)
            batch.uvs.append(uv)
            batch.uvs.append(uv)
            batch.uvs.append(uv)
        slot += 1
    var texture := ImageTexture.create_from_image(palette)
    var matte := _material(Color.WHITE, texture)
    var lights := _material(Color.WHITE, texture)
    lights.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    matte.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    lights.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    _flush_yard_meshes(shaded, matte, "Детали дворов")
    _flush_yard_meshes(unshaded, lights, "Вечерний свет окон и уличных фонарей")
    _detail_batches.clear()
    print("YARD_RENDER_BATCHES_READY: shaded=", shaded.size(), " lit=", unshaded.size())


func _flush_yard_meshes(batches: Dictionary, material: Material, label: String) -> void:
    for batch: Dictionary in batches.values():
        _make_textured_mesh(PackedVector3Array(batch.vertices), PackedVector2Array(batch.uvs),
            material, label)


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


func _road_within(p: Vector2, gap: float) -> bool:
    var area := Rect2(p, Vector2.ZERO).grow(gap)
    for i: int in _clearance_candidates(_road_clearance_cells, area):
        var segment: Array = _roads[i]
        var nearest := Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])
        if p.distance_to(nearest) - float(segment[2]) * 0.5 < gap:
            return true
    return false


func _plot_edge_within(p: Vector2, gap: float, include_boundary := false) -> bool:
    var area := Rect2(p, Vector2.ZERO).grow(gap)
    for i: int in _clearance_candidates(_plot_edge_cells, area):
        var segment: Array = _plot_edges[i]
        var distance := p.distance_to(Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1]))
        if distance < gap or (include_boundary and distance == gap):
            return true
    return false


func _fence_point_clear(p: Vector2) -> bool:
    # These bounds include the road half-width plus 0.5 m. A segment
    # outside them cannot violate the fence's 0.23 m road clearance.
    for i: int in _road_clearance_cells.get(_clearance_cell(p), []):
        if not _road_clearance[i].has_point(p):
            continue
        var segment: Array = _roads[i]
        var nearest := Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])
        if p.distance_to(nearest) - float(segment[2]) * 0.5 < 0.23:
            return false
    return _clear_of_buildings(p, 0.58)


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
        if _road_within(p, 0.48) or _plot_edge_within(p, 0.38):
            return false
        if not _clear_of_buildings(p, 0.35):
            return false
    return true


func _register_road_segment(a: Vector2, b: Vector2, width: float) -> void:
    var clearance := Rect2(a.min(b), (a - b).abs()).grow(width * 0.5 + 0.5)
    _index_clearance(_road_clearance_cells, clearance, _roads.size())
    _roads.append([a, b, width])
    _road_clearance.append(clearance)


func _clearance_cell(point: Vector2) -> Vector2i:
    return Vector2i((point / CLEARANCE_CELL_SIZE).floor())


func _index_clearance(cells: Dictionary, bounds: Rect2, index: int) -> void:
    var lo := _clearance_cell(bounds.position)
    var hi := _clearance_cell(bounds.end)
    for y in range(lo.y, hi.y + 1):
        for x in range(lo.x, hi.x + 1):
            var indices: Array = cells.get_or_add(Vector2i(x, y), [])
            indices.append(index)


func _entry_zone_conflict(p: Vector2, extra: float = 0.0) -> bool:
    # Props with a larger footprint may intersect a route in a neighboring cell.
    var margin := Vector2.ONE * maxf(extra, 0.0)
    var lo := _clearance_cell(p - margin)
    var hi := _clearance_cell(p + margin)
    for y in range(lo.y, hi.y + 1):
        for x in range(lo.x, hi.x + 1):
            for i: int in _entrance_cells.get(Vector2i(x, y), []):
                var route: Dictionary = _entrance_routes[i]
                var bounds: Rect2 = route["bounds"]
                if not bounds.grow(extra).has_point(p):
                    continue
                var closest := Geometry2D.get_closest_point_to_segment(
                    p, route["start"], route["end"])
                if p.distance_to(closest) < 1.10 + extra:
                    return true
    return false


func _build_entrance_routes(features: Array) -> void:
    _entrance_routes.clear()
    _entrance_cells.clear()
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
        _reserve_segment(start, finish)
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
        if _road_within(mid, 1.0):
            score += 8.0
        # Test the two door jambs and the exterior approach along the normal.
        var tangent := side / length
        for depth in [0.85, 1.7, 2.6]:
            for across in [-0.60, 0.0, 0.60]:
                var p := mid + outward * float(depth) + tangent * float(across)
                if not _clear_of_buildings(p, 0.16):
                    score += 15.0
                if depth < 1.8 and _road_within(p, 0.15):
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


func _polygon_bounds(points: PackedVector2Array) -> Rect2:
    var result := Rect2(points[0], Vector2.ZERO)
    for point in points:
        result = result.expand(point)
    return result


func _track_building(points: PackedVector2Array) -> void:
    var index := _building_polygons.size()
    var bounds := _polygon_bounds(points)
    _building_polygons.append(points)
    _building_bounds.append(bounds)
    _index_clearance(_building_cells, bounds, index)


func _clearance_candidates(cells: Dictionary, bounds: Rect2) -> Dictionary:
    var lo := _clearance_cell(bounds.position)
    var hi := _clearance_cell(bounds.end)
    var candidates := {}
    for y in range(lo.y, hi.y + 1):
        for x in range(lo.x, hi.x + 1):
            for index: int in cells.get(Vector2i(x, y), []):
                candidates[index] = true
    return candidates

func _segment_gap(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
    var closest := Geometry2D.get_closest_points_between_segments(a, b, c, d)
    return closest[0].distance_to(closest[1])


func _clear_building_site(envelope: PackedVector2Array, plot: PackedVector2Array) -> bool:
    var bounds := _polygon_bounds(envelope)
    if not plot.is_empty():
        for point in envelope:
            if not Geometry2D.is_point_in_polygon(point, plot):
                return false
        for i in envelope.size():
            for j in plot.size():
                if _segment_gap(envelope[i], envelope[(i + 1) % envelope.size()],
                        plot[j], plot[(j + 1) % plot.size()]) < 0.32:
                    return false
    for i: int in _clearance_candidates(_building_cells, bounds):
        if bounds.intersects(_building_bounds[i]) and not Geometry2D.intersect_polygons(
                envelope, _building_polygons[i]).is_empty():
            return false
    for i: int in _clearance_candidates(_reserved_building_cells, bounds):
        if bounds.intersects(_reserved_building_bounds[i]) and not Geometry2D.intersect_polygons(
                envelope, _reserved_building_space[i]).is_empty():
            return false
    for i: int in _clearance_candidates(_road_clearance_cells, bounds):
        if not bounds.intersects(_road_clearance[i]):
            continue
        var road: Array = _roads[i]
        if Geometry2D.is_point_in_polygon(road[0], envelope) \
                or Geometry2D.is_point_in_polygon(road[1], envelope):
            return false
        for j in envelope.size():
            if _segment_gap(envelope[j], envelope[(j + 1) % envelope.size()],
                    road[0], road[1]) < float(road[2]) * 0.5 + 0.5:
                return false
    return true


func _place_studio_building(points: PackedVector2Array, category: String, feature_id: String) -> void:
    if points.size() < 3:
        return
    _building_count += 1
    var front := _building_front_edge(points)
    var recipe: Dictionary = IZBA_VARIANTS.recipe(points) if category == "house" else {}
    var floors := int(recipe.get("floor_count", 1))
    var height := (5.09 if floors == 2 else 2.84) if category == "house" else (2.29 if category == "sauna" else 2.27)
    var center := _polygon_bounds(points).get_center()
    var plot := PackedVector2Array()
    for index: int in _plot_cells.get(_clearance_cell(center), []):
        var candidate := _plot_polygons[index]
        if Geometry2D.is_point_in_polygon(center, candidate):
            plot = candidate
            break
    var placement: Dictionary = _studio_village.add_building(points, category, front, floors,
        _building_count, _clear_building_site.bind(plot), feature_id)
    if placement.is_empty():
        return
    _track_building(placement.envelope)
    _register_building_collider(placement.foundation, height * placement.scale, category != "shed")
    if category == "house":
        _house_approaches.append(placement)
        var reserved_bounds := _polygon_bounds(placement.reserved)
        _index_clearance(_reserved_building_cells, reserved_bounds, _reserved_building_space.size())
        _reserved_building_space.append(placement.reserved)
        _reserved_building_bounds.append(reserved_bounds)
        if center.distance_to(_feature_house_center) < 2.0:
            # Retain the start-area landmark without adding props in the new corridor.
            print("MANUAL_SHOWCASE_YARD_READY: ", placement.door)


func _reserve_segment(start: Vector2, finish: Vector2) -> void:
    var bounds := Rect2(start.min(finish), (start - finish).abs()).grow(1.6)
    _index_clearance(_entrance_cells, bounds, _entrance_routes.size())
    _entrance_routes.append({"start": start, "end": finish, "bounds": bounds})


func _passage_clear(start: Vector2, finish: Vector2) -> bool:
    for i in range(ceili(start.distance_to(finish) / 0.35) + 1):
        if not _clear_of_buildings(start.move_toward(finish, i * 0.35), 0.68):
            return false
    return true


func _find_road_detour(start: Vector2) -> PackedVector2Array:
    # Four-neighbor search is only needed where a straight approach is blocked.
    var frontier: Array[Vector2i] = [Vector2i.ZERO]
    var previous := {Vector2i.ZERO: Vector2i.ZERO}
    var cursor := 0
    while cursor < frontier.size():
        var cell := frontier[cursor]
        cursor += 1
        var position := start + Vector2(cell)
        if _road_surface_gap(position) <= 0.4:
            var route := PackedVector2Array([position])
            while cell != Vector2i.ZERO:
                cell = previous[cell]
                route.append(start + Vector2(cell))
            route.reverse()
            return route
        for axis in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
            var next: Vector2i = cell + axis
            if previous.has(next) or next.length_squared() > 42 * 42:
                continue
            if not _passage_clear(position, start + Vector2(next)):
                continue
            previous[next] = cell
            frontier.append(next)
    return PackedVector2Array()


func _reserve_placed_entrances() -> void:
    for site in _house_approaches:
        var start: Vector2 = site.front + site.outward * 0.74
        _reserve_segment(site.door, start)
        var candidates: Array[Vector2] = []
        for road in _roads:
            var point := Geometry2D.get_closest_point_to_segment(start, road[0], road[1])
            if point.distance_squared_to(start) < 32.0 ** 2:
                candidates.append(point)
        candidates.sort_custom(func(a: Vector2, b: Vector2) -> bool:
            return start.distance_squared_to(a) < start.distance_squared_to(b)
        )
        var found := false
        for finish in candidates:
            if (finish - start).dot(site.outward) >= -0.1 and _passage_clear(start, finish):
                _reserve_segment(start, finish)
                found = true
                break
        if found:
            continue
        var detour := _find_road_detour(start)
        if detour.is_empty():
            print("VILLAGE_ACCESS_LIMIT: ", start, " road_gap=", _road_surface_gap(start), " start_clear=", _clear_of_buildings(start, 0.68))
            _approaches_blocked += 1
            continue
        var first := 0
        while first < detour.size() - 1:
            var last := detour.size() - 1
            while last > first + 1 and not _passage_clear(detour[first], detour[last]):
                last -= 1
            _reserve_segment(detour[first], detour[last])
            first = last
    print("VILLAGE_ENTRANCES_READY: reserved=", _entrance_routes.size())


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
        if _road_within(p, 0.68):
            break
        if _plot_edge_within(p, 0.26) or not _clear_of_buildings(p, 0.23):
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
        if _road_within(p, 0.85) or _plot_edge_within(p, 0.15):
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
        if _road_within(p, 0.65) or _plot_edge_within(p, 0.45):
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
        if _road_within(p, 0.75) or _plot_edge_within(p, 0.30):
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
    stack_clear = stack_clear and not _plot_edge_within(stack_p, 0.7, true)
    stack_clear = stack_clear and _clear_of_buildings(stack_p, 0.65)
    if stack_clear:
        for i in range(4):
            _batch_box("porch", stack_origin + tangent * float(i % 2) * 0.62 +
                Vector3.UP * (0.18 + 0.36 * float(i / 2)),
                Vector3(0.52, 0.32, 0.50))
    var lamp_origin := origin - tangent * 2.0 + vout * 2.25
    var lamp_p := Vector2(lamp_origin.x, -lamp_origin.z)
    var lamp_clear := _road_surface_gap(lamp_p) > 0.8
    lamp_clear = lamp_clear and not _plot_edge_within(lamp_p, 0.65, true)
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

func _fence_fit_span(a: Vector2, b: Vector2, inward: Vector2,
        polygon: PackedVector2Array) -> Array:
    # Find the smallest safe setback for a section, retaining surveyed plot lines.
    for inset in [0.18, 0.36, 0.65, 1.00, 1.45, 1.95, 2.50, 3.10, 3.80, 4.55]:
        var start := a + inward * float(inset)
        var finish := b + inward * float(inset)
        if _fence_span_clear(start, finish, polygon):
            return [start, finish, float(inset)]
    return []


func _distance_to_fence(point: Vector2, radius: float) -> float:
    var lo := Vector2i(((point - Vector2.ONE * radius) / 4.0).floor())
    var hi := Vector2i(((point + Vector2.ONE * radius) / 4.0).floor())
    var distance := INF
    for x in range(lo.x, hi.x + 1):
        for y in range(lo.y, hi.y + 1):
            for span in _fence_cells.get(Vector2i(x, y), []):
                var closest := Geometry2D.get_closest_point_to_segment(point, span[0], span[1])
                distance = minf(distance, point.distance_to(closest))
    return distance


func _place_fence_once(a: Vector2, b: Vector2) -> void:
    var lo := Vector2i(((a.min(b) - Vector2.ONE * 0.55) / 4.0).floor())
    var hi := Vector2i(((a.max(b) + Vector2.ONE * 0.55) / 4.0).floor())
    var axis := (b - a).normalized()
    for x in range(lo.x, hi.x + 1):
        for y in range(lo.y, hi.y + 1):
            for existing in _fence_cells.get(Vector2i(x, y), []):
                var c: Vector2 = existing[0]
                var d: Vector2 = existing[1]
                if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
                    if minf(a.distance_to(c), a.distance_to(d)) > 0.08 \
                            and minf(b.distance_to(c), b.distance_to(d)) > 0.08:
                        _fence_duplicates += 1
                        return
                if absf(axis.dot((d - c).normalized())) > 0.89:
                    var start := (c - a).dot(axis)
                    var finish := (d - a).dot(axis)
                    var overlap := minf(a.distance_to(b), maxf(start, finish)) - maxf(0.0, minf(start, finish))
                    if overlap > 0.28 and _segment_gap(a, b, c, d) < 0.54:
                        _fence_duplicates += 1
                        return
    for x in range(lo.x, hi.x + 1):
        for y in range(lo.y, hi.y + 1):
            var key := Vector2i(x, y)
            if not _fence_cells.has(key):
                _fence_cells[key] = []
            _fence_cells[key].append([a, b])
    _studio_village.add_fence(a, b, _studio_fence_profile, _fence_count % 3)
    _register_fence_collider(a, b)


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
    _place_fence_once(a, b)
    _fence_joints_joined += 1


func _fence_draw_span(start: Vector2, finish: Vector2,
        polygon: PackedVector2Array) -> void:
    if _last_fence_endpoint != Vector2(INF, INF):
        _fence_bridge_gap(_last_fence_endpoint, start, polygon)
    if _first_fence_endpoint == Vector2(INF, INF):
        _first_fence_endpoint = start
    _place_fence_once(start, finish)
    _last_fence_endpoint = finish


func _fence_break() -> void:
    _last_fence_endpoint = Vector2(INF, INF)


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
            _fence_draw_span(fit[0], fit[1], polygon)
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
            _fence_draw_span(short_fit[0], short_fit[1], polygon)
            if float(short_fit[2]) >= 0.45:
                _fence_panels_relocated += 1
            recovered += 1
        if recovered == 0:
            _fence_panels_skipped += 1
        else:
            _fence_short_spans_recovered += recovered


func _clear_of_buildings(p: Vector2, gap: float) -> bool:
    var margin := Vector2.ONE * gap
    var lo := Vector2i(((p - margin) / CLEARANCE_CELL_SIZE).floor())
    var hi := Vector2i(((p + margin) / CLEARANCE_CELL_SIZE).floor())
    for y in range(lo.y, hi.y + 1):
        for x in range(lo.x, hi.x + 1):
            for j: int in _building_cells.get(Vector2i(x, y), []):
                var bb: Rect2 = _building_bounds[j]
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


func _register_yard_object(object: Dictionary) -> void:
    var bounds := Rect2(object.center, Vector2.ZERO).grow(float(object.radius) + 0.5)
    _index_clearance(_yard_object_cells, bounds, _yard_objects.size())
    _yard_objects.append(object)


func _yard_spot_ok(p: Vector2, polygon: PackedVector2Array,
        other: Array, kind: int) -> bool:
    var radius := _yard_radius(kind)
    if _entry_zone_conflict(p, radius + 0.45):
        return false
    if not Geometry2D.is_point_in_polygon(p, polygon):
        return false
    # Test the whole item's bounding radius instead of its centre.
    if _road_within(p, radius + 0.45):
        return false
    if not _clear_of_buildings(p, radius + 0.45):
        return false
    if _plot_edge_within(p, radius + 0.32):
        return false
    for i in range(polygon.size()):
        var q := Geometry2D.get_closest_point_to_segment(p, polygon[i],
            polygon[(i + 1) % polygon.size()])
        if p.distance_to(q) < radius + 0.32:
            return false
    if _distance_to_fence(p, radius + 0.45) < radius + 0.45:
        return false
    var area := Rect2(p, Vector2.ZERO).grow(radius)
    if _yard_objects.is_empty():
        for previous in other:
            if p.distance_to(previous["center"]) < radius + float(previous["radius"]) + 0.5:
                return false
    else:
        for i: int in _clearance_candidates(_yard_object_cells, area):
            var previous: Dictionary = _yard_objects[i]
            if p.distance_to(previous.center) < radius + float(previous.radius) + 0.5:
                return false
    return true


func _flower_patch(p: Vector2, salt: int) -> void:
    # Across 209 abandoned plots, only a few old perennials survive in
    # November. An absolute cap prevents the expanded Geo Lab map from
    # accidentally looking like a blooming summer village.
    if _flower_patches >= 28:
        return
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
        var object := {"center": p, "radius": _yard_radius(kind)}
        placed.append(object)
        _register_yard_object(object)
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
        if _road_within(p, 0.72) or _plot_edge_within(p, 0.70) \
                or _distance_to_fence(p, 0.75) < 0.75:
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


func _choose_cultist_totem_site() -> void:
    for plot in _placed_plots:
        if _studio_village.plot_profile(plot) != 6:
            continue
        var center := _polygon_bounds(plot).get_center()
        for radius in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 13.0, 16.0]:
            for i in 16:
                var candidate: Vector2 = center + Vector2.from_angle(TAU * i / 16.0) * radius
                if _yard_spot_ok(candidate, plot, [], 6):
                    cultist_totem_site = candidate
                    _register_yard_object({"center": candidate, "radius": 2.0})
                    return


func _add_yard_vegetation(batches: Dictionary) -> void:
    var geo := get_parent()
    var rng := RandomNumberGenerator.new()
    rng.seed = 481056
    var count := 0
    for i in _placed_plots.size():
        if i % 3 != 1:
            continue
        var plot := _placed_plots[i]
        var bounds := _polygon_bounds(plot)
        var placed := 0
        for attempt in 32:
            if placed == 3:
                break
            var point := Vector2(rng.randf_range(bounds.position.x, bounds.end.x),
                rng.randf_range(bounds.position.y, bounds.end.y))
            if not _yard_spot_ok(point, plot, [], 3):
                continue
            var basis := Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * rng.randf_range(0.85, 1.3))
            geo.call("_queue_forest_asset", batches, "yard_scrub" if placed == 0 else "understory_%d" % (i % 4),
                Transform3D(basis, _pt(point, 0.025)))
            _register_yard_object({"center": point, "radius": 2.0})
            placed += 1
            count += 1
    print("YARD_VEGETATION_READY: clusters=", count)


func _decorate_fence(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    _fence_count += 1
    _studio_fence_profile = _studio_village.plot_profile(points)
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
    _placed_plots.append(points)

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
            if _road_within(p, 0.65) or _plot_edge_within(p, 0.55):
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
                    lantern.light_energy = 0.66
                    lantern.light_specular = 0.0
                    lantern.omni_range = 10.0
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
