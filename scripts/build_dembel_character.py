"""Chernozerye: original low-poly adult protagonist. Blender-editable GLB.
Independent leg joints: looking down rotates the CAMERA, not the leg mesh.
Run: python scripts/build_dembel_character.py godot/assets/dembel_2005.glb
"""
import math
import sys
from pathlib import Path
import numpy as np
import trimesh
from trimesh.visual.material import PBRMaterial
from trimesh.visual import TextureVisuals

P = {
 "coat":(105,103,88,255),"dark":(71,75,66,255),"edge":(131,125,103,255),
 "pants":(69,75,72,255),"pants_dark":(52,59,56,255),
 "boots":(57,52,46,255),"sole":(34,34,32,255),
 "canvas":(130,117,91,255),"canvas_dark":(98,87,66,255),
 "belt":(88,66,45,255),"metal":(141,133,109,255),
 "skin":(154,127,110,255),"skin_dark":(110,88,80,255),
 "hair":(54,48,40,255),"shirt":(87,89,73,255),
}
scene=trimesh.Scene()
scene.graph.update(frame_from="world",frame_to="CharacterRoot",matrix=np.eye(4))

def pivot(name,parent,at=(0,0,0)):
    m=np.eye(4);m[:3,3]=at
    scene.graph.update(frame_from=parent,frame_to=name,matrix=m)

def geo(name,parent,mesh,shade):
    # Explicit glTF PBR base-color material. Vertex colours alone imported
    # as white in the Godot Web Compatibility renderer (see 0.6.2 screenshots).
    rgba = [channel / 255.0 for channel in P[shade]]
    mesh.visual = TextureVisuals(material=PBRMaterial(
        name="cloth_" + shade,
        baseColorFactor=rgba,
        metallicFactor=0.0,
        roughnessFactor=1.0,
        doubleSided=name.startswith("FPSCoat")
    ))
    scene.add_geometry(mesh,node_name=name,geom_name=name,parent_node_name=parent)

def cube(name,parent,pos,size,shade):
    mesh=trimesh.creation.box(extents=size);mesh.apply_translation(pos)
    geo(name,parent,mesh,shade)

def tube(name,parent,a,b,r0,r1,shade,steps=7,cap_start=True):
    a=np.array(a,dtype=float);b=np.array(b,dtype=float)
    d=b-a;d/=np.linalg.norm(d)
    ref=np.array((1,0,0)) if abs(d[0])<.9 else np.array((0,0,1))
    r=np.cross(d,ref);r/=np.linalg.norm(r);t=np.cross(d,r)
    v=[]
    for q,rad in ((a,r0),(b,r1)):
        for k in range(steps):
            h=2*math.pi*k/steps
            v.append(q+rad*(math.cos(h)*r+math.sin(h)*t))
    f=[]
    for k in range(steps):
        j=(k+1)%steps
        f += [(k,j,steps+j),(k,steps+j,steps+k)]
    for k in range(1,steps-1):
        if cap_start:
            f.append((0,k+1,k))
        f.append((steps,steps+k,steps+k+1))
    geo(name,parent,trimesh.Trimesh(vertices=v,faces=f,process=False),shade)

def coat():
    rings=[(.79,.310,.197),(.88,.305,.205),(1.18,.278,.196),
           (1.36,.323,.207),(1.45,.357,.182)]
    v=[]
    for y,x,z in rings:
        v += [(-x,y,-z*.63),(-x*.62,y,-z),(x*.62,y,-z),
              (x,y,-z*.63),(x,y,z*.63),(x*.6,y,z),
              (-x*.6,y,z),(-x,y,z*.63)]
    faces=[]
    for r in range(len(rings)-1):
        for k in range(8):
            j=(k+1)%8;lo=r*8;hi=lo+8
            faces += [(lo+k,lo+j,hi+j),(lo+k,hi+j,hi+k)]
    for k in range(1,7):
        faces += [(0,k+1,k),(32,32+k,32+k+1)]
    geo("WinterCoat","CharacterRoot",
        trimesh.Trimesh(vertices=v,faces=faces,process=False),"coat")

coat()
cube("ShirtAtNeck","CharacterRoot",(0,1.425,-.034),(.34,.115,.24),"shirt")
cube("CoatFrontSeam","CharacterRoot",(.035,1.115,-.203),(.025,.62,.014),"dark")
for i in range(4):
    cube("Button_"+str(i),"CharacterRoot",(.044,1.345-i*.14,-.222),(.02,.02,.013),"metal")
for s,short in ((-1,"L"),(1,"R")):
    cube("CoatPocket"+short,"CharacterRoot",(s*.205,.995,-.206),(.16,.17,.052),"dark")
    cube("PocketFlap"+short,"CharacterRoot",(s*.205,1.085,-.240),(.165,.045,.013),"edge")
    cube("ShoulderEpaulette"+short,"CharacterRoot",(s*.276,1.45,-.055),(.153,.028,.121),"dark")
cube("WebBelt","CharacterRoot",(0,.932,0),(.646,.095,.420),"belt")
cube("BeltBuckle","CharacterRoot",(0,.931,-.225),(.092,.07,.025),"metal")
cube("CanvasSidePouch","CharacterRoot",(-.340,.906,-.085),(.145,.215,.22),"canvas")
cube("CanvasPouchFlap","CharacterRoot",(-.34,1.017,-.198),(.157,.055,.024),"canvas_dark")
cube("SidorCanvasSack","CharacterRoot",(0,1.13,.333),(.438,.568,.260),"canvas")
cube("SidorRollTop","CharacterRoot",(0,1.45,.335),(.44,.113,.266),"canvas_dark")
for s,name in ((-1,"L"),(1,"R")):
    tube("ShoulderStrap"+name,"CharacterRoot",
         (s*.213,1.457,-.078),(s*.28,1.006,.245),.034,.028,"belt",6)

