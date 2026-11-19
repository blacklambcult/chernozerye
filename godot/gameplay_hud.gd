extends Control
# Minimal survival HUD. All drawing is anchored to the viewport rather than
# fixed 1920x1080 positions: quest text is owned by StoryPrologue.
# Zero gameplay stats are implied: initial HP is a placeholder only.

const INK := Color("#eee5d4")
const MUTED := Color("#acafa8")
const FRAME := Color(0.10, 0.115, 0.115, 0.84)
const FRAME_STROKE := Color("#655f54")
const GOLD := Color("#d4b886")
const HEALTH := Color("#9e5548")
const SLOT_COUNT := 4
const COMPASS_SPAN := 142.0
const COMPASS_HALF := 226.0

var player: CharacterBody3D
var current_health := 100.0
var max_health := 100.0
var selected_slot := 0
var draw_count := 0

func _ready() -> void:
    name = "SurvivalHUD"
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    player = get_parent().get_parent().get_node_or_null("Player") as CharacterBody3D
    print("SURVIVAL_HUD_READY: compass=center hp=100 hotbar=4 cigarette_pack=slot1")

func choose_slot(n: int) -> void:
    if n < 0 or n >= SLOT_COUNT:
        return
    selected_slot = n
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _font() -> Font:
    return ThemeDB.fallback_font

func _write(x: float, y: float, value: String, text_size: int,
        tint: Color = INK) -> void:
    draw_string(_font(), Vector2(x, y), value,
        HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, tint)

func _heading_degrees() -> float:
    if player == null:
        return 0.0
    # Camera faces -Z when body yaw is zero. Positive heading rotates east.
    return fposmod(-rad_to_deg(player.rotation.y), 360.0)

func _compass_name(degrees: int) -> String:
    match posmod(degrees, 360):
        0:
            return "N"
        90:
            return "E"
        180:
            return "S"
        270:
            return "W"
    return ""

func _draw_compass(view_width: float) -> void:
    var center := view_width * 0.5
    var top := 12.0
    draw_rect(Rect2(center - COMPASS_HALF - 14.0, top - 4.0,
        (COMPASS_HALF + 14.0) * 2.0, 47.0), FRAME, true)
    draw_line(Vector2(center - COMPASS_HALF, top + 34),
        Vector2(center + COMPASS_HALF, top + 34), FRAME_STROKE, 1.0)
    var heading := _heading_degrees()
    for i in range(24):
        var angle := i * 15
        var delta := wrapf(float(angle) - heading, -180.0, 180.0)
        if absf(delta) > COMPASS_SPAN * 0.5:
            continue
        var x := center + delta * (COMPASS_HALF / (COMPASS_SPAN * 0.5))
        var cardinal := _compass_name(angle)
        if cardinal != "":
            _write(x - 6.0, top + 22.0, cardinal, 16, GOLD)
            draw_line(Vector2(x, top + 26.0),
                Vector2(x, top + 33.0), GOLD, 1.5)
        else:
            var length := 8.0 if angle % 30 == 0 else 4.0
            draw_line(Vector2(x, top + 33.0 - length),
                Vector2(x, top + 33.0), MUTED, 1.0)
    # Static centered chevron shows where the player looks.
    draw_colored_polygon(PackedVector2Array([
        Vector2(center - 6, top + 43),
        Vector2(center + 6, top + 43),
        Vector2(center, top + 33)
    ]), GOLD)
    _draw_quest_bearing(center, top, heading)

