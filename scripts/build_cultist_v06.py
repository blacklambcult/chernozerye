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
groups = ["Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg", "LeftShin", "RightShin", "LeftFoot", "RightFoot"]
counter = {k: 0 for k in groups}

def add(name, mesh, color, group="Torso"):
    # Muted randomized face colours simulate dirty nonuniform rough textiles.
    base = np.asarray(color[:3], dtype=float)
    shades = np.clip(np.random.default_rng(counter[group] + 340).normal(0.84, 0.10, len(mesh.vertices)), 0.48, 1)
    col = np.column_stack((np.clip(base[None,:]*shades[:,None],0,255),np.full((len(shades),1),255))).astype("uint8")
    mesh.visual.vertex_colors = col
    scene.add_geometry(mesh, geom_name="%s_%s_%d" % (group,name,counter[group]), parent_node_name=group)
    counter[group] += 1

def sphere(name, at, scale, color, group="Torso", detail=3):
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

def cloth(name,levels,color,group="Torso",segments=64,folds=11,phase=1):
    """Dense, sculpted fabric with interleaved control rings and weathered vertex colours."""
    control=[tuple(v) for v in levels]
    fine=[]
    for row in range(len(control)-1):
        a=control[row]; b=control[row+1]
        # Additional loops follow tapered folds instead of uniformly inflating the garment.
        for j in range(5):
            t=j/5.0
            eased=t*t*(3-2*t)
            fine.append(tuple(a[k]*(1-eased)+b[k]*eased for k in range(5)))
    fine.append(control[-1])
    levels=fine
    vertices=[];faces=[];vertex_colors=[]
    seed=math.sin(phase*7.2)
    for level,(z,rx,ry,x,y) in enumerate(levels):
        progress=level/max(1,len(levels)-1)
        for j in range(segments):
            angle=j*math.tau/segments
            # Different frequency folds, sharper ridges, and controlled anisotropy.
            ridge=math.sin(angle*folds+phase+progress*1.1)
            crease=math.sin(angle*(folds*2+1)-phase+progress*2.2)
            diagonal=math.sin(angle*5-progress*7.0+phase)
            perturb=1+.080*ridge+.024*crease+.022*diagonal
            hem=(.04*math.sin(angle*8+phase)+.025*math.cos(angle*13-phase)+.014*math.sin(angle*23)) if level==0 else 0
            droop=.014*math.sin(angle*7.0+progress*8)
            vx=x+rx*math.cos(angle)*perturb
            vy=y+ry*math.sin(angle)*perturb
            vz=z+hem+droop
            vertices.append([vx,vy,vz])
            # Dirt near the ground; subtle fibre streaks, creases and patchy discoloration.
            hem_dirt=.60+.4*min(1.0,max(0.0,(z-.19)/.75))
            fold_shade=.86+.12*ridge-.065*max(0.0,-crease)
            speckle=.94+.055*math.sin(j*4.7+level*6.2+phase)+.04*math.cos(j*10.1-level*3.3)
            soil=.89 if (int(angle*9+phase*3)%9==3 and progress<.50) else 1.0
            mul=max(.42,min(1.04,hem_dirt*fold_shade*speckle*soil))
            vertex_colors.append([*np.clip(np.asarray(color[:3],dtype=float)*mul,0,255).astype("uint8"),255])
    for i in range(len(levels)-1):
        for j in range(segments):
            a=i*segments+j;b=i*segments+(j+1)%segments;c=(i+1)*segments+j;d=(i+1)*segments+(j+1)%segments
            faces.extend([[a,b,c],[b,d,c]])
    mesh=trimesh.Trimesh(vertices=vertices,faces=faces,process=False)
    mesh.visual.vertex_colors=np.asarray(vertex_colors,dtype="uint8")
    scene.add_geometry(mesh,geom_name="%s_%s_%d"%(group,name,counter[group]),parent_node_name=group)
    counter[group]+=1


def hanging_panel(name, low_z, high_z, angular_center, angular_span, color, radius_low=.48, radius_high=.35, group="Torso"):
    """Asymmetric split overcloth with many natural hanging folds and a ragged hem."""
    nx=40;ny=24;verts=[];colors=[];faces=[]
    for iy in range(ny+1):
        t=iy/ny
        z=low_z*(1-t)+high_z*t
        radius=radius_low*(1-t)+radius_high*t
        for ix in range(nx+1):
            f=ix/nx;angle=angular_center+(f-.5)*angular_span
            fold=.075*math.sin(f*math.tau*5.0+t*.75)+.025*math.sin(f*math.tau*13-t*3)
            edge_torn=(.06*math.sin(f*math.tau*9.1)+.022*math.sin(f*math.tau*21))*(1-t)**5
            rr=radius+fold
            zz=z+edge_torn-.04*(1-t)*(f-.5)
            verts.append([rr*math.cos(angle),rr*math.sin(angle),zz])
            dirt=.64+.34*t
            shade=(.82+.18*math.sin(f*math.tau*5.0))*(.94+.04*math.sin(iy*2.4+ix*3.7))
            colors.append([*np.clip(np.asarray(color[:3])*dirt*shade,0,255).astype("uint8"),255])
    for iy in range(ny):
        for ix in range(nx):
            a=iy*(nx+1)+ix;b=a+1;c=a+(nx+1);d=c+1
            faces.extend([[a,b,c],[b,d,c]])
    mesh=trimesh.Trimesh(vertices=verts,faces=faces,process=False)
    mesh.visual.vertex_colors=np.asarray(colors,dtype="uint8")
    scene.add_geometry(mesh,geom_name="%s_%s_%d"%(group,name,counter[group]),parent_node_name=group)
    counter[group]+=1

