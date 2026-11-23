"""Chernozerye: Slujitel Zhivitsy v0.8, detailed procedural 3D game character.

Authorable free mid-poly GLB, with only numpy + trimesh.  Z-up model space,
- Y is forward (the face is at negative Y), grouped for Godot/Three gait.
Geometry is shaped, not merely subdivided: asymmetrical sculpted layered robes,
ragged fabric, recessed hood, facial features, braided cord and worked boots.
"""
from __future__ import annotations

import math
import sys
from collections import OrderedDict
from pathlib import Path

import numpy as np
import trimesh

PI = math.pi
TAU = 2 * PI
rng = np.random.default_rng(18108)
GROUPS = ("Head", "Torso", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
          "LeftShin", "RightShin", "LeftFoot", "RightFoot")
buckets: dict[str, list[trimesh.Trimesh]] = OrderedDict((k, []) for k in GROUPS)


def append(mesh: trimesh.Trimesh, name: str, rgb: tuple[int,int,int],
           group: str = "Torso", *, grain: float = .075, soot: bool = False):
    if mesh.is_empty or len(mesh.vertices) == 0:
        return
    v = mesh.vertices
    z = v[:, 2]
    ambient = .91 + grain * (.58*np.sin(v[:,0]*75 +v[:,1]*22) +
                            .35*np.cos(v[:,2]*41 -v[:,0]*51) +
                            .33*np.sin(v[:,1]*83+v[:,2]*103))
    ambient += rng.normal(0, .016, size=len(v))
    if soot:
        muddy = np.clip((.75-z)/.72, 0,1)
        ambient *= (1 - .28 * muddy)
        ambient += muddy*.025*np.sin(v[:,0]*117+v[:,1]*101)
    colors = np.clip(np.asarray(rgb, dtype=np.float32)[None,:] * ambient[:,None],0,255)
    mesh.visual.vertex_colors = np.column_stack((colors,np.full(len(v),255))).astype(np.uint8)
    mesh.metadata['name'] = name
    buckets[group].append(mesh)


def ellipsoid(name, center, radii, rgb, group='Torso', subdivisions=3):
    mesh=trimesh.creation.icosphere(subdivisions=subdivisions, radius=1)
    mesh.apply_scale(radii)
    mesh.apply_translation(center)
    append(mesh,name,rgb,group)


def box(name, center, size, rgb,group='Torso', rotate_x=0):
    mesh=trimesh.creation.box(extents=size)
    if rotate_x:
        rot=trimesh.transformations.rotation_matrix(rotate_x,[1,0,0])
        mesh.apply_transform(rot)
    mesh.apply_translation(center)
    append(mesh,name,rgb,group)


def polyline_tube(name,points,radius, rgb,group='Torso',sides=7,closed=False):
    """Continuous multi-section tube, so rope and embroidery add minimal draw calls."""
    pts=np.asarray(points,float)
    if closed:pts=np.concatenate([pts,pts[:1]])
    if len(pts)<2:return
    vertices=[]; faces=[]
    for k,p in enumerate(pts):
        tangent=pts[min(len(pts)-1,k+1)]-pts[max(0,k-1)]
        length=np.linalg.norm(tangent)
        if length<1e-8:tangent=np.array([0.,0.,1.])
        else:tangent/=length
        ref=np.array([0.,0.,1.]) if abs(tangent[2])<.93 else np.array([0.,1.,0.])
        u=np.cross(tangent,ref);u/=max(np.linalg.norm(u),1e-8)
        w=np.cross(tangent,u)
        for n in range(sides):
            a=n*TAU/sides
            vertices.append(p+radius*(math.cos(a)*u+math.sin(a)*w))
    for k in range(len(pts)-1):
        for n in range(sides):
            a=k*sides+n;b=k*sides+(n+1)%sides
            c=(k+1)*sides+n;d=(k+1)*sides+(n+1)%sides
            faces.extend(((a,b,c),(b,d,c)))
    append(trimesh.Trimesh(vertices=vertices,faces=faces,process=False),name,rgb,group,grain=.04)


def interpolate(keys, t):
    """Four-dimensional Catmull-Rom for organically lofted garments."""
    seg=min(len(keys)-2,int(t*(len(keys)-1)))
    u=np.clip(t*(len(keys)-1)-seg,0,1)
    p0=np.array(keys[max(0,seg-1)]);p1=np.array(keys[seg]);p2=np.array(keys[seg+1]);p3=np.array(keys[min(len(keys)-1,seg+2)])
    return p1+ .5*u*(p2-p0+u*(2*p0-5*p1+4*p2-p3+u*(3*(p1-p2)+p3-p0)))