func _draw_quest_bearing(center: float, top: float, heading: float) -> void:
    var story := get_parent().get_parent().get_node_or_null("StoryPrologue")
    if story == null or player == null or bool(story.get("chapter_completed")):
        return
    if bool(story.get("inside_home")):
        return
    var gate: Vector3 = story.call("_gate_location")
    var direction := gate - player.global_position
    if Vector2(direction.x, direction.z).length() < 1.5:
        return
    var bearing := fposmod(rad_to_deg(atan2(direction.x, -direction.z)), 360.0)
    var delta := wrapf(bearing - heading, -180.0, 180.0)
    if absf(delta) > COMPASS_SPAN * 0.5:
        return
    var x := center + delta * (COMPASS_HALF / (COMPASS_SPAN * 0.5))
    draw_colored_polygon(PackedVector2Array([
        Vector2(x, top + 2),
        Vector2(x + 5, top + 7),
        Vector2(x, top + 12),
        Vector2(x - 5, top + 7)
    ]), Color("#e6c38d"))

func _draw_health(view_height: float) -> void:
    var x := 18.0
    var y := view_height - 69.0
    draw_rect(Rect2(x - 7.0, y - 24.0, 231.0, 70.0), FRAME)
    _write(x, y - 3.0, "ЗДОРОВЬЕ", 13, MUTED)
    _write(x + 145.0, y - 3.0, "%d / %d" % [
        int(current_health), int(max_health)], 13)
    draw_rect(Rect2(x, y + 8, 205, 12), FRAME_STROKE)
    draw_rect(Rect2(x + 2, y + 10,
        201 * clampf(current_health / maxf(1.0, max_health), 0.0, 1.0),
        8), HEALTH)

func _draw_slots(view_width: float, view_height: float) -> void:
    var x0 := view_width - 4.0 * 62.0 - 18.0
    var y := view_height - 84.0
    draw_rect(Rect2(x0 - 8.0, y - 28.0, 263.0, 98.0), FRAME)
    _write(x0, y - 9.0, "БЫСТРЫЕ ПРЕДМЕТЫ", 12, MUTED)
    for index in range(SLOT_COUNT):
        var x := x0 + float(index) * 62.0
        var chosen := index == selected_slot
        draw_rect(Rect2(x, y, 56, 56),
            Color(0.19, 0.20, 0.19, 0.94), true)
        draw_rect(Rect2(x, y, 56, 56),
            GOLD if chosen else FRAME_STROKE, false, 2.0 if chosen else 1.0)
        _write(x + 5.0, y + 15.0, str(index + 1), 12,
            GOLD if chosen else MUTED)
        if index == 0:
            # Fictional unbranded inventory icon: simple cream cardboard pack.
            draw_rect(Rect2(x + 19, y + 16, 24, 31), Color("#d6cabb"))
            draw_rect(Rect2(x + 19, y + 31, 24, 8), Color("#97735f"))
            draw_rect(Rect2(x + 22, y + 18, 18, 2), Color("#f1ede1"))
        elif index == 1:
            draw_line(Vector2(x+10,y+25),Vector2(x+41,y+25),INK,4)
            draw_circle(Vector2(x+31,y+29),6,GOLD)
            draw_line(Vector2(x+39,y+28),Vector2(x+44,y+40),Color("#a37c57"),6)
        else:
            draw_line(Vector2(x + 20, y + 31),
                Vector2(x + 37, y + 31), Color("#565850"), 1.0)
    if selected_slot == 1 and player != null:
        var gun: Node3D = player.get("revolver")
        var status := "ПЕРЕЗАРЯДКА" if float(gun.get("reload_left")) > 0 else "%d / 6" % int(gun.get("rounds"))
        _write(x0, y + 72, status + "    ЛКМ — ОГОНЬ    R — ЗАРЯДИТЬ", 11, GOLD)
        draw_circle(size * 0.5, 1.6, INK)
    else:
        _write(x0, y + 72, "1 ПАЧКА · V ДЕЙСТВИЕ     2 РЕВОЛЬВЕР", 11, MUTED)

func _draw() -> void:
    if size.x < 320.0 or size.y < 240.0:
        return
    draw_count += 1
    _draw_compass(size.x)
    _draw_health(size.y)
    _draw_slots(size.x, size.y)
