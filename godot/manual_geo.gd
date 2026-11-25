extends Node3D
# CHERNOZERYE / manually surveyed 3D preview
# Source: user Geo Lab 2.0 survey (710 WGS84 objects, 2026-11-19), converted to UTM local metres.
# Visuals are blockout placeholders; outline shapes and positions are preserved.
const SOURCE := "res://manual_layout.json"
const COLORS := {
    "road": Color("#4b4239"),
    "path": Color("#4a423a"),
    "plot": Color("#32312d"),
    "forest": Color("#3b3e38"),
    "water": Color("#234253"),
    "object": Color("#9c9ca1"),
    "house": Color("#bb8b73"),
    "shed": Color("#937a62"),
    "sauna": Color("#bd7f6b"),
    "car": Color("#5585b0")
}
var _soil_faces := PackedVector3Array()
var object_count: int = 0
const FOREST_MODELS := "res://generated_forest/"
const FOREST_FLOOR := preload("res://forest_floor.gd")
const SHRINE := preload("res://forest_shrine.gd")
var forest_positions: Array[Transform3D] = []
var _forest_floor: Node3D
var _forest_sites: Array[Vector2] = []
var _forest_cells: Dictionary = {}
var _forest_chunk_size := 145.0
var _forest_models: Dictionary = {}
var _shrine_sites: Array[Vector2] = []
var _quest_shrines: Array[Node3D] = []
var tree_trunks: Array[Transform3D] = []
var _tree_collision_total := 0
var manual_roads: Array = []
var building_footprints: Array[PackedVector2Array] = []
var _roadside_tufts := 0
var _mud_patches := 0
var _puddle_patches := 0
var _roadside_sections := 0
var _junctions: Array = []
var _junction_mesh_count := 0
var _base_buildings: Node3D
var _profile_startup := false

func _ready() -> void:
    _profile_startup = "--startup-profile" in OS.get_cmdline_user_args()
    _forest_chunk_size = 96.0 if "--world-chunks-96" in OS.get_cmdline_user_args() else 145.0
    visible = false
    call_deferred("_build_manual")

func _build_manual() -> void:
    await get_tree().process_frame
    var phase_start := Time.get_ticks_usec()
    if not FileAccess.file_exists(SOURCE):
        push_warning("GeoLab manual layout absent")
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not data is Dictionary:
        push_error("GeoLab manual layout invalid")
        return
    var features: Array = data.get("features", [])
    phase_start = _profile_phase("survey_read", phase_start)
    _base_buildings = Node3D.new()
    _base_buildings.name = "UnstyledBuildingBlockout"
    _base_buildings.visible = false
    add_child(_base_buildings)
    var surveyed_road_id := 0
    for f in features:
        if not f is Dictionary:
            continue
        var kind := str(f.get("type", ""))
        if kind == "road" or kind == "path":
            var polyline := _clean_road_points(_points(f.get("points", [])))
            var this_road_id := surveyed_road_id if kind == "road" else -1
            for i in range(polyline.size() - 1):
                if polyline[i].distance_squared_to(polyline[i + 1]) < 0.0004:
                    continue
                manual_roads.append([polyline[i], polyline[i + 1], this_road_id])
            if kind == "road":
                surveyed_road_id += 1
        elif kind in ["house", "sauna", "shed"]:
            var footprint := _points(f.get("points", []))
            if footprint.size() >= 3:
                building_footprints.append(footprint)
    # Find crossings before generating wheel marks and gravel. Otherwise
    # long dark ruts are drawn underneath a small circular junction patch
    # and re-emerge as a hard X through the intersection.
    _detect_road_intersections()
    var road_draw_index := 0
    for f in features:
        if not f is Dictionary:
            continue
        var category: String = str(f.get("type", ""))
        var raw: Array = f.get("points", [])
        if raw.is_empty() or not COLORS.has(category):
            continue
        if category == "car":
            _add_car(raw[0], f)
        elif category == "road" or category == "path":
            if category == "road":
                # Each surveyed road sits on a slightly different depth layer.
                # No overlapping coplanar road planes and no giant round caps.
                _add_strip(raw, 3.8, _road_elevation(road_draw_index),
                    COLORS["road"], "road")
                road_draw_index += 1
            else:
                _add_strip(raw, 1.6, 0.105, COLORS["path"], "path")
        else:
            var points := _points(raw)
            if points.size() < 3:
                continue
            match category:
                "plot":
                    # Editor-only plot outlines floated across roads at y=0.22.
                    # The actual wooden/mesh fence now marks the plot boundary.
                    pass
                "forest":
                    _scatter_forest(points)
                "water":
                    _add_area(points, 0.067, COLORS[category], "Водоём")
                "house", "sauna", "shed":
                    _add_building(points, category)
                "object":
                    _add_area(points, 0.12, COLORS[category], "Объект")
        object_count += 1
    # Surveyed centre lines remain untouched. No visible round junction caps:
    # crossings are handled by small elevation separation + track clearance.
    _build_road_intersections()
    if not _soil_faces.is_empty():
        var road_body := StaticBody3D.new()
        road_body.collision_layer = 2
        road_body.collision_mask = 0
        road_body.set_meta("impact_surface", &"soil")
        var road_shape := ConcavePolygonShape3D.new()
        road_shape.backface_collision = true
        road_shape.set_faces(_soil_faces)
        var road_collider := CollisionShape3D.new()
        road_collider.shape = road_shape
        road_body.add_child(road_collider)
        add_child(road_body)
        _soil_faces.clear()
    phase_start = _profile_phase("survey_meshes_and_sites", phase_start)
    _forest_floor = FOREST_FLOOR.new()
    _forest_floor.name = "ForestFloor"
    add_child(_forest_floor)
    _forest_floor.prepare(features, manual_roads, _forest_sites)
    _forest_floor.build()
    phase_start = _profile_phase("forest_terrain", phase_start)
    _build_forest_instances()
    phase_start = _profile_phase("forest_instances_total", phase_start)
    # Separate, reversible decorative layer; manual survey coordinates remain untouched.
    var art := Node3D.new()
    art.name = "VillageArt22"
    art.set_script(preload("res://manual_art.gd"))
    add_child(art)
    art.call("decorate", features, _profile_startup)
    _profile_phase("village_total", phase_start)
    var totem: Vector2 = art.get("cultist_totem_site")
    if totem.is_finite():
        _spawn_shrine(totem, 0.035, "crimson_totem", Color("#ff294e"))
    print("SHRINE_QUEST_READY: targets=", _quest_shrines.size(), " final=", totem)
    print("MANUAL_LAYOUT_READY: ", object_count)
    print("MANUAL_STREETSCAPE_READY: roadside_sections=", _roadside_sections,
        " roadside_grass=", _roadside_tufts,
        " junctions=", _junction_mesh_count)
    print("NOVEMBER_MUD_READY: patches=", _mud_patches,
        " shallow_puddles=", _puddle_patches)

