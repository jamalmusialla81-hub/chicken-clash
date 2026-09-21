import sys, os, math, bpy, bmesh, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
os.chdir(os.path.dirname(HERE))
import golden                        # builds the geometry (module level)
from clib import *
from pbr import *
from mathutils import Vector

for o in list(bpy.data.objects):
    if o.name.startswith(('BodySrc', 'HeadSrc')): bpy.data.objects.remove(o)

def cleanup(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.dissolve_degenerate(bm, dist=1e-5, edges=bm.edges[:])
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_area() < 1e-8], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    bm.to_mesh(ob.data); bm.free()
for o in [o for o in bpy.data.objects if o.type == 'MESH']: cleanup(o)
BLADES = ('body_feathers', 'wing_feathers', 'tail')
RULES = [('head', 'Head'), ('lid', 'Head'), ('comb', 'Head'), ('crown_band', 'Head'), ('cheek', 'Head'), ('beak_upper', 'Beak'), ('beak_lower', 'Beak'),
         ('neck', 'Neck'), ('gorget', 'Neck'), ('body_feathers', 'Body'), ('body', 'Body'), ('leather_under', 'Body'), ('lame1', 'Body'), ('lame2', 'Body'),
         ('breastplate', 'Chest'), ('chest_ridge', 'Chest'), ('rarity_crest', 'Chest'), ('gem_center', 'Chest'), ('wing_arm', 'WingUpper'), ('pauldron', 'WingUpper'),
         ('wing_feathers', 'WingLower'), ('wing_guard', 'WingLower'), ('tail_ring', 'Tail'), ('tail', 'Tail'), ('cape', 'Cape'), ('thigh', 'Leg'), ('leg', 'Leg'),
         ('greave', 'Leg'), ('knee', 'Leg'), ('toe', 'Foot'), ('claw_guard', 'Foot'), ('spur', 'Foot'), ('halo_rune', 'HaloRune'), ('halo', 'Halo'), ('eye', 'Eyes')]
SIDED = {'WingUpper', 'WingLower', 'Leg', 'Foot'}
def base_name(o): return o.name.split('.')[0]
def group_of(o):
    n = base_name(o)
    for prefix, g in RULES:
        if n == prefix: break
    else: raise KeyError(n)
    if g in SIDED:
        xs = [v.co.x for v in o.data.vertices]; g += 'L' if sum(xs) / len(xs) > 0 else 'R'
    return g

# ---- bucket every mesh into (group, blade|skin)
buckets = {}
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    g = group_of(o); kind = 'blade' if base_name(o) in BLADES else 'skin'
    buckets.setdefault((g, kind), []).append(o)
objs = {}
for (g, kind), lst in buckets.items():
    ob = join(lst, f'{g}_{kind}'); objs[(g, kind)] = ob
print({k: len(v.data.polygons) for k, v in objs.items()})

# ---- eyes + rune are separate materials: pull out of the atlas
eyes = objs.pop(('Eyes', 'skin')); rune = objs.pop(('HaloRune', 'skin'))
skin = [o for (g, k), o in objs.items() if k == 'skin']
blade = [o for (g, k), o in objs.items() if k == 'blade']

# ---- one shared atlas layout: unwrap a joined copy of every skin part, then hand the UVs back part by part
dups = []
for i, o in enumerate(skin):
    d = o.copy(); d.data = o.data.copy(); bpy.context.scene.collection.objects.link(d)
    at = d.data.attributes.new('oid', 'INT', 'FACE'); at.data.foreach_set('value', [i] * len(d.data.polygons)); dups.append(d)
uvjoin = join(list(dups), '__uvjoin')
uv_smart(uvjoin, angle=66, margin=0.004)
activate(uvjoin); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT'); bpy.ops.uv.select_all(action='SELECT')
bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
bpy.ops.object.mode_set(mode='OBJECT')
juv = uvjoin.data.uv_layers.active.data
oid = [0] * len(uvjoin.data.polygons); uvjoin.data.attributes['oid'].data.foreach_get('value', oid)
counters = [0] * len(skin); newuv = [np.zeros((len(o.data.loops), 2), np.float32) for o in skin]
for poly in uvjoin.data.polygons:
    i = oid[poly.index]; k = counters[i]; counters[i] += 1
    op = skin[i].data.polygons[k]
    assert len(op.loop_indices) == len(poly.loop_indices)
    for a_, b_ in zip(op.loop_indices, poly.loop_indices):
        u = juv[b_].uv; newuv[i][a_] = (0.5 + 0.5 * u.x, u.y)
for i, o in enumerate(skin):
    layer = o.data.uv_layers.get('UVMap') or o.data.uv_layers.new(name='UVMap')
    layer.data.foreach_set('uv', newuv[i].ravel()); o.data.uv_layers.active = layer; layer.active_render = True
