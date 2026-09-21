import bpy, bmesh, os, sys, json, math
import numpy as np
from mathutils import Vector, Matrix, Euler
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE); os.chdir(ROOT); sys.path.insert(0, HERE)
NAME = 'GoldenChicken'
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, 'blend/golden_chicken.blend'))
meshes = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}

# ---------------- combat budgets (decimate the smooth-subdivided parts; UVs survive)
RATIO = {'Head': 0.48, 'Body': 0.55, 'Chest': 0.62, 'Neck': 0.45, 'Cape': 0.42, 'WingUpperL': 0.30, 'WingUpperR': 0.30, 'Halo': 0.30,
         'LegL': 0.5, 'LegR': 0.5, 'FootL': 0.62, 'FootR': 0.62, 'Eyes': 0.5, 'Beak': 1.0, 'Tail': 1.0, 'WingLowerL': 1.0, 'WingLowerR': 1.0, 'HaloRune': 0.6}
def apply_mod(o, kind, **kw):
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    m = o.modifiers.new(kind, kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.ops.object.modifier_apply(modifier=m.name)
def tris(o):
    dg = bpy.context.evaluated_depsgraph_get(); me = o.evaluated_get(dg).to_mesh(); n = sum(len(p.vertices) - 2 for p in me.polygons); o.evaluated_get(dg).to_mesh_clear(); return n
before = {n: tris(o) for n, o in meshes.items()}
for n, o in meshes.items():
    if RATIO[n] < 1.0: apply_mod(o, 'DECIMATE', decimate_type='COLLAPSE', ratio=RATIO[n], use_collapse_triangulate=False)
    for p in o.data.polygons: p.use_smooth = True
after = {n: tris(o) for n, o in meshes.items()}

# ---------------- shared skeleton
BONES = [  # name, head, tail, parent
 ('Root', (0, 0.1, 0.0), (0, 0.1, 0.6), None), ('Body', (0, 0.1, 2.4), (0, 0.1, 3.4), 'Root'), ('Chest', (0, -0.4, 3.4), (0, -0.9, 4.2), 'Body'),
 ('Neck', (0, -1.0, 4.2), (0, -1.4, 4.9), 'Chest'), ('Head', (0, -1.4, 4.9), (0, -1.55, 6.2), 'Neck'), ('Beak', (0, -2.3, 4.95), (0, -3.5, 4.65), 'Head'),
 ('Comb', (0, -1.55, 5.9), (0, -1.55, 7.0), 'Head'),
 ('WingUpperL', (1.55, 0.3, 3.7), (2.7, 0.55, 3.4), 'Chest'), ('WingLowerL', (2.7, 0.55, 3.4), (3.0, 2.8, 1.2), 'WingUpperL'),
 ('WingUpperR', (-1.55, 0.3, 3.7), (-2.7, 0.55, 3.4), 'Chest'), ('WingLowerR', (-2.7, 0.55, 3.4), (-3.0, 2.8, 1.2), 'WingUpperR'),
 ('LegL', (0.78, -0.05, 1.9), (0.78, -0.5, 0.4), 'Body'), ('FootL', (0.78, -0.5, 0.4), (0.78, -1.5, 0.05), 'LegL'),
 ('LegR', (-0.78, -0.05, 1.9), (-0.78, -0.5, 0.4), 'Body'), ('FootR', (-0.78, -0.5, 0.4), (-0.78, -1.5, 0.05), 'LegR'),
 ('Tail', (0, 1.5, 3.3), (0, 4.5, 4.0), 'Body'), ('Cape', (0, 0.5, 4.5), (0, 2.3, 2.4), 'Chest'), ('Halo', (0, -0.6, 5.5), (0, -0.6, 6.0), 'Root'),
 ('ArmourAnchor_Chest', (0, -1.7, 3.6), (0, -2.0, 3.6), 'Chest'), ('ArmourAnchor_Back', (0, 1.4, 4.0), (0, 1.7, 4.0), 'Chest'),
 ('Weapon', (2.4, -1.4, 3.0), (2.4, -2.2, 3.0), 'WingUpperL'), ('Aura', (0, 0.1, 0.05), (0, 0.1, 0.4), 'Root'),
 ('Ultimate', (0, 0.1, 8.0), (0, 0.1, 8.4), 'Root'), ('FinisherTarget', (0, -4.5, 3.0), (0, -4.9, 3.0), 'Root')]
arm_data = bpy.data.armatures.new(f'{NAME}_Rig'); arm = bpy.data.objects.new(f'{NAME}_Rig', arm_data); bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par in BONES:
    b = arm_data.edit_bones.new(name); b.head, b.tail = Vector(h), Vector(t)
    if par: b.parent = arm_data.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
BONE_OF = {'Eyes': 'Head', 'HaloRune': 'Halo'}
for n, o in meshes.items():
    bone = BONE_OF.get(n, n)
    vg = o.vertex_groups.new(name=bone); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    md = o.modifiers.new('Armature', 'ARMATURE'); md.object = arm
    o.parent = arm

# ---------------- animations: Idle (loop), Hero reveal pose
sc = bpy.context.scene; sc.render.fps = 24
bpy.context.view_layer.objects.active = arm; bpy.ops.object.mode_set(mode='POSE')
for pb in arm.pose.bones: pb.rotation_mode = 'XYZ'
def key(bone, frame, rot=None, loc=None):
    pb = arm.pose.bones[bone]
    if rot is not None: pb.rotation_euler = Euler([math.radians(a) for a in rot]); pb.keyframe_insert('rotation_euler', frame=frame)
    if loc is not None: pb.location = Vector(loc); pb.keyframe_insert('location', frame=frame)
idle = bpy.data.actions.new('Idle'); arm.animation_data_create(); arm.animation_data.action = idle
N = 96
for f, ph in ((1, 0.0), (N // 4 + 1, 0.5 * math.pi), (N // 2 + 1, math.pi), (3 * N // 4 + 1, 1.5 * math.pi), (N + 1, 2 * math.pi)):
    s_ = math.sin(ph); c_ = math.cos(ph)
    key('Body', f, loc=(0, 0, 0.05 * s_)); key('Chest', f, rot=(-1.8 * s_, 0, 0)); key('Head', f, rot=(1.2 * s_, 0, 1.5 * c_))
    key('WingUpperL', f, rot=(0, 0, -2.2 * s_)); key('WingUpperR', f, rot=(0, 0, 2.2 * s_)); key('Tail', f, rot=(2.0 * s_, 3.0 * c_, 0))
    key('Cape', f, rot=(2.5 * s_, 0, 0)); key('Halo', f, rot=(0, 360.0 * (f - 1) / N, 0)); key('Aura', f, loc=(0, 0, 0))
for fc in idle.fcurves if hasattr(idle, 'fcurves') else []:
    for kp in fc.keyframe_points: kp.interpolation = 'BEZIER'
hero = bpy.data.actions.new('HeroReveal'); arm.animation_data.action = hero
key('Chest', 1, rot=(-9, 0, 0)); key('Head', 1, rot=(-10, 0, 0)); key('WingUpperL', 1, rot=(0, 0, -34)); key('WingUpperR', 1, rot=(0, 0, 34))
key('WingLowerL', 1, rot=(0, 18, -12)); key('WingLowerR', 1, rot=(0, -18, 12)); key('Tail', 1, rot=(-8, 0, 0)); key('Cape', 1, rot=(6, 0, 0)); key('Body', 1, loc=(0, 0, 0.12))
arm.animation_data.action = idle
for pb in arm.pose.bones: pb.rotation_euler = (0, 0, 0); pb.location = (0, 0, 0)
bpy.ops.object.mode_set(mode='OBJECT')
for a in (idle, hero): a.use_fake_user = True

# ---------------- exports
os.makedirs('exports', exist_ok=True)
def sel(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
allobjs = [arm] + list(meshes.values())
sel(allobjs); bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=os.path.abspath(f'exports/{NAME}_combat.glb'), export_format='GLB', use_selection=True, export_animations=True, export_skins=True, export_yup=True)
sel(allobjs); bpy.ops.export_scene.fbx(filepath=os.path.abspath(f'exports/{NAME}_combat.fbx'), use_selection=True, path_mode='COPY', embed_textures=True, add_leaf_bones=False, bake_anim=True, object_types={'ARMATURE', 'MESH'})

# ---------------- preview: one static mesh (+ eyes + runes) at a lower budget
prev = []
for n, o in meshes.items():
    if n in ('Eyes', 'HaloRune'): continue
    d = o.copy(); d.data = o.data.copy(); d.parent = None; d.matrix_world = Matrix.Identity(4); d.modifiers.clear(); d.vertex_groups.clear()
    bpy.context.scene.collection.objects.link(d); prev.append(d)
# world-space geometry is what was authored, so parent-free copies keep it
bpy.ops.object.select_all(action='DESELECT')
for d in prev: d.select_set(True)
bpy.context.view_layer.objects.active = prev[0]; bpy.ops.object.join()
pv = prev[0]; pv.name = pv.data.name = f'{NAME}_Preview'
apply_mod(pv, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.32, use_collapse_triangulate=False)
pv_tris = tris(pv)
pe = meshes['Eyes'].copy(); pe.data = meshes['Eyes'].data.copy(); pe.parent = None; pe.modifiers.clear(); pe.vertex_groups.clear(); bpy.context.scene.collection.objects.link(pe); pe.name = 'Preview_Eyes'
pr = meshes['HaloRune'].copy(); pr.data = meshes['HaloRune'].data.copy(); pr.parent = None; pr.modifiers.clear(); pr.vertex_groups.clear(); bpy.context.scene.collection.objects.link(pr); pr.name = 'Preview_Runes'
sel([pv, pe, pr]); bpy.context.view_layer.objects.active = pv
bpy.ops.export_scene.gltf(filepath=os.path.abspath(f'exports/{NAME}_preview.glb'), export_format='GLB', use_selection=True, export_animations=False)
sel([pv, pe, pr]); bpy.ops.export_scene.fbx(filepath=os.path.abspath(f'exports/{NAME}_preview.fbx'), use_selection=True, path_mode='COPY', embed_textures=True, object_types={'MESH'})

# ---------------- Studio data (Roblox axes: model faces +X, up +Y). blender (x,y,z) -> roblox (-y, z, -x)
def rb(v): return (-v[1], v[2], -v[0])
def dump(o, path):
    dg = bpy.context.evaluated_depsgraph_get(); ob_e = o.evaluated_get(dg); me = ob_e.to_mesh()
    me.calc_loop_triangles()
    uvl = me.uv_layers.get('UVMap') or me.uv_layers.active
    P, N_, U = {}, {}, {}; Pl, Nl, Ul, F = [], [], [], []
    def idx(dct, lst, key, val):
        if key not in dct: dct[key] = len(lst); lst.append(val)
        return dct[key]
    for tri in me.loop_triangles:
        row = [[], [], []]
        for li in tri.loops:
            v = me.vertices[me.loops[li].vertex_index]; nrm = me.corner_normals[li].vector if hasattr(me, 'corner_normals') else v.normal
            pkey = tuple(round(c, 4) for c in rb(v.co)); nkey = tuple(round(c, 3) for c in rb(nrm)); uv = uvl.data[li].uv if uvl else Vector((0.5, 0.5)); ukey = (round(uv.x, 5), round(1 - uv.y, 5))
            row[0].append(idx(P, Pl, pkey, pkey)); row[1].append(idx(U, Ul, ukey, ukey)); row[2].append(idx(N_, Nl, nkey, nkey))
        F.append(row[0] + row[1] + row[2])
    json.dump({'name': o.name, 'P': Pl, 'N': Nl, 'U': Ul, 'F': F}, open(path, 'w'), separators=(',', ':'))
    ob_e.to_mesh_clear(); return len(F), len(Pl)
os.makedirs('serve/golden', exist_ok=True)
stats = {}
for n, o in meshes.items():
    f, v = dump(o, f'serve/golden/part_{n}.json'); stats[n] = {'tris': f, 'unique_verts': v, 'bone': BONE_OF.get(n, n), 'tris_before_decimate': before[n]}
f, v = dump(pv, 'serve/golden/preview_main.json'); stats['PREVIEW_MAIN'] = {'tris': f, 'unique_verts': v}
json.dump({'bones': [{'name': b[0], 'head': rb(b[1]), 'tail': rb(b[2]), 'parent': b[3]} for b in BONES]}, open('serve/golden/skeleton.json', 'w'))
# textures -> raw RGBA8 at 512 (Studio EditableImage)
def rawtex(img, path):
    a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4)
    a = a.reshape(512, 2, 512, 2, 4).mean(axis=(1, 3)) if img.size[0] == 1024 else a
    a = np.flipud(a)   # top row first
    (np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8).tofile(path)
for k, nm in (('albedo', 'golden_albedo'), ('normal', 'golden_normal'), ('rough', 'golden_roughness'), ('metal', 'golden_metalness'), ('eyes', 'golden_eyes')):
    img = bpy.data.images.get(nm) or bpy.data.images.load(os.path.abspath(f'textures/{nm}.png'))
    rawtex(img, f'serve/golden/tex_{k}.bin')
tot = sum(v['tris'] for k, v in stats.items() if k != 'PREVIEW_MAIN')
stats['_summary'] = {'combat_tris_total': tot, 'combat_meshparts': len(meshes), 'preview_tris': pv_tris + tris(pe) + tris(pr), 'atlas': '1024x1024 albedo/normal/roughness/metalness (+ORM packed), 512 copies for Studio', 'eyes_texture': '256x256', 'bones': len(BONES)}
json.dump(stats, open('exports/GoldenChicken_stats.json', 'w'), indent=1)
print(json.dumps(stats['_summary'])); print({k: v['tris'] for k, v in stats.items() if k[0] != '_'})
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('blend/golden_chicken_rigged.blend'))
