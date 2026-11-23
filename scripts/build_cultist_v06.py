"""Generate the free v0.6 cultist as a true grouped GLB before Godot import.
No paid services. Face-colour weathering, uneven cloth and named scene nodes.
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
import trimesh

random.seed(614)
scene = trimesh.Scene()
groups = ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]
counter = {k: 0 for k in groups}

def add(name, mesh, color, group="Torso"):
    # Muted randomized face colours simulate dirty nonuniform rough textiles.
    base = np.asarray(color[:3], dtype=float)
    shades = np.clip(np.random.default_rng(counter[group] + 340).normal(0.84, 0.10, len(mesh.faces)), 0.48, 1)
    col = np.column_stack((np.clip(base[None,:]*shades[:,None],0,255),np.full((len(shades),1),255))).astype("uint8")
    mesh.visual.face_colors = col
    scene.add_geometry(mesh, geom_name="%s_%s_%d" % (group,name,counter[group]), parent_node_name=group)
    counter[group] += 1

def sphere(name, at, scale, color, group="Torso", detail=2):
    mesh = trimesh.creation.icosphere(subdivisions=detail)
    mesh.apply_scale(scale)
    mesh.apply_translation(at)
    add(name, mesh, color, group)

def rope(name, pts, radius, color, group="Torso"):
    for i,(a,b) in enumerate(zip(pts[:-1],pts[1:])):
        a=np.asarray(a,float);b=np.asarray(b,float);vec=b-a
        if np.linalg.norm(vec)<1e-6: continue
        mesh=trimesh.creation.cylinder(radius=radius,height=float(np.linalg.norm(vec)),sections=6)
        mesh.apply_transform(trimesh.geometry.align_vectors([0,0,1],vec))
        mesh.apply_translation((a+b)*.5)
        add(name+str(i),mesh,color,group)

def cloth(name,levels,color,group="Torso",segments=32,folds=8,phase=1):
    vertices=[];faces=[];colors=[]
    for level,(z,rx,ry,x,y) in enumerate(levels):
        for j in range(segments):
            angle=j*math.tau/segments
            perturb=1+.058*math.sin(angle*folds+phase)+.024*math.sin(angle*folds*2)
            bottom=(.027*math.sin(angle*9+phase)+random.uniform(-.021,.021)) if level==0 else 0
            vertices.append([x+rx*math.cos(angle)*perturb,y+ry*math.sin(angle)*perturb,z+bottom])
    for i in range(len(levels)-1):
        for j in range(segments):
            a=i*segments+j;b=i*segments+(j+1)%segments;c=(i+1)*segments+j;d=(i+1)*segments+(j+1)%segments
            faces.extend([[a,b,c],[b,d,c]])
            dirt=.59 if i==0 else (.75 if i==1 else 1)
            value=dirt*(.8+.15*math.sin(j*math.tau*folds/segments+phase))
            colors.extend([[*np.clip(np.array(color[:3])*value,0,255).astype("uint8"),255]]*2)
    mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
    mesh.visual.face_colors=np.asarray(colors,dtype="uint8")
    scene.add_geometry(mesh,geom_name="%s_%s_%d"%(group,name,counter[group]),parent_node_name=group)
    counter[group]+=1

# Boot groups remain independent for future hitzone/animation mapping.
for side,part in [(-1,"LeftLeg"),(1,"RightLeg")]:
    x=side*.195
    sphere("worn_boot", [x,-.14,.11],[.14,.20,.115],[52,51,47,255],part)
    cloth("dark_trouser",[(.24,.13,.12,x,0),(.77,.14,.13,x,0)],[39,40,42,255],part,segments=14,folds=5)

# Outer robe: narrow shoulders, heavy folds, asymmetric damp hem.
cloth("dirty_cassock",[(.24,.44,.28,0,0),(.4,.51,.32,0,0),(.65,.45,.28,0,0),(.95,.36,.24,0,0),(1.25,.29,.21,0,0),(1.65,.28,.2,0,0),(2.07,.30,.18,0,0)],[48,49,50,255],segments=48,folds=11,phase=.6)
cloth("inner_robe",[(.23,.37,.22,0,0),(1.2,.25,.19,0,0)],[29,31,32,255],segments=32,phase=2.0)
cloth("cowl",[(1.72,.30,.18,0,0),(1.87,.35,.22,0,0),(2.05,.28,.17,0,0)],[36,38,40,255],segments=30,phase=2.5)

for side,part in [(-1,"LeftArm"),(1,"RightArm")]:
    cloth("wide_dirty_sleeve",[(1.08,.21,.24,side*.72,0),(1.22,.17,.20,side*.65,0),(1.54,.12,.14,side*.50,0),(1.95,.14,.14,side*.31,0)],[46,48,48,255],part,segments=22,folds=6,phase=side)
    sphere("cuff_darkness",[side*.72,0,1.075],[.17,.14,.025],[15,16,18,255],part,detail=2)

for i in range(36):
    a=i*math.tau/36
    b=(i+1)*math.tau/36
    rope("belt",[(.30*math.cos(a),.22*math.sin(a),1.21),(.30*math.cos(b),.22*math.sin(b),1.21)],.021,[111,109,70,255])
for x in (-.09,.10):
    rope("hanging_cord",[(x,-.23,1.21),(x,-.26,1.0),(x*1.19,-.28,.62)],.015,[129,125,78,255])

sphere("deep_hood",[0,.04,2.31],[.27,.22,.30],[29,30,32,255],"Head",3)
sphere("hood_crown",[0,-.01,2.49],[.23,.18,.12],[30,31,33,255],"Head",2)
sphere("recessed_shadow",[0,-.19,2.31],[.16,.06,.21],[11,13,15,255],"Head",3)
sphere("weathered_face",[0,-.238,2.31],[.11,.034,.15],[77,71,65,255],"Head",3)
sphere("nose",[0,-.27,2.29],[.028,.038,.068],[89,78,70,255],"Head",2)
sphere("beard",[0,-.27,2.21],[.12,.055,.14],[42,43,41,255],"Head",2)
for j in range(14):
    x=(j-6.5)*.017
    rope("rough_beard",[(x,-.31,2.21),(x*.80,-.31,2.11-0.06*random.random())],.006,[52,53,50,255],"Head")
for side in (-1,1):
    sphere("eye_socket",[side*.066,-.27,2.36],[.034,.012,.025],[17,17,18,255],"Head")
    sphere("dull_iris",[side*.064,-.285,2.355],[.009,.006,.009],[103,46,39,255],"Head",1)
    rope("brow",[(side*.032,-.27,2.39),(side*.10,-.26,2.40)],.013,[32,34,35,255],"Head")
rope("hood_rim",[(-.18,-.25,2.2),(-.21,-.25,2.37),(-.16,-.25,2.5),(0,-.244,2.53),(.18,-.25,2.5),(.21,-.25,2.35),(.17,-.25,2.2)],.033,[39,40,42,255],"Head")

# Subdued weathered rust-red chest sign, not luminous plastic.
red=[117,43,38,255]
rope("symbol_left",[(-.14,-.20,1.975),(-.10,-.22,1.89),(0,-.235,1.81)],.012,red)
rope("symbol_right",[(.14,-.20,1.975),(.1,-.22,1.89),(0,-.235,1.81)],.012,red)
rope("symbol_center",[(0,-.22,1.99),(0,-.235,1.81)],.012,red)
rope("symbol_crown",[(-.14,-.2,1.97),(0,-.22,1.95),(.14,-.2,1.97)],.01,red)
for i in range(17):
    a=(i+1)*math.tau/19
    if math.sin(a)>.3:continue
    x=.43*math.cos(a);y=.29*math.sin(a)
    rope("frayed_hem",[(x,y,.30),(x*1.04,y*1.04,.24-random.random()*.035)],.004,[61,62,61,255])

for group in groups:
    scene.graph.update(frame_to=group,frame_from=scene.graph.base_frame)
out=Path(sys.argv[1] if len(sys.argv)>1 else "godot/assets/npc/cultist_modular.glb")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(scene.export(file_type="glb"))
print("CULTIST_MODEL_V06_OK:",out,out.stat().st_size,"bytes",counter)
