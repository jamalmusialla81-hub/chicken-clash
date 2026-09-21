"""Stylised low-poly Golden Chicken (combat master). Clean shapes, palette-atlas colour blocking, no noise.
Front = -Y, up = +Z, ground z = 0. Units = studs."""
import bpy, bmesh, math, sys, os, json
import numpy as np
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts')); os.chdir(os.path.join(ROOT, 'stylised'))
from clib import clear, smooth, to_obj, activate, modifier, subsurf, solidify, bevel, rot_to, loft, ellipsoid, blade, merge_bm, feather, surf_patch, join, tri_count
def V(*a): return Vector(a[0]) if len(a) == 1 else Vector(a)
clear()

# ---- palette rows (top light -> bottom dark). index = material id
PALETTE = [  # name, light, dark, highlight band?
 ('feather_cream', (255, 240, 200), (232, 196, 128), False), ('feather_gold', (255, 190, 70), (226, 128, 38), False),
 ('armour_gold', (255, 226, 96), (222, 152, 24), True), ('leather', (128, 78, 48), (72, 42, 28), False),
 ('cape_red', (206, 46, 60), (122, 24, 40), False), ('gem_red', (255, 110, 120), (190, 22, 44), True),
 ('gem_blue', (140, 210, 255), (30, 96, 208), True), ('beak_talon', (255, 200, 84), (238, 136, 44), False),
 ('halo', (255, 246, 190), (255, 214, 110), False), ('dark', (58, 40, 34), (30, 20, 20), False)]
CREAM, GOLDF, ARMOUR, LEATHER, CAPE, GEMR, GEMB, BEAK, HALO, DARK = range(10)
ATLAS = 512; ROWH = 32
parts = []     # (obj, group, material)
def add(ob, group, mat):
    ob.data.materials.clear()
    parts.append([ob, group, mat]); return ob

def bm_obj(name, bm, group, mat, smooth_ok=True):
    ob = to_obj(name, bm); return add(ob, group, mat)

def ring_tube(center, axis, R, r, seg=24, sides=8, arc=2 * math.pi):
    bm = bmesh.new(); frame = rot_to(axis); rows = []
    for i in range(seg + (0 if arc >= 2 * math.pi - 1e-3 else 1)):
        a = arc * i / seg; nrm = V(0, math.cos(a), math.sin(a)); c = nrm * R; row = []
        for k in range(sides):
            b = 2 * math.pi * k / sides
            row.append(bm.verts.new(c + nrm * math.cos(b) * r + V(1, 0, 0) * math.sin(b) * r))
        rows.append(row)
    cnt = len(rows)
    for i in range(cnt if arc >= 2 * math.pi - 1e-3 else cnt - 1):
        for k in range(sides): bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[(i + 1) % cnt][(k + 1) % sides], rows[(i + 1) % cnt][k]))
    bm.transform(Matrix.Translation(center) @ frame); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); return bm

def fan(dst, root, dirs, length, width, up, thick_bend=0.08, **kw):
    for d, L, W in zip(dirs, length, width):
        feather(dst, root, d, L, W, up=up, bend=thick_bend, tip=0.10, crease=0.03, seg_u=5, seg_v=2, **kw)

def slab(name, bm, group, mat, thick, bev=0.03, sub=0):
    ob = to_obj(name, bm); solidify(ob, thick)
    if bev: bevel(ob, bev, 2, 35)
    if sub: subsurf(ob, sub)
    return add(ob, group, mat)

# ================= body: compact torso, proud chest
def torso_warp(p):
    x, y, z = p
    k = smooth(0.2, 1.6, y); x *= 1 - 0.30 * k; z = z * (1 - 0.18 * k) + 0.25 * k
    f = smooth(0.0, 1.6, -y); z += 0.18 * f
    return V(x, y, z)
tb = ellipsoid((1.55, 1.6, 1.5), 20, 14, torso_warp)
tb.transform(Matrix.Translation((0, 0.15, 2.75)) @ Matrix.Rotation(math.radians(-8), 4, 'X'))
torso = bm_obj('torso', tb, 'Body', CREAM)
def body_pt(th, ph):
    u = V(math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph))
    p = torso_warp(V(u.x * 1.55, u.y * 1.6, u.z * 1.5))
    m = Matrix.Translation((0, 0.15, 2.75)) @ Matrix.Rotation(math.radians(-8), 4, 'X')
    return m @ p, (m.to_3x3() @ u).normalized()
