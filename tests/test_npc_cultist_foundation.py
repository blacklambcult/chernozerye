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
