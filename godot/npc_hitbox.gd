extends StaticBody3D
## Delegates existing revolver / Apostol apply_damage calls to NPC zone.
var controller: Node
var zone := "torso"

func apply_damage(amount: float) -> void:
    if is_instance_valid(controller):
        controller.call("apply_damage", amount, zone)
