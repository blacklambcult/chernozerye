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
    card.anchor_top = 0.05
    card.anchor_right = 0.5
    card.anchor_bottom = 0.95
    card.offset_left = -246
    card.offset_right = 246
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

    var scroll := ScrollContainer.new()
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    margin.add_child(scroll)

    var items := VBoxContainer.new()
    items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    items.add_theme_constant_override("separation", 8)
    scroll.add_child(items)
    items.add_child(_make_label("ЧЕРНОЗЁРЬЕ", 27, INK))
    items.add_child(_make_label("FEARLESS KNIGHTS OF THE CORDON", 11, MUTED))
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

    var graphics := player.get_parent().get_node_or_null("PS1Effects")
    if graphics != null:
        var effects := HBoxContainer.new()
        items.add_child(effects)
        _add_graphics_toggle(effects, "PS1 Jitter", "PS1Jitter", graphics.set_jitter, graphics.jitter_enabled)
        _add_graphics_toggle(effects, "PS1 Пиксели", "PS1Pixels", graphics.set_pixels, graphics.pixels_enabled)
        _add_strength_row(items, "СИЛА ПИКСЕЛИЗАЦИИ", "PS1PixelStrength", graphics.pixel_strength, graphics.set_pixel_strength)
        _add_strength_row(items, "СИЛА JITTER", "PS1JitterStrength", graphics.jitter_strength, graphics.set_jitter_strength)

        var targets := GridContainer.new()
        targets.columns = 2
        items.add_child(targets)
        for target: StringName in graphics.JITTER_CONTROLS:
            var toggle := CheckBox.new()
            toggle.name = "JitterTarget_" + String(target)
            toggle.text = graphics.JITTER_CONTROLS[target]
            toggle.button_pressed = graphics.jitter_targets[target]
            toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            toggle.toggled.connect(func(enabled: bool) -> void:
                graphics.set_jitter_target(target, enabled)
            )
            targets.add_child(toggle)

    items.add_child(_make_label("WASD — идти    SHIFT — бег    C — тихий шаг    МЫШЬ — осмотр", 13, MUTED))
    items.add_child(_make_label("E — взаимодействие    J — журнал    M — карта", 13, MUTED))
    items.add_child(_make_label("ESC — вернуться к игре", 13, ACCENT))
    backdrop.visible = false


func _add_strength_row(items: VBoxContainer, title: String, node_name: String,
        value: float, apply: Callable) -> void:
    var row := HBoxContainer.new()
    items.add_child(row)
    var label := _make_label(title, 13, INK)
    label.custom_minimum_size.x = 175
    row.add_child(label)
    var slider := HSlider.new()
    slider.name = node_name
    slider.max_value = 100.0
    slider.step = 1.0
    slider.value = value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    row.add_child(slider)
    var readout := _make_label("%d%%" % int(value), 14, ACCENT)
    readout.custom_minimum_size.x = 45
    readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    row.add_child(readout)
    slider.value_changed.connect(func(strength: float) -> void:
        apply.call(strength)
        readout.text = "%d%%" % int(strength)
    )


func _add_graphics_toggle(row: HBoxContainer, label: String, node_name: String,
        apply: Callable, enabled: bool) -> void:
    var toggle := CheckButton.new()
    toggle.name = node_name
    toggle.text = label
    toggle.button_pressed = enabled
    toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    toggle.toggled.connect(apply)
    row.add_child(toggle)


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
