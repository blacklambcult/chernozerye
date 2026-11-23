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

    var model := parts.get("model") as Node3D
    var checked := 0
    for child in model.find_children("*", "MeshInstance3D", true, false):
        var mesh_node := child as MeshInstance3D
        if not mesh_node.is_in_group(&"ps1_jitter_stable"):
            push_error("Cultist mesh exposed to PS1 material substitution")
            quit(1)
            return
        for surface in range(mesh_node.mesh.get_surface_count()):
            var mat := mesh_node.get_active_material(surface) as StandardMaterial3D
            var arrays := mesh_node.mesh.surface_get_arrays(surface)
            if mat == null or not mat.vertex_color_use_as_albedo or arrays[Mesh.ARRAY_COLOR] == null:
                push_error("Cultist vertex colors/material missing: " + mesh_node.name)
                quit(1)
                return
            checked += 1
    if checked < 10:
        push_error("Not all cultist surfaces validated")
        quit(1)
        return
    print("CULTIST_MATERIAL_REGRESSION_OK: surfaces=", checked)

    print("CULTIST_RIG_REGRESSION_OK: knees=2 ankles=2 arms=2 head=true glb=true")
    npc.queue_free()
    quit(0)
