"""Static regression checks for the first cultist integration."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORLD = (ROOT / "godot/world.gd").read_text(encoding="utf-8")
NPC = (ROOT / "godot/npc_cultist.gd").read_text(encoding="utf-8")
HITBOX = (ROOT / "godot/npc_hitbox.gd").read_text(encoding="utf-8")
REVOLVER = (ROOT / "godot/revolver.gd").read_text(encoding="utf-8")
APOSTOL = (ROOT / "godot/forge_pistol.gd").read_text(encoding="utf-8")


def test_cultist_spawns_after_manual_village_activation():
    assert WORLD.index("_activate_default_village()\n    _create_first_cultist()") > 0
    assert 'cultist.set_script(preload("res://npc_cultist.gd"))' in WORLD
    assert "MANUAL_VILLAGE_SPAWN + Vector3" in WORLD


def test_cultist_is_self_contained_and_has_six_zones():
    for part in ("head", "torso", "leftArm", "rightArm", "leftLeg", "rightLeg"):
        assert f'"{part}"' in NPC
    assert 'if ResourceLoader.exists(model_path):' in NPC
    assert '"Robe"' in NPC and '"Hood"' in NPC and '"RedRuneCross"' in NPC
    assert '"Trouser"' in NPC and '"Boot"' in NPC
    assert '"torso": [Vector3' in NPC
    assert "collision_layer = 0" in NPC
    assert "collision_mask = 1" in NPC


def test_existing_weapons_forward_hits_to_cultist_zones():
    assert 'hit.collider.has_method("apply_damage")' in REVOLVER
    assert 'collider.has_method("apply_damage")' in APOSTOL
    assert 'func apply_damage(amount: float)' in HITBOX
    assert 'controller.call("apply_damage", amount, zone)' in HITBOX


def test_walk_and_alert_behavior():
    assert 'func _physics_process(delta: float)' in NPC
    assert 'move_and_slide()' in NPC
    assert 'notice_distance' in NPC
    assert '_parts[limb_name]' in NPC
    assert 'PhysicsRayQueryParameters3D.create' in NPC
    assert 'if desired.length() < 2.1' in NPC


def test_articulated_glb_and_grounded_gait():
    generator = (ROOT / "scripts/build_cultist_v09.py").read_text(encoding="utf-8")
    viewer = (ROOT / "site/cultist/index.html").read_text(encoding="utf-8")
    for group in ("LeftLeg", "RightLeg", "LeftShin", "RightShin", "LeftFoot", "RightFoot"):
        assert f'"{group}"' in generator
    assert '"leftShin"' in NPC and '"rightShin"' in NPC
    assert 'shin.reparent(thigh, true)' in NPC
    assert 'foot.reparent(shin, true)' in NPC
    assert '_visual.position.y = 0.0' in NPC
    assert 'sin(_step_clock) * 0.026' not in NPC
    assert 'function solveTwoBoneIK' in viewer
    assert 'function animateFootsteps' in viewer
    assert 'const stanceRatio=.63' in viewer
    assert 'actor.position.y=Math.sin' not in viewer


def test_v08_game_export_uses_detailed_model_not_old_preview():
    workflow = (ROOT / ".github/workflows/web.yml").read_text(encoding="utf-8")
    source = (ROOT / "scripts/build_cultist_v09.py").read_text(encoding="utf-8")
    assert 'python scripts/build_cultist_v09.py godot/assets/npc/cultist_modular.glb' in workflow
    assert 'CULTIST_GAME_V09_OK' in workflow
    assert 'CULTIST_V09_OK' in source
    assert 'trimesh.util.concatenate(pieces)' in source
    assert 'len(counts)==10' in source
    assert '28000 < triangles < 115000' in source
    assert 'ModelFacingCorrection' in NPC


def test_animation_pass():
    assert 'func _animate_character' in NPC
    assert '_gait_blend' in NPC
    assert 'Vector2(displacement.x, displacement.z).length()' in NPC
    assert 'res://cultist_cloth.gdshader' in NPC
