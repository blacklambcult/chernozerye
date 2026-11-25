import unittest
from scripts.convert_editor_geojson import validate_appearance

class WorldAppearanceTest(unittest.TestCase):
    def test_building(self):
        recipe = {"version": 1, "generator": "building", "type": "izba",
                  "parameters": {"floors": 2, "walls": 1, "roof": 2, "window": 3, "door": 4},
                  "conditions": {"walls": "normal", "roof": "normal", "door": "normal", "fence": "normal", "window": 2}}
        self.assertEqual(validate_appearance(recipe, "house"), recipe)
        with self.assertRaises(ValueError):
            validate_appearance(recipe, "forest")
        recipe["parameters"]["floors"] = True
        with self.assertRaises(ValueError):
            validate_appearance(recipe, "house")
    def test_nature(self):
        recipe = {"version": 1, "generator": "nature", "type": "tree",
                  "parameters": {"species": 8, "height": 2, "canopy": 1, "seed": 4}, "environment": "n"}
        self.assertEqual(validate_appearance(recipe, "forest"), recipe)
        recipe["parameters"]["seed"] = 5
        with self.assertRaises(ValueError):
            validate_appearance(recipe, "forest")
