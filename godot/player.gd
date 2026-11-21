extends CharacterBody3D

signal noise_emitted(at: Vector3, strength: float)

const QUIET_SPEED := 1.45
const EARTH_STEP := preload("res://step_earth.wav")
const BOARD_STEP := preload("res://step_boards.wav")
const SPEED := 3.35
const SPRINT_SPEED := 5.15
const WALK_ACCELERATION := 9.0
const WALK_FRICTION := 12.0
const JUMP := 4.5
const MOUSE_SENS := 0.002
const TEST_WEAPONS := [
    {"class": "revolver", "label": "РЕВОЛЬВЕР", "short": "РЕВ",
     "model": preload("res://assets/weapon_test/revolver.glb"), "scale": 0.95,
     "capacity": 6, "damage": 28, "recoil": 1.25, "reload": 2.2, "weight": 1.2,
     "sound": "heavy"},
    {"class": "pistol", "label": "ПИСТОЛЕТ", "short": "ПСТ",
     "model": preload("res://assets/weapon_test/pistol.glb"), "scale": 0.95,
     "capacity": 8, "damage": 20, "recoil": 1.0, "reload": 1.2, "weight": 0.9,
     "sound": "standard"},
    {"class": "smg", "label": "ПИСТОЛЕТ-ПУЛЕМЁТ", "short": "ПП",
     "model": preload("res://assets/weapon_test/smg.glb"), "scale": 0.82,
     "capacity": 20, "damage": 16, "recoil": 0.8, "reload": 1.6, "weight": 2.3,
     "sound": "standard", "mode": "auto", "rate": 650},
    {"class": "assault", "label": "АВТОМАТ", "short": "АВТ",
     "model": preload("res://assets/weapon_test/assault.glb"), "scale": 0.7,
     "capacity": 30, "damage": 32, "recoil": 1.45, "reload": 1.8, "weight": 3.35,
     "sound": "heavy", "mode": "auto", "rate": 600},
    {"class": "boltrifle", "label": "БОЛТОВАЯ ВИНТОВКА", "short": "БОЛТ",
     "model": preload("res://assets/weapon_test/boltrifle.glb"), "scale": 0.64,
     "capacity": 5, "damage": 72, "recoil": 2.2, "reload": 2.4, "weight": 3.8,
     "sound": "heavy"},
    {"class": "semirifle", "label": "САМОЗАРЯДНАЯ ВИНТОВКА", "short": "САМ",
     "model": preload("res://assets/weapon_test/semirifle.glb"), "scale": 0.68,
     "capacity": 10, "damage": 48, "recoil": 1.75, "reload": 2.0, "weight": 3.65,
     "sound": "heavy"},
    {"class": "doubleshotgun", "label": "ДВУСТВОЛКА", "short": "ДВУ",
     "model": preload("res://assets/weapon_test/doubleshotgun.glb"), "scale": 0.84,
     "capacity": 2, "damage": 64, "recoil": 2.4, "reload": 2.6, "weight": 3.0,
     "sound": "heavy"},
    {"class": "pumpshotgun", "label": "ПОМПОВЫЙ ДРОБОВИК", "short": "ПОМП",
     "model": preload("res://assets/weapon_test/pumpshotgun.glb"), "scale": 0.72,
     "capacity": 6, "damage": 52, "recoil": 2.0, "reload": 2.8, "weight": 3.45,
     "sound": "heavy"},
]

var revolver := preload("res://revolver.gd").new()
var forge_pistol := preload("res://forge_pistol.gd").new()
var forge_weapons: Dictionary = {}
var test_loadout := false
var step_sound := AudioStreamPlayer.new()
var music := preload("res://location_music.gd").new()
var wind := AudioStreamPlayer.new()
var step_distance := 0.0
var noise_level := 0.0
var camera: Camera3D
var status_label: Label
var last_event := "none"
var pressed := {"w": false, "a": false, "s": false, "d": false, "m": false}
var map_open := false
var controls_locked := false
var mouse_sensitivity := MOUSE_SENS
# Narrative character animation is isolated from player movement and stats.
var _avatar: Node3D
var _modeled_character: Node3D
var recoil_pitch := 0.0
var recoil_recovery := 1.0
var recoil_roll := 0.0
var bodycam_offset := Vector2.ZERO
var bodycam_roll := 0.0
var bodycam_recovery := 1.0
var _inspection_camera: Camera3D
var _inspection_hint: Label
var _inspection_light: SpotLight3D
var _inspect_enabled := false
var _character_sequence: Node3D

