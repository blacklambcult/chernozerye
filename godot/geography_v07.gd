extends Node3D
# V0.7 — provisional low-poly geographical blockout.
# Georeferenced OSM roads are retained in world.gd.
# Settlement/forest/river outlines below are artist-created approximations
# informed by the user's own annotated references, NOT measured cadastral data.
# One Godot unit still equals one meter.

const SOURCE := "res://world_data.json"
const MAP_HALF := 995.0
const HOUSE_LIMIT := 540
const TREE_LIMIT := 13500

var rng := RandomNumberGenerator.new()
var material_cache: Dictionary = {}
var roads: Array = []
var sketch_roads: Array = [] # Only manually approximated streets; OSM roads remain distinct.
var house_positions: Array[Vector2] = []
var house_footprints: Array[Dictionary] = []
var settlements: Array = []
# Provisional, artist-designed field silhouette. NOT surveyed Google contours.
var meadow := PackedVector2Array([
    Vector2(-560, -190), Vector2(-480, -130), Vector2(-380, -112),
    Vector2(-285, -135), Vector2(-195, -125), Vector2(-85, -156),
    Vector2(40, -205), Vector2(126, -290), Vector2(146, -367),
    Vector2(112, -450), Vector2(42, -520), Vector2(-65, -553),
    Vector2(-168, -535), Vector2(-244, -564), Vector2(-335, -532),
    Vector2(-455, -490), Vector2(-518, -420), Vector2(-501, -323),
    Vector2(-574, -247)
])
# Forest island in the lower-western portion of the open ground.
var meadow_island := PackedVector2Array([
    Vector2(-370, -395), Vector2(-340, -356), Vector2(-285, -352),
    Vector2(-246, -380), Vector2(-228, -435), Vector2(-270, -489),
    Vector2(-334, -481), Vector2(-369, -441)
])
# A narrow, illustrative farm track along the northern meadow boundary.
var field_track := PackedVector2Array([
    Vector2(-515, -175), Vector2(-426, -148), Vector2(-330, -150),
    Vector2(-223, -156), Vector2(-110, -176), Vector2(6, -217)
])
var lake_center := Vector2(730, -760)
var lake_outline := PackedVector2Array()
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

    _build_lake_outline()
    _smooth_river_path()

    var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
    if data is Dictionary:
        for feature in data.get("features", []):
            if feature is Dictionary and feature.get("type", "") == "road":
                var t: String = str(feature.get("tags", {}).get("highway", ""))
                if t in ["residential", "unclassified", "service"]:
                    roads.append(feature.get("points", []))

    _add_street_details()
    _draw_meadow()
    _draw_field_scrub()
    _draw_river()
    _draw_lake()
    _draw_houses()
    _draw_forests()
    _draw_undergrowth()
    _draw_grass_tufts()

func _mat(tint: Color) -> StandardMaterial3D:
    # Reuse palette materials: thousands of unique materials would hurt Web performance.
    var key := tint.to_html()
    if material_cache.has(key):
        return material_cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.roughness = 1.0
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    material_cache[key] = mat
    return mat

func _is_in_poly(p: Vector2, poly: PackedVector2Array) -> bool:
    return Geometry2D.is_point_in_polygon(p, poly)

func _is_housing(p: Vector2) -> bool:
    for zone in settlements:
        if _is_in_poly(p, zone):
            return true
    return false

func _is_water(p: Vector2) -> bool:
    if p.x < 340.0:
        return false
    if _is_in_poly(p, lake_outline):
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
    _draw_flat_polygon(meadow, Color("#697957"), 0.018)
    _draw_flat_polygon(meadow_island, Color("#344d3a"), 0.031)
    _draw_strip(field_track, 2.3, Color("#8c856a"), 0.040)

func _draw_field_scrub() -> void:
    # Low-poly shrubs are decorative. Sparse enough to preserve an open field.
    var bush_mesh := SphereMesh.new()
    bush_mesh.radius = 0.72
    bush_mesh.height = 1.0
    bush_mesh.radial_segments = 6
    bush_mesh.rings = 3
    var bush_positions: Array[Vector3] = []
    for i in range(1500):
        if bush_positions.size() >= 180:
            break
        var p := Vector2(rng.randf_range(-570.0, 150.0), rng.randf_range(-565.0, -110.0))
        if not _is_in_poly(p, meadow) or _is_in_poly(p, meadow_island):
            continue
        if _close_to_road(p, 5.0):
            continue
        if rng.randf() > 0.25:
            continue
        bush_positions.append(Vector3(p.x, 0.42, -p.y))
    if bush_positions.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = bush_mesh
    multi.instance_count = bush_positions.size()
    for i in range(bush_positions.size()):
        var scale := rng.randf_range(0.75, 1.55)
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale), bush_positions[i]))
    var node := MultiMeshInstance3D.new()
    node.multimesh = multi
    node.material_override = _mat(Color("#46583d"))
    add_child(node)

