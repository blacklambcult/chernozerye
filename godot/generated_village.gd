extends Node3D
## Batches Studio models across the surveyed plots without changing the map data.

const MODEL_DIR := "res://generated_village/"
const SECTOR_CENTER := Vector2(-660.0, 390.0)
const SECTOR_HALF := 340.0
const BASE_SIZES := {"house": Vector2(4.8, 4.2), "sauna": Vector2(3.4, 3.0), "shed": Vector2(3.8, 2.8)}
var _plots: Array[Dictionary] = []
var _models: Dictionary = {}
var _transforms: Dictionary = {}
var _counts := [0, 0, 0, 0]
var _placed := 0
var _fences := 0
var _cultist_point := Vector2.ZERO


func prepare(features: Array) -> void:
    var houses: Array[Vector2] = []
    for feature in features:
        if feature.get("type") == "house":
            houses.append(_center(_points(feature)))
    for feature in features:
        if feature.get("type") != "plot":
            continue
        var polygon := _points(feature)
        if polygon.size() < 3:
            continue
        var center := _center(polygon)
        var occupied := false
        for house in houses:
            if Geometry2D.is_point_in_polygon(house, polygon):
                occupied = true
                break
        _plots.append({"polygon": polygon, "center": center, "occupied": occupied,
            "key": str(feature.get("id", str(center))), "profile": 0})

    var eligible: Array[Dictionary] = []
    var cultist: Dictionary = {}
    for plot in _plots:
        if not plot.occupied:
            continue
        var point: Vector2 = plot.center
        var delta := (point - SECTOR_CENTER).abs()
        if delta.x <= SECTOR_HALF and delta.y <= SECTOR_HALF:
            if cultist.is_empty() or point.x > cultist.center.x:
                cultist = plot
        eligible.append(plot)
    if not cultist.is_empty():
        cultist.profile = 6
        _cultist_point = cultist.center
        eligible.erase(cultist)
    eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return String(a.key).sha256_text() < String(b.key).sha256_text()
    )
    for i in eligible.size():
        if i < 2:
            eligible[i].profile = 5
        elif i < 9:
            eligible[i].profile = 4
    for plot in _plots:
        _counts[maxi(0, int(plot.profile) - 3)] += 1


func _points(feature: Dictionary) -> PackedVector2Array:
    var polygon := PackedVector2Array()
    for point in feature.get("points", []):
        polygon.append(Vector2(float(point[0]), float(point[1])))
    return polygon


func _center(points: PackedVector2Array) -> Vector2:
    var center := Vector2.ZERO
    for point in points:
        center += point
    return center / maxf(1.0, points.size())


func profile_at(point: Vector2) -> int:
    for plot in _plots:
        if Geometry2D.is_point_in_polygon(point, plot.polygon):
            return plot.profile
    return 0


func plot_profile(points: PackedVector2Array) -> int:
    var center := _center(points)
    for plot in _plots:
        if center.is_equal_approx(plot.center):
            return plot.profile
    return 0


func add_building(points: PackedVector2Array, category: String, front: int,
        floors: int, ordinal: int) -> PackedVector2Array:
    var center := _center(points)
    var a := points[front]
    var b := points[(front + 1) % points.size()]
    var edge := (b - a).normalized()
    var outward := Vector2(edge.y, -edge.x)
    if outward.dot((a + b) * 0.5 - center) < 0.0:
        outward *= -1.0
    var right := Vector2(-outward.y, outward.x)
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for point in points:
        var local := Vector2(point.dot(right), point.dot(outward))
        lo = lo.min(local)
        hi = hi.max(local)
    var midpoint := (lo + hi) * 0.5
    center = right * midpoint.x + outward * midpoint.y
    var size: Vector2 = BASE_SIZES[category]
    var profile := profile_at(_center(points))
    if profile == 0:
        profile = ordinal % 4
    var prefix: String = {"house": "izba%d" % floors, "sauna": "banya", "shed": "saray"}[category]
    var basis := Basis(Vector3.UP, atan2(outward.x, -outward.y))
    _queue(prefix + "_" + str(profile), Transform3D(
        basis, Vector3(center.x, 0.025, -center.y)))
    if category == "house" and profile >= 4:
        var light := OmniLight3D.new()
        var anchor := center + outward * (size.y * 0.5 + 0.6)
        light.position = Vector3(anchor.x, 1.9, -anchor.y)
        light.light_color = Color("#ffb46b") if profile == 4 else Color("#63ebaf")
        light.light_energy = 0.32
        light.omni_range = 5.0
        add_child(light)
    _placed += 1
    var across := right * size.x * 0.5
    var depth := outward * size.y * 0.5
    return PackedVector2Array([
        center - across - depth, center + across - depth,
        center + across + depth, center - across + depth,
    ])


func add_fence(a: Vector2, b: Vector2, profile: int, material_index: int) -> void:
    var heading := b - a
    var center := (a + b) * 0.5
    var style := "cultist" if profile == 6 else ("normal" if profile == 4 else "ruined")
    var basis := Basis(Vector3.UP, atan2(heading.y, heading.x))
    _queue("fence_%s_%d" % [style, material_index], Transform3D(
        basis.scaled_local(Vector3(heading.length() / 1.65, 1.0, 1.0)),
        Vector3(center.x, 0.055, -center.y)))
    _fences += 1


func _queue(id: String, pose: Transform3D) -> void:
    if not _transforms.has(id):
        _transforms[id] = {}
    var cell := Vector2i(floori(pose.origin.x / 128.0), floori(pose.origin.z / 128.0))
    var cells: Dictionary = _transforms[id]
    if not cells.has(cell):
        cells[cell] = []
    cells[cell].append(pose)


func finish() -> void:
    var missing := 0
    for id in _transforms:
        var packed := load(MODEL_DIR + id + ".glb") as PackedScene
        if packed == null:
            missing += 1
            continue
        var template := packed.instantiate() as Node3D
        var cells: Dictionary = _transforms[id]
        for part in template.find_children("*", "MeshInstance3D", true, false):
            var relative: Transform3D = part.transform
            var parent: Node3D = part.get_parent()
            while parent != template:
                relative = parent.transform * relative
                parent = parent.get_parent()
            var mesh := part.mesh as ArrayMesh
            for i in mesh.get_surface_count():
                var material := mesh.surface_get_material(i) as BaseMaterial3D
                if material != null:
                    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
            for poses: Array in cells.values():
                var multi := MultiMesh.new()
                multi.transform_format = MultiMesh.TRANSFORM_3D
                multi.mesh = mesh
                multi.instance_count = poses.size()
                for i in poses.size():
                    multi.set_instance_transform(i, poses[i] * relative)
                var batch := MultiMeshInstance3D.new()
                batch.name = id
                batch.multimesh = multi
                batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                add_child(batch, true)
        template.free()
    _transforms.clear()
    print("STUDIO_VILLAGE_READY: buildings=", _placed, " fence_sections=", _fences,
        " abandoned=", _counts[0], " warm=", _counts[1], " eerie=", _counts[2],
        " cultist=", _counts[3], " cultist_center=", _cultist_point, " missing_models=", missing)