def garment(name, keys, rgb, group='Torso', *, rings=72, rows=30, pleats=11,
            seed=0.7, hem=.02, tilt=0, grime=False, damage=False):
    """Loft a flowing asymmetrical garment in Z-up, with shaded sculpted folds.

    keys ascending Z: each (z,r_x,r_y,x_offset,y_offset).
    A low-poly primitive becomes a woven, irregular shape with vertical fold
    structure, correlated displacement, and an uneven fraying lower boundary.
    """
    v=[];f=[]
    wiggle=rng.normal(0,1,rings)
    wiggle=np.convolve(np.r_[wiggle[-2:],wiggle,wiggle[:2]], np.ones(5)/5,mode='valid')
    for iy in range(rows+1):
        t=iy/rows
        z,rx,ry,cx,cy=interpolate(keys,t)
        for i in range(rings):
            angle=i*TAU/rings
            fold1=math.sin(angle*pleats+seed+z*.7)
            fold2=math.sin(angle*pleats*2-seed+z*1.2)
            fold3=math.cos(angle*3.5+z*3.1)
            fold_amp=.045+.032*(1-t)+.013*math.sin(z*2.8)
            crumple=1+fold_amp*fold1+.014*fold2+.018*fold3
            crumple+=.009*wiggle[i]
            hem_shift = (hem*(.68*math.sin(angle*7+seed)+.30*math.sin(angle*17)+.3*wiggle[i])*(1-t)**8)
            vertical = z + hem_shift + tilt*(cx*math.cos(angle))*(1-t)**3
            if damage and iy==0 and (i%23 in (4,5,6)):
                vertical += .037
            y = cy + (ry*crumple)*math.sin(angle) -.008*math.sin(t*PI)
            x = cx +(rx*crumple)*math.cos(angle)
            v.append((x,y,vertical))
    for iy in range(rows):
        for i in range(rings):
            a=iy*rings+i;b=iy*rings+(i+1)%rings
            c=(iy+1)*rings+i;d=(iy+1)*rings+(i+1)%rings
            if damage and iy<2 and i%29 in (9,10):
                continue
            f.extend(((a,b,c),(b,d,c)))
    mesh=trimesh.Trimesh(vertices=v,faces=f,process=False)
    append(mesh,name,rgb,group,grain=.14,soot=grime)


def drape_panel(name, z_bot,z_top,x0,x1, depth, color,
                *,group='Torso', rx=40, rz=22, fold=5, angle_slant=.15, rag=.05):
    """Asymmetric thin torn over-panel facing the camera, no ring silhouette."""
    v=[];f=[]
    for j in range(rz+1):
        t=j/rz
        for i in range(rx+1):
            u=i/rx
            x=x0+(x1-x0)*u+.022*math.sin(t*PI*2+u*6)
            z=z_bot+(z_top-z_bot)*t+angle_slant*(u-.5)*(1-t)
            if j==0:z+=rag*(.38*math.sin(u*27)+.23*math.sin(u*71))
            y=depth+.043*math.sin(u*TAU*fold+.4)*(1-t)+.018*math.sin(u*27+t*9)
            v.append((x,y,z))
    for j in range(rz):
        for i in range(rx):
            a=j*(rx+1)+i;b=a+1;c=(j+1)*(rx+1)+i;d=c+1
            if j<3 and i%19 in (6,7):continue
            f.extend(((a,b,c),(b,d,c)))
    append(trimesh.Trimesh(vertices=v,faces=f,process=False),name,color,group,grain=.14,soot=True)


def twisted_rope(name, path, radius, rgb,group='Torso',strands=3,sides=6):
    """One grouped mesh per strand; overlapping spiral creates a braided cord."""
    pts=np.asarray(path,float)
    for strand in range(strands):
        samples=[]
        for i,p in enumerate(pts):
            forward=pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]
            forward/=max(np.linalg.norm(forward),1e-7)
            u=np.cross(forward,[0,0,1.])
            if np.linalg.norm(u)<1e-5:u=np.cross(forward,[0,1,0.])
            u/=max(np.linalg.norm(u),1e-7)
            w=np.cross(forward,u)
            a=TAU*(i/max(1,len(pts)-1))*7.5+strand*TAU/strands
            samples.append(p+radius*.35*(math.cos(a)*u+math.sin(a)*w))
        shade=1-(strand%2)*.10
        polyline_tube(name+f'_strand{strand}',samples,radius*.54,tuple(int(c*shade) for c in rgb),group,sides=sides)