func _draw_river() -> void:
    _draw_strip(river_path, 32.0, Color("#273f46"), 0.045)

func _build_lake_outline() -> void:
    # An asymmetrical stylized lake. Not a surveyed shoreline.
    lake_outline.clear()
    for i in range(64):
        var theta := float(i) * TAU / 64.0
        var factor := 1.0 + 0.11 * sin(theta * 3.0 + 0.55) + 0.06 * cos(theta * 5.0 - 0.2)
        var x := cos(theta) * 124.0 * factor
        var y := sin(theta) * 96.0 * (factor + 0.07 * sin(theta + 0.5))
        lake_outline.append(lake_center + Vector2(x, y))

func _smooth_river_path() -> void:
    # Round off the visual corners between rough river waypoints.
    if river_path.size() < 3:
        return
    var smooth := PackedVector2Array()
    for i in range(river_path.size() - 1):
        var a: Vector2 = river_path[i]
        var b: Vector2 = river_path[i + 1]
        var previous: Vector2 = river_path[maxi(i - 1, 0)]
        var following: Vector2 = river_path[mini(i + 2, river_path.size() - 1)]
        for sample in range(4):
            smooth.append(a.cubic_interpolate(b, previous, following, float(sample) / 4.0))
    smooth.append(river_path[river_path.size() - 1])
    river_path = smooth

func _draw_lake() -> void:
    _draw_flat_polygon(lake_outline, Color("#233b42"), 0.052)

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
        sketch_roads.append(points)
        var path := PackedVector2Array()
        for p in points:
            path.append(Vector2(float(p[0]), float(p[1])))
        _draw_strip(path, 3.2, Color("#847a68"), 0.068)

# Prototype roof geometry: an inexpensive pitched-roof silhouette, not an
# individual real-world building reconstruction.
func _create_pitched_roof(width: float, depth: float, wall_height: float, roof_tint: Color) -> MeshInstance3D:
    var roof := MeshInstance3D.new()
    var eave_x := width * 0.5 + 0.35
    var eave_z := depth * 0.5 + 0.35
    var y_low := wall_height * 0.5 + 0.20
    var y_top := y_low + minf(2.2, width * 0.24)
    var left_front := Vector3(-eave_x, y_low, -eave_z)
    var left_back := Vector3(-eave_x, y_low, eave_z)
    var right_front := Vector3(eave_x, y_low, -eave_z)
    var right_back := Vector3(eave_x, y_low, eave_z)
    var peak_front := Vector3(0.0, y_top, -eave_z)
    var peak_back := Vector3(0.0, y_top, eave_z)
    var vertices := PackedVector3Array([
        left_front, peak_front, peak_back,
        left_front, peak_back, left_back,
        peak_front, right_front, right_back,
        peak_front, right_back, peak_back,
        left_front, right_front, peak_front,
        left_back, peak_back, right_back
    ])
    var normals := PackedVector3Array()
    for triangle_index in range(0, vertices.size(), 3):
        var v0: Vector3 = vertices[triangle_index]
        var v1: Vector3 = vertices[triangle_index + 1]
        var v2: Vector3 = vertices[triangle_index + 2]
        var face_normal := (v1 - v0).cross(v2 - v0).normalized()
        # Both sloping roof faces must be lit from above regardless of winding.
        if face_normal.y < -0.01:
            face_normal = -face_normal
        normals.append_array(PackedVector3Array([face_normal, face_normal, face_normal]))
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    roof.mesh = mesh
    roof.material_override = _mat(roof_tint)
    return roof