# leather underlayer (visible around the plate), belt with buckle
lea = to_obj('leather', surf_patch(body_pt, 0.0, 0.10, 1.0, 0.92, 0.06, rings=7, seg=24, sup=2.3)); solidify(lea, 0.05); add(lea, 'Body', LEATHER)
bb = ring_tube(V(0, 0, 0), V(0, 0, 1), 1.36, 0.12, seg=22, sides=6); bb.transform(Matrix.Translation((0, 0.22, 2.12)) @ Matrix.Scale(1.10, 4, V(0, 1, 0))); belt = bm_obj('belt', bb, 'Body', LEATHER)
buckle = bm_obj('buckle', ring_tube(V(0, -1.35, 1.82), V(0, 1, 0), 0.01, 0.01), 'Body', GEMR) if False else None
bk = bmesh.new(); bmesh.ops.create_icosphere(bk, subdivisions=1, radius=0.22); bk.transform(Matrix.Translation((0, -1.62, 2.15))); bm_obj('buckle', bk, 'Body', GEMR)

# ================= chest: one fitted breastplate + feather emblem + collar
pl = to_obj('breastplate', surf_patch(body_pt, 0.0, 0.30, 0.80, 0.60, 0.13, rings=6, seg=22, sup=2.5, dome=0.10)); solidify(pl, 0.10); bevel(pl, 0.035, 2, 35); add(pl, 'Chest', ARMOUR)
crest_pt = surf_patch(body_pt, 0.0, 0.34, 0.20, 0.20, 0.32, rings=5, seg=18, sup=2.0, dome=0.05)
em = to_obj('emblem', crest_pt); solidify(em, 0.05); add(em, 'Chest', ARMOUR)
col = bm_obj('collar', ring_tube(V(0, -0.85, 3.95), V(0, -0.3, 1.0), 1.0, 0.16, seg=24, sides=8), 'Chest', ARMOUR)
gem = bmesh.new(); bmesh.ops.create_icosphere(gem, subdivisions=1, radius=0.19); gem.transform(Matrix.Translation(body_pt(0, 0.62)[0] + body_pt(0, 0.62)[1] * 0.2)); bm_obj('chest_gem', gem, 'Chest', GEMB)

# neck (feather mass between torso and head)
nk = loft([(V(0, -0.6, 3.8), 1.0, 0.95), (V(0, -1.0, 4.2), 0.95, 0.9), (V(0, -1.2, 4.45), 0.9, 0.85)], ring=12)
bm_obj('neck', nk, 'Neck', CREAM)

# ================= head: big, wide, chunky
HC = V(0, -1.25, 4.75)
def head_warp(p):
    x, y, z = p
    x *= 1 + 0.10 * smooth(-0.3, 0.4, abs(y) * 0 + (1 - abs(z)))      # fuller cheeks
    if y < 0: x *= 1 - 0.18 * smooth(0.2, 1.0, -y)
    z *= 1 - 0.10 * smooth(0.3, 1.0, -z)                              # slightly flat crown for the comb band
    return V(x, y, z)
hb = ellipsoid((1.48, 1.38, 1.38), 22, 16, head_warp); hb.transform(Matrix.Translation(HC))
head = bm_obj('head', hb, 'Head', CREAM)
def head_pt(th, ph):
    u = V(math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph))
    return head_warp(V(u.x * 1.48, u.y * 1.38, u.z * 1.38)) + HC, u.normalized()
