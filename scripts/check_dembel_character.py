"""Guard GLB material colour and first-person cutaway geometry before Godot import."""
import sys
from pathlib import Path
import trimesh
from trimesh.visual.material import PBRMaterial

p=Path(sys.argv[1])
scene=trimesh.load(p,force="scene",process=False)
assert isinstance(scene,trimesh.Scene), "not a GLB scene"
all_shapes=scene.geometry
assert len(all_shapes)>=55, f"Unexpected number of GLB mesh parts: {len(all_shapes)}"
for name,mesh in all_shapes.items():
    if not isinstance(mesh.visual.material,PBRMaterial):
        raise AssertionError(f"{name}: no PBR material")
    c=mesh.visual.material.baseColorFactor
    if c is None or all(x>=0.98 for x in c[:3]):
        raise AssertionError(f"{name}: white or missing PBR colour {c}")
for piece in ["WinterCoat","LeftThigh","RightThigh","LeftBootToe","RightBootToe","FPSCoatUpperLeft","FPSCoatUpperRight"]:
    assert piece in all_shapes,f"Missing mesh {piece}"
for piece in ["FPSCoatUpperLeft","FPSCoatUpperRight","FPSCoatLowerLeft","FPSCoatLowerRight"]:
    mesh=all_shapes[piece]
    assert mesh.bounds[1,1] <= 1.11, f"{piece}: too close to eyes (y={mesh.bounds[1,1]:.2f})"
    assert max(abs(mesh.bounds[0,0]),abs(mesh.bounds[1,0])) <= 0.28, f"{piece}: too wide for downlook"
    assert len(mesh.faces)==2, f"{piece}: reversed duplicate triangles"
print(f"CHARACTER_ASSET_VALIDATED: colored_pbr=true cutaway_bounds=true coat_mesh=true parts={len(all_shapes)}")
