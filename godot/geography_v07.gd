extends Node3D
# V0.7 — provisional low-poly geographical blockout.
# Georeferenced OSM roads are retained in world.gd.
# Settlement/forest/river outlines below are artist-created approximations
# informed by the user's own annotated references, NOT measured cadastral data.
# One Godot unit still equals one meter.

const SOURCE := "res://world_data.json"
const MAP_HALF := 995.0
const HOUSE_LIMIT := 900
const TREE_LIMIT := 7800

var rng := RandomNumberGenerator.new()
var roads: Array = []
var house_positions: Array[Vector2] = []
var settlements: Array = []
var meadow := PackedVector2Array([
    Vector2(-480, -410), Vector2(-410, -110), Vector2(-160, -95),
    Vector2(65, -170), Vector2(130, -270), Vector2(50, -390),
    Vector2(-160, -480)
])
var lake_center := Vector2(730, -760)
var river_path := PackedVector2Array([
    Vector2(1050, 235), Vector2(935, 205), Vector2(800, 200),
    Vector2(670, 145), Vector2(540, 80), Vector2(465, 20),
    Vector2(450, -90), Vector2(515, -185), Vector2(640, -235),
    Vector2(745, -310), Vector2(755, -420), Vector2(680, -520),
    Vector2(795, -630), Vector2(770, -730)
])

func _ready() -> void:
    rng.seed = 20261117
    settlements = [
        PackedVector2Array([
            Vector2(-945, 140), Vector2(-925, 670), Vector2(-520, 610),
            Vector2(-465, 405), Vector2(-490, 285), Vector2(-790, 155)
        ]),
        PackedVector2Array([
            Vector2(-510, 255), Vector2(-405, 390), Vector2(-65, 325),
            Vector2(40, 190), Vector2(-70, 125), Vector2(-390, 175)
        ]),
        PackedVector2Array([
            Vector2(-60, 55), Vector2(90, 55), Vector2(350, 120),
            Vector2(485, 300), Vector2(335, 375), Vector2(55, 345)
        ]),
        PackedVector2Array([
            Vector2(395, 240), Vector2(555, 390), Vector2(795, 550),
            Vector2(880, 535), Vector2(905, 425), Vector2(730, 280)
        ])
    ]

    var data := JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if data is Dictionary:
        for feature in data.get("features", []):
            if feature is Dictionary and feature.get("type", "") == "road":
                var t: String = str(feature.get("tags", {}).get("highway", ""))
                if t in ["residential", "unclassified", "service"]:
                    roads.append(feature.get("points", []))

    _add_street_details()
    _draw_meadow()
    _draw_river()
    _draw_lake()
    _draw_houses()
    _draw_forests()