bpy.data.objects.remove(uvjoin)
tot = 0.0
for o in skin:
    uvd = o.data.uv_layers.active.data; a = 0.0
    for poly in o.data.polygons:
        pts = [uvd[i].uv for i in poly.loop_indices]
        for k in range(1, len(pts) - 1):
            a += abs((pts[k].x - pts[0].x) * (pts[k + 1].y - pts[0].y) - (pts[k + 1].x - pts[0].x) * (pts[k].y - pts[0].y)) / 2
    tot += a; print('UVAREA', o.name, round(a, 4), 'mats', len(o.data.materials), 'active uv', o.data.uv_layers.active.name, [l.name for l in o.data.uv_layers])
print('UV TOTAL AREA', tot)
import numpy as _n
for o in skin[:4]:
    u=_n.array([l.uv[:] for l in o.data.uv_layers.active.data]); print('UVBOX', o.name, u.min(0), u.max(0), len(o.data.uv_layers))
print('unwrapped; skin tris', sum(tri_count(o) for o in skin), 'blade tris', sum(tri_count(o) for o in blade))

# ---- bake procedural materials into the atlas (skin side)
bpy.ops.object.select_all(action='DESELECT')
for o in skin: o.select_set(True)
bpy.context.view_layer.objects.active = skin[0]
SIZE = 1024
imgs = bake_atlas(skin, SIZE, samples=6, margin=10)
albedo, rough, metal, nrm = (img_to_np(imgs[k]) for k in ('albedo', 'rough', 'metal', 'normal'))
for k, a in zip(('albedo','rough','metal','nrm'), (albedo, rough, metal, nrm)): print('STAT', k, a.shape, float(a[...,:3].min()), float(a[...,:3].mean()), float(a[...,:3].max()))

for o in skin:
    uvd = o.data.uv_layers.active.data
    pts = np.array([l.uv[:] for l in uvd]); px = (pts * (SIZE - 1)).astype(int).clip(0, SIZE - 1)
    print('SAMPLE', o.name, 'albedo mean', albedo[px[:, 1], px[:, 0], :3].mean(0).round(3))
for o in skin + blade:
    me = o.data; c = sum((v.co for v in me.vertices), Vector()) / len(me.vertices)
    inv = sum(1 for p_ in me.polygons if p_.normal.dot(p_.center - c) < 0)
    print('NORMALS', o.name, 'facing-inward polys', inv, 'of', len(me.polygons))
# ---- composite the authored feather tile into the left half
tile = feather_tile(SIZE, [(0.42, 0.20, 0.05), (0.80, 0.50, 0.14), (0.98, 0.84, 0.50), (0.22, 0.09, 0.03)])
half = SIZE // 2
albedo[:, :half, :3] = tile['albedo']
rough[:, :half, :3] = tile['rough'][..., None]
metal[:, :half, :3] = tile['metal'][..., None]
nrm[:, :half, :3] = normal_from_height(tile['height'], 1.3)
os.makedirs('textures', exist_ok=True)
def save(name, arr, cs):
    img = np_to_img(name, arr, cs); img.filepath_raw = os.path.abspath(f'textures/{name}.png'); img.file_format = 'PNG'
    img.save(); return img
final = {'albedo': save('golden_albedo', albedo, 'sRGB'), 'normal': save('golden_normal', nrm, 'Non-Color'),
         'rough': save('golden_roughness', rough, 'Non-Color'), 'metal': save('golden_metalness', metal, 'Non-Color')}
orm = np.ones((SIZE, SIZE, 4), np.float32); orm[..., 0] = 1.0; orm[..., 1] = rough[..., 0]; orm[..., 2] = metal[..., 0]
final['orm'] = save('golden_orm', orm, 'Non-Color')