EYE_R = 0.50
eye_objs = []
for s in (-1, 1):
    c = HC + V(0.68 * s, -1.12, 0.22)
    e = bmesh.new(); bmesh.ops.create_uvsphere(e, u_segments=16, v_segments=12, radius=EYE_R); e.transform(Matrix.Translation(c)); eo = bm_obj('eye', e, 'Head', 'EYE'); eye_objs.append((eo, c))
    lid = bmesh.new(); bmesh.ops.create_uvsphere(lid, u_segments=18, v_segments=12, radius=EYE_R + 0.07)
    bmesh.ops.delete(lid, geom=[f for f in lid.faces if f.calc_center_median().z < 0.16 + 0.25 * abs(f.calc_center_median().x) * 0], context='FACES')
    lid.transform(Matrix.Rotation(math.radians(-26 * s), 4, 'Y') @ Matrix.Rotation(math.radians(12), 4, 'X') @ Matrix.Translation((0, 0, 0)))
    lid.transform(Matrix.Translation(c + V(0, -0.03, 0.02)))
    lo = to_obj('brow', lid); solidify(lo, 0.05, 1); add(lo, 'Head', GOLDF)

# ================= beak: short, wide
ub = loft([(V(0, -2.45, 4.45), .56, .34), (V(0, -2.88, 4.38), .46, .27), (V(0, -3.32, 4.24), .22, .15), (V(0, -3.48, 4.16), .06, .06)], ring=10)
bm_obj('beak_upper', ub, 'Beak', BEAK)
lb = loft([(V(0, -2.45, 4.18), .42, .18), (V(0, -2.85, 4.12), .34, .15), (V(0, -3.20, 4.05), .14, .09)], ring=10)
bm_obj('beak_lower', lb, 'Beak', BEAK)
# ================= comb: brow band + five rounded crown petals
band = to_obj('crown_band', surf_patch(head_pt, 0.0, 0.66, 1.22, 0.13, 0.05, rings=4, seg=28, sup=4.0)); solidify(band, 0.09); bevel(band, 0.025, 2, 35); add(band, 'Comb', ARMOUR)
cb = bmesh.new()
for i in range(5):
    t = (i - 2) / 2.0; x = t * 0.95; L = 1.35 - 0.6 * abs(t) ** 1.3 + 0.0; W = 0.62 - 0.05 * abs(t)
    base = V(x, HC.y - 0.55 - 0.18 * abs(t), HC.z + 1.12 - 0.34 * abs(t) ** 1.6)
    feather(cb, base, V(t * 0.30, 0.0, 1.0), L, W, up=V(0, -1, 0), bend=0.0, tip=0.10, crease=0.0, seg_u=4, seg_v=1)
petals = to_obj('crown_petals', cb); solidify(petals, 0.30); bevel(petals, 0.05, 1, 35); add(petals, 'Comb', ARMOUR)
cg = bmesh.new(); bmesh.ops.create_icosphere(cg, subdivisions=1, radius=0.17); cg.transform(Matrix.Translation(HC + V(0, -0.98, 1.16))); bm_obj('crown_gem', cg, 'Comb', GEMB)

# ================= wings (big, feathery, NOT arms): shoulder mass + dome guard, fan of broad feathers, leading guards
for s, side in ((-1, 'R'), (1, 'L')):
    sh = V(1.55 * s, 0.35, 3.25); el = V(2.15 * s, 0.55, 2.95)
    up = ellipsoid((0.72, 0.95, 0.72), 14, 10); up.transform(Matrix.Translation(sh + V(0.25 * s, 0.1, -0.1))); bm_obj('wing_mass', up, 'WingUpper' + side, CREAM)
    dome = ellipsoid((1.05, 1.2, 0.85), 16, 10); dome.transform(Matrix.Translation(sh + V(0.25 * s, 0.05, 0.42)))
    dm = to_obj('dome_src', dome)
    sh_bm = bmesh.new(); sh_bm.from_mesh(dm.data); bpy.data.objects.remove(dm)
    bmesh.ops.delete(sh_bm, geom=[f for f in sh_bm.faces if f.calc_center_median().z < sh.z + 0.42 - 0.05], context='FACES')
    gd = to_obj('shoulder_guard', sh_bm); solidify(gd, 0.10); bevel(gd, 0.035, 3, 35); add(gd, 'WingUpper' + side, ARMOUR)
    trim = bm_obj('shoulder_trim', ring_tube(sh + V(0.25 * s, 0.05, 0.36), V(0, 0, 1), 0.92, 0.09, seg=18, sides=6, arc=math.radians(200)), 'WingUpper' + side, GOLDF) if False else None
    # broad feather fan (grouped shapes, 4 cream + 3 gold on top)
    fb = bmesh.new()
    dirs = [V(s * (0.34 - 0.10 * t), 0.50 + 0.62 * t, -0.42 - 0.62 * t).normalized() for t in (0, 0.33, 0.66, 1.0)]
    fan(fb, el + V(0, 0.05, 0.05), dirs, (3.3, 3.5, 3.3, 2.9), (1.3, 1.35, 1.3, 1.15), V(s, 0, 0.5), 0.13)
    slab('wing_feathers', fb, 'WingLower' + side, CREAM, 0.18, 0)
    gb = bmesh.new()
    dirs2 = [V(s * (0.30 - 0.10 * t), 0.46 + 0.60 * t, -0.40 - 0.55 * t).normalized() for t in (0.1, 0.5, 0.9)]
    fan(gb, el + V(0, 0.02, 0.24), dirs2, (2.3, 2.4, 2.1), (1.1, 1.15, 1.05), V(s, 0, 0.6), 0.16)
    slab('wing_coverts', gb, 'WingLower' + side, GOLDF, 0.16, 0)
    for i in range(2):
        pb = bmesh.new(); feather(pb, el + V(-0.55 * s + 0.0, 0.05 + 0.1 * i, 0.42 + 0.02 * i), V(s * 0.28, 0.70, -0.55), 1.55 - 0.25 * i, 0.95 - 0.1 * i, up=V(s, 0, 1), bend=0.16, tip=0.14, crease=0.0, seg_u=5, seg_v=2, cup=0.25)
        slab('wing_guard', pb, 'WingLower' + side, ARMOUR, 0.10, 0.03)