func set_controls_locked(value: bool) -> void:
    controls_locked = value
    pressed = {"w": false, "a": false, "s": false, "d": false, "m": false}
    if controls_locked:
        velocity.x = 0.0
        velocity.z = 0.0

func _ready() -> void:
    add_child(music)
    step_sound.bus = &"Effects"
    wind.bus = &"Effects"
    add_child(step_sound)
    wind.stream = preload("res://village_wind.wav")
    wind.volume_db = -75.0
    add_child(wind)
    # The existing seamless wind WAV reads like a continuous waterfall on
    # headphones. Leave the player available for compatibility, but disabled.
    wind.stop()
    camera = Camera3D.new()
    camera.name = "Camera3D"
    camera.position.y = 1.55
    # A near plane of 0.05 made subpixel roof layers flicker in GL Compatibility.
    camera.near = 0.22
    camera.far = 2300.0
    camera.current = true
    add_child(camera)
    var collision := CollisionShape3D.new()
    collision.name = "CollisionShape3D"
    var shape := CapsuleShape3D.new()
    shape.height = 1.8
    shape.radius = 0.46
    collision.position.y = 0.9
    collision.shape = shape
    floor_snap_length = 0.18
    safe_margin = 0.015
    add_child(collision)
    Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    var hud := CanvasLayer.new()
    hud.layer = 30
    add_child(hud)
    status_label = Label.new()
    status_label.position = Vector2(14, 48)
    status_label.add_theme_color_override("font_color", Color("#fcf1bb"))
    status_label.add_theme_color_override("font_shadow_color", Color.BLACK)
    status_label.add_theme_constant_override("shadow_offset_x", 1)
    status_label.add_theme_constant_override("shadow_offset_y", 1)
    status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud.add_child(status_label)
    status_label.visible = false
    _avatar = Node3D.new()
    _avatar.name = "FirstPersonFullBody"
    _avatar.set_script(preload("res://first_person_body.gd"))
    add_child(_avatar)
    # No first-person body rendering. Keep this hidden compatibility node
    # for scripted cinematics only, never as a fallback for the model.
    _avatar.visible = false
    _avatar.set_process(false)
    _modeled_character = Node3D.new()
    _modeled_character.name = "ModeledCharacter"
    _modeled_character.set_script(preload("res://modeled_character.gd"))
    add_child(_modeled_character)
    camera.add_child(revolver)
    if test_loadout and OS.has_feature("web"):
        test_loadout = JavaScriptBridge.eval(
            "new URLSearchParams(location.search).get('forge')", true) != "local"
    if test_loadout:
        _load_test_weapons()
    else:
        camera.add_child(forge_pistol)
        forge_weapons[forge_pistol.inventory_slot] = forge_pistol
        _load_forge_slots()
    _character_sequence = Node3D.new()
    _character_sequence.name = "CharacterSmoking"
    _character_sequence.set_script(preload("res://character_smoking.gd"))
    camera.add_child(_character_sequence)
    # F4 inspection: camera faces the actual complete imported GLB from
    # three metres away. It is never used for first-person gameplay.
    _inspection_camera = Camera3D.new()
    _inspection_camera.name = "CharacterInspectionCamera"
    _inspection_camera.position = Vector3(0.0, 1.62, -3.20)
    _inspection_camera.near = 0.12
    _inspection_camera.far = 2300.0
    _inspection_camera.fov = 55.0
    add_child(_inspection_camera)
    _inspection_camera.look_at(global_position + Vector3(0, 1.04, 0), Vector3.UP)
    _inspection_camera.current = false
    _inspection_light = SpotLight3D.new()
    _inspection_light.name = "InspectionLight"
    _inspection_light.light_energy = 3.2
    _inspection_light.spot_range = 6.0
    _inspection_light.spot_angle = 50.0
    _inspection_camera.add_child(_inspection_light)
    _inspection_light.visible = false
    _inspection_hint = Label.new()
    _inspection_hint.name = "InspectionHint"
    _inspection_hint.text = "F4 — ВЕРНУТЬСЯ В ИГРУ    /    ДЕМБЕЛЬ, 2005"
    _inspection_hint.position = Vector2(24, 94)
    _inspection_hint.add_theme_color_override("font_color", Color("#e7dfce"))
    _inspection_hint.visible = false
    hud.add_child(_inspection_hint)
    var pause_overlay := CanvasLayer.new()
    pause_overlay.name = "PauseOverlay"
    pause_overlay.set_script(preload("res://pause_overlay.gd"))
    add_child(pause_overlay)

