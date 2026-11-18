extends Node3D
# CHERNOZERYE 2.2 / ART LAYER
# All spatial placements derive from the user's manual GeoJSON features.
# Decorative features are deterministic and never modify the survey geometry.

const WOOD_TONES := ["#454941", "#51473e", "#3b4039", "#4e433c", "#43463d", "#525047"]
const ROOF_TONES := ["#282e31", "#373432", "#30383a", "#403933"]
const DOOR_COLOR := Color("#24221f")
const FRAME_COLOR := Color("#736859")
const WINDOW_COLOR := Color("#131a1f")
const WINDOW_LIT := Color("#efac5d")
const FENCE_COLOR := Color("#786a56")
const POST_COLOR := Color("#524b43")
const RUT_COLOR := Color("#423a32")

var _roads: Array = []
var _detail_batches: Dictionary = {}
var _textures: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _lights_placed: int = 0
var _fence_posts: PackedVector3Array = PackedVector3Array()
var _fence_rails: PackedVector3Array = PackedVector3Array()
var _fence_slats: PackedVector3Array = PackedVector3Array()
var _yard_details: PackedVector3Array = PackedVector3Array()
var _road_ruts: PackedVector3Array = PackedVector3Array()
var _bush_positions: Array[Transform3D] = []
var _aspen_positions: Array[Transform3D] = []
var _building_count := 0
var _fence_count := 0
var _road_count := 0
var _feature_house_center := Vector2(INF, INF)
var _feature_house_distance := INF

func decorate(features: Array) -> void:
    _rng.seed = 19960918
    # Choose one real, hand-surveyed building nearest the documented village spawn.
    # This is a visual showcase, not an invented new geographic footprint.
    var player_spawn_2d := Vector2(-789.7, 268.6)
    for item in features:
        if not item is Dictionary or str(item.get("type", "")) != "house":
            continue
        var points := _local_points(item.get("points", []))
        if points.size() < 3:
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
        if str(item.get("type", "")) == "road":
            var road_points := _local_points(item.get("points", []))
            for i in range(road_points.size() - 1):
                _roads.append([road_points[i], road_points[i + 1]])
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
    _create_solid_mesh(_fence_posts, Color("#554a40"), "Забор / столбы")
    _create_solid_mesh(_fence_rails, Color("#5a5247"), "Забор / рейки")
    _create_solid_mesh(_fence_slats, Color("#49483e"), "Забор / обветшавший штакетник")
    _create_solid_mesh(_yard_details, Color("#48443b"), "Старый деревенский быт / ящики и дрова")
    _create_solid_mesh(_road_ruts, RUT_COLOR, "Дорога / земляные колеи")
    _create_forest_assets()
    print("MANUAL_ART_READY: buildings=", _building_count,
        " plots=", _fence_count, " roads=", _road_count, " lamps=", _lights_placed)

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
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
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
            var offset := rng.randf_range(-0.14, 0.10)
            if rooftop:
                if y % 9 == 0:
                    offset -= 0.25
                if x % 11 == 0:
                    offset -= 0.12
                if y % 21 >= 17 and x % 13 < 4:
                    offset += 0.09
            else:
                match wall_style:
                    1:
                        # Coarse horizontal village log/plank cladding.
                        if y % 8 <= 1:
                            offset -= 0.25
                        if (x + (y / 8) * 13) % 28 == 0:
                            offset -= 0.11
                    2:
                        # Limewash over uneven plaster, without strong wood stripes.
                        offset = rng.randf_range(-0.095, 0.045)
                        if (x / 9 + y / 7 + seed) % 13 == 0:
                            offset -= 0.12
                    3:
                        # Old red-brick farm masonry in offset rows.
                        if y % 8 == 0:
                            offset -= 0.23
                        if (x + (8 if int(y / 8) % 2 == 0 else 0)) % 18 == 0:
                            offset -= 0.19
                    _:
                        if x % 8 == 0:
                            offset -= 0.24
                        if x % 8 == 1:
                            offset += 0.055
                        if y % 19 == 0:
                            offset -= 0.08
                if (x * 17 + y * 7 + seed) % 67 <= 2:
                    offset -= 0.16
            var shade := clampf(1.0 + offset, 0.35, 1.16)
            img.set_pixel(x, y, Color(tone.r * shade, tone.g * shade, tone.b * shade, 1.0))
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
        "frame": FRAME_COLOR,
        "door": DOOR_COLOR,
        "lintel": Color("#52473f"),
        "chimney": Color("#444442"),
        "board": Color("#50493e"),
        "porch": Color("#4b433b"),
        "lamp": Color("#df9c52"),
        "trim": Color("#8a9c9c"),
        "rust": Color("#604039")
    }
    for key in _detail_batches.keys():
        var verts: PackedVector3Array = _detail_batches[key]
        if key == "window_lit":
            var lit_mat := _material(WINDOW_LIT)
            lit_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            var arrays := []
            arrays.resize(Mesh.ARRAY_MAX)
            arrays[Mesh.ARRAY_VERTEX] = verts
            var mesh := ArrayMesh.new()
            mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
            var lit_node := MeshInstance3D.new()
            lit_node.name = "Редкие янтарные окна"
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

