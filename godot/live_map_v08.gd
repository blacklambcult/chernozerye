extends Control
# Live, engine-drawn geographic comparison map. Illustrative polygons are not surveyed.
const HALF := 1000.0
var world: Node3D
var geo: Node3D
var player: Node3D
var osm_features: Array = []

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

func _poly(points: PackedVector2Array, tint: Color) -> void:
    if points.size() < 3:
        return
    var converted := PackedVector2Array()
    for p in points:
        converted.append(_map_pos(p))
    draw_colored_polygon(converted, tint)

func _line(points: PackedVector2Array, tint: Color, width: float = 2.0) -> void:
    if points.size() < 2:
        return
    var converted := PackedVector2Array()
    for p in points:
        converted.append(_map_pos(p))
    draw_polyline(converted, tint, width, true)

func _text(p: Vector2, text: String, color: Color = Color.WHITE, font_size: int = 13) -> void:
    draw_string(ThemeDB.fallback_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.036, 0.035, 0.97))
    var nw := _map_pos(Vector2(-HALF, HALF))
    var se := _map_pos(Vector2(HALF, -HALF))
    draw_rect(Rect2(nw, se - nw), Color("#415447"))
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
        _line(geo.river_path, Color("#6fbbdc"), 11.0)
        var lake := PackedVector2Array()
        for i in range(36):
            var a := float(i) * TAU / 36.0
            lake.append(geo.lake_center + Vector2(cos(a) * 125.0, sin(a) * 92.0))
        _poly(lake, Color("#477f9b"))
        for h in geo.house_positions:
            var c := _map_pos(h)
            draw_rect(Rect2(c - Vector2(1.3, 1.3), Vector2(2.6, 2.6)), Color("#dfbc9e"))
    for feature in osm_features:
        if not feature is Dictionary or feature.get("type", "") != "road":
            continue
        var path := PackedVector2Array()
        for point in feature.get("points", []):
            path.append(Vector2(float(point[0]), float(point[1])))
        _line(path, Color("#d3ba8a"), 2.0)
    if is_instance_valid(geo):
        for route in geo.roads:
            var path := PackedVector2Array()
            for p in route:
                path.append(Vector2(float(p[0]), float(p[1])))
            _line(path, Color("#b49c78"), 1.2)
    draw_rect(Rect2(nw, se - nw), Color("#d7dbcf"), false, 2.0)
    var marks := [
        [Vector2(90, 20), "START"],
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
    _text(Vector2(18, 29), "CHERNOZERYE / LIVE MAP 0.8", Color("#f2ead8"), 20)
    _text(Vector2(18, 49), "2 x 2 km  |  N UP  |  M = close", Color("#c2cfc0"))
    _text(Vector2(18, size.y - 27), "Beige: settlements/roads  |  Green: field/forest  |  Blue: water  |  Orange: player", Color("#c9d3c8"), 12)
    _text(Vector2(18, size.y - 10), "Roads: OSM + rough sketches; houses/forest/water: provisional artistic blockout", Color("#d3b4a0"), 11)