# ================= tail fan: 5 broad feathers over 5 gold under-feathers
tbm = bmesh.new(); tg = bmesh.new(); TR = V(0, 1.45, 3.05)
for i in range(5):
    a = math.radians(-52 + i * 26); c = 1 - abs(i - 2) / 3.0
    d = V(math.sin(a) * 0.95, math.cos(a) * 0.85, 0.50 + 0.14 * c).normalized()
    feather(tbm, TR + V(0, 0.15, 0.10), d, 3.5 + 0.7 * c, 1.35, up=V(0, 0, 1), bend=-0.06, tip=0.10, crease=0.02, seg_u=6, seg_v=2)
    feather(tg, TR, d, 3.75 + 0.75 * c, 1.55, up=V(0, 0, 1), bend=-0.06, tip=0.10, crease=0.02, seg_u=6, seg_v=2)
slab('tail_top', tbm, 'Tail', CREAM, 0.18, 0); slab('tail_under', tg, 'Tail', GOLDF, 0.16, 0)

# ================= legs: short, strong, big feet
for s, side in ((-1, 'R'), (1, 'L')):
    hip = V(0.85 * s, -0.05, 1.9); knee = V(0.85 * s, -0.30, 1.2); ank = V(0.85 * s, -0.55, 0.45)
    th = ellipsoid((0.66, 0.72, 0.85), 14, 10); th.transform(Matrix.Translation(hip + V(0, 0, -0.1))); bm_obj('thigh', th, 'UpperLeg' + side, GOLDF)
    kn = bmesh.new(); bmesh.ops.create_uvsphere(kn, u_segments=12, v_segments=8, radius=0.42); kn.transform(Matrix.Translation(knee + V(0, -0.12, 0))); bm_obj('knee', kn, 'UpperLeg' + side, ARMOUR)
    sk = loft([(knee, .30, .30), (V(0.85 * s, -0.45, 0.8), .27, .27), (ank, .24, .24)], ring=10); bm_obj('shin', sk, 'LowerLeg' + side, BEAK)
    gv = loft([(knee + V(0, -0.02, -0.05), .40, .40), (V(0.85 * s, -0.42, 0.85), .36, .36), (V(0.85 * s, -0.5, 0.6), .34, .34)], ring=10, cap_start=False)
    bm_obj('greave', gv, 'LowerLeg' + side, ARMOUR)
    for ang, ln in ((-0.62, 1.15), (0.0, 1.4), (0.62, 1.15)):
        d = V(math.sin(ang) * 1, -math.cos(ang), 0)
        base = V(ank.x, ank.y, 0.30)
        toe = loft([(base, .34, .28), (base + d * ln * 0.45, .32, .26), (base + d * ln * 0.80, .26, .22), (base + d * ln * 1.0 + V(0, 0, -0.06), .10, .09)], ring=8)
        bm_obj('toe', toe, 'Foot' + side, BEAK)
        cap = loft([(base + d * ln * 0.50 + V(0, 0, 0.02), .36, .30), (base + d * ln * 0.85, .28, .23), (base + d * ln * 1.06 + V(0, 0, -0.06), .06, .06)], ring=8)
        bm_obj('talon_cap', cap, 'Foot' + side, ARMOUR)
    pad = ellipsoid((0.55, 0.6, 0.30), 10, 7); pad.transform(Matrix.Translation(V(ank.x, ank.y, 0.30))); bm_obj('foot_pad', pad, 'Foot' + side, BEAK)
    sp = loft([(V(ank.x, ank.y + 0.2, 0.32), .18, .16), (V(ank.x, ank.y + 0.7, 0.30), .10, .10), (V(ank.x, ank.y + 0.95, 0.28), .03, .03)], ring=8); bm_obj('spur', sp, 'Foot' + side, BEAK)