func _building_front_edge(points: PackedVector2Array) -> int:
    var best_index := 0
    var best_score := INF
    for i in range(points.size()):
        var a := points[i]
        var b := points[(i + 1) % points.size()]
        var length := a.distance_to(b)
        if length < 2.5:
            continue
        var distance := _nearest_road_distance((a + b) * 0.5)
        var score := distance - minf(length, 15.0) * 0.1
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
        center_fraction: float, side_length: float, illuminated: bool, boarded: bool = false) -> void:
    var half := minf(0.07, 0.72 / maxf(side_length, 0.1))
    var u0 := center_fraction - half
    var u1 := center_fraction + half
    _wall_panel("frame", start, finish, normal, u0 - 0.017, u1 + 0.017, 1.36, 2.78, 0.115)
    _wall_panel("window_lit" if illuminated else "window",
        start, finish, normal, u0, u1, 1.47, 2.66, 0.142)
    _wall_panel("lintel", start, finish, normal, u0, u1, 1.97, 2.04, 0.157)
    # Narrow painted frames: recognisable provincial window surrounds.
    _wall_panel("trim", start, finish, normal, u0 - 0.025, u0 - 0.009, 1.30, 2.83, 0.169)
    _wall_panel("trim", start, finish, normal, u1 + 0.009, u1 + 0.025, 1.30, 2.83, 0.169)
    _wall_panel("trim", start, finish, normal, u0 - 0.024, u1 + 0.024, 2.77, 2.88, 0.173)
    _wall_panel("trim", start, finish, normal, u0 - 0.038, u1 + 0.038, 1.28, 1.38, 0.170)
    if boarded:
        _wall_panel("board", start, finish, normal, u0, u1, 1.68, 1.94, 0.170)
        _wall_panel("board", start, finish, normal, u0, u1, 2.23, 2.43, 0.174)
    if illuminated and _lights_placed < 7:
        _lights_placed += 1
        var center := start.lerp(finish, center_fraction)
        var lamp := OmniLight3D.new()
        lamp.name = "Тусклая лампа / окно"
        lamp.position = _pt(center, 2.3) + normal * 1.1
        lamp.light_color = Color("#ffbc7e")
        lamp.light_energy = 0.72
        lamp.omni_range = 11.0
        lamp.shadow_enabled = false
        add_child(lamp)