for s,label in ((-1,"Left"),(1,"Right")):
    hip=label+"LegPivot";pivot(hip,"CharacterRoot",(s*.163,.866,.026))
    tube(label+"Thigh",hip,(0,0,0),(0,-.380,-.008),.132,.110,"pants",8,cap_start=False)
    knee=label+"KneePivot";pivot(knee,hip,(0,-.380,-.008))
    tube(label+"LowerLeg",knee,(0,0,0),(0,-.355,.022),.112,.088,"pants_dark",cap_start=False)
    ankle=label+"AnklePivot";pivot(ankle,knee,(0,-.355,.022))
    cube(label+"BootShaft",ankle,(0,-.04,-.035),(.189,.162,.208),"boots")
    cube(label+"BootToe",ankle,(0,-.072,-.176),(.194,.092,.275),"boots")
    cube(label+"BootSole",ankle,(0,-.125,-.142),(.211,.043,.334),"sole")
    for k in range(3):
        cube(label+"BootLace_"+str(k),ankle,(0,-.003-k*.030,-.208),(.087,.008,.013),"metal")
    arm=label+"ArmPivot";pivot(arm,"CharacterRoot",(s*.324,1.436,0))
    tube(label+"UpperSleeve",arm,(0,0,0),(s*.054,-.277,-.029),.134,.113,"coat")
    elbow=label+"ElbowPivot";pivot(elbow,arm,(s*.054,-.277,-.029))
    tube(label+"ForearmSleeve",elbow,(0,0,0),(s*.022,-.259,-.07),.111,.087,"dark")
    cube(label+"CoatCuff",elbow,(s*.02,-.265,-.069),(.154,.075,.173),"edge")
    hand=label+"HandPivot";pivot(hand,elbow,(s*.022,-.294,-.07))
    cube(label+"Hand",hand,(0,-.068,-.006),(.113,.161,.092),"skin")
    cube(label+"Thumb",hand,(-s*.066,-.065,-.031),(.043,.079,.051),"skin_dark")

pivot("HeadPivot","CharacterRoot",(0,1.505,0))
tube("Neck","HeadPivot",(0,-.03,0),(0,.065,-.01),.095,.085,"skin",8)
tube("Head","HeadPivot",(0,.066,-.01),(0,.292,-.026),.114,.111,"skin",10)
tube("ShortHair","HeadPivot",(0,.267,-.025),(0,.325,-.028),.114,.111,"hair",10)
cube("Nose","HeadPivot",(0,.174,-.146),(.051,.072,.051),"skin_dark")
for s,name in ((-1,"Left"),(1,"Right")):
    cube(name+"Eyebrow","HeadPivot",(s*.066,.237,-.131),(.055,.018,.02),"hair")
    cube(name+"EyeShadow","HeadPivot",(s*.066,.206,-.139),(.044,.019,.014),"skin_dark")

# An original first-person CUTAWAY sewn from the SAME garment palette.
# This face-only variant has no cap/back: it cannot surround or swallow the
# player's eye. The full winter coat remains intact for F4 model inspection.
def fp_panel(name, points, shade):
    v=np.array(points,dtype=float)
    # A single winding and double-sided PBR. Duplicated opposite triangles
    # cancelled normals and made spiky, unpredictable lighting in WebGL.
    f=np.array([(0,1,2),(0,2,3)])
    geo(name,"CharacterRoot",trimesh.Trimesh(vertices=v,faces=f,process=False),shade)

# The front is a short waist/chest crop WELL BELOW the player's eye.
# Previous panels reached y=1.30 (eye=1.55), exploding to ~2/3 screen
# width during steep lookdown. The upper limit is now 1.055 m.
fp_panel("FPSCoatUpperLeft", [
    (-.226,1.055,-.126),(-.012,1.055,-.138),
    (-.012,.920,-.191),(-.252,.920,-.185)],"coat")
fp_panel("FPSCoatUpperRight", [
    (.012,1.055,-.138),(.226,1.055,-.126),
    (.252,.920,-.185),(.012,.920,-.191)],"edge")
fp_panel("FPSCoatLowerLeft", [
    (-.252,.920,-.185),(-.012,.920,-.191),
    (-.012,.775,-.199),(-.266,.785,-.177)],"dark")
fp_panel("FPSCoatLowerRight", [
    (.012,.920,-.191),(.252,.920,-.185),
    (.266,.785,-.177),(.012,.775,-.199)],"coat")
cube("FPSCoatCenterSeam","CharacterRoot",(0,.917,-.202),(.015,.255,.012),"dark")
for i in range(3):
    cube("FPSCoatButton"+str(i),"CharacterRoot",(.023,1.012-i*.070,-.211),(.014,.014,.012),"metal")
cube("FPSCoatLowerHem","CharacterRoot",(0,.773,-.202),(.528,.022,.018),"edge")
for s,name in ((-1,"L"),(1,"R")):
    cube("FPSCoatPocket"+name,"CharacterRoot",(s*.180,.833,-.206),(.114,.066,.014),"canvas_dark")
    cube("FPSCoatPocketFlap"+name,"CharacterRoot",(s*.180,.870,-.214),(.125,.023,.014),"canvas")

dest=Path(sys.argv[1] if len(sys.argv)>1 else "dembel_2005.glb")
dest.parent.mkdir(parents=True,exist_ok=True)
dest.write_bytes(scene.export(file_type="glb"))
print("CHARACTER_ASSET_READY: file=",dest," bytes=",dest.stat().st_size,
      " meshes=",len(scene.geometry)," pivots=8")