# ================= short royal cape (with gold hem) + small halo
cape = bmesh.new(); NU, NV = 16, 10; grid = []
for i in range(NU + 1):
    u = i / NU * 2 - 1; th = u * 1.0
    for j in range(NV + 1):
        v = j / NV; r = 1.70 + 0.32 * v; z = 4.05 - v * 2.05
        grid.append(cape.verts.new((math.sin(th) * r, 0.30 + math.cos(th) * r * 0.95, z)))
faces = []
for i in range(NU):
    for j in range(NV):
        faces.append(cape.faces.new((grid[i * (NV + 1) + j], grid[(i + 1) * (NV + 1) + j], grid[(i + 1) * (NV + 1) + j + 1], grid[i * (NV + 1) + j + 1])))
capeo = to_obj('cape', cape); solidify(capeo, 0.06); bevel(capeo, 0.02, 1, 60); add(capeo, 'Cape', CAPE)
halo = bm_obj('halo', ring_tube(V(0, -1.25, 7.45), V(0, 0, 1), 1.0, 0.075, seg=28, sides=6), 'Halo', HALO)

# ================= finalise: shade smooth, palette UVs, join by group
for ob, g, m in parts:
    for p in ob.data.polygons: p.use_smooth = True
def uv_for(ob, mat, eye_c=None):
    me = ob.data; uvl = me.uv_layers.get('UVMap') or me.uv_layers.new(name='UVMap')
    for poly in me.polygons:
        for li in poly.loop_indices:
            v = me.vertices[me.loops[li].vertex_index].co
            if mat == 'EYE':
                r = EYE_R; u = 0.5 + 0.25 * (0.5 + (v.x - eye_c.x) / (2 * r)); vv = 1.0 - 0.25 * (0.5 - (v.z - eye_c.z) / (2 * r)); uvl.data[li].uv = (u, vv)
            elif mat == 'EMBLEM':
                pass
            else:
                t = max(0.0, min(1.0, v.z / 7.0)); row = mat
                v0 = 1.0 - (row + 1) * ROWH / ATLAS; uvl.data[li].uv = (0.125, v0 + (0.10 + 0.80 * t) * ROWH / ATLAS)
eye_center = {id(o): c for o, c in eye_objs}
for ob, g, m in parts:
    uv_for(ob, m, eye_center.get(id(ob)))
# emblem uses its own painted block
for ob, g, m in parts:
    if ob.name.startswith('emblem'):
        me = ob.data; uvl = me.uv_layers['UVMap']; cs = [me.vertices[i].co for i in range(len(me.vertices))]
        c = sum(cs, Vector()) / len(cs)
        for poly in me.polygons:
            for li in poly.loop_indices:
                v = me.vertices[me.loops[li].vertex_index].co
                uvl.data[li].uv = (0.75 + 0.25 * (0.5 + (v.x - c.x) / 0.9), 1.0 - 0.25 * (0.5 - (v.z - c.z) / 0.9))
