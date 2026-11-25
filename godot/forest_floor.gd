extends Node3D
## The forest floor overlays the level's flat base. Wet hollows are carved into
## raised banks, so the existing world floor can remain as a fallback.
const STEP := 4.0
const INDEX_SIZE := 48.0
var ponds: Array[Dictionary] = []
var _trails: Array[PackedVector2Array] = []
var _heights: Dictionary = {}
var _forest: Array[Dictionary] = []
var _forest_index: Dictionary = {}
var _excluded: Dictionary = {}
var _roads: Dictionary = {}
var _noise := FastNoiseLite.new()


func _area(polygon: PackedVector2Array) -> Dictionary:
    var bounds := Rect2(polygon[0], Vector2.ZERO)
    for point in polygon:
        bounds = bounds.expand(point)
    return {"bounds": bounds, "polygon": polygon}


func _index(index: Dictionary, bounds: Rect2, value: Variant) -> void:
    var lo := Vector2i((bounds.position / INDEX_SIZE).floor())
    var hi := Vector2i((bounds.end / INDEX_SIZE).floor())
    for x in range(lo.x, hi.x + 1):
        for y in range(lo.y, hi.y + 1):
            var cell := Vector2i(x, y)
            if not index.has(cell):
                index[cell] = []
            index[cell].append(value)


func prepare(features: Array, roads: Array, sites: Array[Vector2]) -> void:
    for road in roads:
        var a: Vector2 = road[0]
        var b: Vector2 = road[1]
        var bounds := Rect2(a.min(b), (a - b).abs())
        _index(_roads, bounds.grow(26.0), [a, b, bounds])
    _noise.seed = 112005
    _noise.frequency = 0.029
    for feature in features:
        var kind: String = feature.get("type", "")
        if kind not in ["forest", "water", "plot", "house", "sauna", "shed"]:
            continue
        var polygon := PackedVector2Array()
        for point in feature.get("points", []):
            polygon.append(Vector2(point[0], point[1]))
        if polygon.size() < 3:
            continue
        var area := _area(polygon)
        if kind == "forest":
            _forest.append(area)
            _index(_forest_index, area.bounds, area)
        else:
            _index(_excluded, area.bounds.grow(24.0), area.bounds)
    for anchor in [Vector2(-850, 480), Vector2(-555, 500), Vector2(-450, 225)]:
        var best := Vector2.INF
        var distance := INF
        for site in sites:
            if site.distance_squared_to(anchor) >= distance or not _inside(site, 19.0):
                continue
            var separated := true
            for pond in ponds:
                if site.distance_to(pond.center) < 75.0:
                    separated = false
                    break
            if separated:
                best = site
                distance = site.distance_squared_to(anchor)
        if best != Vector2.INF:
            ponds.append({"center": best, "radius": Vector2(10.5, 7.0) if ponds.size() == 1
                else Vector2(6.3, 4.6), "water": 0.94 if ponds.size() == 1 else 0.72})

    for pond in ponds:
        for direction in 12:
            var axis := Vector2.from_angle(TAU * direction / 12.0)
            var side := Vector2(-axis.y, axis.x)
            var trail := PackedVector2Array()
            for step in 16:
                var distance := float(step) * 1.1
                var point: Vector2 = pond.center + axis * pond.radius * 1.32 \
                    + axis * distance + side * sin(distance * 0.19) * 1.9
                if not _inside(point, 6.0) or is_wet(point):
                    break
                trail.append(point)
            if trail.size() >= 11:
                _trails.append(trail)
                break


func benchmark_view() -> Transform3D:
    if _trails.is_empty():
        return Transform3D.IDENTITY
    var trail := _trails[mini(1, _trails.size() - 1)]
    var step := trail.size() / 2
    var point := trail[step]
    var heading := trail[step + 1] - trail[step - 1]
    var yaw := atan2(-heading.x, heading.y)
    return Transform3D(Basis(Vector3.UP, yaw),
        Vector3(point.x, sample_height(point) + 0.22, -point.y))


func is_on_trail(point: Vector2) -> bool:
    for trail in _trails:
        if point.distance_squared_to(trail[0]) > 21.0 ** 2:
            continue
        for i in range(trail.size() - 1):
            if point.distance_to(Geometry2D.get_closest_point_to_segment(
                    point, trail[i], trail[i + 1])) < 0.85:
                return true
    return false