func _toggle_model_inspection() -> void:
    if _modeled_character == null or not bool(_modeled_character.get("model_loaded")):
        return
    if not _inspect_enabled and controls_locked:
        return
    _inspect_enabled = not _inspect_enabled
    _modeled_character.call("set_inspection_mode", _inspect_enabled)
    _inspection_camera.current = _inspect_enabled
    camera.current = not _inspect_enabled
    _inspection_light.visible = _inspect_enabled
    _inspection_hint.visible = _inspect_enabled
    _sync_equipped_weapons()
    _character_sequence.visible = not _inspect_enabled
    set_controls_locked(_inspect_enabled)
    if _inspect_enabled:
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
    print("CHARACTER_INSPECTION_MODE:", _inspect_enabled)


func _start_character_sequence() -> bool:
    if _character_sequence == null:
        return false
    var hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
    var slot := -1
    if hud != null:
        slot = int(hud.get("selected_slot"))
    return bool(_character_sequence.call("start_if_selected",slot,controls_locked))


func _armed_slot() -> bool:
    var hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
    return not test_loadout and hud != null and int(hud.get("selected_slot")) == 1

func _load_test_weapons() -> void:
    for index in range(TEST_WEAPONS.size()):
        var specs: Dictionary = TEST_WEAPONS[index]
        var sidearm := index < 2
        var weapon := forge_pistol if index == 0 else preload("res://forge_pistol.gd").new()
        weapon.test_label = specs["label"]
        weapon.test_slot_label = specs["short"]
        weapon.model_override = specs["model"]
        weapon.package_override = {
            "name": specs["label"], "slot": index + 3, "weaponType": specs["class"],
            "gameplay": specs,
            "viewmodel": {
                "position": [0.245, -0.235, -0.47] if sidearm else [0.255, -0.23, -0.57],
                "rotation": [0.0, 6.0, 0.0],
                "scale": specs["scale"],
                "hand_position": [0.012, 0.015, 0.025],
            },
        }
        camera.add_child(weapon)
        forge_weapons[weapon.inventory_slot] = weapon

func _load_forge_slots() -> void:
    if not OS.has_feature("web"):
        return
    var raw: Variant = JavaScriptBridge.eval("window.chernozeryeForgeSlots", true)
    for attempt in range(100):
        if raw is String:
            break
        await get_tree().create_timer(0.05).timeout
        raw = JavaScriptBridge.eval("window.chernozeryeForgeSlots", true)
    if not raw is String:
        return
    var records: Variant = JSON.parse_string(raw)
    if not records is Array:
        return
    for record in records.slice(0, 8):
        if not record is Dictionary:
            continue
        var slot_number: Variant = record.get("slot")
        if not (slot_number is int or slot_number is float):
            continue
        var slot := int(slot_number) - 1
        if slot < 2 or slot > 9 or float(slot + 1) != float(slot_number):
            continue
        var weapon := preload("res://forge_pistol.gd").new()
        if not weapon.accepts_package(record):
            weapon.free()
            continue
        weapon.package_override = record
        weapon.indoors = forge_pistol.indoors
        camera.add_child(weapon)
        if not weapon.custom_model_loaded:
            weapon.queue_free()
            continue
        var previous: Node3D = forge_weapons.get(slot)
        if previous != null:
            previous.hide()
            previous.queue_free()
            if forge_pistol == previous:
                forge_pistol = weapon
        forge_weapons[slot] = weapon
    _sync_equipped_weapons()