func _add_dacha_yard(p: Vector2, yaw: float, size_factor: float, palette_index: int) -> void:
    # A faint garden floor makes the housing strip read as separate plots.
    # These plots have no collision and are entirely illustrative.
    var patch := MeshInstance3D.new()
    var patch_mesh := BoxMesh.new()
    patch_mesh.size = Vector3(13.0 * size_factor, 0.018, 18.0 * size_factor)
    patch.mesh = patch_mesh
    patch.position = Vector3(p.x, 0.020, -p.y)
    patch.rotation.y = yaw
    var greens := [Color("#4b654c"), Color("#566649"), Color("#5d6a4b"), Color("#52624a")]
    patch.material_override = _mat(greens[palette_index % greens.size()])
    add_child(patch)

# Very simple wooden fences to make the provisional plots visible from
# street level. These are decorative game objects, NOT surveyed property lines.
func _add_low_fence(p: Vector2, yaw: float, road_side: float, index: int) -> void:
    if index % 4 == 0:
        return
    var fence_root := Node3D.new()
    fence_root.position = Vector3(p.x, 0.0, -p.y)
    fence_root.rotation.y = yaw
    add_child(fence_root)
    var pale := Color("#867c68") if index % 3 != 0 else Color("#6a705f")
    var parts := [
        [Vector3(-5.7, 0.56, road_side * 10.0), Vector3(7.0, 1.12, 0.15)],
        [Vector3(5.7, 0.56, road_side * 10.0), Vector3(7.0, 1.12, 0.15)],
        [Vector3(-9.1, 0.55, 0.0), Vector3(0.16, 1.10, 17.0)]
    ]
    for item in parts:
        var panel := MeshInstance3D.new()
        var board := BoxMesh.new()
        board.size = item[1]
        panel.mesh = board
        panel.position = item[0]
        panel.material_override = _mat(pale)
        fence_root.add_child(panel)

# A small visible door and windows help read houses at walking distance.
# All openings are decorative and deliberately not tied to real property plans.
func _add_simple_facade(house: MeshInstance3D, width: float, depth: float, height: float, front: float, index: int) -> void:
    var door := MeshInstance3D.new()
    var door_mesh := BoxMesh.new()
    door_mesh.size = Vector3(1.25, 2.0, 0.13)
    door.mesh = door_mesh
    door.position = Vector3(0.0, -height * 0.5 + 1.0, front * (depth * 0.5 + 0.09))
    door.material_override = _mat(Color("#514b47"))
    house.add_child(door)
    for side in [-1.0, 1.0]:
        var window := MeshInstance3D.new()
        var glass := BoxMesh.new()
        glass.size = Vector3(1.20, 1.00, 0.12)
        window.mesh = glass
        window.position = Vector3(side * width * 0.29, -height * 0.5 + 2.3, front * (depth * 0.5 + 0.09))
        var window_tint := Color("#9b875a") if index % 6 == 0 else Color("#34464c")
        window.material_override = _mat(window_tint)
        house.add_child(window)

