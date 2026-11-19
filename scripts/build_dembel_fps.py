"""Standalone first-person lower body. Head, torso, shoulders and chest
are NOT part of this mesh. Viewmodel shoulders follow the camera instead.
"""
import math
import sys
from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual import TextureVisuals

COLORS={
 "cloth":(101,103,86,255),"shadow":(70,75,64,255),
 "edge":(129,123,101,255),"lining":(77,80,66,255),
 "pocket":(98,87,67,255),"pants":(73,81,73,255),
 "calf":(55,64,59,255),"boot":(80,73,61,255),
 "sole":(43,39,35,255),"metal":(159,149,117,255)
}
scene=trimesh.Scene()
scene.graph.update(frame_from="world",frame_to="FPCharacterRoot",matrix=np.eye(4))

def pivot(name,parent,at):
    m=np.eye(4)
    m[:3,3]=at
    scene.graph.update(frame_from=parent,frame_to=name,matrix=m)

def geom(name,parent,mesh,shade):
    mesh.visual=TextureVisuals(material=PBRMaterial(
        name="fps_"+shade,
        baseColorFactor=[n/255 for n in COLORS[shade]],
        roughnessFactor=1.0,metallicFactor=0.0,doubleSided=False))
    scene.add_geometry(mesh,node_name=name,geom_name=name,parent_node_name=parent)

def box(name,parent,at,size,shade):
    m=trimesh.creation.box(extents=size)
    m.apply_translation(at)
    geom(name,parent,m,shade)

def tube(name,parent,a,b,radius_a,radius_b,shade,segments=10):
    a=np.array(a,float);b=np.array(b,float)
    d=(b-a)/np.linalg.norm(b-a)
    basis=np.array((1,0,0)) if abs(d[0])<.9 else np.array((0,0,1))
    u=np.cross(d,basis);u/=np.linalg.norm(u)
    v=np.cross(d,u)
    vertices=[]
    for end,rad in ((a,radius_a),(b,radius_b)):
        for j in range(segments):
            theta=2*math.pi*j/segments
            vertices.append(end+rad*(math.cos(theta)*u+math.sin(theta)*v))
    faces=[]
    for j in range(segments):
        k=(j+1)%segments
        faces += [(j,k,segments+k),(j,segments+k,segments+j)]
    # Open top and bottom: no large circular cap above knees.
    geom(name,parent,trimesh.Trimesh(vertices=vertices,faces=faces,process=False),shade)

# Only LOWER BODY is drawn by this GLB. No coat collar or chest shell
# in front of the player's eyes. Camera-attached arms draw the shoulders.
box("FPPelvis","FPCharacterRoot",(0,.801,.014),(.410,.150,.315),"pants")
box("FPCrotch","FPCharacterRoot",(0,.712,.006),(.130,.075,.238),"calf")
for side,tag in ((-1,"L"),(1,"R")):
    box("FPCoatHem"+tag,"FPCharacterRoot",
        (side*.213,.805,-.076),(.115,.074,.183),"cloth")
    box("FPCoatFold"+tag,"FPCharacterRoot",
        (side*.222,.785,-.161),(.096,.017,.031),"shadow")

for side,name in ((-1,"Left"),(1,"Right")):
    hip=name+"LegPivot"
    pivot(hip,"FPCharacterRoot",(side*.157,.836,.018))
    tube(name+"Thigh",hip,(0,.018,0),(0,-.360,-.004),.126,.108,"pants")
    knee=name+"KneePivot"
    pivot(knee,hip,(0,-.360,-.004))
    tube(name+"Calf",knee,(0,.008,0),(0,-.333,.020),.111,.091,"calf")
    ankle=name+"AnklePivot"
    pivot(ankle,knee,(0,-.333,.020))
    box(name+"BootShaft",ankle,(0,-.045,-.027),(.178,.154,.183),"boot")
    box(name+"BootToe",ankle,(0,-.077,-.168),(.192,.085,.250),"boot")
    box(name+"BootSole",ankle,(0,-.122,-.125),(.205,.033,.308),"sole")
    for j in range(3):
        box(name+"Lace%d"%j,ankle,(0,-.011-j*.024,-.204),(.080,.007,.014),"metal")

path=Path(sys.argv[1] if len(sys.argv)>1 else "dembel_fp.glb")
path.parent.mkdir(parents=True,exist_ok=True)
path.write_bytes(scene.export(file_type="glb"))
print(f"FPS_CHARACTER_ASSET_READY: separate=true meshes={len(scene.geometry)} bytes={path.stat().st_size}")
