extends SceneTree
# Smoke test the exact Forge GLB and a seven-round single-click arcade cycle.
func _fail(why: String) -> void:
    push_error("FORGE_PISTOL_REGRESSION_FAILED: " + why)
    quit(1)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var actor := CharacterBody3D.new()
    actor.name = "Player"
    actor.set_script(load("res://player.gd"))
    get_root().add_child(actor)
    var pistol: Node3D = actor.get("forge_pistol")
    var revolver: Node3D = actor.get("revolver")
    if pistol == null or not pistol.has_node("ForgePistolVisual"):
        _fail("uploaded Forge model missing from camera")
        return
    if pistol.get("grip_marker") == null or pistol.get("forward_marker") == null \
            or pistol.get("magazine_marker") == null:
        _fail("GLB anchor nodes were not imported")
        return
    var pistol_hand := pistol.get_node_or_null("WeaponRightHand") as Node3D
    var revolver_hand := revolver.get_node_or_null("WeaponRightHand") as Node3D
    if pistol_hand == null or revolver_hand == null:
        _fail("camera-space holding hand missing from either weapon")
        return
    if pistol_hand.find_children("*", "MeshInstance3D", true, false).size() < 8:
        _fail("pistol wrist and fingers do not have visible geometry")
        return
    if revolver_hand.find_children("*", "MeshInstance3D", true, false).size() < 8:
        _fail("revolver wrist and fingers do not have visible geometry")
        return
    if not is_equal_approx(float(pistol.get("model_scale")), 0.32):
        _fail("pistol remains at its old undersized viewmodel scale")
        return
    if (pistol.position - Vector3(0.285, -0.225, -0.47)).length() > 0.001:
        _fail("Forge camera-relative pose was not loaded")
        return
    if (pistol_hand.position - Vector3(-0.01, 0.06, -0.01)).length() > 0.001:
        _fail("new author-positioned viewmodel hand was not applied")
        return
    if (pistol.rotation - Vector3(0.0, deg_to_rad(9.0), 0.0)).length() > 0.001:
        _fail("new author-selected rotation did not load")
        return
    var model := pistol.get("imported_model") as Node3D
    if model.find_children("*", "MeshInstance3D", true, false).size() < 10:
        _fail("uploaded GLB has lost its author-designed visual parts")
        return
    if int(pistol.get("rounds")) != 7 or pistol.visible:
        _fail("pistol did not start holstered with 7 rounds")
        return
    pistol.call("equip", true)
    if revolver.visible or not pistol_hand.is_visible_in_tree():
        _fail("pistol holding hand hidden or legacy revolver unexpectedly visible")
        return
    for count in range(7):
        pistol.set("cooldown", 0.0)
        pistol.call("request_shot")
        if not bool(pistol.get("pending")) or str(pistol.get("last_action")) != "fire":
            _fail("one click must queue an immediate game shot")
            return
        pistol.call("_shoot")
        if int(pistol.get("rounds")) != 6-count or bool(pistol.get("pending")):
            _fail("each click must consume exactly one of seven rounds")
            return
    pistol.set("cooldown", 0.0)
    pistol.call("request_shot")
    if bool(pistol.get("pending")):
        _fail("an empty magazine accepted a shot")
        return
    pistol.call("reload")
    if float(pistol.get("reload_left")) <= 0.0:
        _fail("reload did not begin")
        return
    pistol.call("_physics_process", 2.0)
    if int(pistol.get("rounds")) != 7:
        _fail("reload did not refill seven rounds")
        return
    pistol.call("equip", false)
    revolver.call("equip", true)
    if int(revolver.get("rounds")) != 6 or not revolver_hand.is_visible_in_tree():
        _fail("original six-round revolver or its holding hand was changed")
        return
    print("FORGE_PISTOL_REGRESSION_OK: uploaded_glb=true anchors=3 parts>=10 capacity=7 one_click=true reload=true original_revolver=true hands=2 fp_profile=true")
    quit(0)
