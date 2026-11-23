# Cultist NPC foundation (Godot)

Experimental branch, not yet merged to main.

- `npc_cultist.gd`: NPC with patrol, detection, approach, hit reaction and knockdown.
- `npc_hitbox.gd`: named zone colliders forwarding `apply_damage(amount)` to the controller. Works with existing `revolver.gd` and `forge_pistol.gd` ray hits without editing their firing logic.
- `world.gd`: spawns Cultist_001 6.5 m from the authored manual village spawn.
- If `res://assets/npc/cultist_modular.glb` exists, it is loaded as the NPC visual; otherwise a simple low-poly procedural robed silhouette is displayed.
- The existing prototype `cultist_modular.glb` must be copied into `godot/assets/npc/` to see the referenced model. It is **not** committed with this branch.
- The supplied GLB is unrigged: there is no skeleton or skeletal animation; the visual is translated/bobbed for a temporary walk cycle.
- The optional sleeve detachment in this branch is a non-graphic costume effect and currently applies only to the fallback silhouette. The imported GLB remains intact until its named nodes are properly mapped.
- Scene collision is deliberately conservative; a proper navigation mesh, line-of-sight checks and animations are follow-up work.

## Manual QA (Godot 4.x)
1. Run the normal village project entrypoint.
2. At the canonical village start, look around ~8 m from spawn for a robed NPC.
3. Approach the NPC and verify it approaches without attacking. Move away and verify it returns to patrol.
4. With the Apostol equipped, test normal hit reactions and knockdown via the existing `apply_damage` hook.
5. Ensure original village entry, map and pickups continue to function.

## Limits
This branch has not been executed inside the Godot editor or validated in a deployed web build. It should be smoke-tested before merging.