# Articulated parts: thigh, shin and boot retain independent nodes in the GLB.
# Naming mirrors the game body's hit zones and the browser's three-joint gait rig.
for side,part in [(-1,"LeftLeg"),(1,"RightLeg")]:
    x=side*.195
    shin=part.replace("Leg","Shin")
    foot=part.replace("Leg","Foot")
    cloth("upper_trouser",[(.44,.14,.12,x,0),(.79,.145,.13,x,0)],[42,43,45,255],part,segments=14,folds=5)
    cloth("lower_trouser",[(.18,.13,.12,x,0),(.47,.145,.12,x,0)],[39,40,43,255],shin,segments=14,folds=5)
    sphere("worn_boot", [x,-.14,.11],[.14,.20,.115],[52,51,47,255],foot)
    sphere("worn_heel", [x,.025,.065],[.115,.10,.06],[37,37,35,255],foot,detail=1)

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


# Sculpted overlapping overcloth panels. The front is -Y, so these sections stay
# visible beneath the chest symbol while breaking the cylindrical silhouette.
hanging_panel("asymmetric_outer_front",.34,1.34,-math.pi/2-.24,1.70,[47,44,42,255],.60,.32)
hanging_panel("torn_side_layer",.44,1.65,-math.pi/2+1.25,1.05,[39,39,40,255],.56,.30)
hanging_panel("tattered_shoulder_mantle",1.43,2.04,-math.pi/2,2.48,[49,48,46,255],.37,.25)

# Double-layer hood edge and many uneven beard clumps; designed as actual meshes,
# rather than painting a dense image over a blocky face.
for i in range(21):
    a=math.pi*.05+i*math.pi*.90/20
    x=math.cos(a)*.245;z=2.31+math.sin(a)*.20
    rope("thick_hood_seam",[(x,-.238,z),(x*.97,-.253,z-.017)],.011,[35,35,36,255],"Head")
for i in range(54):
    xx=(i-26.5)/53*.23
    seed_i=math.sin(i*5.6)
    top=2.22-.022*math.sin(i*2.1)
    end_z=2.04-.11*(1-abs(xx)/.15)+.038*seed_i
    rope("beard_strand",[(xx,-.298,top),(xx*.90,-.32,top-.085),(xx*.75,-.316,end_z)],.0045+(.002*(i%4)),[58+(i%3)*3,56+(i%4)*3,53+(i%5)*2,255],"Head")
for side in (-1,1):
    for n in range(8):
        a=side*(.085+.014*n)
        rope("hood_wear_stitch",[(a,-.206,2.21+.013*n),(a+side*.02,-.198,2.20+.013*n)],.003,[63,61,57,255],"Head")

# Rope is braided as three textured strands, retaining the existing belt geometry.
for i in range(80):
    a=i*math.tau/80;b=(i+1)*math.tau/80
    for strand in range(3):
        phase=strand*math.tau/3+i*.62
        za=1.21+.010*math.sin(phase);zb=1.21+.010*math.sin(phase+.62)
        ra=.30+.010*math.cos(phase);rb=.30+.010*math.cos(phase+.62)
        rope("woven_belt",[(ra*math.cos(a),.22*math.sin(a),za),(rb*math.cos(b),.22*math.sin(b),zb)],.006,[132,122,81,255])
for side in (-1,1):
    for strand in range(3):
        x=side*.13 + (strand-1)*.009
        rope("braid_tail",[(x,-.27,1.17),(x+.006*math.sin(strand),-.288,.92),(x+side*.012,-.30,.61)],.006,[118,113,73,255])

# Boots: layered leather tongues, raised soles, lacings and fine hardware.
for side,part in [(-1,"LeftFoot"),(1,"RightFoot")]:
    x=side*.195
    sphere("toe_cap", [x,-.188,.095],[.145,.13,.073],[58,53,47,255],part)
    sphere("sole", [x,-.12,.006],[.158,.225,.038],[34,33,30,255],part)
    for i in range(6):
        z=.10+i*.035
        rope("boot_laces",[(x-.052,-.238,z),(x+.052,-.238,z+.012)],.0048,[85,80,73,255],part)
        for delta in (-1,1):
            sphere("eyelet",[x+delta*.053,-.239,z],[.008,.004,.008],[85,80,72,255],part,detail=1)

# Chest paint, applied in irregular flecks instead of perfectly sharp neon strokes.
for i in range(47):
    xx=random.uniform(-.145,.145)
    zz=random.uniform(1.77,1.99)
    yy=-.215+.03*math.cos(xx*7)
    if random.random()<.72:
        rope("weathered_red_paint",[(xx,yy,zz),(xx+.01*random.random(),yy-.007,zz-.007-random.random()*.02)],.0028,[111+random.randrange(22),31+random.randrange(12),30,255])

for group in groups:
    scene.graph.update(frame_to=group,frame_from=scene.graph.base_frame)
out=Path(sys.argv[1] if len(sys.argv)>1 else "godot/assets/npc/cultist_modular.glb")
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(scene.export(file_type="glb"))
print("CULTIST_MODEL_V06_OK:",out,out.stat().st_size,"bytes",counter)