# --------- Lower body / animation-friendly groups -----------
for side,name in ((-1,'Left'),(1,'Right')):
    x=side*.195
    garment('upper_trouser',[(.43,.135,.125,x,0),(.57,.14,.12,x,0),(.79,.17,.145,x,-.015)],
            (42,42,43),name+'Leg',rings=26,rows=14,pleats=5,seed=side,hem=.006)
    garment('creases_in_shin',[(.17,.123,.12,x,.005),(.32,.126,.12,x,.02),(.49,.145,.14,x,.01)],
            (35,37,39),name+'Shin',rings=26,rows=16,pleats=6,seed=side*2,hem=.007)
    ellipsoid('boot_upper',(x,-.01,.175),(.142,.155,.17),(42,40,37),name+'Foot',3)
    ellipsoid('boot_toe',(x,-.17,.105),(.16,.20,.105),(45,43,41),name+'Foot',3)
    box('boot_sole',(x,-.10,.035),(.31,.43,.075),(27,28,27),name+'Foot')
    box('boot_heel',(x,.035,.056),(.25,.18,.092),(31,31,30),name+'Foot')
    for row in range(5):
        z=.16+row*.038;y=-.155+row*.009
        polyline_tube('boot_laces',[(x-.065,y,z),(x+.055,y-.005,z+.012)],.005,(77,69,58),name+'Foot',sides=5)
    for row in range(3):
        ellipsoid('laces_eyelet',(x+side*.075,-.153,row*.055+.15),(.008,.009,.009),(82,78,66),name+'Foot',1)

# ------------------ Cassock and layered overgown ------------------
garment('underrobe',[(.20,.41,.26,0,0),(.52,.42,.29,0,0),(1.09,.24,.22,0,0),(1.58,.24,.17,0,0)],
        (27,30,31),rings=64,rows=24,pleats=10,seed=2.1,hem=.055,grime=True)
garment('heavy_outer_cassock',[(.22,.52,.36,.012,.002),(.43,.545,.37,0,.005),(.72,.43,.31,0,0),
    (1.02,.315,.255,.018,.008),(1.30,.29,.23,0,.005),(1.60,.29,.21,0,0),(1.99,.31,.21,0,0)],
    (39,40,41),rings=86,rows=42,pleats=14,seed=.45,hem=.09,grime=True,damage=True,tilt=.045)
# Shredded overlapping diagonal panels, more natural than one cylinder.
drape_panel('layered_tattered_front',.38,1.60,-.46,.31,-.31,(39,39,40),rx=60,rz=34,fold=7,
            angle_slant=.24,rag=.055)
drape_panel('outer_asymmetric_front',.55,1.47,.01,.42,-.32,(42,41,39),rx=34,rz=22,fold=4,
            angle_slant=-.29,rag=.085)
# Cowl across shoulders and hood shawl. The lower edge is rough & asymmetrical.
garment('shoulder_mantle',[(1.68,.42,.28,0,-.008),(1.81,.44,.28,0,0),(1.94,.36,.23,0,0),
    (2.12,.26,.185,0,0)],(39,39,40),rings=70,rows=21,pleats=10,seed=1.6,hem=.06,damage=True)
# Shoulder cape hangs in front, showing a triangular chest point.
drape_panel('front_shoulder_shawl',1.60,2.13,-.36,.36,-.274,(35,36,38),rx=50,rz=22,fold=6,
            angle_slant=0,rag=.045)

# ---------------- Sleeves & worn cuffs ----------------
for side,name in ((-1,'LeftArm'),(1,'RightArm')):
    garment('bell_sleeve',[(1.03,.28,.29,side*.72,0),(1.14,.30,.30,side*.70,0),
        (1.43,.155,.17,side*.56,0),(1.72,.133,.14,side*.44,0),(1.96,.16,.15,side*.30,0)],
        (39,40,43),name,rings=44,rows=24,pleats=9,seed=.65+side,hem=.052,grime=False,damage=True)
    ellipsoid('dark_inside_sleeve',(side*.72,-.01,1.055),(.23,.22,.018),(13,14,16),name,2)
    for j in range(10):
        a=(j+2)*TAU/13
        sx=side*.72+.25*math.cos(a)
        sy=.23*math.sin(a)
        polyline_tube('cuff_fringing',[(sx,sy,1.057),(sx+.01*side,sy-.01,1.005-rng.uniform(.01,.05))],
                      .003,(68,63,59),name,sides=5)

