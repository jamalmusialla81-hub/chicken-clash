import bpy, os, sys, json, math
import numpy as np
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts')); os.chdir(os.path.join(ROOT, 'stylised'))
NAME = 'GoldenChicken'
bpy.ops.wm.open_mainfile(filepath=os.path.abspath('blend/golden_toon_master.blend'))
meshes = {o.name: o for o in bpy.data.objects if o.type == 'MESH'}
def tris(o):
    dg = bpy.context.evaluated_depsgraph_get(); me = o.evaluated_get(dg).to_mesh(); n = sum(len(p.vertices) - 2 for p in me.polygons); o.evaluated_get(dg).to_mesh_clear(); return n
def apply_mod(o, kind, **kw):
    bpy.context.view_layer.objects.active = o; bpy.ops.object.select_all(action='DESELECT'); o.select_set(True)
    m = o.modifiers.new(kind, kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.ops.object.modifier_apply(modifier=m.name)

# name mapping to the shared Roblox rig standard
PART_TO_BONE = {'Body': 'Body', 'Chest': 'Chest', 'Neck': 'Neck', 'Head': 'Head', 'Beak': 'Beak', 'Comb': 'Comb', 'Tail': 'Tail', 'Cape': 'Cape', 'Halo': 'Halo',
    'WingUpperL': 'LeftWingUpper', 'WingLowerL': 'LeftWingLower', 'WingUpperR': 'RightWingUpper', 'WingLowerR': 'RightWingLower',
    'UpperLegL': 'LeftUpperLeg', 'LowerLegL': 'LeftLowerLeg', 'FootL': 'LeftFoot', 'UpperLegR': 'RightUpperLeg', 'LowerLegR': 'RightLowerLeg', 'FootR': 'RightFoot'}
BONES = [  # name, head, tail, parent, kind
 ('HumanoidRootPart', (0, 0.15, 1.9), (0, 0.15, 2.4), None, 'root'), ('Body', (0, 0.15, 2.75), (0, 0.15, 3.4), 'HumanoidRootPart', 'part'),
 ('Chest', (0, -0.5, 3.4), (0, -0.9, 4.0), 'Body', 'part'), ('Neck', (0, -0.9, 3.9), (0, -1.2, 4.4), 'Chest', 'part'), ('Head', (0, -1.2, 4.4), (0, -1.25, 5.8), 'Neck', 'part'),
 ('Beak', (0, -2.4, 4.3), (0, -3.4, 4.2), 'Head', 'part'), ('Comb', (0, -1.25, 5.7), (0, -1.25, 6.9), 'Head', 'part'),
 ('LeftWingUpper', (1.55, 0.35, 3.25), (2.15, 0.55, 2.95), 'Chest', 'part'), ('LeftWingLower', (2.15, 0.55, 2.95), (2.5, 2.5, 1.4), 'LeftWingUpper', 'part'),
 ('RightWingUpper', (-1.55, 0.35, 3.25), (-2.15, 0.55, 2.95), 'Chest', 'part'), ('RightWingLower', (-2.15, 0.55, 2.95), (-2.5, 2.5, 1.4), 'RightWingUpper', 'part'),
 ('Tail', (0, 1.45, 3.05), (0, 3.5, 3.9), 'Body', 'part'),
 ('LeftUpperLeg', (0.85, -0.05, 1.9), (0.85, -0.3, 1.2), 'Body', 'part'), ('LeftLowerLeg', (0.85, -0.3, 1.2), (0.85, -0.55, 0.45), 'LeftUpperLeg', 'part'), ('LeftFoot', (0.85, -0.55, 0.45), (0.85, -1.6, 0.3), 'LeftLowerLeg', 'part'),
 ('RightUpperLeg', (-0.85, -0.05, 1.9), (-0.85, -0.3, 1.2), 'Body', 'part'), ('RightLowerLeg', (-0.85, -0.3, 1.2), (-0.85, -0.55, 0.45), 'RightUpperLeg', 'part'), ('RightFoot', (-0.85, -0.55, 0.45), (-0.85, -1.6, 0.3), 'RightLowerLeg', 'part'),
 ('Cape', (0, 0.4, 4.0), (0, 1.9, 2.0), 'Chest', 'part'), ('Halo', (0, -1.25, 7.4), (0, -1.25, 7.8), 'Head', 'part'),
 ('AuraRoot', (0, 0.15, 0.05), (0, 0.15, 0.3), 'HumanoidRootPart', 'attach'), ('FootSigil', (0, 0.0, 0.02), (0, 0.0, 0.25), 'HumanoidRootPart', 'attach'),
 ('LeftWingTrail', (2.6, 2.3, 1.5), (2.7, 2.6, 1.4), 'LeftWingLower', 'attach'), ('RightWingTrail', (-2.6, 2.3, 1.5), (-2.7, 2.6, 1.4), 'RightWingLower', 'attach'),
 ('Weapon', (2.3, -0.9, 2.6), (2.3, -1.4, 2.6), 'LeftWingLower', 'attach'), ('Ultimate', (0, 0.15, 8.4), (0, 0.15, 8.8), 'HumanoidRootPart', 'attach'),
 ('CrownEffect', (0, -1.25, 7.2), (0, -1.25, 7.5), 'Comb', 'attach'), ('BackEffect', (0, 1.6, 3.5), (0, 1.9, 3.5), 'Chest', 'attach'), ('FinisherTarget', (0, -4.5, 2.8), (0, -4.9, 2.8), 'HumanoidRootPart', 'attach')]
combat = {g: o for g, o in meshes.items()}
arm_data = bpy.data.armatures.new(f'{NAME}_Rig'); arm = bpy.data.objects.new(f'{NAME}_Rig', arm_data); bpy.context.scene.collection.objects.link(arm)
bpy.context.view_layer.objects.active = arm; arm.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
for name, h, t, par, kind in BONES:
    b = arm_data.edit_bones.new(name); b.head, b.tail = Vector(h), Vector(t)
    if par: b.parent = arm_data.edit_bones[par]
bpy.ops.object.mode_set(mode='OBJECT')
for g, o in combat.items():
    bone = PART_TO_BONE[g]; o.name = bone; o.data.name = bone
    vg = o.vertex_groups.new(name=bone); vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')
    md = o.modifiers.new('Armature', 'ARMATURE'); md.object = arm; o.parent = arm

os.makedirs('exports', exist_ok=True)
def sel(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
allobjs = [arm] + [o for o in bpy.data.objects if o.type == 'MESH']
sel(allobjs); bpy.context.view_layer.objects.active = arm
bpy.ops.export_scene.gltf(filepath=os.path.abspath(f'exports/{NAME}_Stylised_combat.glb'), export_format='GLB', use_selection=True, export_skins=True, export_animations=False, export_yup=True)
sel(allobjs); bpy.ops.export_scene.fbx(filepath=os.path.abspath(f'exports/{NAME}_Stylised_combat.fbx'), use_selection=True, path_mode='COPY', embed_textures=True, add_leaf_bones=False, object_types={'ARMATURE', 'MESH'})
combat_tris = {o.name: tris(o) for o in bpy.data.objects if o.type == 'MESH'}

# ---- preview: the same model, merged + decimated (face, crown, breastplate, tail silhouette preserved), no rig
prev = []
for o in [o for o in bpy.data.objects if o.type == 'MESH']:
    d = o.copy(); d.data = o.data.copy(); d.parent = None; d.modifiers.clear(); d.vertex_groups.clear(); d.matrix_world = Matrix.Identity(4)
    bpy.context.scene.collection.objects.link(d); prev.append(d)
bpy.ops.object.select_all(action='DESELECT')
for d in prev: d.select_set(True)
bpy.context.view_layer.objects.active = prev[0]; bpy.ops.object.join()
pv = prev[0]; pv.name = pv.data.name = f'{NAME}_Preview'
apply_mod(pv, 'DECIMATE', decimate_type='COLLAPSE', ratio=0.42, use_collapse_triangulate=False, use_symmetry=False)
pv_tris = tris(pv)
sel([pv]); bpy.context.view_layer.objects.active = pv
bpy.ops.export_scene.gltf(filepath=os.path.abspath(f'exports/{NAME}_Stylised_preview.glb'), export_format='GLB', use_selection=True)
sel([pv]); bpy.ops.export_scene.fbx(filepath=os.path.abspath(f'exports/{NAME}_Stylised_preview.fbx'), use_selection=True, path_mode='COPY', embed_textures=True, object_types={'MESH'})

# ---- reports: triangles, rig, joints in Roblox axes (model faces +X, up +Y):  blender (x,y,z) -> roblox (-y, z, -x)
def rb(v): return [round(-v[1], 4), round(v[2], 4), round(-v[0], 4)]
rep = {'combat_tris': combat_tris, 'combat_tris_total': sum(combat_tris.values()), 'combat_meshparts': len(combat_tris), 'preview_tris': pv_tris, 'preview_meshparts': 1,
       'atlas': '512x512 albedo only (palette gradients + painted eye + emblem); no normal/roughness/metalness maps',
       'bones': len(BONES), 'rig': [{'name': b[0], 'parent': b[3], 'kind': b[4], 'joint': rb(b[1])} for b in BONES],
       'part_to_bone': PART_TO_BONE}
json.dump(rep, open('exports/GoldenChicken_Stylised_report.json', 'w'), indent=1)
print(json.dumps({k: rep[k] for k in ('combat_tris_total', 'combat_meshparts', 'preview_tris')}))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('blend/golden_toon_rigged.blend'))
