extends CanvasLayer
# In-game pause overlay: it owns Esc while the World remains paused.
# No game progress is reset when returning from this panel.

const INK := Color("#e7dfce")
const MUTED := Color("#a7a9a2")
const ACCENT := Color("#c7a774")
const BASE_SENSITIVITY := 0.002

var player: CharacterBody3D
var backdrop: ColorRect
var sensitivity_readout: Label
var sensitivity_slider: HSlider
const AUDIO_CONFIG := "user://audio.cfg"
var audio_settings := ConfigFile.new()
var is_open := false
var was_captured := false


func _make_label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    return label


func _ready() -> void:
    name = "PauseOverlay"
    layer = 90
    process_mode = Node.PROCESS_MODE_ALWAYS
    player = get_parent() as CharacterBody3D
    audio_settings.load(AUDIO_CONFIG)
    _build_ui()
    print("PAUSE_OVERLAY_READY: esc=toggle world_pauses=true sensitivity=true")


func _build_ui() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "PauseBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.025, 0.032, 0.031, 0.86)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    var card := PanelContainer.new()
    card.name = "PauseCard"
    card.anchor_left = 0.5
    card.anchor_top = 0.5
    card.anchor_right = 0.5
    card.anchor_bottom = 0.5
    card.offset_left = -246
    card.offset_top = -215
    card.offset_right = 246
    card.offset_bottom = 215
    var border := StyleBoxFlat.new()
    border.bg_color = Color("#171d1b")
    border.border_color = Color("#716655")
    border.set_border_width_all(1)
    card.add_theme_stylebox_override("panel", border)
    backdrop.add_child(card)

    var margin := MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 27)
    margin.add_theme_constant_override("margin_right", 27)
    margin.add_theme_constant_override("margin_top", 24)
    margin.add_theme_constant_override("margin_bottom", 24)
    card.add_child(margin)

    var items := VBoxContainer.new()
    items.add_theme_constant_override("separation", 12)
    margin.add_child(items)
    items.add_child(_make_label("ЧЕРНОЗЁРЬЕ", 27, INK))
    items.add_child(_make_label("FEARLESS KNIGHTS OF THE CORDON / PRE-ALPHA 0.7.0", 11, MUTED))
    items.add_child(_make_label("ПАУЗА", 18, ACCENT))

    var resume := Button.new()
    resume.name = "ResumeButton"
    resume.text = "ПРОДОЛЖИТЬ ИГРУ"
    resume.custom_minimum_size = Vector2(0, 43)
    resume.pressed.connect(close_pause)
    items.add_child(resume)

    items.add_child(_make_label("ЧУВСТВИТЕЛЬНОСТЬ МЫШИ", 13, INK))
    var sensitivity_row := HBoxContainer.new()
    sensitivity_row.add_theme_constant_override("separation", 13)
    items.add_child(sensitivity_row)
    sensitivity_slider = HSlider.new()
    sensitivity_slider.name = "SensitivitySlider"
    sensitivity_slider.min_value = 0.5
    sensitivity_slider.max_value = 1.8
    sensitivity_slider.step = 0.1
    sensitivity_slider.value = 1.0
    sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sensitivity_slider.custom_minimum_size = Vector2(240, 25)
    sensitivity_row.add_child(sensitivity_slider)
    sensitivity_readout = _make_label("1.0x", 14, ACCENT)
    sensitivity_row.add_child(sensitivity_readout)
    sensitivity_slider.value_changed.connect(_on_sensitivity_changed)

    _add_volume_row(items, &"Effects", "ГРОМКОСТЬ ЗВУКОВ")
    _add_volume_row(items, &"Music", "ГРОМКОСТЬ МУЗЫКИ")

    items.add_child(_make_label("WASD — идти    SHIFT — бег    C — тихий шаг    МЫШЬ — осмотр", 13, MUTED))
    items.add_child(_make_label("E — взаимодействие    J — журнал    M — карта", 13, MUTED))
    items.add_child(_make_label("ESC — вернуться к игре", 13, ACCENT))
    backdrop.visible = false


func _add_volume_row(items: VBoxContainer, bus: StringName, title: String) -> void:
    var row := HBoxContainer.new()
    items.add_child(row)
    var label := _make_label(title, 13, INK)
    label.custom_minimum_size.x = 155
    row.add_child(label)
    var slider := HSlider.new()
    slider.name = str(bus) + "Volume"
    slider.tooltip_text = title
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(slider)
    var readout := _make_label("", 14, ACCENT)
    readout.custom_minimum_size.x = 45
    readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(readout)
    slider.value = clampf(float(audio_settings.get_value("volume", bus, 100)), 0, 100)
    var index := AudioServer.get_bus_index(bus)
    var apply := func(value: float) -> void:
        AudioServer.set_bus_mute(index, value == 0)
        AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 1.0) / 100.0))
        readout.text = "%d%%" % int(value)
    apply.call(slider.value)
    slider.value_changed.connect(func(value: float) -> void:
        apply.call(value)
        audio_settings.set_value("volume", bus, int(value))
        audio_settings.save(AUDIO_CONFIG)
    )


func _on_sensitivity_changed(multiplier: float) -> void:
    if player != null:
        player.set("mouse_sensitivity", BASE_SENSITIVITY * multiplier)
    if sensitivity_readout != null:
        sensitivity_readout.text = "%.1fx" % multiplier


func open_pause() -> void:
    if is_open or get_tree().paused:
        return
    was_captured = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    is_open = true
    backdrop.visible = true
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    get_tree().paused = true


func close_pause() -> void:
    if not is_open:
        return
    get_tree().paused = false
    backdrop.visible = false
    is_open = false
    Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED if was_captured
        else Input.MOUSE_MODE_VISIBLE)


func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
            if is_open:
                close_pause()
            else:
                open_pause()
            get_viewport().set_input_as_handled()