func _decorate_building(points: PackedVector2Array, category: String) -> void:
    if points.size() < 3:
        return
    _building_count += 1
    var index := _building_count
    # The bright survey blockout is hidden in manual_geo.gd; art can use natural 1-storey proportions.
    var walls_height := (3.35 + float(index % 4) * 0.27) if category == "house" else (2.7 if category == "sauna" else 2.35)
    # Alternating cladding and construction material breaks up identical cottage rows.
    var wall_style := 0
    var tone := Color(WOOD_TONES[(index * 7) % WOOD_TONES.size()])
    if category == "house":
        if index % 7 == 0:
            wall_style = 3
            tone = Color("#806154")  # weathered brick
            walls_height = 4.45
        elif index % 5 == 0:
            wall_style = 2
            tone = Color("#838982")  # limewash
        elif index % 3 == 0:
            wall_style = 1
            tone = Color("#5a5044")  # horizontal logs
    elif category == "sauna":
        tone = Color("#38362f")
        wall_style = 1
    elif category == "shed":
        tone = Color("#49453f")
    var wall_tex := _pixel_texture(tone, 8021 + int(index % 5), false, wall_style)
    var roof_tex := _pixel_texture(Color(ROOF_TONES[index % ROOF_TONES.size()]), 9121 + int(index % 4), true)
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
        var offset := normal * 0.07
        _quad(wall_verts, wall_uvs, _pt(a, 0.12) + offset, _pt(b, 0.12) + offset,
            _pt(b, walls_height) + offset, _pt(a, walls_height) + offset)
        if i == front_index and length > 3.3:
            var door_half := 0.55 / length
            _wall_panel("frame", a, b, normal, 0.5 - door_half - 0.02,
                0.5 + door_half + 0.02, 0.1, 2.23)
            _wall_panel("door", a, b, normal, 0.5 - door_half,
                0.5 + door_half, 0.12, 2.13, 0.15)
            if category == "house" and length > 7.0:
                _make_window(a, b, normal, 0.19, length, index % 6 == 0, index % 5 == 0)
                _make_window(a, b, normal, 0.81, length, index % 9 == 0, index % 7 == 0)
        elif category == "house" and length > 5.0:
            _make_window(a, b, normal, 0.5, length, index % 11 == 0 and i % 2 == 0,
                (index + i) % 8 == 0)
    _make_textured_mesh(wall_verts, wall_uvs, _material(Color.WHITE, wall_tex),
        category + " / pixel-wood")
    _decorate_roof(points, category, walls_height, roof_tex, index)
    if category == "house":
        _decorate_showcase_yard(points, front_index)

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
    # Three uneven timber steps, woodpile and one creaking yard lamp.
    for i in range(3):
        var delta := vout * (0.55 + float(i) * 0.58)
        var h := 0.48 - float(i) * 0.12
        var half_width := 1.10 + float(i) * 0.08
        var left := origin + delta - tangent * half_width + Vector3.UP * h
        var right := origin + delta + tangent * half_width + Vector3.UP * h
        _batch_quad("porch", left, right, right + vout * 0.42, left + vout * 0.42)
        _batch_quad("porch", left + Vector3.DOWN * 0.12, right + Vector3.DOWN * 0.12, right, left)
    # Wood crates near the front wall.
    var stack_origin := origin + tangent * 2.25 + vout * 1.4
    for i in range(4):
        _batch_box("porch", stack_origin + tangent * float(i % 2) * 0.62 +
            Vector3.UP * (0.18 + 0.36 * float(i / 2)),
            Vector3(0.52, 0.32, 0.50))
    # A dim yard lantern outside the doorway.
    var lamp_origin := origin - tangent * 2.0 + vout * 2.25
    _batch_box("chimney", lamp_origin + Vector3.UP * 1.55, Vector3(0.13, 3.05, 0.13))
    _batch_box("lamp", lamp_origin + Vector3.UP * 3.05, Vector3(0.35, 0.36, 0.35))
    var light := OmniLight3D.new()
    light.name = "Старая лампа у крыльца"
    light.position = lamp_origin + Vector3.UP * 3.05
    light.light_color = Color("#ffb46d")
    light.light_energy = 0.9
    light.omni_range = 10.0
    light.shadow_enabled = false
    add_child(light)
    print("MANUAL_SHOWCASE_YARD_READY: ", centroid)