# ---- eyes: own tiny texture (pupil, amber iris, catch-light)
S = 256; yy, xx = np.mgrid[0:S, 0:S]; r = np.hypot(xx - S / 2, yy - S / 2) / (S / 2)
ang = np.arctan2(yy - S / 2, xx - S / 2)
iris = np.array([1.0, 0.62, 0.06]) * (0.7 + 0.3 * np.sin(ang * 26)[..., None] ** 2) * (1.15 - r[..., None] * 0.55)
eye = np.where((r < 0.60)[..., None], np.clip(iris, 0, 1), np.array([0.10, 0.05, 0.02]))
eye = np.where((r < 0.20)[..., None], np.array([0.02, 0.01, 0.01]), eye)
eye = np.where(((np.hypot(xx - S * 0.62, yy - S * 0.66) / S) < 0.05)[..., None], np.array([1.0, 1.0, 0.95]), eye)
eyeimg = np_to_img('golden_eyes', eye, 'sRGB'); eyeimg.filepath_raw = os.path.abspath('textures/golden_eyes.png'); eyeimg.file_format = 'PNG'; eyeimg.save()
def planar_eye_uv(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data); uvl = bm.loops.layers.uv.verify()
    c = Vector((0, 0, 0)); 
    for v in bm.verts: c += v.co
    # every eyeball is its own island: centre by connected component of the loose parts
    bm.free()
    me = ob.data; bm = bmesh.new(); bm.from_mesh(me); uvl = bm.loops.layers.uv.verify()
    seen = set(); comps = []
    for v in bm.verts:
        if v in seen: continue
        stack = [v]; comp = []; seen.add(v)
        while stack:
            a = stack.pop(); comp.append(a)
            for e in a.link_edges:
                b = e.other_vert(a)
                if b not in seen: seen.add(b); stack.append(b)
        comps.append(comp)
    cent = {}
    for comp in comps:
        cc = sum((v.co for v in comp), Vector()) / len(comp)
        for v in comp: cent[v] = cc
    for f in bm.faces:
        for l in f.loops:
            d = (l.vert.co - cent[l.vert]).normalized(); l[uvl].uv = (0.5 - 0.5 * d.x, 0.5 + 0.5 * d.z * 1.0)
    bm.to_mesh(me); bm.free()
planar_eye_uv(eyes)

# ---- final atlas material
def atlas_material(name, imgs):
    m = bpy.data.materials.new(name); m.use_nodes = True; t = m.node_tree; b = t.nodes['Principled BSDF']
    def tex(img, cs):
        n = t.nodes.new('ShaderNodeTexImage'); n.image = img; n.interpolation = 'Linear'; return n
    a = tex(imgs['albedo'], 'sRGB'); t.links.new(a.outputs['Color'], b.inputs['Base Color'])
    o = tex(imgs['orm'], 'Non-Color'); sep = t.nodes.new('ShaderNodeSeparateColor'); t.links.new(o.outputs['Color'], sep.inputs['Color'])
    t.links.new(sep.outputs['Green'], b.inputs['Roughness']); t.links.new(sep.outputs['Blue'], b.inputs['Metallic'])
    n = tex(imgs['normal'], 'Non-Color'); nm = t.nodes.new('ShaderNodeNormalMap'); t.links.new(n.outputs['Color'], nm.inputs['Color']); t.links.new(nm.outputs['Normal'], b.inputs['Normal'])
    return m
atlas = atlas_material('GoldenAtlas', final)
eyem = bpy.data.materials.new('GoldenEyes'); eyem.use_nodes = True
en = eyem.node_tree.nodes.new('ShaderNodeTexImage'); en.image = eyeimg; eyem.node_tree.links.new(en.outputs['Color'], eyem.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
eyem.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.12
runem = bpy.data.materials.new('GoldenRune'); runem.use_nodes = True
rb = runem.node_tree.nodes['Principled BSDF']; rb.inputs['Base Color'].default_value = (1.0, 0.8, 0.3, 1); rb.inputs['Emission Color'].default_value = (1.0, 0.75, 0.25, 1); rb.inputs['Emission Strength'].default_value = 4.0

# ---- finish: join skin+blade per group, assign the atlas
GROUPS = {}
for (g, kind), o in objs.items(): GROUPS.setdefault(g, []).append(o)
out = {}
for g, lst in GROUPS.items():
    ob = join(lst, g) if len(lst) > 1 else lst[0]; ob.name = ob.data.name = g
    for l_ in ob.data.uv_layers: l_.active_render = (l_.name == 'UVMap')
    ob.data.materials.clear(); ob.data.materials.append(atlas)
    for p in ob.data.polygons: p.material_index = 0
    out[g] = ob
eyes.name = eyes.data.name = 'Eyes'; eyes.data.materials.clear(); eyes.data.materials.append(eyem)
rune.name = rune.data.name = 'HaloRune'; rune.data.materials.clear(); rune.data.materials.append(runem)
out['Eyes'] = eyes; out['HaloRune'] = rune
print({k: tri_count(v) for k, v in out.items()}, 'TOTAL', sum(tri_count(v) for v in out.values()))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('blend/golden_chicken.blend'))

if '--nonormal' in sys.argv:
    t_ = atlas.node_tree
    for l_ in list(t_.links):
        if l_.to_socket.name == 'Normal': t_.links.remove(l_)
if '--render' in sys.argv:
    from render import setup_scene, render_views
    setup_scene()
    for f in render_views('renders/golden_f', target=Vector((0, 0.4, 3.8)), dist=15): print(f)
