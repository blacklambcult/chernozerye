extends Node3D
# CHERNOZERYE / manually surveyed 3D preview
# Source: user Geo Lab 2.0 survey (130 WGS84 objects), converted to UTM local metres.
# Visuals are blockout placeholders; outline shapes and positions are preserved.
const SOURCE := "res://manual_layout.json"
const COLORS := {
    "road": Color("#796e60"),
    "path": Color("#66645c"),
    "plot": Color("#333b32"),
    "forest": Color("#1c3228"),
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
    for f in features:
        if f is Dictionary and str(f.get("type", "")) == "road":
            var polyline := _points(f.get("points", []))
            for i in range(polyline.size() - 1):
                manual_roads.append([polyline[i], polyline[i + 1]])
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
            _add_strip(raw, 5.1 if category == "road" else 1.6, 0.11, COLORS[category], category)
        else:
            var points := _points(raw)
            if points.size() < 3:
                continue
            match category:
                "plot":
                    _add_outline(points, 0.24, 0.22, COLORS[category], "Участок")
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
    _build_forest_instances()
    # Separate, reversible decorative layer; manual survey coordinates remain untouched.
    var art := Node3D.new()
    art.name = "VillageArt22"
    art.set_script(preload("res://manual_art.gd"))
    add_child(art)
    art.call("decorate", features)
    print("MANUAL_LAYOUT_READY: ", object_count)

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

func _add_strip(raw: Array, width: float, height: float, tint: Color, label: String) -> void:
    var points := _points(raw)
    var verts := PackedVector3Array()
    for i in range(points.size() - 1):
        var a: Vector3 = _pos(points[i], height)
        var b: Vector3 = _pos(points[i + 1], height)
        var delta := b - a
        if delta.length_squared() < 0.01:
            continue
        var sideways := Vector3(-delta.z, 0, delta.x).normalized() * width * 0.5
        _put_triangle(verts, a-sideways, a+sideways, b+sideways)
        _put_triangle(verts, a-sideways, b+sideways, b-sideways)
    _mesh_from_triangles(verts, tint, label)

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
        if _nearest_road(p) < 7.0:
            continue
        var scale := rng.randf_range(0.67, 1.12)
        var rotation := rng.randf_range(-PI, PI)
        var basis := Basis().rotated(Vector3.UP, rotation).scaled(Vector3.ONE * scale)
        if count % 4 == 0:
            broad_canopies.append(Transform3D(basis, _pos(p, 5.7 * scale)))
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
    node.material_override = _mat(color)
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
    lowest.bottom_radius = 2.4
    lowest.height = 4.1
    lowest.radial_segments = 6
    _instanced_tree(lowest, _layer_transforms(forest_positions, -1.1),
        Color("#263d36"), "Ели / нижние лапы")

    var middle := CylinderMesh.new()
    middle.top_radius = 0.22
    middle.bottom_radius = 1.83
    middle.height = 3.4
    middle.radial_segments = 6
    _instanced_tree(middle, _layer_transforms(forest_positions, 1.1),
        Color("#2a4539"), "Ели / средние лапы")

    var top := CylinderMesh.new()
    top.top_radius = 0.0
    top.bottom_radius = 1.30
    top.height = 2.9
    top.radial_segments = 5
    _instanced_tree(top, _layer_transforms(forest_positions, 3.05),
        Color("#304a3c"), "Ели / кроны")

    # Aspen canopy is irregular, compact, and visually distinct from conifers.
    var broad := SphereMesh.new()
    broad.radius = 2.15
    broad.height = 3.5
    broad.radial_segments = 6
    broad.rings = 3
    _instanced_tree(broad, broad_canopies, Color("#3b5446"), "Осинник / кроны")
    var smaller := SphereMesh.new()
    smaller.radius = 1.45
    smaller.height = 2.7
    smaller.radial_segments = 5
    smaller.rings = 2
    _instanced_tree(smaller, _layer_transforms(broad_canopies, 2.1),
        Color("#435d49"), "Осинник / верхушки")
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.25
    trunk.bottom_radius = 0.40
    trunk.height = 3.3
    trunk.radial_segments = 5
    _instanced_tree(trunk, tree_trunks, Color("#3b3b34"), "Лес / стволы")
    print("MANUAL_FOREST_READY: trees=", tree_trunks.size())