func _draw_houses() -> void:
    # Provisional houses, not measured footprints. Fewer homes with breathing room,
    # spread across all street networks (instead of filling early roads first).
    var candidates: Array[Dictionary] = []
    var spacing := 27.0
    for route in roads:
        for i in range(route.size() - 1):
            var start := Vector2(float(route[i][0]), float(route[i][1]))
            var finish := Vector2(float(route[i + 1][0]), float(route[i + 1][1]))
            var delta := finish - start
            var length := delta.length()
            if length < 15.0:
                continue
            var tangent := delta.normalized()
            var side := Vector2(-tangent.y, tangent.x)
            var count := maxi(1, int(length / spacing))
            for j in range(count):
                for direction in [-1.0, 1.0]:
                    if rng.randf() < 0.20:
                        continue # unbuilt lots, gardens and open plots
                    var p := start + delta * ((float(j) + 0.5) / float(count))
                    p += tangent * rng.randf_range(-2.5, 2.5)
                    p += side * direction * rng.randf_range(17.0, 24.0)
                    if absf(p.x) > MAP_HALF or absf(p.y) > MAP_HALF:
                        continue
                    if not _is_housing(p) or _is_water(p) or _is_in_poly(p, meadow):
                        continue
                    if _close_to_road(p, 9.5):
                        continue
                    candidates.append({
                        "point": p,
                        "angle": atan2(tangent.y, tangent.x),
                        "front": direction
                    })

    # A spatial hash makes this deterministic and prevents overlapping buildings.
    # Random selection prevents the house cap favoring the first OSM road.
    var used := {}
    var accepted := 0
    const CELL = 24.0
    while not candidates.is_empty() and accepted < HOUSE_LIMIT:
        var candidate_index := rng.randi_range(0, candidates.size() - 1)
        var candidate: Dictionary = candidates[candidate_index]
        candidates.remove_at(candidate_index)
        var p: Vector2 = candidate["point"]
        var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
        var overlaps := false
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                var nearby_cell := cell + Vector2i(dx, dy)
                if used.has(nearby_cell):
                    for neighbor in used[nearby_cell]:
                        if p.distance_to(neighbor) < 23.0:
                            overlaps = true
                            break
                if overlaps:
                    break
            if overlaps:
                break
        if overlaps:
            continue
        if not used.has(cell):
            used[cell] = []
        used[cell].append(p)

        var width := rng.randf_range(6.0, 10.0)
        var depth := rng.randf_range(8.0, 12.0)
        var height := rng.randf_range(3.0, 5.2)
        var mesh := BoxMesh.new()
        mesh.size = Vector3(width, height, depth)
        var house := MeshInstance3D.new()
        house.mesh = mesh
        house.position = Vector3(p.x, height * 0.5, -p.y)
        house.rotation.y = float(candidate["angle"])
        var palette := [
            Color("#816c60"), Color("#857b70"),
            Color("#a38a76"), Color("#706b65"), Color("#8c746b")
        ]
        house.material_override = _mat(palette[rng.randi_range(0, palette.size() - 1)])
        add_child(house)
        # Keep building walls physical; otherwise the prototype player walks through homes.
        var wall_body := StaticBody3D.new()
        var wall_collision := CollisionShape3D.new()
        var wall_shape := BoxShape3D.new()
        wall_shape.size = Vector3(width, height, depth)
        wall_collision.shape = wall_shape
        wall_body.add_child(wall_collision)
        house.add_child(wall_body)
        # Individual garden pads and pitched roofs replace anonymous box-only silhouettes.
        _add_dacha_yard(p, house.rotation.y, rng.randf_range(0.86, 1.14), accepted)
        _add_low_fence(p, house.rotation.y, float(candidate["front"]), accepted)
        var roof_colors := [
            Color("#784d43"), Color("#575f69"), Color("#80695c"),
            Color("#6c4b47"), Color("#586774"), Color("#675e54")
        ]
        house.add_child(_create_pitched_roof(width, depth, height,
            roof_colors[rng.randi_range(0, roof_colors.size() - 1)]))
        _add_simple_facade(house, width, depth, height, float(candidate["front"]), accepted)
        if rng.randf() < 0.24:
            # Small secondary outbuilding at a few properties, never every house.
            var shed := MeshInstance3D.new()
            var shed_mesh := BoxMesh.new()
            shed_mesh.size = Vector3(2.5, 2.3, 3.6)
            shed.mesh = shed_mesh
            shed.position = Vector3(0.0, -height * 0.5 + 1.15, -depth * 0.5 - 4.6)
            shed.material_override = _mat(Color("#69645b"))
            house.add_child(shed)
        house_positions.append(p)
        house_footprints.append({
            "center": p,
            "width": width,
            "depth": depth,
            "angle": -float(candidate["angle"])
        })
        accepted += 1
    print("Чернозёрье 1.2: условных домов с крышами ", accepted, " (пока не реальные контуры зданий)")

func _draw_undergrowth() -> void:
    # A few shared low-poly instances around the gardens. No collisions,
    # negligible draw calls, and clear walking space along the roads.
    var brush := SphereMesh.new()
    brush.radius = 0.75
    brush.height = 0.90
    brush.radial_segments = 5
    brush.rings = 3
    var plants := PackedVector3Array()
    for house_pos in house_positions:
        for j in range(3):
            var p := house_pos + Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-14.0, 14.0))
            if not _is_housing(p) or _is_water(p) or _close_to_road(p, 6.5):
                continue
            if p.distance_to(house_pos) < 7.0:
                continue
            plants.append(Vector3(p.x, 0.42, -p.y))
    if plants.is_empty():
        return
    var multimesh := MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D
    multimesh.mesh = brush
    multimesh.instance_count = plants.size()
    for i in range(plants.size()):
        var scale := rng.randf_range(0.6, 1.25)
        multimesh.set_instance_transform(i, Transform3D(
            Basis.IDENTITY.scaled(Vector3(scale, scale, scale)), plants[i]))
    var bushes := MultiMeshInstance3D.new()
    bushes.multimesh = multimesh
    bushes.material_override = _mat(Color("#485842"))
    bushes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(bushes)