func _roof_face(verts: PackedVector3Array, uvs: PackedVector2Array,
        a: Vector2, b: Vector2, c: Vector2, ah: float, bh: float, ch: float) -> void:
    _face(verts, uvs, _pt(a, ah), _pt(b, bh), _pt(c, ch),
        Vector2(0, 0), Vector2(a.distance_to(b) / 5.0, 0),
        Vector2(a.distance_to(c) / 5.0, 1.0))

func _decorate_roof(points: PackedVector2Array, category: String, base: float,
        tex: Texture2D, index: int) -> void:
    var v := PackedVector3Array()
    var uv := PackedVector2Array()
    var rise := (1.75 if index % 3 != 0 else 1.25) if category == "house" else 0.7
    var eave := base + 0.12
    if points.size() == 4:
        var across_0 := points[0].distance_to(points[1])
        var across_1 := points[1].distance_to(points[2])
        if across_0 >= across_1:
            var r0 := (points[0] + points[3]) * 0.5
            var r1 := (points[1] + points[2]) * 0.5
            _roof_face(v, uv, points[0], points[1], r1, eave, eave, eave + rise)
            _roof_face(v, uv, points[0], r1, r0, eave, eave + rise, eave + rise)
            _roof_face(v, uv, points[3], r0, r1, eave, eave + rise, eave + rise)
            _roof_face(v, uv, points[3], r1, points[2], eave, eave + rise, eave)
            _roof_face(v, uv, points[0], r0, points[3], eave, eave + rise, eave)
            _roof_face(v, uv, points[1], points[2], r1, eave, eave, eave + rise)
        else:
            var r0 := (points[0] + points[1]) * 0.5
            var r1 := (points[2] + points[3]) * 0.5
            _roof_face(v, uv, points[1], points[2], r1, eave, eave, eave + rise)
            _roof_face(v, uv, points[1], r1, r0, eave, eave + rise, eave + rise)
            _roof_face(v, uv, points[0], r0, r1, eave, eave + rise, eave + rise)
            _roof_face(v, uv, points[0], r1, points[3], eave, eave + rise, eave)
            _roof_face(v, uv, points[0], points[1], r0, eave, eave, eave + rise)
            _roof_face(v, uv, points[2], points[3], r1, eave, eave, eave + rise)
    else:
        var centroid := Vector2.ZERO
        for p in points:
            centroid += p
        centroid /= float(points.size())
        for i in range(points.size()):
            _roof_face(v, uv, points[i], points[(i + 1) % points.size()], centroid,
                eave, eave, eave + rise)
    _make_textured_mesh(v, uv, _material(Color.WHITE, tex), category + " / rough slate roof")
    if category == "house" and index % 3 != 0:
        var center := Vector2.ZERO
        for p in points:
            center += p
        center /= float(points.size())
        _batch_box("chimney", _pt(center + Vector2(0.5, 0.4), base + rise + 0.18),
            Vector3(0.7, 1.1, 0.7))

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

func _fence_edge(a: Vector2, b: Vector2, gate_center: bool) -> void:
    var length := a.distance_to(b)
    if length < 0.35:
        return
    var count := maxi(1, int(ceil(length / 2.8)))
    var tang := (b - a) / length
    var gate_a := 0.0
    var gate_b := 0.0
    if gate_center and length >= 6.0:
        gate_a = length * 0.5 - 1.85
        gate_b = length * 0.5 + 1.85
    for i in range(count + 1):
        var t := float(i) / float(count)
        var dist := length * t
        if gate_center and dist >= gate_a and dist <= gate_b:
            continue
        var p := a.lerp(b, t)
        var leaning := 0.05 * sin(float(i * 19))
        _append_box_to(_fence_posts, _pt(p, 0.82) + Vector3(leaning, 0, 0),
            Vector3(0.16, 1.58, 0.16))
    for i in range(count):
        var from_dist := length * float(i) / float(count)
        var to_dist := length * float(i + 1) / float(count)
        var segment_mid := (from_dist + to_dist) * 0.5
        if gate_center and segment_mid >= gate_a and segment_mid <= gate_b:
            continue
        var start := a + tang * from_dist
        var finish := a + tang * to_dist
        # Some plots have an irregular full picket fence; others keep the old open rails.
        if _fence_count % 4 == 1:
            var slat_count := maxi(1, int(ceil((to_dist - from_dist) / 0.74)))
            for j in range(slat_count):
                if (i * 7 + j * 13 + _fence_count) % 17 == 0:
                    continue
                var fraction := (float(j) + 0.5) / float(slat_count)
                var center := start.lerp(finish, fraction)
                var h := 1.10 + 0.3 * sin(float(i * 19 + j * 17))
                _append_box_to(_fence_slats, _pt(center, h * 0.5 + 0.12),
                    Vector3(0.13, h, 0.13))
        for y in [0.52, 1.10]:
            # Vertical timber ribbons facing the street: older rails were
            # horizontal zero-thickness strips and nearly invisible at eye level.
            var v0 := _pt(start, y)
            var v1 := _pt(finish, y)
            var toward := Vector3(-tang.y, 0, -tang.x).normalized() * 0.04
            var down := Vector3.UP * 0.085
            _push_tri(_fence_rails, v0 + toward - down, v1 + toward - down, v1 + toward + down)
            _push_tri(_fence_rails, v0 + toward - down, v1 + toward + down, v0 + toward + down)

