extends SceneTree
# No-body FPS regression: camera hands only; complete GLB exclusively in F4.

func _fail(message: String) -> void:
    push_error("MODELED_CHARACTER_REGRESSION_FAILED: " + message)
    quit(1)


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var player := CharacterBody3D.new()
    player.name = "Player"
    player.set_script(load("res://player.gd"))
    get_root().add_child(player)
    var rig := player.get_node_or_null("ModeledCharacter") as Node3D
    var legacy := player.get_node_or_null("FirstPersonFullBody") as Node3D
    var arms := player.get_node_or_null("Camera3D/FPSViewmodel") as Node3D
    var eye := player.get_node_or_null("Camera3D") as Camera3D
    if rig == null or legacy == null or arms == null or eye == null:
        _fail("player visuals were not instantiated")
        return
    if legacy.visible or legacy.is_processing():
        _fail("hidden compatibility avatar still renders or animates")
        return
    if not bool(rig.get("model_loaded")):
        _fail("F4 full GLB unavailable")
        return
    if rig.get("first_person_body") != null:
        _fail("an unwanted first-person body mesh was instantiated")
        return
    var full := rig.get("full_body") as Node3D
    if full == null or full.visible:
        _fail("F4 full model is visible during gameplay")
        return
    if full.find_child("Head", true, false) == null or full.find_child("WinterCoat", true, false) == null:
        _fail("F4 character is incomplete")
        return
    for pitch in [0.0, -0.5, -1.0, -1.45]:
        eye.rotation.x = pitch
        arms.call("_process", 0.016)
        rig.call("_process", 0.016)
        if not arms.visible:
            _fail("FPS hands disappear when looking down")
            return
        if full.visible or legacy.visible or rig.get("first_person_body") != null:
            _fail("body mesh entered first-person view at pitch %s" % pitch)
            return
    player.call("_toggle_model_inspection")
    if not full.visible or not (player.get_node("CharacterInspectionCamera") as Camera3D).current:
        _fail("F4 did not activate the full model/camera")
        return
    if arms.visible or legacy.visible:
        _fail("FPS arms or old body overlap the F4 inspector")
        return
    player.call("_toggle_model_inspection")
    arms.call("_process", 0.016)
    if full.visible or legacy.visible or not arms.visible or rig.get("first_person_body") != null:
        _fail("F4 return did not restore hands-only gameplay")
        return
    print("MODELED_CHARACTER_REGRESSION_OK: fps_body_absent=true legacy_hidden=true arms_visible_downlook=true full_model_f4_only=true f4_roundtrip=true")
    quit(0)