func _seed_forest_edges(positions: Array[Vector3]) -> int:
    # Dense forest belts immediately OUTSIDE the approximate housing polygons.
    # This repairs the empty-horizon problem in the 1.3 first-person screenshot.
    # These belts are artistic massing, not measured tree/woodland boundaries.
    var added := 0
    for zone in settlements:
        var boundary: PackedVector2Array = zone
        for edge_index in range(boundary.size()):
            var a: Vector2 = boundary[edge_index]
            var b: Vector2 = boundary[(edge_index + 1) % boundary.size()]
            var tangent := (b - a).normalized()
            var perp := Vector2(-tangent.y, tangent.x)
            var samples := maxi(1, ceili(a.distance_to(b) / 6.5))
            for sample in range(samples):
                var along := (float(sample) + 0.5) / float(samples)
                var base := a.lerp(b, along)
                # Test both sides; a point is accepted only outside ALL housing.
                for side in [-1.0, 1.0]:
                    for distance in [8.0, 20.0, 34.0]:
                        if rng.randf() < 0.28:
                            continue
                        var p: Vector2 = base + perp * float(side) * (float(distance) + rng.randf_range(-2.2, 2.2))
                        p += tangent * rng.randf_range(-2.4, 2.4)
                        if absf(p.x) > MAP_HALF or absf(p.y) > MAP_HALF:
                            continue
                        if _is_housing(p) or _is_water(p) or _is_in_poly(p, meadow):
                            continue
                        if _close_to_road(p, 8.0):
                            continue
                        positions.append(Vector3(p.x, 0.0, -p.y))
                        added += 1
    return added

func _draw_grass_tufts() -> void:
    # Small crossed triangular grass tufts break up the bare single-colour
    # plane. One MultiMesh keeps the Web draw-call cost low.
    var grass_vertices := PackedVector3Array([
        Vector3(-0.29, 0.0, 0.0), Vector3(0.29, 0.0, 0.0), Vector3(0.0, 0.6, 0.03),
        Vector3(0.0, 0.0, -0.24), Vector3(0.0, 0.0, 0.24), Vector3(0.03, 0.53, 0.0),
        Vector3(-0.22, 0.0, -0.17), Vector3(0.22, 0.0, 0.17), Vector3(0.0, 0.44, 0.0)
    ])
    var arrays := []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = grass_vertices
    var blade_mesh := ArrayMesh.new()
    blade_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var locations := PackedVector3Array()
    for house_pos in house_positions:
        for j in range(15):
            var patch_pos := house_pos + Vector2(rng.randf_range(-17.0, 17.0), rng.randf_range(-17.0, 17.0))
            if not _is_housing(patch_pos) or _is_water(patch_pos):
                continue
            if patch_pos.distance_to(house_pos) < 5.0 or _close_to_road(patch_pos, 5.5):
                continue
            locations.append(Vector3(patch_pos.x, 0.06, -patch_pos.y))
    for j in range(6800):
        var field_pos := Vector2(rng.randf_range(-575.0, 155.0), rng.randf_range(-555.0, -110.0))
        if _is_in_poly(field_pos, meadow) and not _is_in_poly(field_pos, meadow_island):
            if not _close_to_road(field_pos, 5.0):
                locations.append(Vector3(field_pos.x, 0.06, -field_pos.y))
    if locations.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = blade_mesh
    multi.instance_count = locations.size()
    for i in range(locations.size()):
        var scale := rng.randf_range(0.75, 1.6)
        var rotate := rng.randf_range(-PI, PI)
        multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rotate).scaled(Vector3.ONE * scale), locations[i]))
    var clumps := MultiMeshInstance3D.new()
    clumps.multimesh = multi
    clumps.material_override = _mat(Color("#677459"))
    clumps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(clumps)

