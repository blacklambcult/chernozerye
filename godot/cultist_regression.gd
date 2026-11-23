extends SceneTree
## Headless regression of the authored v0.7 model and non-graphic articulated rig.

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var resource := load("res://assets/npc/cultist_modular.glb") as PackedScene
    if resource == null:
        push_error("Cultist GLB was not imported")
        quit(1)
        return

    var npc := CharacterBody3D.new()
    npc.set_script(preload("res://npc_cultist.gd"))
    root.add_child(npc)
    await process_frame

    var parts: Dictionary = npc.get("_parts")
    for key in ["head", "leftArm", "rightArm", "leftLeg", "rightLeg", "leftShin", "rightShin", "leftFoot", "rightFoot"]:
        if not parts.has(key):
            push_error("Missing articulated cultist group: " + key)
            quit(1)
            return

    for side in ["left", "right"]:
        var thigh := parts[side + "Leg"] as Node3D
        var shin := parts[side + "Shin"] as Node3D
        var foot := parts[side + "Foot"] as Node3D
        if shin.get_parent() != thigh or foot.get_parent() != shin:
            push_error("Broken nested leg rig on: " + side)
            quit(1)
            return

    if npc.get("_has_joint_rig") != true:
        push_error("Articulated cultist rig was not activated")
        quit(1)
        return

    print("CULTIST_RIG_REGRESSION_OK: knees=2 ankles=2 arms=2 head=true glb=true")
    npc.queue_free()
    quit(0)