func _sync_equipped_weapons() -> void:
    revolver.equip(not _inspect_enabled and _armed_slot())
    var hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
    var slot := int(hud.get("selected_slot")) if hud != null else -1
    for index in forge_weapons:
        var weapon = forge_weapons[index]
        var selected: bool = not _inspect_enabled and index == slot
        if selected:
            forge_pistol = weapon
        if weapon.visible != selected:
            weapon.equip(selected)

func _matches(event: InputEventKey, latin: int, cyrillic: String) -> bool:
    return event.physical_keycode == latin or event.keycode == latin or (event.unicode != 0 and char(event.unicode).to_lower() == cyrillic)

func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
        forge_pistol.trigger_held = false
    if event is InputEventKey:
        var inspect_key := event as InputEventKey
        if inspect_key.pressed and not inspect_key.echo and (inspect_key.keycode == KEY_F4 or inspect_key.physical_keycode == KEY_F4):
            _toggle_model_inspection()
            return
    if _inspect_enabled or controls_locked:
        return
    if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP] and event.pressed:
        if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and forge_pistol.visible:
            if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                forge_pistol.cock()
            else:
                forge_pistol.insert_shells()
            get_viewport().set_input_as_handled()
        return
    if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
        # GUI buttons need the click; never capture mouse before their pressed event.
        if get_viewport().gui_get_hovered_control() is Button:
            return
        var map_overlay := get_parent().get_node_or_null("MapOverlay") as CanvasLayer
        if map_overlay != null and map_overlay.visible:
            return # Let the on-map buttons receive clicks without capturing the pointer.
        last_event = "mouse click"
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        # The first click counts as the hammer pull even when focus is captured.
        # Otherwise the six-round cycle would silently require 13 clicks.
        if revolver.visible:
            revolver.request_shot()
        elif forge_pistol.visible:
            forge_pistol.trigger_held = true
            forge_pistol.request_shot()
    elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        rotate_y(-event.relative.x * mouse_sensitivity)
        camera.rotate_x(-event.relative.y * mouse_sensitivity)
        camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)
        if forge_pistol.visible:
            forge_pistol.add_look_motion(event.relative)
        last_event = "mouse movement"
    elif event is InputEventKey:
        var key := event as InputEventKey
        last_event = "keycode=%s physical=%s unicode=%s pressed=%s" % [key.keycode, key.physical_keycode, key.unicode, key.pressed]
        if _matches(key, KEY_W, "ц"): pressed["w"] = key.pressed
        if _matches(key, KEY_A, "ф"): pressed["a"] = key.pressed
        if _matches(key, KEY_S, "ы"): pressed["s"] = key.pressed
        if _matches(key, KEY_D, "в"): pressed["d"] = key.pressed
        if _matches(key, KEY_M, "ь"): pressed["m"] = key.pressed
        if key.pressed and not key.echo and key.physical_keycode >= KEY_0 and key.physical_keycode <= KEY_9:
            var survival_hud := get_parent().get_node_or_null("GameplayHUD/SurvivalHUD")
            if survival_hud != null:
                # Inventory selection stays responsive during the ambient visual.
                # The cigarette is a separate camera attachment, not a hand item.
                var slot := 9 if key.physical_keycode == KEY_0 else int(key.physical_keycode) - KEY_1
                survival_hud.call("choose_slot", slot)
                _sync_equipped_weapons()
        if key.pressed and not key.echo and _matches(key, KEY_R, "к"):
            if revolver.visible:
                revolver.reload()
            elif forge_pistol.visible:
                forge_pistol.reload()
        if key.pressed and not key.echo and (key.keycode == KEY_V or key.physical_keycode == KEY_V):
            _start_character_sequence()
        if key.pressed and not key.echo and (key.keycode == KEY_F3 or key.physical_keycode == KEY_F3):
            status_label.visible = not status_label.visible

func kick_view(strength := 1.0, recovery_speed := 1.0, twist := 0.0) -> void:
    var kick := minf(deg_to_rad(2.3) * strength, 1.45 - camera.rotation.x)
    camera.rotation.x += kick
    recoil_pitch += kick
    recoil_recovery = recovery_speed
    recoil_roll = clampf(recoil_roll + twist * 0.4, -0.07, 0.07)

