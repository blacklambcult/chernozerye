"""Quest Lab conversion regression tests: no Godot binary required."""
import json
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
from convert_questlab import compile_questlab

DATA = json.loads((ROOT / "data" / "questlab_return_cordon.json").read_text(encoding="utf-8"))
ORIGIN = json.loads((ROOT / "godot" / "world_data.json").read_text(encoding="utf-8"))["metadata"]


class QuestLabConversionTest(unittest.TestCase):
    def test_supplied_user_quest(self):
        result = compile_questlab(DATA, ORIGIN)
        self.assertEqual(result["schema"], "chernozerye.questlab.runtime-1")
        quest = result["quests"][0]
        self.assertEqual(quest["title"], "ВОЗВРАЩЕНИЕ НА ЧЕРНЫЙ КОРДОН")
        self.assertEqual([step["title"] for step in quest["steps"]],
                         ["Добраться до Черного Кордона", "Найти дом старосты"])
        self.assertEqual([step["text"] for step in quest["steps"]],
                         ["Ты дома. Почти.", "Что же происходит?"])
        self.assertAlmostEqual(quest["spawn_world"][0], -809.39, delta=2.0)
        self.assertAlmostEqual(quest["spawn_world"][2], 38.82, delta=2.0)
        self.assertAlmostEqual(quest["steps"][0]["target_world"][0], -498.12, delta=2.0)
        self.assertAlmostEqual(quest["steps"][0]["target_world"][2], -240.13, delta=2.0)
        self.assertAlmostEqual(quest["steps"][1]["target_world"][2], -354.38, delta=2.0)

    def test_interaction_collectible_demo_is_independent(self):
        demo=json.loads((ROOT / "data" / "questlab_interactions_demo.json").read_text(encoding="utf-8"))
        result=compile_questlab(demo,ORIGIN)
        self.assertEqual([s["type"] for s in result["quests"][0]["steps"]],
                         ["interact","collect","message"])
        self.assertIsNone(result["quests"][0]["steps"][2]["target_world"])
        self.assertTrue(result["quests"][0]["steps"][0]["target_world"])
        self.assertTrue(result["quests"][0]["steps"][1]["target_world"])
        self.assertNotEqual(result["quests"][0]["spawn_world"],
                            result["quests"][0]["steps"][0]["target_world"])
        self.assertEqual(result["quests"][0]["id"],"quest-interaction-demo")

    def test_invalid_geo_and_missing_target(self):
        broken = json.loads(json.dumps(DATA))
        broken["quests"][0]["steps"][0]["target"]["lat"] = float("nan")
        with self.assertRaisesRegex(ValueError, "finite"):
            compile_questlab(broken, ORIGIN)
        broken = json.loads(json.dumps(DATA))
        broken["quests"][0]["steps"][0]["target"] = None
        with self.assertRaisesRegex(ValueError, "requires a target"):
            compile_questlab(broken, ORIGIN)

    def test_duplicate_ids_and_unrecognized_format(self):
        broken = json.loads(json.dumps(DATA))
        broken["quests"].append(broken["quests"][0])
        with self.assertRaisesRegex(ValueError, "repeated quest ID"):
            compile_questlab(broken, ORIGIN)
        broken = json.loads(json.dumps(DATA))
        broken["format"] = "nonsense"
        with self.assertRaisesRegex(ValueError, "format"):
            compile_questlab(broken, ORIGIN)


if __name__ == "__main__":
    unittest.main()
