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
    if rig == null or legacy == null or arms != null or eye == null:
        _fail("player visuals were not instantiated")
        return
    if legacy.visible or legacy.is_processing():
        _fail("hidden compatibility avatar still renders or animates")
        return
    if rig.get("model_loaded") or rig.get("full_body") != null or rig.get("first_person_body") != null:
        _fail("a body mesh was loaded before F4")
        return
    for pitch in [0.0, -0.5, -1.0, -1.45]:
        eye.rotation.x = pitch
        rig.call("_process", 0.016)
        if legacy.visible or rig.get("full_body") != null:
            _fail("body mesh entered first-person view at pitch %s" % pitch)
            return
    player.call("_toggle_model_inspection")
    var full := rig.get("full_body") as Node3D
    if full == null or not full.visible or not (player.get_node("CharacterInspectionCamera") as Camera3D).current:
        _fail("F4 did not load and activate the full model/camera")
        return
    if full.find_child("Head", true, false) == null or full.find_child("WinterCoat", true, false) == null:
        _fail("F4 character is incomplete")
        return
    if legacy.visible:
        _fail("FPS arms or old body overlap the F4 inspector")
        return
    player.call("_toggle_model_inspection")
    if full.visible or legacy.visible or rig.get("first_person_body") != null:
        _fail("F4 return did not restore hands-only gameplay")
        return
    player.call("_toggle_model_inspection")
    if rig.get("full_body") != full or not full.visible:
        _fail("F4 reopening did not reuse the loaded model")
        return
    player.call("_toggle_model_inspection")
    print("MODELED_CHARACTER_REGRESSION_OK: fps_body_absent=true legacy_hidden=true unarmed_clear=true full_model_f4_only=true f4_roundtrip=true")
    quit(0)
