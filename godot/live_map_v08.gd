extends Control
# Live, engine-drawn geographic comparison map. Illustrative polygons are not surveyed.
const HALF := 1000.0
var world: Node3D
var geo
var player: Node3D
var osm_features: Array = []
var overture_buildings: Array = []
var show_overture_buildings := true
var show_houses := false
var show_osm_buildings := false
var sector_a_zoom := false
var neighborhood_zoom := false
var show_manual := false
var manual_features: Array = []

func initialize(world_node: Node3D, geo_node: Node3D, player_node: Node3D, features: Array, overture: Array) -> void:
    world = world_node
    geo = geo_node
    player = player_node
    osm_features = features
    overture_buildings = overture
    if FileAccess.file_exists("res://manual_layout.json"):
        var manual_data = JSON.parse_string(FileAccess.get_file_as_string("res://manual_layout.json"))
        if manual_data is Dictionary:
            manual_features = manual_data.get("features", [])

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

var elapsed_since_redraw := 0.0
func _process(delta: float) -> void:
    if visible:
        elapsed_since_redraw += delta
        if elapsed_since_redraw >= 0.16:
            elapsed_since_redraw = 0.0
            queue_redraw()

func _view_center() -> Vector2:
    if show_manual:
        return Vector2(-620.0, 90.0)
    if neighborhood_zoom:
        return Vector2(-760.0, 360.0)
    return Vector2(-660.0, 390.0) if sector_a_zoom else Vector2.ZERO

func _view_half() -> float:
    if show_manual:
        return 700.0
    if neighborhood_zoom:
        return 150.0
    return 340.0 if sector_a_zoom else HALF

func _in_view(p: Vector2) -> bool:
    var c := _view_center()
    var h := _view_half()
    return absf(p.x - c.x) <= h and absf(p.y - c.y) <= h

func _map_pos(p: Vector2) -> Vector2:
    var side: float = maxf(10.0, minf(size.x - 36.0, size.y - 98.0))
    var origin := Vector2((size.x - side) * 0.5, 60.0 + maxf(0.0, (size.y - 98.0 - side) * 0.5))
    var c := _view_center()
    var h := _view_half()
    return origin + Vector2((p.x - c.x + h) * side / (2.0 * h), (c.y + h - p.y) * side / (2.0 * h))

# Clip all geometry to the 2 x 2 km study square before drawing.
# Source OSM ways extend beyond the square and must not appear outside its frame.
func _bounds() -> PackedVector2Array:
    var c := _view_center()
    var h := _view_half()
    return PackedVector2Array([
        Vector2(c.x - h, c.y - h), Vector2(c.x + h, c.y - h),
        Vector2(c.x + h, c.y + h), Vector2(c.x - h, c.y + h)
    ])

func _poly(points: PackedVector2Array, tint: Color) -> void:
    if points.size() < 3:
        return
    var all_inside := true
    for p in points:
        if not _in_view(p):
            all_inside = false
            break
    var pieces: Array = [points] if all_inside else Geometry2D.intersect_polygons(points, _bounds())
    for piece in pieces:
        if piece.size() < 3:
            continue
        var vertices := PackedVector2Array()
        for p in piece:
            vertices.append(_map_pos(p))
        draw_colored_polygon(vertices, tint)

func _clip_segment(a: Vector2, b: Vector2) -> PackedVector2Array:
    # Liang-Barsky segment clipping: returns zero or two vertices.
    var d := b - a
    var p_values := [-d.x, d.x, -d.y, d.y]
    var c := _view_center()
    var h := _view_half()
    var q_values := [a.x - (c.x - h), c.x + h - a.x, a.y - (c.y - h), c.y + h - a.y]
    var low := 0.0
    var high := 1.0
    for k in range(4):
        var pk: float = float(p_values[k])
        var qk: float = float(q_values[k])
        if absf(pk) < 0.00001:
            if qk < 0.0:
                return PackedVector2Array()
        else:
            var t: float = qk / pk
            if pk < 0.0:
                low = maxf(low, t)
            else:
                high = minf(high, t)
            if low > high:
                return PackedVector2Array()
    return PackedVector2Array([a + d * low, a + d * high])