func _mat(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    return mat

func _is_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
    return Geometry2D.is_point_in_polygon(p, poly)

func _is_housing(p: Vector2) -> bool:
    for zone in settlements:
        if _is_in_poly(p, zone):
            return true
    return false

func _is_water(p: Vector2) -> bool:
    if p.distance_to(lake_center) < 150.0:
        return true
    for i in range(river_path.size() - 1):
        if p.distance_to(Geometry2D.get_closest_point_to_segment(p, river_path[i], river_path[i + 1])) < 21.0:
            return true
    return false

func _close_to_road(p: Vector2, clearance: float) -> bool:
    for pts in roads:
        for i in range(pts.size() - 1):
            var a := Vector2(float(pts[i][0]), float(pts[i][1]))
            var b := Vector2(float(pts[i + 1][0]), float(pts[i + 1][1]))
            if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < clearance:
                return true
    return false

func _draw_flat_polygon(coords: PackedVector2Array, tint: Color, height: float) -> void:
    var indices := Geometry2D.triangulate_polygon(coords)
    if indices.is_empty():
        return
    var vertices := PackedVector3Array()
    for idx in indices:
        var p := coords[idx]
        vertices.append(Vector3(p.x, height, -p.y))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _mat(tint)
    add_child(node)

func _draw_strip(path: PackedVector2Array, width: float, tint: Color, height: float) -> void:
    var vertices := PackedVector3Array()
    for i in range(path.size() - 1):
        var a := path[i]
        var b := path[i + 1]
        if a.distance_to(b) < 0.01:
            continue
        var normal := Vector2(-(b.y - a.y), b.x - a.x).normalized() * width * 0.5
        var p0 := Vector3(a.x - normal.x, height, -(a.y - normal.y))
        var p1 := Vector3(a.x + normal.x, height, -(a.y + normal.y))
        var p2 := Vector3(b.x + normal.x, height, -(b.y + normal.y))
        var p3 := Vector3(b.x - normal.x, height, -(b.y - normal.y))
        vertices.append_array(PackedVector3Array([p0, p1, p2, p0, p2, p3]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var node := MeshInstance3D.new()
    node.mesh = mesh
    node.material_override = _mat(tint)
    add_child(node)

func _draw_meadow() -> void:
    _draw_flat_polygon(meadow, Color("#667451"), 0.018)

func _draw_river() -> void:
    _draw_strip(river_path, 32.0, Color("#273f46"), 0.045)

func _draw_lake() -> void:
    var edge := PackedVector2Array()
    for i in range(40):
        var theta := float(i) * TAU / 40.0
        var ripple := 1.0 + 0.08 * sin(theta * 5.0)
        edge.append(lake_center + Vector2(cos(theta) * 125.0, sin(theta) * 92.0) * ripple)
    _draw_flat_polygon(edge, Color("#233b42"), 0.052)

func _add_street_details() -> void:
    # Supplementary streets approximated from the user's marked-up road network.
    # Do not treat these as surveyed geometries.
    var extras: Array = [
        [[-885, 615], [-910, 350], [-885, 185]],
        [[-815, 635], [-830, 370]],
        [[-735, 635], [-755, 370]],
        [[-660, 605], [-685, 350]],
        [[-520, 555], [-510, 320]],
        [[-880, 505], [-670, 475], [-470, 465]],
        [[-875, 405], [-690, 395], [-485, 390]],
        [[-825, 300], [-600, 280], [-460, 275]],
        [[-450, 300], [-290, 290], [-90, 275]],
        [[-395, 355], [-390, 195]],
        [[-255, 340], [-260, 195]],
        [[-100, 310], [-105, 170]],
        [[65, 310], [90, 90]],
        [[150, 315], [155, 90]],
        [[245, 340], [245, 100]],
        [[330, 325], [340, 145]],
        [[420, 300], [455, 170]],
        [[490, 320], [565, 410], [770, 505]],
        [[525, 265], [610, 370], [825, 485]],
        [[575, 245], [650, 330], [835, 415]]
    ]
    for points in extras:
        roads.append(points)
        var path := PackedVector2Array()
        for p in points:
            path.append(Vector2(float(p[0]), float(p[1])))
        _draw_strip(path, 3.2, Color("#847a68"), 0.068)

func _draw_houses() -> void:
    var used := {}
    var count := 0
    for route in roads:
        for i in range(route.size() - 1):
            var start := Vector2(float(route[i][0]), float(route[i][1]))
            var finish := Vector2(float(route[i + 1][0]), float(route[i + 1][1]))
            var delta := finish - start
            var length := delta.length()
            if length < 12.0:
                continue
            var tangent := delta.normalized()
            var side := Vector2(-tangent.y, tangent.x)
            var samples := int(length / 20.0)
            for j in range(samples):
                for direction in [-1.0, 1.0]:
                    var p := start + delta * ((float(j) + 0.5) / float(samples))
                    p += tangent * rng.randf_range(-3.5, 3.5)
                    p += side * direction * rng.randf_range(13.5, 21.0)
                    if absf(p.x) > MAP_HALF or absf(p.y) > MAP_HALF:
                        continue
                    if not _is_housing(p) or _is_water(p) or _is_in_poly(p, meadow):
                        continue
                    var key := Vector2i(roundi(p.x / 14.0), roundi(p.y / 14.0))
                    if used.has(key):
                        continue
                    used[key] = true
                    var width := rng.randf_range(6.0, 10.0)
                    var depth := rng.randf_range(7.0, 13.0)
                    var height := rng.randf_range(3.0, 5.2)
                    var mesh := BoxMesh.new()
                    mesh.size = Vector3(width, height, depth)
                    var house := MeshInstance3D.new()
                    house.mesh = mesh
                    house.position = Vector3(p.x, height * 0.5, -p.y)
                    house.rotation.y = -atan2(tangent.y, tangent.x)
                    var palette := [
                        Color("#816c60"), Color("#857b70"),
                        Color("#a38a76"), Color("#706b65"),
                        Color("#8c746b")
                    ]
                    house.material_override = _mat(palette[rng.randi_range(0, palette.size() - 1)])
                    add_child(house)
                    house_positions.append(p)
                    count += 1
                    if count >= HOUSE_LIMIT:
                        print("Чернозёрье 0.7: условных домов ", count)
                        return
    print("Чернозёрье 0.7: условных домов ", count)

func _draw_forests() -> void:
    # Populate forests outside housing, meadow, water and road envelopes.
    # This fills OSM gaps, but is NOT an exact tree-by-tree reconstruction.
    var positions: Array[Vector3] = []
    for i in range(42000):
        if positions.size() >= TREE_LIMIT:
            break
        var p := Vector2(rng.randf_range(-MAP_HALF, MAP_HALF), rng.randf_range(-MAP_HALF, MAP_HALF))
        if _is_housing(p) or _is_in_poly(p, meadow) or _is_water(p):
            continue
        if _close_to_road(p, 9.0):
            continue
        positions.append(Vector3(p.x, 0.0, -p.y))
    if positions.is_empty():
        return
    var trunk_mesh := CylinderMesh.new()
    trunk_mesh.top_radius = 0.14
    trunk_mesh.bottom_radius = 0.24
    trunk_mesh.height = 3.4
    trunk_mesh.radial_segments = 5
    var crown_mesh := CylinderMesh.new()
    crown_mesh.top_radius = 0.0
    crown_mesh.bottom_radius = 1.5
    crown_mesh.height = 7.1
    crown_mesh.radial_segments = 5
    var stem := MultiMesh.new()
    stem.transform_format = MultiMesh.TRANSFORM_3D
    stem.mesh = trunk_mesh
    stem.instance_count = positions.size()
    var canopy := MultiMesh.new()
    canopy.transform_format = MultiMesh.TRANSFORM_3D
    canopy.mesh = crown_mesh
    canopy.instance_count = positions.size()
    for i in range(positions.size()):
        var scale := rng.randf_range(0.78, 1.28)
        var point := positions[i]
        var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale)
        stem.set_instance_transform(i, Transform3D(basis, point + Vector3.UP * (1.7 * scale)))
        canopy.set_instance_transform(i, Transform3D(basis, point + Vector3.UP * (5.1 * scale)))
    var trunks := MultiMeshInstance3D.new()
    trunks.multimesh = stem
    trunks.material_override = _mat(Color("#534235"))
    add_child(trunks)
    var crowns := MultiMeshInstance3D.new()
    crowns.multimesh = canopy
    crowns.material_override = _mat(Color("#273b30"))
    add_child(crowns)
    print("Чернозёрье 0.7: деревьев ", positions.size())