# ---------------- Rope belt with twisted helical fibers ----------------
ring_points=[(.31*math.cos(a),.241*math.sin(a),1.245+.010*math.sin(a*4))
             for a in np.linspace(0,TAU,81)]
twisted_rope('waist_belt',ring_points,.020,(95,86,64))
for side in (-1,1):
    belt_path=[(side*.08,-.26,1.25),(.10*side,-.32,1.20),(.14*side,-.335,1.05),
               (.145*side,-.34,.85),(.150*side,-.335,.63),(.16*side,-.34,.56)]
    # 30 sample points for continuous braided cords.
    path=[]
    for a,b in zip(belt_path[:-1],belt_path[1:]):
        for t in np.linspace(0,1,7,endpoint=False):
            path.append(np.asarray(a)*(1-t)+np.asarray(b)*t)
    path.append(belt_path[-1])
    twisted_rope('cord_hang',path,.017,(98,90,69))
    for j in range(8):
        ang=j*TAU/8
        polyline_tube('cord_fray',[(side*.16+.015*math.cos(ang),-.34+.01*math.sin(ang),.57),
                                    (side*.16+.025*math.cos(ang),-.34+.018*math.sin(ang),.50-rng.uniform(0,.045))],
                      .002,(103,96,75),sides=5)
ellipsoid('thick_knot',(0,-.31,1.23),(.075,.045,.06),(85,79,58),'Torso',2)

# ---------------- Head: hood, shadow face, grey beard ----------------
# Back hood has organic folds (front opening is made of a separate rim, not a perfect oval).
ellipsoid('hood_mass',(0,.048,2.31),(.286,.258,.325),(27,28,29),'Head',subdivisions=4)
ellipsoid('hood_brow',(0,-.085,2.49),(.276,.252,.19),(34,34,35),'Head',subdivisions=3)
ellipsoid('shadow_recess',(0,-.216,2.305),(.190,.075,.235),(10,11,13),'Head',subdivisions=3)
ellipsoid('weathered_angular_face',(0,-.236,2.290),(.098,.03,.151),(64,60,58),'Head',subdivisions=4)
ellipsoid('long_nose',(0,-.256,2.281),(.03,.05,.065),(69,63,59),'Head',subdivisions=2)
ellipsoid('cheek_left',(-.087,-.263,2.293),(.028,.033,.065),(61,58,55),'Head',2)
ellipsoid('cheek_right',(.087,-.263,2.293),(.028,.033,.065),(58,54,51),'Head',2)
# Hood opening edge follows eyebrow and cheek, thick enough to cast a shadow.
hood_rim=[(-.185,-.259,2.14),(-.237,-.255,2.29),(-.232,-.256,2.405),
          (-.19,-.252,2.53),(-.11,-.247,2.573),(0,-.248,2.589),
          (.112,-.246,2.573),(.196,-.253,2.52),(.233,-.254,2.39),(.224,-.256,2.26),(.18,-.258,2.13)]
polyline_tube('torn_hood_brim',hood_rim,.034,(41,39,38),'Head',sides=9)
# Layered textile bands to make the side of the hood look sewn, not round.
for side in [-1,1]:
    polyline_tube('hood_seam',[(side*.23,-.10,2.48),(side*.29,.02,2.40),
        (side*.31,.12,2.23),(side*.27,.16,2.15)],.011,(51,50,49),'Head',sides=7)
    ellipsoid('sunken_eye',(side*.066,-.295,2.347),(.039,.011,.020),(22,22,22),'Head',2)
    ellipsoid('dull_eye',(side*.066,-.306,2.347),(.009,.008,.009),(62,48,46),'Head',2)
    polyline_tube('heavy_eyebrow',[(side*.024,-.295,2.385),(side*.097,-.288,2.393)],.015,(47,46,44),'Head')
