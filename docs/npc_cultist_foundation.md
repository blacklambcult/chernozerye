# Cultist NPC v0.7 — articulated gait

Development branch only: `feature/cultist-npc-foundation`. Changes are **not merged to main**.

## What works

- NPC behavior in `godot/npc_cultist.gd`: patrol, player observation with line-of-sight, approach with stopping distance, and non-graphic hit feedback.
- Hit zones use `godot/npc_hitbox.gd` and stay independent of visual joint pivots.
- The first NPC is spawned by `godot/world.gd` near the authored village.
- The free procedural asset is built before Godot import using `scripts/build_cultist_v06.py` into `godot/assets/npc/cultist_modular.glb`.
- The GLB contains ten named groups: `Head`, `Torso`, `LeftArm`, `RightArm`, `LeftLeg`, `RightLeg`, `LeftShin`, `RightShin`, `LeftFoot`, `RightFoot`.
- Godot creates runtime pivots so each thigh owns its shin and foot; stepping is distance-driven, with no vertical hopping of the entire model.
- Browser viewer: `site/cultist/index.html`. The preview animates the knee and ankle via simple two-bone inverse kinematics, plants the support foot in world space, and eases patrol turns and stops.
- Browser build and GLB structure are checked by `scripts/build_cultist_preview.sh`.
- Godot regression `godot/cultist_regression.gd` checks imported GLB groups and joint hierarchy.

## Important limitations

- This is an **articulated node hierarchy**, not a deforming `Skeleton3D` with bone weights. The robe is a static mesh, and cloth deformation has not been implemented.
- The browser preview uses stance foot locking. The Godot controller currently uses articulated procedural swing; the same inverse kinematics have not been ported to its engine.
- No claim that the Godot web export or headless rig test has passed until a GitHub Actions job explicitly reports success.
- The production/main game is unchanged.

## How to check

1. Open the separate Vercel browser preview and select **Patrol**.
2. Compare the support foot with the ground: the entire NPC should not bounce vertically.
3. Inspect both knees, ankles, and boot positions during the turning pause.
4. In CI, check for `CULTIST_V07_OK` for preview and `CULTIST_RIG_REGRESSION_OK` for the Godot headless script.
5. Keep the NPC branch unmerged until the authored village level and collision regression are verified.