func _decorate_fence(points: PackedVector2Array) -> void:
    if points.size() < 3:
        return
    _fence_count += 1
    var gate_edge := 0
    var near := INF
    for i in range(points.size()):
        var distance := _nearest_road_distance((points[i] + points[(i + 1) % points.size()]) * 0.5)
        if distance < near:
            near = distance
            gate_edge = i
    for i in range(points.size()):
        _fence_edge(points[i], points[(i + 1) % points.size()], i == gate_edge)
    if _fence_count % 3 == 0:
        var centroid := Vector2.ZERO
        for point in points:
            centroid += point
        centroid /= float(points.size())
        if Geometry2D.is_point_in_polygon(centroid, points) and _nearest_road_distance(centroid) > 5.0:
            for i in range(3):
                var offset := Vector2(float(i) * 0.72, float(i % 2) * 0.46)
                _append_box_to(_yard_details, _pt(centroid + offset, 0.23),
                    Vector3(0.55, 0.45, 0.5))

func _decorate_road(points: PackedVector2Array) -> void:
    if points.size() < 2:
        return
    _road_count += 1
    for i in range(points.size() - 1):
        var a := points[i]
        var b := points[i + 1]
        var length := a.distance_to(b)
        if length < 0.5:
            continue
        var perpendicular := Vector2(-(b.y-a.y), (b.x-a.x)).normalized()
        for lane in [-1.0, 1.0]:
            var off: Vector2 = perpendicular * float(lane) * 1.18
            var pa := _pt(a + off, 0.134)
            var pb := _pt(b + off, 0.134)
            var side := Vector3(perpendicular.x, 0, -perpendicular.y) * 0.10
            _push_tri(_road_ruts, pa - side, pa + side, pb + side)
            _push_tri(_road_ruts, pa - side, pb + side, pb - side)

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
        if _nearest_road_distance(p) < 8.0:
            continue
        var scale := rng.randf_range(0.75, 1.4)
        var basis := Basis().rotated(Vector3.UP, rng.randf_range(-PI, PI)).scaled(Vector3.ONE * scale)
        if placed % 3 == 0:
            _aspen_positions.append(Transform3D(basis, _pt(p, 5.6 * scale)))
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
    node.material_override = _material(tint)
    add_child(node)

func _create_forest_assets() -> void:
    var canopy := SphereMesh.new()
    canopy.radius = 2.8
    canopy.height = 5.3
    canopy.radial_segments = 5
    canopy.rings = 3
    _add_instanced(canopy, _aspen_positions, Color("#445b43"), "Осинник / ломанные кроны")
    var bush := SphereMesh.new()
    bush.radius = 0.85
    bush.height = 1.6
    bush.radial_segments = 5
    bush.rings = 2
    _add_instanced(bush, _bush_positions, Color("#3a4c35"), "Подлесок / репейник")