# Shaggy three-dimensional beard beard; strips, not 1 cone.
ellipsoid('beard_thickness',(0,-.278,2.16),(.131,.09,.167),(53,51,48),'Head',3)
for j in range(48):
    t=(j+0.5)/48
    x=(t-.5)*.263
    fullness=1-abs(2*t-1)**1.5
    ztop=2.245-rng.uniform(0,.027)
    zend=2.08-.110*fullness-rng.uniform(0,.075)
    edge=.008+fullness*.004
    polyline_tube('beard_wisp',[(x,-.322,ztop),(x*.96,-.335,ztop-.07),
        (x*.9+rng.uniform(-.008,.008),-.339,zend)],edge,
        (47+int(rng.integers(0,18)),48+int(rng.integers(0,14)),47+int(rng.integers(0,13))),'Head',sides=5)
for side in [-1,1]:
    for j in range(8):
        x=side*(.036+j*.009)
        polyline_tube('wild_mustache',[(x,-.315,2.257),(x+side*.021,-.328,2.238),
                          (x+side*.033,-.33,2.212-rng.uniform(0,.026))],.006,
                         (57,54,50),'Head',sides=5)

# ---------------- Weathered hand-painted vermilion sigil ----------------
def paint_stroke(name,pts,width=.012,color=(109,39,35)):
    # A stitched pigment strip running just over chest fabric.
    v=[];f=[]
    for i,p in enumerate(pts):
        x,y,z=p
        # front negative Y; uneven edges with stable random seed
        w=width*(.75+rng.uniform(-.13,.21))
        v.extend(((x-w/2,y-.007,z),(x+w/2,y-.007,z)))
    for j in range(len(pts)-1):
        a=j*2;b=a+1;c=a+2;d=a+3
        f.extend(((a,b,c),(b,d,c)))
    if f:append(trimesh.Trimesh(vertices=v,faces=f,process=False),name,color,grain=.18)

# A slender geometric symbol like the user image, with unequal hand-brushed lines.
red=(91,34,32)
paint_stroke('sigil_upper_left',[(-.15,-.283,1.95),(-.11,-.293,1.915),(-.04,-.296,1.85),(0,-.297,1.80)],.016,red)
paint_stroke('sigil_upper_right',[(.16,-.282,1.97),(.09,-.295,1.915),(.038,-.298,1.86),(0,-.298,1.8)],.014,red)
paint_stroke('sigil_crown',[(-.15,-.283,1.95),(-.05,-.296,1.968),(.08,-.291,1.97),(.16,-.285,1.97)],.014,red)
paint_stroke('sigil_heart',[(0,-.30,2.02),(0,-.312,1.97),(0,-.311,1.88),(0,-.295,1.79)],.012,red)
paint_stroke('sigil_low_cross',[(-.10,-.307,1.89),(0,-.31,1.895),(.11,-.307,1.895)],.013,red)
for side in [-1,1]:
    paint_stroke('sigil_hook',[(side*.135,-.286,1.978),(side*.08,-.3,1.952),
         (side*.04,-.306,1.924),(side*.12,-.3,1.87)],.013,red)

# ---------------- Irregular frayed selvage near the muddy hem ----------------
for i in range(64):
    a=i*TAU/64
    if math.sin(a)>.22 or i%7==1:continue
    x=.51*math.cos(a);y=.36*math.sin(a)
    z=.27+rng.uniform(-.055,.035)
    polyline_tube('loose_hem_thread',[(x,y,z),(x*1.027,y*1.035,z-rng.uniform(.02,.085))],
                  .0025,(66,63,59),'Torso',sides=5)

# Export: collapse same-node geometry to keep draw calls low in real Godot game.
scene=trimesh.Scene()
counts={}
for group,pieces in buckets.items():
    if not pieces:
        raise RuntimeError('Empty rig group: '+group)
    combined=trimesh.util.concatenate(pieces)
    counts[group]={'meshes':len(pieces),'faces':len(combined.faces)}
    scene.add_geometry(combined,geom_name=group+'_Detailed_Mesh',parent_node_name=group)
    scene.graph.update(frame_to=group,frame_from=scene.graph.base_frame)
output=Path(sys.argv[1] if len(sys.argv)>1 else 'godot/assets/npc/cultist_modular.glb')
output.parent.mkdir(parents=True,exist_ok=True)
output.write_bytes(scene.export(file_type='glb'))
triangles=sum(x['faces'] for x in counts.values())
assert 28000 < triangles < 115000,triangles
assert len(counts)==10
print('CULTIST_V08_OK:',output,'bytes=',output.stat().st_size,'triangles=',triangles,'groups=',len(counts),'details=',sum(x['meshes'] for x in counts.values()))