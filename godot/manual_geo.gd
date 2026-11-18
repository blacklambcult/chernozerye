extends Node3D
# CHERNOZERYE / manually surveyed 3D preview
# Source: user Geo Lab 2.0 survey (130 WGS84 objects), converted to UTM local metres.
# Visuals are blockout placeholders; outline shapes and positions are preserved.
const SOURCE := "res://manual_layout.json"
const COLORS := {
    "road": Color("#514b41"),
    "path": Color("#49493f"),
    "plot": Color("#333b32"),
    "forest": Color("#38483d"),
    "water": Color("#234253"),
    "object": Color("#9c9ca1"),
    "house": Color("#bb8b73"),
    "shed": Color("#937a62"),
    "sauna": Color("#bd7f6b"),
    "car": Color("#5585b0")
}
var object_count: int = 0
var forest_positions: Array[Transform3D] = []
var broad_canopies: Array[Transform3D] = []
var tree_trunks: Array[Transform3D] = []
var manual_roads: Array = []
var building_footprints: Array[PackedVector2Array] = []
var _roadside_tufts := 0
var _roadside_sections := 0
var _junctions: Array = []
var _junction_mesh_count := 0
var _base_buildings: Node3D

func _ready() -> void:
    visible = false
    call_deferred("_build_manual")

func _build_manual() -> void:
    await get_tree().process_frame
    if not FileAccess.file_exists(SOURCE):
        push_warning("GeoLab manual layout absent")
        return
    var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if not data is Dictionary:
        push_error("GeoLab manual layout invalid")
        return
    var features: Array = data.get("features", [])
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
            _add_strip(raw, 3.8 if category == "road" else 1.6, 0.11, COLORS[category], category)
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
                    _add_area(points, 0.058, COLORS[category], "Лес")
                    _scatter_forest(points)
                "water":
                    _add_area(points, 0.067, COLORS[category], "Водоём")
                "house", "sauna", "shed":
                    _add_building(points, category)
                "object":
                    _add_area(points, 0.12, COLORS[category], "Объект")
        object_count += 1
    # Intersection caps sit above the individual road surfaces: same-height
    # crossing quads previously z-fought and produced black triangles on WebGL.
    _build_road_intersections()
    _build_forest_instances()
    # Separate, reversible decorative layer; manual survey coordinates remain untouched.
    var art := Node3D.new()
    art.name = "VillageArt22"
    art.set_script(preload("res://manual_art.gd"))
    add_child(art)
    art.call("decorate", features)
    print("MANUAL_LAYOUT_READY: ", object_count)
    print("MANUAL_STREETSCAPE_READY: roadside_sections=", _roadside_sections,
        " roadside_grass=", _roadside_tufts,
        " junctions=", _junction_mesh_count)

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

func _mesh_from_triangles(vertices: PackedVector3Array, color: Color, label: String) -> void:
    if vertices.is_empty():
        return
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.material_override = _mat(color)
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
    _mesh_from_triangles(verts, tint, label)

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


func _add_strip(raw: Array, width: float, height: float, tint: Color, label: String) -> void:
    var points := _clean_road_points(_points(raw))
    if points.size() < 2:
        return
    var surface := PackedVector3Array()
    _append_joined_ribbon(surface, points, width, 0.0, height)
    _mesh_from_triangles(surface, tint, label)
    if label == "road":
        _add_road_wear(points, height + 0.035)
        _add_village_roadside(points, width, height)


