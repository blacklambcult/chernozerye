extends Node3D
## Batches Studio models across the surveyed plots without changing the map data.

const MODEL_DIR := "res://generated_village/"
const DEFAULT_CHUNK_SIZE := 128.0
const TEST_FENCE_CHUNK_SIZE := 96.0
const SECTOR_CENTER := Vector2(-660.0, 390.0)
const SECTOR_HALF := 340.0
const BASE_SIZES := {"house": Vector2(4.8, 4.2), "sauna": Vector2(3.4, 3.0), "shed": Vector2(3.8, 2.8)}
var _fence_chunk_size := DEFAULT_CHUNK_SIZE
var _building_chunk_size := DEFAULT_CHUNK_SIZE
var _plots: Array[Dictionary] = []
var _models: Dictionary = {}
var _transforms: Dictionary = {}
var _model_bounds: Dictionary = {}
var _relocated := 0
var _tight_sites := 0
var _reduced := 0
var _scale_sum := 0.0
var _counts := [0, 0, 0, 0]
var _placed := 0
var _fences := 0
var _cultist_point := Vector2.ZERO


func prepare(features: Array) -> void:
    _building_chunk_size = 96.0 if "--world-chunks-96" in OS.get_cmdline_user_args() else DEFAULT_CHUNK_SIZE
    if OS.has_feature("web") and JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('fence_chunks') === '96'", true
    ) == true:
        _fence_chunk_size = TEST_FENCE_CHUNK_SIZE
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
        floors: int, ordinal: int, fits: Callable = Callable(), feature_id := "") -> Dictionary:
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
    var id := prefix + "_" + str(profile)
    var bounds := _bounds_for_model(id, size)
    var desired_scale := 1.08 + float(posmod(hash(feature_id), 101)) * 0.0014
    var scale_factor := 1.0 if not fits.is_valid() else desired_scale
    var envelope := PackedVector2Array()
    var reserved := PackedVector2Array()
    if fits.is_valid():
        var found := false
        for shrink in [1.0, 0.94, 0.86, 0.76, 0.65, 0.52]:
            scale_factor = desired_scale * shrink
            for radius in [0.0, 0.75, 1.5, 2.5, 4.0, 5.5, 7.0]:
                for direction in (1 if radius == 0.0 else 16):
                    var candidate: Vector2 = center + Vector2.from_angle(TAU * direction / 16.0) * radius
                    envelope = _rectangle(candidate, right, outward, scale_factor, bounds)
                    var clearance := bounds.grow(0.22 / scale_factor)
                    if category == "house":
                        clearance.size.y += 1.4 / scale_factor
                    reserved = _rectangle(candidate, right, outward, scale_factor, clearance)
                    if fits.call(reserved):
                        center = candidate
                        _relocated += int(radius > 0.0)
                        _reduced += int(shrink < 1.0)
                        found = true
                        break
                if found:
                    break
            if found:
                break
        if not found:
            _tight_sites += 1
            return {}
    _queue(id, Transform3D(basis.scaled(Vector3.ONE * scale_factor),
        Vector3(center.x, 0.0, -center.y)))
    if category == "house" and profile >= 4:
        var light := OmniLight3D.new()
        var anchor := center + outward * (size.y * scale_factor * 0.5 + 0.6)
        light.position = Vector3(anchor.x, 1.9, -anchor.y)
        light.light_color = Color("#ffb46b") if profile == 4 else Color("#63ebaf")
        light.light_energy = 0.32
        light.omni_range = 5.0
        add_child(light)
    _placed += 1
    _scale_sum += scale_factor
    var foundation := _rectangle(center, right, outward, scale_factor, Rect2(-size * 0.5, size))
    return {"foundation": foundation, "envelope": envelope, "reserved": reserved, "scale": scale_factor,
        "door": center + outward * size.y * scale_factor * 0.5,
        "front": center + outward * bounds.end.y * scale_factor, "outward": outward}


func _rectangle(center: Vector2, right: Vector2, outward: Vector2,
        scale_factor: float, rect: Rect2) -> PackedVector2Array:
    var result := PackedVector2Array()
    for point in [rect.position, Vector2(rect.end.x, rect.position.y),
            rect.end, Vector2(rect.position.x, rect.end.y)]:
        result.append(center + (right * point.x + outward * point.y) * scale_factor)
    return result


func _bounds_for_model(id: String, size: Vector2) -> Rect2:
    if _model_bounds.has(id):
        return _model_bounds[id]
    var result := Rect2(-size * 0.5, size)
    if ResourceLoader.exists(MODEL_DIR + id + ".glb"):
        var packed := load(MODEL_DIR + id + ".glb") as PackedScene
        var template := packed.instantiate() as Node3D
        # Studio's bake stores all parts directly under the model root.
        for part: MeshInstance3D in template.find_children("*", "MeshInstance3D", true, false):
            var bounds: AABB = part.transform * part.get_aabb()
            result = result.merge(Rect2(Vector2(bounds.position.x, bounds.position.z),
                Vector2(bounds.size.x, bounds.size.z)))
        template.free()
    _model_bounds[id] = result
    return result


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
    var size := _fence_chunk_size if id.begins_with("fence_") else _building_chunk_size
    var cell := Vector2i(floori(pose.origin.x / size), floori(pose.origin.z / size))
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
        var render_group := &"perf_fences" if id.begins_with("fence_") else &"perf_buildings"
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
                    # Godot's glTF import does not enable albedo vertex colors for these batches.
                    if (mesh.surface_get_format(i) & Mesh.ARRAY_FORMAT_COLOR) != 0:
                        material.vertex_color_use_as_albedo = true
            for poses: Array in cells.values():
                var multi := MultiMesh.new()
                multi.transform_format = MultiMesh.TRANSFORM_3D
                multi.mesh = mesh
                multi.instance_count = poses.size()
                for i in poses.size():
                    multi.set_instance_transform(i, poses[i] * relative)
                var batch := MultiMeshInstance3D.new()
                batch.name = id
                batch.add_to_group(render_group)
                if render_group == &"perf_fences":
                    batch.lod_bias = 0.6
                batch.multimesh = multi
                batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
                add_child(batch, true)
        template.free()
    _transforms.clear()
    print("STUDIO_CLEARANCE_READY: relocated=", _relocated, " no_safe_fit=", _tight_sites,
        " reduced=", _reduced, " average_scale=", _scale_sum / maxf(_placed, 1.0))
    print("STUDIO_VILLAGE_READY: buildings=", _placed, " fence_sections=", _fences,
        " abandoned=", _counts[0], " warm=", _counts[1], " eerie=", _counts[2],
        " cultist=", _counts[3], " cultist_center=", _cultist_point, " missing_models=", missing)