func _build_trails() -> void:
    if _trails.is_empty():
        return
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for trail in _trails:
        for i in range(trail.size() - 1):
            var a := trail[i]
            var b := trail[i + 1]
            var side := (b - a).normalized().orthogonal()
            var width := 0.51 + 0.11 * sin(i * 0.78)
            for point in [a - side * width, a + side * width, b + side * width,
                    a - side * width, b + side * width, b - side * width]:
                surface.set_uv(point * 0.42)
                surface.add_vertex(Vector3(point.x, sample_height(point) + 0.055, -point.y))
    surface.generate_normals()
    var material := StandardMaterial3D.new()
    material.albedo_color = Color("#6b563d")
    material.albedo_texture = _litter_texture()
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    _mesh(surface.commit(), material, false)


func _inside(point: Vector2, clearance: float) -> bool:
    var cell := Vector2i((point / INDEX_SIZE).floor())
    var in_forest := false
    for area: Dictionary in _forest_index.get(cell, []):
        if not area.bounds.has_point(point) or not Geometry2D.is_point_in_polygon(point, area.polygon):
            continue
        in_forest = true
        if clearance > 0.0:
            var ring: PackedVector2Array = area.polygon
            for i in ring.size():
                if point.distance_to(Geometry2D.get_closest_point_to_segment(
                        point, ring[i], ring[(i + 1) % ring.size()])) < clearance:
                    in_forest = false
                    break
        if in_forest:
            break
    if not in_forest:
        return false
    for bounds: Rect2 in _excluded.get(cell, []):
        if bounds.grow(clearance + 5.0).has_point(point):
            return false
    for road in _roads.get(cell, []):
        var a: Vector2 = road[0]
        var b: Vector2 = road[1]
        var gap := clearance + 6.5
        if road[2].grow(gap).has_point(point) and \
                point.distance_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < gap:
            return false
    return true


func pond_distance(point: Vector2, pond: Dictionary) -> float:
    var offset: Vector2 = (point - pond.center) / pond.radius
    var angle := offset.angle()
    return offset.length() / (1.0 + 0.09 * sin(angle * 3.0) + 0.06 * cos(angle * 5.0))


func is_wet(point: Vector2) -> bool:
    for pond in ponds:
        if pond_distance(point, pond) < 1.12:
            return true
    return false


func _grid_height(cell: Vector2i) -> float:
    if _heights.has(cell):
        return _heights[cell]
    var point := Vector2(cell) * STEP
    var height := 0.0
    if _inside(point, STEP):
        var roll := _noise.get_noise_2d(point.x, point.y)
        var detail := _noise.get_noise_2d(point.y * 2.3, point.x * 2.3)
        height = maxf(0.08, 0.8 + roll * 1.65 + detail * 0.34)
        if _inside(point, STEP * 2.0):
            height += 0.52
        for pond in ponds:
            var radius := pond_distance(point, pond)
            if radius < 2.0:
                var basin: float = lerpf(0.13, pond.water + 0.42, smoothstep(0.40, 1.12, radius))
                height = lerpf(height, basin, 1.0 - smoothstep(1.18, 2.0, radius))
    _heights[cell] = height
    return height


func sample_height(point: Vector2) -> float:
    # Interpolate the same triangles used by the visual mesh and the collider.
    var grid := point / STEP
    var cell := Vector2i(grid.floor())
    var f := grid - Vector2(cell)
    var a := _grid_height(cell)
    var d := _grid_height(cell + Vector2i.ONE)
    if f.x >= f.y:
        var b := _grid_height(cell + Vector2i.RIGHT)
        return a * (1.0 - f.x) + b * (f.x - f.y) + d * f.y
    var c := _grid_height(cell + Vector2i.DOWN)
    return a * (1.0 - f.y) + c * (f.y - f.x) + d * f.x


func _ground_color(point: Vector2, height: float) -> Color:
    var noise := _noise.get_noise_2d(point.x * 3.0, point.y * 3.0)
    var soil := Color("#564731").lerp(Color("#6a6b43"), clampf(noise + 0.45, 0.0, 1.0))
    if height < 0.01:
        soil = Color("#34382b")
    for pond in ponds:
        if pond_distance(point, pond) < 1.34:
            return soil.lerp(Color("#394137"), 0.64)
    return soil