func _draw_forests() -> void:
    # Populate forests outside housing, meadow, water and road envelopes.
    # This fills OSM gaps, but is NOT an exact tree-by-tree reconstruction.
    var positions: Array[Vector3] = []
    # Dense island grove inside the otherwise open meadow.
    for j in range(260):
        var island_p := Vector2(rng.randf_range(-374.0, -224.0), rng.randf_range(-495.0, -348.0))
        if _is_in_poly(island_p, meadow_island):
            positions.append(Vector3(island_p.x, 0.0, -island_p.y))
    # Treetops just outside the settlement form the missing wooded horizon.
    var forest_edge_count := _seed_forest_edges(positions)
    # Tree groups inside dacha gardens: the old broad settlement masks left
    # the entire village unnaturally bare, unlike wooded rural neighbourhoods.
    var yard_count := 0
    for j in range(13000):
        if yard_count >= 1050:
            break
        var yard_p := Vector2(rng.randf_range(-960.0, 930.0), rng.randf_range(30.0, 720.0))
        if not _is_housing(yard_p) or _is_water(yard_p):
            continue
        if _close_to_road(yard_p, 8.0):
            continue
        var too_close := false
        for built in house_positions:
            if built.distance_squared_to(yard_p) < 10.0 * 10.0:
                too_close = true
                break
        if too_close:
            continue
        positions.append(Vector3(yard_p.x, 0.0, -yard_p.y))
        yard_count += 1
    for i in range(58000):
        if positions.size() >= TREE_LIMIT:
            break
        var p := Vector2(rng.randf_range(-MAP_HALF, MAP_HALF), rng.randf_range(-MAP_HALF, MAP_HALF))
        if _is_housing(p) or (_is_in_poly(p, meadow) and not _is_in_poly(p, meadow_island)) or _is_water(p):
            continue
        if _close_to_road(p, 9.0):
            continue
        positions.append(Vector3(p.x, 0.0, -p.y))
    if positions.is_empty():
        return
    # Mixed forest: broadleaf silhouettes + two-tier low-poly firs.
    # Shared MultiMeshes keep the forest inexpensive for the Web renderer.
    var trunks: Array[Transform3D] = []
    var lower_firs: Array[Transform3D] = []
    var upper_firs: Array[Transform3D] = []
    var leaf_crowns: Array[Transform3D] = []
    for point in positions:
        var scale := rng.randf_range(0.74, 1.18)
        var basis := Basis.IDENTITY.scaled(Vector3.ONE * scale)
        trunks.append(Transform3D(basis, point + Vector3.UP * 1.45 * scale))
        if rng.randf() < 0.28:
            leaf_crowns.append(Transform3D(basis, point + Vector3.UP * 4.45 * scale))
        else:
            lower_firs.append(Transform3D(basis, point + Vector3.UP * 4.0 * scale))
            upper_firs.append(Transform3D(basis, point + Vector3.UP * 6.25 * scale))

    var bark := CylinderMesh.new()
    bark.height = 2.9
    bark.bottom_radius = 0.25
    bark.top_radius = 0.15
    bark.radial_segments = 5
    var fir_lower := CylinderMesh.new()
    fir_lower.height = 4.2
    fir_lower.bottom_radius = 1.65
    fir_lower.top_radius = 0.38
    fir_lower.radial_segments = 6
    var fir_upper := CylinderMesh.new()
    fir_upper.height = 3.4
    fir_upper.bottom_radius = 1.05
    fir_upper.top_radius = 0.06
    fir_upper.radial_segments = 6
    var leaves := SphereMesh.new()
    leaves.radius = 2.2
    leaves.height = 3.9
    leaves.radial_segments = 7
    leaves.rings = 4

    _add_tree_instances(bark, trunks, Color("#51463c"))
    _add_tree_instances(fir_lower, lower_firs, Color("#314a3c"))
    _add_tree_instances(fir_upper, upper_firs, Color("#3f5744"))
    _add_tree_instances(leaves, leaf_crowns, Color("#50634a"))
    print("Чернозёрье 1.4: деревьев ", positions.size(), " (на опушках ", forest_edge_count, ", садовых ", yard_count, ")")

func _add_tree_instances(mesh: Mesh, transforms: Array[Transform3D], tint: Color) -> void:
    if transforms.is_empty():
        return
    var instances := MultiMesh.new()
    instances.transform_format = MultiMesh.TRANSFORM_3D
    instances.mesh = mesh
    instances.instance_count = transforms.size()
    for i in range(transforms.size()):
        instances.set_instance_transform(i, transforms[i])
    var node := MultiMeshInstance3D.new()
    node.multimesh = instances
    node.material_override = _mat(tint)
    # Dynamic shadows from thousands of trees are prohibitive in Web/GL.
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