func kick_bodycam(strength: float, twist: float, recovery_speed: float) -> void:
    bodycam_offset = (bodycam_offset + Vector2(twist * 0.25, -0.031) * strength).limit_length(0.055)
    bodycam_roll = clampf(bodycam_roll + twist * minf(strength, 1.0) * 0.78, -0.045, 0.045)
    bodycam_recovery = recovery_speed
    camera.h_offset = bodycam_offset.x
    camera.v_offset = bodycam_offset.y
    camera.rotation.z = recoil_roll + bodycam_roll

func _movement_speed(sprinting: bool, quiet: bool = false) -> float:
    if quiet:
        return QUIET_SPEED
    return SPRINT_SPEED if sprinting else SPEED


func _physics_process(delta: float) -> void:
    noise_level = move_toward(noise_level, 0.0, delta * 0.85)
    var recovery := recoil_pitch * (1.0 - exp(-9.0 * recoil_recovery * delta))
    camera.rotation.x = maxf(-1.45, camera.rotation.x - recovery)
    recoil_pitch -= recovery
    recoil_roll *= exp(-12.0 * recoil_recovery * delta)
    var bodycam_decay := exp(-19.0 * bodycam_recovery * delta)
    bodycam_offset *= bodycam_decay
    bodycam_roll *= bodycam_decay
    camera.h_offset = bodycam_offset.x
    camera.v_offset = bodycam_offset.y
    camera.rotation.z = recoil_roll + bodycam_roll
    if not is_on_floor():
        velocity.y -= 17.0 * delta
    if (Input.is_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_SPACE)) and is_on_floor():
        velocity.y = JUMP
    if controls_locked:
        velocity.x = 0.0
        velocity.z = 0.0
        move_and_slide()
        return
    var axis := Vector2.ZERO
    if pressed["w"] or Input.is_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_W): axis.y -= 1.0
    if pressed["s"] or Input.is_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_S): axis.y += 1.0
    if pressed["a"] or Input.is_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_A): axis.x -= 1.0
    if pressed["d"] or Input.is_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_D): axis.x += 1.0
    var direction := (transform.basis * Vector3(axis.x, 0.0, axis.y)).normalized()
    var speed := _movement_speed(Input.is_key_pressed(KEY_SHIFT), Input.is_physical_key_pressed(KEY_C))
    var desired := direction * speed
    var acceleration := WALK_FRICTION if direction.length_squared() < 0.01 else WALK_ACCELERATION
    velocity.x = move_toward(velocity.x, desired.x, acceleration * delta)
    velocity.z = move_toward(velocity.z, desired.z, acceleration * delta)
    move_and_slide()
    var travel := get_position_delta()
    if is_on_floor():
        _track_steps(Vector2(travel.x, travel.z).length(), delta)
    else:
        step_distance = 0.0
    if is_instance_valid(status_label):
        status_label.text = "INPUT DIAGNOSTICS 0.6\nLast: %s\nAxis: %s | Pos: (%.1f, %.1f)\nMouse: %s\nClick on game, then press W / M" % [last_event, str(axis), position.x, position.z, str(Input.mouse_mode)]

func set_indoors(value: bool) -> void:
    music.set_indoors(value)
    revolver.indoors = value
    for weapon in forge_weapons.values():
        weapon.indoors = value
    wind.volume_db = -80.0 if value else -75.0  # Remain silent; preserve the old interior mix relationship
    step_sound.stream = BOARD_STEP if value else EARTH_STEP
    step_distance = 0.0

func emit_noise(strength: float) -> void:
    noise_level = maxf(noise_level, strength)
    noise_emitted.emit(global_position, strength)

func _track_steps(distance: float, delta: float) -> void:
    if distance < 0.001 or delta <= 0.0:
        return
    var actual_speed := distance / delta
    step_distance += distance
    if step_distance < clampf(0.75 + actual_speed * 0.17, 0.8, 1.7):
        return
    step_distance = 0.0
    var strength := clampf(actual_speed / SPRINT_SPEED, 0.1, 1.0) * 0.72
    if step_sound.stream == null:
        step_sound.stream = EARTH_STEP
    step_sound.volume_db = lerpf(-27.0, -6.0, strength / 0.72)
    step_sound.pitch_scale = randf_range(0.91, 1.09)
    step_sound.play()
    emit_noise(strength)