func _profile_phase(phase: String, start_usec: int) -> int:
    var now := Time.get_ticks_usec()
    if _profile_startup:
        print("STARTUP_PROFILE: phase=%s ms=%.3f" % [phase, (now - start_usec) / 1000.0])
    return now

func _points(raw: Array) -> PackedVector2Array:
    var result := PackedVector2Array()
    for p in raw:
        if p is Array and p.size() >= 2:
            result.append(Vector2(float(p[0]), float(p[1])))
    return result

func _pos(p: Vector2, y: float) -> Vector3:
    return Vector3(p.x, y, -p.y)

func _mat(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 1.0
    m.specular = 0.0
    m.metallic = 0.0
    m.clearcoat_enabled = false
    m.rim_enabled = false
    m.anisotropy_enabled = false
    m.emission_enabled = false
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _mesh_from_triangles(vertices: PackedVector3Array, color: Color, label: String,
        soil: bool = false, jitter_group: StringName = &"",
        render_group: StringName = &"") -> void:
    if vertices.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var material := _mat(color)
    if soil:
        _soil_faces.append_array(vertices)
        var uvs := PackedVector2Array()
        uvs.resize(vertices.size())
        for i in vertices.size():
            uvs[i] = Vector2(vertices[i].x, vertices[i].z) / 3.6
        arrays[Mesh.ARRAY_TEX_UV] = uvs
        material.albedo_texture = preload("res://textures/lane_soil.png")
        # Blend mip samples to reduce shimmer when the camera looks along the road.
        material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
        material.albedo_color = Color(color.r * 2.15, color.g * 2.25, color.b * 2.40)
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = label
    if jitter_group != &"":
        instance.add_to_group(jitter_group)
    if render_group != &"":
        instance.add_to_group(render_group)
    instance.mesh = mesh
    instance.material_override = material
    instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    if label.ends_with("_walls") or label.ends_with("_roof"):
        _base_buildings.add_child(instance)
    else:
        add_child(instance)

func _put_triangle(output: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3) -> void:
    output.append_array(PackedVector3Array([a, b, c]))

func _add_area(points: PackedVector2Array, y: float, tint: Color, label: String) -> void:
    if points.size() < 3:
        return
    var triangles := Geometry2D.triangulate_polygon(points)
    var verts := PackedVector3Array()
    for k in range(0, triangles.size(), 3):
        _put_triangle(verts, _pos(points[triangles[k]], y),
            _pos(points[triangles[k + 1]], y), _pos(points[triangles[k + 2]], y))
    var jitter_group := &"ps1_jitter_foliage" if label in ["Лес", "Водоём"] else &""
    _mesh_from_triangles(verts, tint, label, false, jitter_group)

func _clean_road_points(points: PackedVector2Array) -> PackedVector2Array:
    # Exported hand-drawn lines occasionally contain repeated consecutive points.
    var clean := PackedVector2Array()
    for p in points:
        if clean.is_empty() or p.distance_squared_to(clean[clean.size() - 1]) > 0.0004:
            clean.append(p)
    return clean


func _joined_offset(points: PackedVector2Array, index: int, distance: float) -> Vector2:
    # One shared offset vertex at each turn prevents cracks between road segments.
    var last := points.size() - 1
    var prev_dir := (points[index] - points[maxi(0, index - 1)]).normalized()
    var next_dir := (points[mini(last, index + 1)] - points[index]).normalized()
    if index == 0:
        prev_dir = next_dir
    elif index == last:
        next_dir = prev_dir
    var n0 := Vector2(-prev_dir.y, prev_dir.x)
    var n1 := Vector2(-next_dir.y, next_dir.x)
    var bisector := n0 + n1
    if bisector.length_squared() < 0.02:
        return points[index] + n1 * distance
    var miter := bisector.normalized()
    var projection := miter.dot(n1)
    if projection < 0.36:
        return points[index] + n1 * distance
    return points[index] + miter * distance * minf(1.65, 1.0 / projection)


func _append_joined_ribbon(vertices: PackedVector3Array, points: PackedVector2Array,
        width: float, offset: float, elevation: float) -> void:
    if points.size() < 2:
        return
    var half_width := width * 0.5
    for i in range(points.size() - 1):
        var left0 := _pos(_joined_offset(points, i, offset - half_width), elevation)
        var right0 := _pos(_joined_offset(points, i, offset + half_width), elevation)
        var left1 := _pos(_joined_offset(points, i + 1, offset - half_width), elevation)
        var right1 := _pos(_joined_offset(points, i + 1, offset + half_width), elevation)
        _put_triangle(vertices, left0, right0, right1)
        _put_triangle(vertices, left0, right1, left1)


func _road_elevation(road_id: int) -> float:
    # Up to 20 surveyed roads, max height difference ≈ 7 cm.
    # Separates overlapping Godot WebGL polygons with no circular junction discs.
    return 0.11 + float(road_id) * 0.0036


func _add_strip(raw: Array, width: float, height: float, tint: Color, label: String) -> void:
    var points := _clean_road_points(_points(raw))
    if points.size() < 2:
        return
    var surface := PackedVector3Array()
    _append_joined_ribbon(surface, points, width, 0.0, height)
    var jitter_group := &"ps1_jitter_road" if label in ["road", "path"] else &""
    _mesh_from_triangles(surface, tint, label, true, jitter_group)
    if label == "road":
        _add_november_mud(points, height)
        _add_road_wear(points, height + 0.035)
        _add_village_roadside(points, width, height)


func _append_mud_patch(output: PackedVector3Array, center: Vector2,
        tangent: Vector2, wide: Vector2, length: float, width: float,
        altitude: float, salt: int) -> void:
    # Eight broad, uneven soil polygons, not round junction covers.
    # Each patch is strictly inside the road and above its own surface.
    var sides := 8
    for k in range(sides):
        var angle_a := TAU * float(k) / float(sides)
        var angle_b := TAU * float(k + 1) / float(sides)
        var distortion_a := 0.88 + 0.10 * sin(float(k * 13 + salt * 7))
        var distortion_b := 0.88 + 0.10 * sin(float((k + 1) * 13 + salt * 7))
        var p0 := center + tangent * (cos(angle_a) * length * distortion_a)
        p0 += wide * (sin(angle_a) * width * distortion_a)
        var p1 := center + tangent * (cos(angle_b) * length * distortion_b)
        p1 += wide * (sin(angle_b) * width * distortion_b)
        _put_triangle(output, _pos(center, altitude),
            _pos(p0, altitude), _pos(p1, altitude))


func _add_november_mud(points: PackedVector2Array, height: float) -> void:
    # Waterlogged soil and narrow shallow puddles, clipped to each 3.8 m
    # roadway. Do not scatter at crossroads (would reintroduce flickering).
    var mud := PackedVector3Array()
    var dark_mud := PackedVector3Array()
    var puddles := PackedVector3Array()
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261118 + int(absf(points[0].x * 11.0 + points[0].y * 17.0))
    for i in range(points.size() - 1):
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var delta := b - a
        var distance := delta.length()
        if distance < 0.4:
            continue
        var tangent := delta / distance
        var wide := Vector2(-tangent.y, tangent.x)
        var sections := maxi(1, int(ceil(distance / 3.6)))
        for j in range(sections):
            if rng.randf() > 0.72:
                continue
            var along := (float(j) + rng.randf_range(0.25, 0.75)) / float(sections)
            var center := a.lerp(b, along)
            center += wide * rng.randf_range(-0.85, 0.85)
            if _near_junction(center, 2.4):
                continue
            var half_long := rng.randf_range(0.48, 1.20)
            var half_wide := rng.randf_range(0.24, 0.62)
            var pool := rng.randf() < 0.16
            if pool:
                half_long *= 0.70
                half_wide *= 0.65
                _append_mud_patch(puddles, center, tangent, wide, half_long,
                    half_wide, height + 0.024, i * 61 + j)
                _puddle_patches += 1
            else:
                if (j + i) % 3 == 0:
                    _append_mud_patch(dark_mud, center, tangent, wide, half_long,
                        half_wide, height + 0.018, i * 61 + j)
                else:
                    _append_mud_patch(mud, center, tangent, wide, half_long,
                        half_wide, height + 0.018, i * 61 + j)
                _mud_patches += 1
    _mesh_from_triangles(mud, Color("#40352e"), "Ноябрь / влажный грунт", true, &"ps1_jitter_road")
    _mesh_from_triangles(dark_mud, Color("#332c28"), "Ноябрь / грязевые пятна", true, &"ps1_jitter_road")
    _mesh_from_triangles(puddles, Color("#3e4445"), "Ноябрь / неглубокие лужи", false, &"ps1_jitter_road")


func _near_junction(point: Vector2, margin: float = 0.0) -> bool:
    for crossing in _junctions:
        var center: Vector2 = crossing["center"]
        var radius: float = crossing["radius"]
        if point.distance_squared_to(center) <= pow(radius + margin, 2.0):
            return true
    return false


func _add_road_wear(points: PackedVector2Array, height: float) -> void:
    # Old continuous dark tracks from two surveyed roads overlapped into a
    # black X at crossroads. Draw faint, interrupted wheel marks instead;
    # never render marks near intersections or plot crossings.
    var tracks := PackedVector3Array()
    var grass := PackedVector3Array()
    for i in range(points.size() - 1):
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var delta := b - a
        var distance := delta.length()
        if distance < 0.3:
            continue
        var tangent := delta / distance
        var side := Vector2(-tangent.y, tangent.x)
        var steps := maxi(1, int(ceil(distance / 2.25)))
        for j in range(steps):
            var p0 := a.lerp(b, float(j) / float(steps))
            var p1 := a.lerp(b, float(j + 1) / float(steps))
            var mid := (p0 + p1) * 0.5
            if _near_junction(mid, 2.8):
                continue
            # A few empty sections prevent mechanical parallel lines.
            if (i * 7 + j * 3) % 9 != 0:
                var tint_shift := 0.07 * sin(float(j * 11 + i * 3))
                for side_sign in [-1, 1]:
                    var lane := float(side_sign) * (1.04 + tint_shift)
                    var start := p0 + side * lane
                    var finish := p1 + side * lane
                    var narrow := PackedVector2Array([start, finish])
                    var mark_width := 0.20 + 0.09 * absf(sin(float(j * 5 + i * 7)))
                    _append_joined_ribbon(tracks, narrow, mark_width, 0.0, height)
            if (j + i) % 4 == 1 and not _near_junction(mid, 4.0):
                var center := PackedVector2Array([p0, p1])
                _append_joined_ribbon(grass, center, 0.13, 0.0, height + 0.010)
    _mesh_from_triangles(tracks, Color("#3b342e"), "Дорога / мягкие прерывистые колеи", true, &"ps1_jitter_road")
    _mesh_from_triangles(grass, Color("#49473c"), "Дорога / редкая центральная трава", false, &"ps1_jitter_road")


func _add_village_roadside(points: PackedVector2Array, width: float, height: float) -> void:
    # Dirt shoulders, small stone chips and knee-high verge plants.
    # Geometry follows user-drawn GeoJSON roads, with no changed centre lines.
    # A modest batched budget keeps the Web Compatibility renderer responsive.
    var shoulders := PackedVector3Array()
    # Joined base apron sits 2.5 cm under the road and remains visible on both sides.
    # Keep every road's shoulder below even the lowest road surface, regardless
    # of render-layer bias, to avoid another dark X at the junction.
    var shoulder_height := 0.072 + maxf(0.0, height - 0.11) * 0.10
    _append_joined_ribbon(shoulders, points, width + 1.45, 0.0, shoulder_height)
    var stones := PackedVector3Array()
    var weeds := PackedVector3Array()
    var dried := PackedVector3Array()
    var rng := RandomNumberGenerator.new()
    if points.size() < 2:
        return
    rng.seed = 712671 + int(absf(points[0].x * 3.9 + points[0].y * 6.1))
    for i in range(points.size() - 1):
        var a: Vector2 = points[i]
        var b: Vector2 = points[i + 1]
        var delta := b - a
        var length := delta.length()
        if length < 0.25:
            continue
        var tangent := delta / length
        var side := Vector2(-tangent.y, tangent.x)
        var steps := mini(220, maxi(1, int(ceil(length / 2.8))))
        for j in range(steps):
            var t0 := float(j) / float(steps)
            var t1 := float(j + 1) / float(steps)
            var first := a.lerp(b, t0)
            var last := a.lerp(b, t1)
            # Use integer signs: GDScript's % operator rejects float operands.
            for sign in [-1, 1]:
                var sgn := float(sign)
                _roadside_sections += 1
                # Deterministic sparse wild grass at the outer shoulder, not on tire tracks.
                if (j + i * 7 + sign * 3) % 3 == 0:
                    var center := first.lerp(last, rng.randf_range(0.15, 0.85))
                    center += side * sgn * (width * 0.5 + rng.randf_range(0.64, 1.20))
                    if _near_building(center, 0.75) or _near_junction(center, 2.0):
                        continue
                    var blade := rng.randf_range(0.28, 0.66)
                    var lean := tangent * rng.randf_range(-0.15, 0.15)
                    var crown := _pos(center + lean, 0.12 + blade)
                    var half := side * 0.11
                    # Mutate the original packed buffer, not a copy-on-write alias.
                    if (j + sign + i) % 5 == 0:
                        _put_triangle(dried, _pos(center - half, 0.12), crown,
                            _pos(center + half, 0.12))
                        _put_triangle(dried, _pos(center - tangent * 0.11, 0.12),
                            crown, _pos(center + tangent * 0.11, 0.12))
                    else:
                        _put_triangle(weeds, _pos(center - half, 0.12), crown,
                            _pos(center + half, 0.12))
                        _put_triangle(weeds, _pos(center - tangent * 0.11, 0.12),
                            crown, _pos(center + tangent * 0.11, 0.12))
                    _roadside_tufts += 1
            # Pebbles and irregular compacted soil, small enough not to read as a grid.
            if (j + i) % 2 == 0:
                var t := first.lerp(last, rng.randf())
                t += side * rng.randf_range(-1.55, 1.55)
                if not _near_junction(t, 1.0):
                    var dx := tangent * rng.randf_range(0.09, 0.22)
                    var dy := side * rng.randf_range(0.10, 0.28)
                    var plane_y := height + 0.052
                    _put_triangle(stones, _pos(t - dx, plane_y),
                        _pos(t + dy, plane_y), _pos(t + dx, plane_y))
    _mesh_from_triangles(shoulders, Color("#3e3830"), "Дорога / сырые земляные обочины", true, &"ps1_jitter_road", &"perf_roadside")
    _mesh_from_triangles(stones, Color("#544d43"), "Дорога / мокрый гравий и выбоины", true, &"ps1_jitter_road", &"perf_roadside")
    _mesh_from_triangles(weeds, Color("#3f4439"), "Обочина / пожухлая ноябрьская трава", false, &"ps1_jitter_foliage", &"perf_roadside")
    _mesh_from_triangles(dried, Color("#605444"), "Обочина / сухие стебли", false, &"ps1_jitter_foliage", &"perf_roadside")


func _register_road_junction(point: Vector2, radius: float) -> void:
    # Nearby manual line endpoints often duplicate a junction; one patch per
    # intersection prevents overlapping coplanar junction fans.
    for n in range(_junctions.size()):
        var old: Dictionary = _junctions[n]
        if point.distance_to(old["center"]) < 2.2:
            old["radius"] = maxf(float(old["radius"]), radius)
            _junctions[n] = old
            return
    _junctions.append({"center": point, "radius": radius})


func _detect_road_intersections() -> void:
    _junctions.clear()
    for i in range(manual_roads.size()):
        var one: Array = manual_roads[i]
        if one.size() < 3 or int(one[2]) < 0:
            continue
        var a: Vector2 = one[0]
        var b: Vector2 = one[1]
        var da := (b - a).normalized()
        for j in range(i + 1, manual_roads.size()):
            var two: Array = manual_roads[j]
            if two.size() < 3 or int(two[2]) < 0 or int(one[2]) == int(two[2]):
                continue
            var c: Vector2 = two[0]
            var d: Vector2 = two[1]
            var db := (d - c).normalized()
            var sine := absf(da.cross(db))
            if sine < 0.45:
                continue
            # Cheap segment AABB before Geometry2D's exact intersection.
            if maxf(a.x, b.x) + 2.1 < minf(c.x, d.x) or (
                    maxf(c.x, d.x) + 2.1 < minf(a.x, b.x)):
                continue
            if maxf(a.y, b.y) + 2.1 < minf(c.y, d.y) or (
                    maxf(c.y, d.y) + 2.1 < minf(a.y, b.y)):
                continue
            var junction: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
            if junction == null:
                # Imported segments may nearly touch at a T junction without
                # sharing mathematically identical endpoints.
                var best_distance := INF
                var best_point := Vector2.ZERO
                for end in [a, b]:
                    var near := Geometry2D.get_closest_point_to_segment(end, c, d)
                    var dist: float = end.distance_to(near)
                    if dist < best_distance:
                        best_distance = dist
                        best_point = (end + near) * 0.5
                for end in [c, d]:
                    var near := Geometry2D.get_closest_point_to_segment(end, a, b)
                    var dist: float = end.distance_to(near)
                    if dist < best_distance:
                        best_distance = dist
                        best_point = (end + near) * 0.5
                if best_distance > 1.3:
                    continue
                junction = best_point
            # At shallow angles, the crossing road strips occupy a wider area.
            var patch_radius := clampf(2.2 / maxf(sine, 0.70), 2.2, 3.2)
            _register_road_junction(junction, patch_radius)


func _build_road_intersections() -> void:
    # Deliberately NO junction mesh. The earlier 16-sided cap produced huge
    # discs across the road and over the vegetation. Road surfaces already
    # use separate depth layers, while wheel ruts stop before intersections.
    _junction_mesh_count = 0
    print("MANUAL_ROAD_JUNCTIONS_READY: total=", _junctions.size(),
        " cap_meshes=", _junction_mesh_count)


func _add_outline(points: PackedVector2Array, width: float, height: float, tint: Color, label: String) -> void:
    var ring: Array = []
    for p in points:
        ring.append([p.x, p.y])
    ring.append([points[0].x, points[0].y])
    _add_strip(ring, width, height, tint, label)

func _add_building(points: PackedVector2Array, category: String) -> void:
    var height := 5.0
    var roof_tint := Color("#554a49")
    match category:
        "house":
            height = 5.0
            roof_tint = Color("#614d47")
        "sauna":
            height = 3.1
            roof_tint = Color("#785548")
        "shed":
            height = 2.6
            roof_tint = Color("#555958")
    var verts := PackedVector3Array()
    for i in range(points.size()):
        var a: Vector2 = points[i]
        var b: Vector2 = points[(i + 1) % points.size()]
        if a.distance_squared_to(b) < 0.01:
            continue
        var alow := _pos(a, 0.11)
        var blow := _pos(b, 0.11)
        var atop := _pos(a, height)
        var btop := _pos(b, height)
        _put_triangle(verts, alow, blow, btop)
        _put_triangle(verts, alow, btop, atop)
    _mesh_from_triangles(verts, COLORS[category], category + "_walls")
    _add_area(points, height, roof_tint, category + "_roof")

func _add_car(point: Array, _feature: Dictionary) -> void:
    var p := Vector2(float(point[0]), float(point[1]))
    var box := BoxMesh.new()
    box.size = Vector3(2.0, 1.35, 4.0)
    var body := StaticBody3D.new()
    body.set_meta("impact_surface", &"metal")
    body.name = "Машина"
    body.position = _pos(p, 0.78)
    var visual := MeshInstance3D.new()
    visual.mesh = box
    visual.material_override = _mat(COLORS["car"])
    body.add_child(visual)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = box.size
    collider.shape = shape
    body.add_child(collider)
    add_child(body)

func _nearest_road(point: Vector2) -> float:
    var best := INF
    for segment in manual_roads:
        var close := Geometry2D.get_closest_point_to_segment(point, segment[0], segment[1])
        best = minf(best, point.distance_to(close))
    return best

func _near_building(point: Vector2, clearance: float) -> bool:
    for polygon in building_footprints:
        if Geometry2D.is_point_in_polygon(point, polygon):
            return true
        for i in range(polygon.size()):
            var closest := Geometry2D.get_closest_point_to_segment(point,
                polygon[i], polygon[(i + 1) % polygon.size()])
            if point.distance_to(closest) < clearance:
                return true
    return false

func _scatter_forest(points: PackedVector2Array) -> void:
    var min_p := Vector2(INF, INF)
    var max_p := Vector2(-INF, -INF)
    var twice_area := 0.0
    for i in range(points.size()):
        var p: Vector2 = points[i]
        min_p = min_p.min(p)
        max_p = max_p.max(p)
        var q: Vector2 = points[(i + 1) % points.size()]
        twice_area += p.x * q.y - q.x * p.y
    var area_m2 := absf(twice_area) * 0.5
    # Batching keeps large forest polygons viable on Web without thousands of nodes.
    var desired := mini(950, int(area_m2 / 145.0))
    var rng := RandomNumberGenerator.new()
    rng.seed = 20261118 + points.size() * 103 + int(absf(min_p.x) * 10.0)
    var count := 0
    for attempt in range(desired * 20):
        if count >= desired:
            break
        var p := Vector2(rng.randf_range(min_p.x, max_p.x), rng.randf_range(min_p.y, max_p.y))
        if not Geometry2D.is_point_in_polygon(p, points):
            continue
        if _nearest_road(p) < 13.0 or _near_building(p, 6.5):
            continue
        var cell := Vector2i((p / 4.0).floor())
        var nearby := false
        for x in range(cell.x - 1, cell.x + 2):
            for y in range(cell.y - 1, cell.y + 2):
                for neighbor: Vector2 in _forest_cells.get(Vector2i(x, y), []):
                    if p.distance_squared_to(neighbor) < 13.0:
                        nearby = true
        if nearby:
            continue
        if not _forest_cells.has(cell):
            _forest_cells[cell] = []
        _forest_cells[cell].append(p)
        _forest_sites.append(p)
        var scale := rng.randf_range(0.88, 1.42)
        var rotation := rng.randf_range(-PI, PI)
        var basis := Basis().rotated(Vector3.UP, rotation).scaled(Vector3.ONE * scale)
        forest_positions.append(Transform3D(basis, _pos(p, 0.0)))
        count += 1


func _forest_model(id: String) -> PackedScene:
    if not _forest_models.has(id):
        var path := FOREST_MODELS + id + ".glb"
        if ResourceLoader.exists(path):
            _forest_models[id] = load(path)
    return _forest_models.get(id) as PackedScene


func _queue_forest_asset(batches: Dictionary, id: String, pose: Transform3D) -> void:
    var cell := Vector2i((Vector2(pose.origin.x, pose.origin.z) / _forest_chunk_size).floor())
    if not batches.has(id):
        batches[id] = {}
    var cells: Dictionary = batches[id]
    if not cells.has(cell):
        cells[cell] = []
    cells[cell].append(pose)


func _render_forest_batches(batches: Dictionary) -> void:
    for id in batches:
        var packed := _forest_model(id)
        if packed == null:
            continue
        var template := packed.instantiate() as Node3D
        for part: MeshInstance3D in template.find_children("*", "MeshInstance3D", true, false):
            var mesh := part.mesh
            for surface in mesh.get_surface_count():
                var material := mesh.surface_get_material(surface) as BaseMaterial3D
                if material != null:
                    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
            for poses: Array in batches[id].values():
                var multi := MultiMesh.new()
                multi.transform_format = MultiMesh.TRANSFORM_3D
                multi.mesh = mesh
                multi.instance_count = poses.size()
                for i in poses.size():
                    multi.set_instance_transform(i, poses[i] * part.transform)
                var batch := MultiMeshInstance3D.new()
                batch.multimesh = multi
                batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                batch.add_to_group(&"ps1_jitter_foliage")
                batch.add_to_group(&"perf_forest_vegetation")
                add_child(batch)
        template.free()


func _place_forest_shrines() -> void:
    var anchors := [Vector2(-850, 420), Vector2(-660, 555),
        Vector2(-460, 420), Vector2(-625, 185)]
    var colors := [Color("#74e2be"), Color("#ca86ed"), Color("#e09f69"), Color("#86bdf1")]
    for i in anchors.size():
        var selected := Vector2.INF
        var distance := INF
        for point in _forest_sites:
            if _forest_floor.is_wet(point) or _forest_floor.is_on_trail(point):
                continue
            var spread := true
            for other in _shrine_sites:
                if point.distance_squared_to(other) < 85.0 ** 2:
                    spread = false
                    break
            var score := point.distance_squared_to(anchors[i])
            if spread and score < distance:
                distance = score
                selected = point
        if selected == Vector2.INF:
            continue
        if _spawn_shrine(selected, _forest_floor.sample_height(selected) + 0.03,
                "shrine_%d" % i, colors[i]):
            _shrine_sites.append(selected)


func _spawn_shrine(point: Vector2, height: float, id: String, color: Color) -> bool:
    var model := _forest_model(id + "_active")
    var ruined := _forest_model(id + "_broken")
    if model == null or ruined == null:
        return false
    var shrine := SHRINE.new()
    shrine.name = id
    shrine.position = _pos(point, height)
    add_child(shrine)
    shrine.install(model, ruined, color)
    var stage := _quest_shrines.size()
    shrine.can_take_damage = func() -> bool:
        var objective := shrine_objective()
        return objective.ready and objective.cleared == stage
    _quest_shrines.append(shrine)
    return true


func shrine_objective() -> Dictionary:
    var target: Variant = null
    var cleared := 0
    for shrine in _quest_shrines:
        if shrine.is_destroyed:
            cleared += 1
        elif target == null:
            target = shrine.global_position
    return {"cleared": cleared, "target": target, "ready": _quest_shrines.size() == 5}


func _build_trunk_collision() -> void:
    # One batched trimesh for the entire instanced forest (not thousands of
    # StaticBody nodes). Low-sided trunks approximate visible 40cm tree bases.
    var faces := PackedVector3Array()
    var sides := 5
    for transform in tree_trunks:
        var scale := transform.basis.get_scale().x
        var at := transform.origin
        var floor_y := at.y - 0.035
        var top_y := at.y + 5.5 * scale
        for side in range(sides):
            var angle0 := float(side) * TAU / float(sides)
            var angle1 := float(side + 1) * TAU / float(sides)
            var radius := 0.23 * scale
            var p0 := Vector3(at.x + cos(angle0) * radius, floor_y, at.z + sin(angle0) * radius)
            var p1 := Vector3(at.x + cos(angle1) * radius, floor_y, at.z + sin(angle1) * radius)
            _put_triangle(faces, p0, p1, Vector3(p1.x, top_y, p1.z))
            _put_triangle(faces, p0, Vector3(p1.x, top_y, p1.z), Vector3(p0.x, top_y, p0.z))
    if not faces.is_empty():
        var trunk_body := StaticBody3D.new()
        trunk_body.set_meta("impact_surface", &"wood")
        trunk_body.name = "CollisionForestTrunks"
        var collision := CollisionShape3D.new()
        var shape := ConcavePolygonShape3D.new()
        shape.set_faces(faces)
        shape.backface_collision = true
        collision.shape = shape
        trunk_body.add_child(collision)
        add_child(trunk_body)
    _tree_collision_total = tree_trunks.size()
    print("FOREST_COLLISION_READY: trunks=", _tree_collision_total)


func _build_forest_instances() -> void:
    var phase_start := Time.get_ticks_usec()
    _place_forest_shrines()
    var batches := {}
    var undergrowth := 0
    var ground_details := 0
    var snow: Array[Vector2] = []
    for i in forest_positions.size():
        var pose := forest_positions[i]
        var p := _forest_sites[i]
        var clearing := false
        for site in _shrine_sites:
            if p.distance_squared_to(site) < 5.5 ** 2:
                clearing = true
                break
        if clearing or _forest_floor.is_wet(p) or _forest_floor.is_on_trail(p):
            continue
        pose.origin.y = _forest_floor.sample_height(p) - 0.06
        var id := "birch" if i % 17 == 0 else ("pine_%d" % (i % 5))
        var height_scale := 1.85 if id != "birch" else 1.0
        var tree_pose := Transform3D(pose.basis.scaled_local(Vector3(1.0, height_scale, 1.0)), pose.origin)
        _queue_forest_asset(batches, id, tree_pose)
        tree_trunks.append(pose)
        if i % 4 == 0:
            var drift := p + Vector2.from_angle(float(i) * 2.13) * 2.2
            if _forest_floor.sample_height(drift) > 0.24 and not _forest_floor.is_wet(drift) \
                    and not _forest_floor.is_on_trail(drift):
                snow.append(drift)
        if i % 2 != 0:
            continue
        var detail := p + Vector2.from_angle(float(i) * 2.39996) * 1.8
        if _nearest_road(detail) < 13.0 or _near_building(detail, 6.5) or _forest_floor.is_wet(detail) \
                or _forest_floor.is_on_trail(detail):
            continue
        var kind := "ground" if i % 4 == 0 else "understory"
        _queue_forest_asset(batches, "%s_%d" % [kind, (i / 2) % 4],
            Transform3D(pose.basis, _pos(detail, _forest_floor.sample_height(detail) + 0.015)))
        ground_details += int(kind == "ground")
        undergrowth += int(kind == "understory")
        if kind == "understory" and i % 12 == 2:
            # Break the single-bush pattern without increasing tree density.
            var companion := detail + Vector2.from_angle(float(i) * 1.618) * 1.35
            if not _forest_floor._inside(companion, 2.0) or _nearest_road(companion) < 13.0 \
                    or _near_building(companion, 6.5) or _forest_floor.is_wet(companion) \
                    or _forest_floor.is_on_trail(companion):
                continue
            if _shrine_sites.any(func(site): return companion.distance_squared_to(site) < 5.5 ** 2):
                continue
            var basis := pose.basis.rotated(Vector3.UP, 1.7).scaled_local(Vector3.ONE * 0.78)
            _queue_forest_asset(batches, "understory_%d" % ((i / 2 + 1) % 4),
                Transform3D(basis, _pos(companion, _forest_floor.sample_height(companion) + 0.015)))
            undergrowth += 1
    _add_forest_ponds(batches)
    _forest_floor.add_snow(snow)
    phase_start = _profile_phase("forest_placement", phase_start)
    _render_forest_batches(batches)
    phase_start = _profile_phase("forest_model_load_and_batches", phase_start)
    _build_trunk_collision()
    _profile_phase("forest_trunk_collision", phase_start)
    print("MANUAL_FOREST_READY: trees=", tree_trunks.size(), " clearance=roads13/buildings6.5",
        " bushes=", undergrowth, " ground_details=", ground_details, " shrines=", _shrine_sites.size(), " snow=", snow.size())

func _add_forest_ponds(batches: Dictionary) -> void:
    var count := 0
    for pond: Dictionary in _forest_floor.ponds:
        var model := _forest_model("pond_water" if pond.radius.x > 8.0 else "bog_water")
        if model == null:
            continue
        var template := model.instantiate() as Node3D
        var water := template.find_child("WaterSurface", true, false) as MeshInstance3D
        if water != null:
            count += 1
            var material := water.mesh.surface_get_material(0) as BaseMaterial3D
            material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
            material.metallic = 0.0
            material.roughness = 0.68
            _forest_floor.add_water(pond, material)
            for i in 16:
                if (i + count) % 4 == 0:
                    continue
                var angle := TAU * i / 16.0
                var p: Vector2 = pond.center + Vector2.from_angle(angle) * pond.radius * 1.05
                var y: float = _forest_floor.sample_height(p)
                _queue_forest_asset(batches, "bog_reeds",
                    Transform3D(Basis(Vector3.UP, angle), _pos(p, maxf(y, pond.water - 0.12))))
        template.free()
    print("FOREST_WATER_READY: surfaces=", count)
