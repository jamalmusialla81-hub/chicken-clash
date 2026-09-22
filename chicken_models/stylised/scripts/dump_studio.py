import bpy, os, sys, json
import numpy as np
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..')); os.chdir(os.path.join(ROOT, 'stylised'))
bpy.ops.wm.open_mainfile(filepath=os.path.abspath('blend/golden_toon_rigged.blend'))
def rb(v): return (-v[1], v[2], -v[0])   # blender (x,y,z) -> roblox (-y, z, -x): model faces +X, up +Y
def dump(o, path):
    dg = bpy.context.evaluated_depsgraph_get(); oe = o.evaluated_get(dg); me = oe.to_mesh(); me.calc_loop_triangles()
    uvl = me.uv_layers.get('UVMap') or me.uv_layers.active
    pts = [rb(v.co) for v in me.vertices]; arr = np.array(pts); mn, mx = arr.min(0), arr.max(0); centre = (mn + mx) / 2
    P, N, U = {}, {}, {}; Pl, Nl, Ul, F = [], [], [], []
    def idx(d, l, k, v):
        if k not in d: d[k] = len(l); l.append(v)
        return d[k]
    for tri in me.loop_triangles:
        row = [[], [], []]
        for li in tri.loops:
            v = me.vertices[me.loops[li].vertex_index]; n = me.corner_normals[li].vector
            pk = tuple(round(float(c - cc), 4) for c, cc in zip(rb(v.co), centre)); nk = tuple(round(c, 3) for c in rb(n)); uv = uvl.data[li].uv; uk = (round(uv.x, 5), round(1 - uv.y, 5))
            row[0].append(idx(P, Pl, pk, pk)); row[1].append(idx(U, Ul, uk, uk)); row[2].append(idx(N, Nl, nk, nk))
        F.append(row[0] + row[1] + row[2])
    json.dump({'name': o.name, 'centre': [round(float(c), 4) for c in centre], 'P': Pl, 'N': Nl, 'U': Ul, 'F': F}, open(path, 'w'), separators=(',', ':'))
    oe.to_mesh_clear(); return len(F)
stats = {}
for o in bpy.data.objects:
    if o.type != 'MESH': continue
    stats[o.name] = dump(o, f'serve/part_{o.name}.json')
img = bpy.data.images.load(os.path.abspath('textures/golden_toon_atlas.png'))
a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4); a = np.flipud(a)
(np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8).tofile('serve/atlas_512.bin')
print(json.dumps(stats)); print('atlas', img.size[:])