groups = {}
for ob, g, m in parts: groups.setdefault(g, []).append(ob)
final = {}
for g, lst in groups.items():
    final[g] = join(lst, g) if len(lst) > 1 else lst[0]; final[g].name = final[g].data.name = g
    for l in final[g].data.uv_layers: l.active_render = True

# ---- painted atlas: clean gradients, eye, emblem (no noise)
def lerp(a, b, t): return np.array(a, np.float32) * (1 - t) + np.array(b, np.float32) * t
tex = np.zeros((ATLAS, ATLAS, 3), np.float32) + 0.5
for r, (name, light, dark, hi) in enumerate(PALETTE):
    for y in range(ROWH):
        s = (ROWH - 1 - y) / (ROWH - 1)   # top of the row = light
        c = lerp(dark, light, s ** 0.8) / 255.0
        if hi: c = np.clip(c + 0.10 * np.exp(-((s - 0.72) / 0.10) ** 2), 0, 1)
        tex[r * ROWH + y, 0:256] = c
S = 128; yy, xx = np.mgrid[0:S, 0:S]; cx = cy = S / 2
# eye block (x 256..384, y 0..128): cream sclera, big warm iris, dark pupil, catch-light
r = np.hypot(xx - cx, yy - cy) / (S / 2); eye = np.ones((S, S, 3), np.float32) * np.array([1.0, 0.98, 0.92])
iris = r < 0.70; eye[iris] = lerp((0.98, 0.62, 0.10), (0.78, 0.36, 0.05), np.clip((r[iris] - 0.35) / 0.35, 0, 1)[:, None])
eye[r < 0.34] = np.array([0.06, 0.03, 0.03])
hl = np.hypot(xx - S * 0.62, yy - S * 0.36) / S < 0.075; eye[hl] = 1.0
hl2 = np.hypot(xx - S * 0.40, yy - S * 0.64) / S < 0.035; eye[hl2] = 1.0
tex[0:S, 256:256 + S] = eye
# emblem block (x 384..512): gold disc with a dark engraved feather
em_ = np.ones((S, S, 3), np.float32) * np.array([1.0, 0.85, 0.42]); rr = np.hypot(xx - cx, yy - cy) / (S / 2)
em_[rr > 0.92] = np.array([0.55, 0.36, 0.08])
u_ = (xx - cx) / (S / 2); v_ = (cy - yy) / (S / 2)
shaft = (np.abs(u_ + 0.25 * v_) < 0.045) & (np.abs(v_) < 0.62)
vane = (np.abs(u_ + 0.25 * v_) < 0.30 * (1 - np.abs(v_) / 0.7) ** 0.8) & (np.abs(v_) < 0.62)
em_[vane] = np.array([0.80, 0.55, 0.12]); em_[shaft] = np.array([0.42, 0.26, 0.05])
tex[0:S, 384:384 + S] = em_
img = bpy.data.images.new('golden_toon_atlas', ATLAS, ATLAS, alpha=False)
img.colorspace_settings.name = 'sRGB'
rgba = np.ones((ATLAS, ATLAS, 4), np.float32); rgba[..., :3] = np.flipud(tex)
img.pixels.foreach_set(rgba.ravel())
img.filepath_raw = os.path.abspath('textures/golden_toon_atlas.png'); img.file_format = 'PNG'; img.save()
mat = bpy.data.materials.new('GoldenToon'); mat.use_nodes = True
b = mat.node_tree.nodes['Principled BSDF']; tn = mat.node_tree.nodes.new('ShaderNodeTexImage'); tn.image = img; tn.interpolation = 'Linear'
mat.node_tree.links.new(tn.outputs['Color'], b.inputs['Base Color']); b.inputs['Roughness'].default_value = 0.55; b.inputs['Metallic'].default_value = 0.0
for g, ob in final.items():
    ob.data.materials.clear(); ob.data.materials.append(mat)
    for p in ob.data.polygons: p.material_index = 0
stats = {g: tri_count(o) for g, o in final.items()}; print('TRIS', stats, 'TOTAL', sum(stats.values()))
bpy.ops.wm.save_as_mainfile(filepath=os.path.abspath('blend/golden_toon_master.blend'))
if '--render' in sys.argv:
    from render import setup_scene, render_views
    setup_scene(); render_views('renders/toon_c', target=V(0, 0.2, 3.6), dist=16)