func _add_road_wear(points: PackedVector2Array, height: float) -> void:
    # Tracks share a turn vertex with the road centre line; no independent
    # rectangular segments that split or overlap at sharp bends.
    var tracks := PackedVector3Array()
    var grass := PackedVector3Array()
    _append_joined_ribbon(tracks, points, 0.38, -1.12, height)
    _append_joined_ribbon(tracks, points, 0.38, 1.12, height)
    # Irregular broken vegetation in the middle, below the tracks' height.
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.22:
            continue
        var steps := maxi(1, int(ceil(length / 4.3)))
        for j in range(steps):
            if (i * 7 + j) % 4 == 0:
                continue
            var t0 := float(j) / float(steps)
            var t1 := float(j + 1) / float(steps)
            var segment := PackedVector2Array([a.lerp(b, t0), a.lerp(b, t1)])
            _append_joined_ribbon(grass, segment, 0.26, 0.0, height + 0.014)
    _mesh_from_triangles(tracks, Color("#3b362f"), "Дорога / непрерывные колеи")
    _mesh_from_triangles(grass, Color("#424a3b"), "Дорога / редкая трава между колеями")


func _add_village_roadside(points: PackedVector2Array, width: float, height: float) -> void:
    # Dirt shoulders, small stone chips and knee-high verge plants.
    # Geometry follows user-drawn GeoJSON roads, with no changed centre lines.
    # A modest batched budget keeps the Web Compatibility renderer responsive.
    var shoulders := PackedVector3Array()
    # Joined base apron sits 2.5 cm under the road and remains visible on both sides.
    _append_joined_ribbon(shoulders, points, width + 1.45, 0.0, height - 0.025)
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
                    if _near_building(center, 0.75):
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
                var dx := tangent * rng.randf_range(0.09, 0.22)
                var dy := side * rng.randf_range(0.10, 0.28)
                var plane_y := height + 0.052
                _put_triangle(stones, _pos(t - dx, plane_y),
                    _pos(t + dy, plane_y), _pos(t + dx, plane_y))
    _mesh_from_triangles(shoulders, Color("#4a4438"), "Дорога / неровные грунтовые обочины")
    _mesh_from_triangles(stones, Color("#655c4b"), "Дорога / гравий и выбоины")
    _mesh_from_triangles(weeds, Color("#404f37"), "Обочина / тёмная дикая трава")
    _mesh_from_triangles(dried, Color("#656044"), "Обочина / сухие стебли")


func _register_road_junction(point: Vector2, radius: float) -> void:
    # Nearby manual line endpoints often duplicate a junction; one patch per
    # intersection prevents overlapping coplanar junction fans.
    for n in range(_junctions.size()):
        var old: Dictionary = _junctions[n]
        if point.distance_to(old["center"]) < 6.5:
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
            if sine < 0.26:
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
            var patch_radius := clampf(3.0 / maxf(sine, 0.57), 3.25, 5.2)
            _register_road_junction(junction, patch_radius)


func _junction_fan(center: Vector2, radius: float, height: float,
        verts: PackedVector3Array, salt: int) -> void:
    var sides := 16
    for i in range(sides):
        var a0 := float(i) * TAU / float(sides)
        var a1 := float(i + 1) * TAU / float(sides)
        var r0 := radius * (0.965 + 0.035 * sin(float(i * 13 + salt)))
        var r1 := radius * (0.965 + 0.035 * sin(float((i + 1) * 13 + salt)))
        var p0 := center + Vector2(cos(a0), sin(a0)) * r0
        var p1 := center + Vector2(cos(a1), sin(a1)) * r1
        _put_triangle(verts, _pos(center, height),
            _pos(p0, height), _pos(p1, height))


