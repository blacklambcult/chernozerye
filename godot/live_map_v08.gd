extends Control
# Live, engine-drawn geographic comparison map. Illustrative polygons are not surveyed.
const HALF := 1000.0
var world: Node3D
var geo
var player: Node3D
var osm_features: Array = []
var show_houses := false

func initialize(world_node: Node3D, geo_node: Node3D, player_node: Node3D, features: Array) -> void:
    world = world_node
    geo = geo_node
    player = player_node
    osm_features = features

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
    if visible:
        queue_redraw()

func _map_pos(p: Vector2) -> Vector2:
    var side: float = maxf(10.0, minf(size.x - 36.0, size.y - 98.0))
    var origin := Vector2((size.x - side) * 0.5, 60.0 + maxf(0.0, (size.y - 98.0 - side) * 0.5))
    return origin + Vector2((p.x + HALF) * side / (2.0 * HALF), (HALF - p.y) * side / (2.0 * HALF))

# Clip all geometry to the 2 x 2 km study square before drawing.
# Source OSM ways extend beyond the square and must not appear outside its frame.
func _bounds() -> PackedVector2Array:
    return PackedVector2Array([
        Vector2(-HALF, -HALF), Vector2(HALF, -HALF),
        Vector2(HALF, HALF), Vector2(-HALF, HALF)
    ])

func _poly(points: PackedVector2Array, tint: Color) -> void:
    if points.size() < 3:
        return
    var all_inside := true
    for p in points:
        if absf(p.x) > HALF or absf(p.y) > HALF:
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
    var q_values := [a.x + HALF, HALF - a.x, a.y + HALF, HALF - a.y]
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

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.036, 0.035, 0.97))
    var nw := _map_pos(Vector2(-HALF, HALF))
    var se := _map_pos(Vector2(HALF, -HALF))
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
    for tick in range(-1000, 1001, 500):
        var a := _map_pos(Vector2(float(tick), -HALF))
        var b := _map_pos(Vector2(float(tick), HALF))
        draw_line(a, b, Color(1, 1, 1, 0.12), 1.0)
        a = _map_pos(Vector2(-HALF, float(tick)))
        b = _map_pos(Vector2(HALF, float(tick)))
        draw_line(a, b, Color(1, 1, 1, 0.12), 1.0)
    if is_instance_valid(geo):
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
                var center: Vector2 = _map_pos(house["center"])
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
        var p := _map_pos(mark[0])
        draw_circle(p, 4.0, Color("#f5d17e"))
        _text(p + Vector2(7, -6), str(mark[1]), Color("#f5e5bd"), 11)
    if is_instance_valid(player):
        var p := _map_pos(Vector2(player.position.x, -player.position.z))
        draw_circle(p, 7.0, Color("#ff9149"))
        draw_arc(p, 9.0, 0.0, TAU, 24, Color("#191d1b"), 2.0)
    _text(Vector2(18, 29), "CHERNOZERYE / LIVE MAP 1.4", Color("#f2ead8"), 20)
    _text(Vector2(18, 49), "2 x 2 km  |  N UP  |  M = close  |  H = toggle houses", Color("#c2cfc0"))
    var house_status := "ДОМА НА СХЕМЕ: ПОКАЗАНЫ" if show_houses else "ДОМА НА СХЕМЕ: СКРЫТЫ"
    _text(Vector2(18, 77), house_status, Color("#ffce80") if show_houses else Color("#c0c7c0"), 16)
    _text(Vector2(18, size.y - 27), "OSM forests: dark green  |  OSM roads: light  |  Sketched roads: orange  |  Field: pale green", Color("#c9d3c8"), 12)
    _text(Vector2(18, size.y - 10), "Unmapped areas are unknown, not necessarily forest | Field / homes / river are approximate", Color("#d3b4a0"), 11)
