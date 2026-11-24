extends CanvasLayer

const SAMPLE_WINDOW_USEC := 2_000_000
const MIB := 1048576.0
const RENDER_GROUPS := [&"perf_fences", &"perf_buildings", &"perf_roadside", &"perf_forest_vegetation"]
const RENDER_MODES := ["Вся сцена", "Без заборов", "Без моделей зданий", "Без деталей обочины", "Без растительности леса"]

var _render_mode := 0
var _hidden_meshes: Array[Node3D] = []

var _panel := PanelContainer.new()
var _metrics := Label.new()
var _frame_times := PackedFloat64Array()
var _previous_frame_usec := 0
var _window_start_usec := 0


func _ready() -> void:
    layer = 100
    add_child(_panel)
    _panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
    _panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
    _panel.grow_vertical = Control.GROW_DIRECTION_BOTH
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.06, 0.07, 0.07, 0.92)
    background.content_margin_left = 12.0
    background.content_margin_right = 12.0
    background.content_margin_top = 8.0
    background.content_margin_bottom = 8.0
    _panel.add_theme_stylebox_override("panel", background)
    _metrics.add_theme_font_size_override("font_size", 14)
    _metrics.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_metrics)
    _panel.hide()
    set_process(false)


func _input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    if event.keycode == KEY_F8:
        _panel.visible = not _panel.visible
        if not _panel.visible:
            _show_full_scene()
        set_process(_panel.visible)
    elif event.keycode == KEY_F9 and _panel.visible:
        var next_mode := (_render_mode + 1) % RENDER_MODES.size()
        _show_full_scene()
        _render_mode = next_mode
        if _render_mode > 0:
            for mesh: Node3D in get_tree().get_nodes_in_group(RENDER_GROUPS[_render_mode - 1]):
                if mesh.visible:
                    mesh.hide()
                    _hidden_meshes.append(mesh)
    else:
        return
    _reset_sample()
    get_viewport().set_input_as_handled()


func _show_full_scene() -> void:
    for mesh in _hidden_meshes:
        if is_instance_valid(mesh):
            mesh.show()
    _hidden_meshes.clear()
    _render_mode = 0


func _heading() -> String:
    return "F8 · Performance Lab\nF9 · %s" % RENDER_MODES[_render_mode]


func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_IN:
        _reset_sample()


func _reset_sample() -> void:
    _previous_frame_usec = 0
    _window_start_usec = 0
    _frame_times.clear()
    if _panel.visible:
        _metrics.text = _heading() + "\nСбор замеров…"


func _process(_delta: float) -> void:
    if not get_window().has_focus():
        return
    var now := Time.get_ticks_usec()
    if _previous_frame_usec == 0:
        _previous_frame_usec = now
        _window_start_usec = now
        return

    _frame_times.append((now - _previous_frame_usec) / 1000.0)
    _previous_frame_usec = now
    var elapsed := now - _window_start_usec
    if elapsed < SAMPLE_WINDOW_USEC:
        return

    var fps := _frame_times.size() * 1_000_000.0 / elapsed
    _frame_times.sort()
    var p95_index := ceili(_frame_times.size() * 0.95) - 1
    var draw_calls := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
    var primitives := Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
    var memory := Performance.get_monitor(Performance.MEMORY_STATIC)
    var memory_text := "%.1f МиБ" % (memory / MIB) if memory > 0 else "н/д"
    _metrics.text = "\n".join([
        _heading(),
        "%.1f FPS   |   p95 %.1f мс" % [fps, _frame_times[p95_index]],
        "Draw calls / кадр    %d" % draw_calls,
        "Примитивы / кадр     %d" % primitives,
        "Узлы Godot          %d" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
        "Память Godot        %s" % memory_text,
    ])
    _frame_times.clear()
    _window_start_usec = now