func _build_road_intersections() -> void:
    _detect_road_intersections()
    if _junctions.is_empty():
        print("MANUAL_ROAD_JUNCTIONS_READY: total=0")
        return
    var outer := PackedVector3Array()
    var packed := PackedVector3Array()
    for index in range(_junctions.size()):
        var entry: Dictionary = _junctions[index]
        var point: Vector2 = entry["center"]
        var radius: float = entry["radius"]
        # Raise above road at 0.11, tracks at 0.145, grass at 0.159 and
        # gravel at 0.162. Avoid all coplanar crosses, but add no collider.
        _junction_fan(point, radius + 0.35, 0.182, outer, index)
        _junction_fan(point, radius, 0.193, packed, index)
    _mesh_from_triangles(outer, Color("#474235"), "Перекрёстки / грунтовые переходы")
    _mesh_from_triangles(packed, COLORS["road"], "Перекрёстки / единая поверхность")
    _junction_mesh_count = _junctions.size()
    print("MANUAL_ROAD_JUNCTIONS_READY: total=", _junction_mesh_count)


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
    var node := MeshInstance3D.new()
    node.name = "Машина"
    node.mesh = box
    node.position = _pos(p, 0.78)
    node.material_override = _mat(COLORS["car"])
    add_child(node)

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
    var desired := mini(950, int(area_m2 / 115.0))
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
        var scale := rng.randf_range(0.72, 1.05)
        var rotation := rng.randf_range(-PI, PI)
        var basis := Basis().rotated(Vector3.UP, rotation).scaled(Vector3.ONE * scale)
        if count % 4 == 0:
            broad_canopies.append(Transform3D(basis, _pos(p, 4.4 * scale)))
        else:
            forest_positions.append(Transform3D(basis, _pos(p, 5.0 * scale)))
        tree_trunks.append(Transform3D(basis, _pos(p, 1.65 * scale)))
        count += 1

func _instanced_tree(mesh: Mesh, transforms: Array[Transform3D], color: Color, label: String) -> void:
    if transforms.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = multi
    var tree_mat := _mat(color)
    tree_mat.specular = 0.0
    # Diffuse lighting restores the faceted PS1 look; unshaded green stood out against the dusk fog.
    # Keep specular reflections and cast shadows disabled to avoid web-rendering artifacts.
    node.material_override = tree_mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)

func _layer_transforms(source: Array[Transform3D], local_rise: float) -> Array[Transform3D]:
    var layers: Array[Transform3D] = []
    for t in source:
        # A basis-scaled offset keeps foliage aligned with tree size.
        layers.append(Transform3D(t.basis, t.origin + t.basis * Vector3(0.0, local_rise, 0.0)))
    return layers

func _build_forest_instances() -> void:
    # Three staggered bough layers read as old pines instead of a single giant cone.
    # All layers reuse the original surveyed forest point positions.
    var lowest := CylinderMesh.new()
    lowest.top_radius = 0.32
    lowest.bottom_radius = 2.0
    lowest.height = 3.5
    lowest.radial_segments = 6
    _instanced_tree(lowest, _layer_transforms(forest_positions, -1.4),
        Color("#24342f"), "Ели / нижние лапы")

    var middle := CylinderMesh.new()
    middle.top_radius = 0.22
    middle.bottom_radius = 1.55
    middle.height = 2.9
    middle.radial_segments = 6
    _instanced_tree(middle, _layer_transforms(forest_positions, 0.65),
        Color("#293b34"), "Ели / средние лапы")

    var top := CylinderMesh.new()
    top.top_radius = 0.0
    top.bottom_radius = 1.12
    top.height = 2.5
    top.radial_segments = 5
    _instanced_tree(top, _layer_transforms(forest_positions, 2.3),
        Color("#33463a"), "Ели / кроны")

    # Aspen canopy is irregular, compact, and visually distinct from conifers.
    var broad := SphereMesh.new()
    broad.radius = 1.75
    broad.height = 3.0
    broad.radial_segments = 6
    broad.rings = 3
    _instanced_tree(broad, broad_canopies, Color("#36463e"), "Осинник / кроны")
    var smaller := SphereMesh.new()
    smaller.radius = 1.1
    smaller.height = 2.1
    smaller.radial_segments = 5
    smaller.rings = 2
    _instanced_tree(smaller, _layer_transforms(broad_canopies, 1.3),
        Color("#3b4c40"), "Осинник / верхушки")
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.25
    trunk.bottom_radius = 0.40
    trunk.height = 3.3
    trunk.radial_segments = 5
    _instanced_tree(trunk, tree_trunks, Color("#3b3b34"), "Лес / стволы")
    print("MANUAL_FOREST_READY: trees=", tree_trunks.size(), " clearance=roads13/buildings6.5")
