"""Fail CI for missing, white, flat or mixed character assets."""
import sys
import trimesh
from trimesh.visual.material import PBRMaterial

full_path,fp_path=sys.argv[1:3]
full=trimesh.load(full_path,force="scene",process=False)
fp=trimesh.load(fp_path,force="scene",process=False)
assert isinstance(full,trimesh.Scene) and isinstance(fp,trimesh.Scene)
assert full_path!=fp_path and len(full.geometry)>=45 and len(fp.geometry)>=22
for name,scene in (("full",full),("fps",fp)):
    for part,mesh in scene.geometry.items():
        material=mesh.visual.material
        assert isinstance(material,PBRMaterial),f"{name}/{part}: PBR missing"
        color=material.baseColorFactor
        assert color is not None,f"{name}/{part}: colour missing"
        divisor=255 if max(float(x) for x in color[:3])>1.0 else 1.0
        assert not all(float(x)/divisor>.97 for x in color[:3]),f"{name}/{part}: white geometry"
for part in ("WinterCoat","Head","LeftThigh","RightThigh","SidorCanvasSack","LeftBootToe"):
    assert part in full.geometry,f"full missing {part}"
assert not any(n.startswith("FP") for n in full.geometry),"full contains FPS cuts"
for part in ("FPPelvis","FPCrotch","FPCoatHemL","FPCoatHemR",
             "LeftThigh","RightThigh","LeftCalf","RightCalf","LeftBootToe","RightBootToe"):
    assert part in fp.geometry,f"FPS missing {part}"
for banned in ("FPTorsoShell","FPShirtLining","FPWaistInner",
               "FPSCoatUpperLeft","Head","WinterCoat","SidorCanvasSack"):
    assert banned not in fp.geometry,f"camera-blocking upper mesh present: {banned}"
for part in ("FPPelvis","FPCrotch","FPCoatHemL","FPCoatHemR"):
    mesh=fp.geometry[part]
    assert mesh.is_watertight and mesh.volume>0,f"{part} must have solid volume"
assert max(float(mesh.bounds[1,1]) for mesh in fp.geometry.values())<=.91,"FPS GLB reaches into camera"
print("TWO_CHARACTER_ASSETS_OK: separate_glb=true colored_pbr=true lower_only=true closed_pelvis=true no_high_coat=true")
