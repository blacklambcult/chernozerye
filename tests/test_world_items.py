"""World placement authoring: separate from any quest or F7 scene."""
import copy
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"scripts"))
from convert_questlab import compile_questlab

ORIGIN=json.loads((ROOT/"godot/world_data.json").read_text(encoding="utf-8"))["metadata"]
SOURCE=json.loads((ROOT/"data/questlab_world_items.json").read_text(encoding="utf-8"))


def all_free_source():
    doc=copy.deepcopy(SOURCE)
    doc["worldItems"]=[x for x in doc["worldItems"] if not x["objectId"]]
    return doc


class WorldItemsCompileTest(unittest.TestCase):
    def test_multiple_free_objects_compile_without_missions(self):
        result=compile_questlab(all_free_source(),ORIGIN)
        self.assertEqual(result["quests"],[])
        self.assertEqual(len(result["world_items"]),3)
        by_id={x["id"]:x for x in result["world_items"]}
        note=by_id["world-note-roadside"]
        self.assertEqual(note["type"],"note")
        self.assertIn("ноябрь 2005",note["body"])
        self.assertEqual(note["target_source"],"free_point")
        self.assertAlmostEqual(note["position_world"][0],-784.8,delta=0.05)
        self.assertAlmostEqual(note["position_world"][2],-270.5,delta=0.05)
        self.assertEqual(by_id["world-item-rusted-key"]["type"],"item")
        self.assertAlmostEqual(by_id["world-item-rusted-key"]["position_world"][0],-776.9,delta=0.05)
        self.assertAlmostEqual(by_id["world-note-observer"]["position_world"][0],-769.6,delta=0.05)

    def test_findables_are_near_the_actual_live_village_spawn(self):
        import math
        import re
        world_script=(ROOT/"godot/world.gd").read_text(encoding="utf-8")
        found=re.search(r"const MANUAL_VILLAGE_SPAWN := Vector3\(([-.0-9]+),\s*[-.0-9]+,\s*([-.0-9]+)\)",world_script)
        self.assertIsNotNone(found,"World must expose its canonical surveyed-village spawn")
        sx,sz=map(float,found.groups())
        result=compile_questlab(all_free_source(),ORIGIN)
        distances=[math.hypot(i["position_world"][0]-sx,i["position_world"][2]-sz)
                   for i in result["world_items"]]
        self.assertLess(distances[0],8.0)
        self.assertTrue(all(d<27 for d in distances),distances)
        self.assertGreater(distances[1],distances[0])
        self.assertGreater(distances[2],distances[1])

    def test_geo_link_resolves_real_survey_object_instead_of_editor_centroid(self):
        f=ROOT/"godot/manual_layout.json"
        if not f.exists():
            self.skipTest("CI generates the reviewed Geo Lab layout")
        geo=json.loads(f.read_text(encoding="utf-8"))
        before=json.dumps(geo,sort_keys=True)
        result=compile_questlab(SOURCE,ORIGIN,geo)
        self.assertEqual(len(result["world_items"]),4)
        linked=result["world_items"][-1]
        self.assertEqual(linked["object_id"],"4499fe7a-c031-469c-aac4-96636c23eea8")
        self.assertEqual(linked["target_source"],"geo_lab_id")
        self.assertEqual(linked["type"],"note")
        self.assertEqual(len(linked["position_world"]),3)
        self.assertEqual(json.dumps(geo,sort_keys=True),before)

    def test_empty_legacy_project_compiles_to_zero_world_items(self):
        legacy=json.loads((ROOT/"data/questlab_return_cordon.json").read_text(encoding="utf-8"))
        compiled=compile_questlab(legacy,ORIGIN)
        self.assertEqual(compiled["world_items"],[])
        self.assertEqual(len(compiled["quests"]),1)

    def test_reject_missing_coordinates_duplicate_ids_invalid_note_and_bad_geo_id(self):
        doc=all_free_source()
        doc["worldItems"][0]["target"]=None
        with self.assertRaisesRegex(ValueError,"mapped position"):
            compile_questlab(doc,ORIGIN)
        doc=all_free_source()
        doc["worldItems"].append(copy.deepcopy(doc["worldItems"][0]))
        with self.assertRaisesRegex(ValueError,"repeated world item ID"):
            compile_questlab(doc,ORIGIN)
        doc=all_free_source()
        doc["worldItems"][0]["body"]=""
        with self.assertRaisesRegex(ValueError,"require a title and body"):
            compile_questlab(doc,ORIGIN)
        with self.assertRaisesRegex(ValueError,"Geo Lab map required"):
            compile_questlab(SOURCE,ORIGIN)

if __name__=="__main__":
    unittest.main()