func _line(points: PackedVector2Array, tint: Color, width: float = 2.0) -> void:
    if points.size() < 2:
        return
    for i in range(points.size() - 1):
        var clipped := _clip_segment(points[i], points[i + 1])
        if clipped.size() == 2:
            draw_line(_map_pos(clipped[0]), _map_pos(clipped[1]), tint, width, true)

func _text(p: Vector2, text: String, color: Color = Color.WHITE, font_size: int = 13) -> void:
    draw_string(ThemeDB.fallback_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw_manual_survey(nw: Vector2, se: Vector2) -> void:
    var order := ["forest", "water", "plot", "road", "path", "object", "house", "sauna", "shed", "car"]
    var tints := {
        "forest": Color("#406848"),
        "water": Color("#4c9fc1"),
        "plot": Color("#e9c38a"),
        "road": Color("#dab18b"),
        "path": Color("#e1cc91"),
        "object": Color("#aab5b1"),
        "house": Color("#e4a178"),
        "sauna": Color("#e17c83"),
        "shed": Color("#bcb0a0"),
        "car": Color("#7bb7f0")
    }
    for category in order:
        for feature in manual_features:
            if not feature is Dictionary or str(feature.get("type", "")) != category:
                continue
            var pts := PackedVector2Array()
            for raw in feature.get("points", []):
                pts.append(Vector2(float(raw[0]), float(raw[1])))
            if pts.is_empty():
                continue
            var tint: Color = tints[category]
            if category == "car":
                if _in_view(pts[0]):
                    draw_circle(_map_pos(pts[0]), 4.0, tint)
            elif category == "road" or category == "path":
                _line(pts, tint, 3.0 if category == "road" else 1.5)
            elif category == "plot":
                pts.append(pts[0])
                _line(pts, tint, 1.6)
            else:
                _poly(pts, tint)
    draw_rect(Rect2(nw, se - nw), Color("#e1ece5"), false, 2.0)
    if is_instance_valid(player):
        var p := Vector2(player.position.x, -player.position.z)
        if _in_view(p):
            draw_circle(_map_pos(p), 7.0, Color("#ff934e"))
    _text(Vector2(18, 29), "FEARLESS KNIGHTS OF THE CORDON / PRE-ALPHA 0.3.9", Color("#f0e7db"), 20)
    _text(Vector2(18, 49), "ЧЕРНОЗЁРЬЕ / КАРТА ДЕРЕВНИ / 1400 × 1400 М / СЕВЕР ВВЕРХ", Color("#e4d0b2"), 13)
    _text(Vector2(18, 80), str(manual_features.size()) + " объектов пользователя / без процедурной генерации", Color("#ffd1a1"), 15)
    _text(Vector2(18, 111), "Здания — оранжевые, участки — контуры, лес — зелёный, дороги — бежевые", Color("#bacdc5"), 12)
    var bar_origin := Vector2(nw.x + 24.0, se.y - 26.0)
    var bar_width := (_map_pos(_view_center() + Vector2(100.0, 0.0)) - _map_pos(_view_center())).x
    draw_line(bar_origin, bar_origin + Vector2(bar_width, 0.0), Color.WHITE, 3.0)
    _text(bar_origin + Vector2(4.0, -6.0), "100 м", Color.WHITE, 13)
    _text(Vector2(18.0, size.y - 12.0), "GEO LAB 2.0 → Godot 2.1 / Плоский рельеф, примерные высоты", Color("#c7d5cc"), 12)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.036, 0.035, 0.97))
    var c := _view_center()
    var h := _view_half()
    var nw := _map_pos(c + Vector2(-h, h))
    var se := _map_pos(c + Vector2(h, -h))
    # Unmapped territory is not automatically classified as forest.
    draw_rect(Rect2(nw, se - nw), Color("#3a403b"))
    # OpenStreetMap forest polygons are mapped evidence, but coverage is incomplete.
    for feature in osm_features:
        if not feature is Dictionary or feature.get("type", "") != "forest":
            continue
        var forest_polygon := PackedVector2Array()
        for point in feature.get("points", []):
            forest_polygon.append(Vector2(float(point[0]), float(point[1])))
        _poly(forest_polygon, Color("#29473a"))
    var tick_step := 100 if show_manual else (50 if neighborhood_zoom else (100 if sector_a_zoom else 500))
    for tick in range(-2000, 2001, tick_step):
        _line(PackedVector2Array([Vector2(float(tick), -HALF), Vector2(float(tick), HALF)]), Color(1, 1, 1, 0.12), 1.0)
        _line(PackedVector2Array([Vector2(-HALF, float(tick)), Vector2(HALF, float(tick))]), Color(1, 1, 1, 0.12), 1.0)
    if show_manual:
        _draw_manual_survey(nw, se)
        return
    if is_instance_valid(geo):
        # Historical settlement polygons are illustrative and often omit real homes.
        # Hide these masks in sector A inspection mode; rely on Overture outlines.
        if not sector_a_zoom:
            for zone in geo.settlements:
                _poly(zone, Color("#858576"))
        _poly(geo.meadow, Color("#8b9971"))
        _poly(geo.meadow_island, Color("#365644"))
        _line(geo.field_track, Color("#d0b992"), 1.5)
        _line(geo.river_path, Color("#6fbbdc"), 11.0)
        _poly(geo.lake_outline, Color("#477f9b"))
        if show_houses:
            var meters_to_pixels := (_map_pos(Vector2(1.0, 0.0)) - _map_pos(Vector2.ZERO)).x
            for house in geo.house_footprints:
                var world_center: Vector2 = house["center"]
                if not _in_view(world_center):
                    continue
                var center: Vector2 = _map_pos(world_center)
                var footprint := Vector2(
                    maxf(4.0, float(house["width"]) * meters_to_pixels),
                    maxf(4.0, float(house["depth"]) * meters_to_pixels)
                )
                draw_set_transform(center, float(house["angle"]), Vector2.ONE)
                draw_rect(Rect2(-footprint * 0.5, footprint), Color("#ffce80"))
            draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    for feature in osm_features:
        if not feature is Dictionary or feature.get("type", "") != "road":
            continue
        var path := PackedVector2Array()
        for point in feature.get("points", []):
            path.append(Vector2(float(point[0]), float(point[1])))
        var kind: String = str(feature.get("tags", {}).get("highway", ""))
        var major := kind in ["trunk", "motorway", "primary"]
        _line(path, Color("#c0c5c0") if major else Color("#d3ba8a"), 3.0 if major else 2.0)
    var visible_overbuilding_count := 0
    if show_overture_buildings:
        # At neighbourhood scale, pale fills expose actual building footprints;
        # at 2 km they are outlines to avoid unreadable overlapping pixels.
        for feature in overture_buildings:
            if not feature is Dictionary:
                continue
            var shape_points: Array = feature.get("points", [])
            if shape_points.size() < 3:
                continue
            var outline := PackedVector2Array()
            var center := Vector2.ZERO
            for pt in shape_points:
                var p := Vector2(float(pt[0]), float(pt[1]))
                outline.append(p)
                center += p
            center /= float(outline.size())
            if not _in_view(center):
                continue
            visible_overbuilding_count += 1
            if sector_a_zoom or neighborhood_zoom:
                _poly(outline, Color("#d994cf"))
            outline.append(outline[0])
            _line(outline, Color("#f1bee9"), 1.0 if not neighborhood_zoom else 1.8)
    if show_osm_buildings:
        # OSM outlines are real mapped contributions but can be outdated/incomplete.
        # Do not confuse them with the provisional yellow house layer.
        for feature in osm_features:
            if not feature is Dictionary or feature.get("type", "") != "building":
                continue
            var outline := PackedVector2Array()
            for point in feature.get("points", []):
                outline.append(Vector2(float(point[0]), float(point[1])))
            if outline.size() >= 3:
                outline.append(outline[0])
                _line(outline, Color("#75e1e0"), 2.0)
    if is_instance_valid(geo):
        # Render only the extra sketched roads here, not the OSM lines twice.
        for route in geo.sketch_roads:
            var path := PackedVector2Array()
            for p in route:
                path.append(Vector2(float(p[0]), float(p[1])))
            _line(path, Color("#c58e66"), 1.7)
    draw_rect(Rect2(nw, se - nw), Color("#d7dbcf"), false, 2.0)
    var marks := [
        [Vector2(130, 82), "START"],
        [Vector2(100, 720), "CAMP"],
        [Vector2(715, -800), "LAKE BASE"],
        [Vector2(975, 120), "EXIT?"]
    ]
    for mark in marks:
        if not _in_view(mark[0]):
            continue
        var p := _map_pos(mark[0])
        draw_circle(p, 4.0, Color("#f5d17e"))
        _text(p + Vector2(7, -6), str(mark[1]), Color("#f5e5bd"), 11)
    if is_instance_valid(player):
        var player_map_pos := Vector2(player.position.x, -player.position.z)
        if _in_view(player_map_pos):
            var p := _map_pos(player_map_pos)
            draw_circle(p, 7.0, Color("#ff9149"))
            draw_arc(p, 9.0, 0.0, TAU, 24, Color("#191d1b"), 2.0)
    _text(Vector2(18, 29), "FEARLESS KNIGHTS OF THE CORDON / PRE-ALPHA 0.3.9", Color("#f2ead8"), 20)
    var map_scale := "КВАРТАЛ СЕКТОРА A / 300 x 300 м" if neighborhood_zoom else ("СЕКТОР A / 680 x 680 м" if sector_a_zoom else "2 x 2 km")
    _text(Vector2(18, 49), map_scale + "  |  N UP  |  M = close  |  H = toggle houses", Color("#c2cfc0"))
    var house_status := "УСЛОВНЫЕ ДОМА: ПОКАЗАНЫ" if show_houses else "УСЛОВНЫЕ ДОМА: СКРЫТЫ"
    _text(Vector2(18, 77), house_status, Color("#ffce80") if show_houses else Color("#c0c7c0"), 16)
    if sector_a_zoom or neighborhood_zoom:
        _text(Vector2(18, 100), "Розовые пятна = геоданные зданий; высоты в 3D приблизительные", Color("#e7a9df"), 13)
    _text(Vector2(18, 119), "Overture: " + str(visible_overbuilding_count) + " в кадре / " + str(overture_buildings.size()) + " всего", Color("#bdc9c5"), 12)
    # Scale bar is tied to projected metres, not the screen width.
    var ruler_m := 50.0 if neighborhood_zoom else (100.0 if sector_a_zoom else 250.0)
    var ruler_px := (_map_pos(_view_center() + Vector2(ruler_m, 0.0)) - _map_pos(_view_center())).x
    var ruler_y := se.y - 23.0
    draw_line(Vector2(nw.x + 22.0, ruler_y), Vector2(nw.x + 22.0 + ruler_px, ruler_y), Color("#faf5e7"), 3.0)
    draw_line(Vector2(nw.x + 22.0, ruler_y - 4.0), Vector2(nw.x + 22.0, ruler_y + 4.0), Color("#faf5e7"), 2.0)
    draw_line(Vector2(nw.x + 22.0 + ruler_px, ruler_y - 4.0), Vector2(nw.x + 22.0 + ruler_px, ruler_y + 4.0), Color("#faf5e7"), 2.0)
    _text(Vector2(nw.x + 28.0, ruler_y - 7.0), str(int(ruler_m)) + " м", Color("#faf5e7"), 13)
    _text(Vector2(18, size.y - 27), "OSM forests: dark green  |  OSM roads: light  |  Sketched roads: orange  |  Field: pale green", Color("#c9d3c8"), 12)
    _text(Vector2(18, size.y - 10), "Buildings: Overture coordinates, approximate 3D heights | Google imagery not imported", Color("#d3b4a0"), 11)