func build() -> void:
    var cells := {}
    for area in _forest:
        var bounds: Rect2 = area.bounds
        var lo := Vector2i((bounds.position / STEP).floor())
        var hi := Vector2i((bounds.end / STEP).ceil())
        for x in range(lo.x, hi.x):
            for y in range(lo.y, hi.y):
                cells[Vector2i(x, y)] = true
    var chunks := {}
    # Adjacent triangles share grid vertices and use the same soil color.
    var colors: Dictionary = {}
    var offsets := [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]
    for cell: Vector2i in cells:
        var heights := [_grid_height(cell), _grid_height(cell + Vector2i.RIGHT),
            _grid_height(cell + Vector2i.DOWN), _grid_height(cell + Vector2i.ONE)]
        if heights.max() <= 0.0:
            continue
        var chunk := Vector2i((Vector2(cell) / 24.0).floor())
        if not chunks.has(chunk):
            var surface := SurfaceTool.new()
            surface.begin(Mesh.PRIMITIVE_TRIANGLES)
            chunks[chunk] = surface
        var surface: SurfaceTool = chunks[chunk]
        for i in [0, 3, 1, 0, 2, 3]:
            var vertex: Vector2i = cell + offsets[i]
            var point := Vector2(vertex) * STEP
            if not colors.has(vertex):
                colors[vertex] = _ground_color(point, heights[i])
            surface.set_color(colors[vertex])
            surface.set_uv(point * 0.42)
            surface.add_vertex(Vector3(point.x, maxf(0.018, heights[i]), -point.y))
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    material.metallic_specular = 0.0
    material.albedo_texture = _litter_texture()
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
    for surface: SurfaceTool in chunks.values():
        surface.generate_normals()
        _mesh(surface.commit(), material, true)
    _build_trails()
    print("FOREST_TERRAIN_READY: chunks=", chunks.size(), " ponds=", ponds.size(), " trails=", _trails.size())


func _litter_texture() -> ImageTexture:
    var rng := RandomNumberGenerator.new()
    rng.seed = 200511
    var image := Image.create(32, 32, false, Image.FORMAT_RGB8)
    for y in 32:
        for x in 32:
            var value := rng.randf_range(0.65, 1.0)
            image.set_pixel(x, y, Color(value, value * 0.98, value * 0.92))
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)


func _mesh(mesh: ArrayMesh, material: Material, solid: bool) -> void:
    var visual := MeshInstance3D.new()
    visual.mesh = mesh
    visual.material_override = material
    visual.add_to_group(&"ps1_jitter_stable")
    visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(visual)
    if solid:
        visual.create_trimesh_collision()
        visual.get_child(0).set_meta("impact_surface", &"soil")


func add_water(pond: Dictionary, material: Material) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in 32:
        for j in [-1, i + 1, i]:
            var theta := TAU * float(j) / 32.0
            var radius := 1.0 + 0.09 * sin(theta * 3.0) + 0.06 * cos(theta * 5.0)
            var point: Vector2 = pond.center
            if j >= 0:
                point += Vector2.from_angle(theta) * pond.radius * radius
            surface.set_uv(point * 0.28)
            surface.add_vertex(Vector3(point.x, pond.water, -point.y))
    surface.generate_normals()
    _mesh(surface.commit(), material, false)


func add_snow(points: Array[Vector2]) -> void:
    var surface := SurfaceTool.new()
    surface.begin(Mesh.PRIMITIVE_TRIANGLES)
    for index in points.size():
        var center := points[index]
        var radius := 0.48 + float(index % 13) * 0.12
        for i in 8:
            for j in [-1, i, i + 1]:
                var point := center
                if j >= 0:
                    var angle := TAU * float(j) / 8.0
                    point += Vector2.from_angle(angle) * radius * (0.78 + 0.22 * sin(angle * 3.0 + index))
                var mounding := 0.10 if j == -1 else 0.026
                surface.set_color(Color("#aab8bd") if j == -1 else Color("#77858a"))
                surface.add_vertex(Vector3(point.x, sample_height(point) + mounding, -point.y))
    if points.is_empty():
        return
    surface.generate_normals()
    var material := StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.roughness = 1.0
    _mesh(surface.commit(), material, false)
