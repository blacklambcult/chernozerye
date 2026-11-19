extends SceneTree
# Headless regression: Esc overlay must freeze and unfreeze the same game world.

func _fail(message: String) -> void:
    paused = false
    push_error("PAUSE_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var overlay := actor.get_node_or_null("PauseOverlay") as CanvasLayer
    if overlay == null or overlay.process_mode != Node.PROCESS_MODE_ALWAYS:
        _fail("pause overlay missing or stops processing when game freezes")
        return
    var curtain := overlay.get_node_or_null("PauseBackdrop") as ColorRect
    var slider := overlay.get_node_or_null("PauseBackdrop/PauseCard/MarginContainer/VBoxContainer/SensitivitySlider") as HSlider
    # The slider is inside a horizontal row; verify its existence by searching
    # through the actual UI tree instead of relying on a fragile absolute path.
    slider = overlay.find_child("SensitivitySlider", true, false) as HSlider
    if curtain == null or slider == null or curtain.visible:
        _fail("pause UI starts visible or is incomplete")
        return
    overlay.call("open_pause")
    if not paused or not curtain.visible or not bool(overlay.get("is_open")):
        _fail("opening pause does not freeze and show the panel")
        return
    overlay.call("open_pause")
    if not paused:
        _fail("repeat pause open toggled the game back on")
        return
    var effects := overlay.find_child("EffectsVolume", true, false) as HSlider
    var tracks := overlay.find_child("MusicVolume", true, false) as HSlider
    var music = actor.get("music")
    var fx_bus := AudioServer.get_bus_index("Effects")
    var music_bus := AudioServer.get_bus_index("Music")
    if effects == null or tracks == null or fx_bus < 0 or music_bus < 0:
        _fail("missing audio controls or bus layout")
        return
    var old_effects := effects.value
    var old_music := tracks.value
    effects.value = 42
    tracks.value = 0
    actor.call("set_indoors", true)
    music.transition.custom_step(2.1)
    if music.cabin.bus != &"Music" or music.street.bus != &"Music" or not AudioServer.is_bus_mute(music_bus):
        _fail("location transition bypassed music mute")
        return
    if actor.wind.bus != &"Effects" or actor.step_sound.bus != &"Effects" or actor.revolver.report.bus != &"Effects":
        _fail("effect source bypassed effects bus")
        return
    if AudioServer.is_bus_mute(fx_bus) or not is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(fx_bus)), 0.42):
        _fail("muting music affected the effects mix")
        return
    var saved := ConfigFile.new()
    if saved.load(overlay.AUDIO_CONFIG) != OK or saved.get_value("volume", "Effects") != 42 or saved.get_value("volume", "Music") != 0:
        _fail("volume settings were not saved")
        return
    effects.value = old_effects
    tracks.value = old_music
    slider.value = 1.5
    if absf(float(actor.get("mouse_sensitivity")) - 0.003) > 0.00001:
        _fail("sensitivity slider does not reach player look controls")
        return
    overlay.call("close_pause")
    if paused or curtain.visible or bool(overlay.get("is_open")):
        _fail("resume did not restore world updates")
        return
    if absf(float(actor.get("mouse_sensitivity")) - 0.003) > 0.00001:
        _fail("resume reset the sensitivity adjustment")
        return
    print("PAUSE_REGRESSION_OK: freeze=true resume=true sensitivity=1.5x persistent_in_session=true")
    quit(0)
