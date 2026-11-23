# Cultist NPC foundation (Godot)

Experimental branch, not yet merged to main.

- `npc_cultist.gd`: NPC with patrol, detection, approach, hit reaction and knockdown.
- `npc_hitbox.gd`: named zone colliders forwarding `apply_damage(amount)` to the controller. Works with existing `revolver.gd` and `forge_pistol.gd` ray hits without editing their firing logic.
- `world.gd`: spawns Cultist_001 6.5 m from the authored manual village spawn.
- If `res://assets/npc/cultist_modular.glb` exists, it is loaded as the NPC visual; otherwise a simple low-poly procedural robed silhouette is displayed.
- The grouped `cultist_modular.glb` is available separately in `chernozerye_cultist_asset_pack.zip`. Unzip it to the repository root to place `godot/assets/npc/cultist_modular.glb`. The binary file is **not** committed with this branch. The grouped source was generated from the first cultist prototype using the included Python script.
- The supplied GLB is unrigged: there is no skeleton or skeletal animation; the visual is translated/bobbed for a temporary walk cycle.
- The GLB uses named groups `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`; the NPC maps sleeve groups for non-graphic detachment. There are no skeletal animations or anatomically graphic visuals.
- Scene collision is deliberately conservative; a proper navigation mesh, line-of-sight checks and animations are follow-up work.

## Manual QA (Godot 4.x)
1. Run the normal village project entrypoint.
2. At the canonical village start, look around ~8 m from spawn for a robed NPC.
3. Approach the NPC and verify it approaches without attacking. Move away and verify it returns to patrol.
4. With the Apostol equipped, test normal hit reactions and knockdown via the existing `apply_damage` hook.
5. Ensure original village entry, map and pickups continue to function.

## Limits
This branch has not been executed inside the Godot editor or validated in a deployed web build. It should be smoke-tested before merging.
