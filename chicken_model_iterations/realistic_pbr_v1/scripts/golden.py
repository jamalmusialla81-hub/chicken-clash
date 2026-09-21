import bpy, bmesh, math, random, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from clib import *
from render import setup_scene, render_views
from mathutils import Vector, Matrix
clear()
def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)

def mat(name, color, metal=0.0, rough=0.5, emit=None, alpha=1.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1); b.inputs['Metallic'].default_value = metal; b.inputs['Roughness'].default_value = rough
    if emit:
        b.inputs['Emission Color'].default_value = (*emit, 1); b.inputs['Emission Strength'].default_value = 3.0
    return m
MATS = [mat('feather', (0.72, 0.40, 0.12), 0, 0.75), mat('leather', (0.16, 0.08, 0.05), 0, 0.85), mat('gold', (1.0, 0.68, 0.18), 1, 0.28),
        mat('gem_red', (0.8, 0.02, 0.05), 0, 0.1), mat('gem_blue', (0.05, 0.3, 0.9), 0, 0.1), mat('cloth', (0.45, 0.04, 0.08), 0, 0.9),
        mat('rune', (1, 0.8, 0.3), 0, 0.5, emit=(1, 0.75, 0.25)), mat('horn', (0.95, 0.55, 0.16), 0, 0.5), mat('eye', (1.0, 0.72, 0.1), 0, 0.15)]
FEATHER, LEATHER, GOLD, GEMR, GEMB, CLOTH, RUNE, HORN, EYE = range(9)
parts = []
def finish(ob, m):
    set_mat(ob, MATS, m); parts.append(ob); return ob

# ---------------- body (sculpted egg, upright proud chest)
def body_warp(p):
    x, y, z = p
    k = smooth(0.15, 1.7, y); x *= 1 - 0.5 * k; z = z * (1 - 0.30 * k) + 0.55 * k
    f = smooth(0.0, 1.7, -y); z += 0.28 * f; x *= 1 + 0.06 * f
    x *= 1 - 0.22 * smooth(-0.6, -1.85, z)
    return Vector((x, y, z))
body_bm = ellipsoid((1.55, 1.75, 1.9), 32, 22, body_warp)
bm2 = body_bm.copy()
body_bm.transform(Matrix.Rotation(math.radians(-10), 4, 'X')); body_bm.transform(Matrix.Translation((0, 0.1, 3.1)))
body_src = to_obj('BodySrc', body_bm)
bm2.transform(Matrix.Rotation(math.radians(-10), 4, 'X')); bm2.transform(Matrix.Translation((0, 0.1, 3.1)))
body_hi = to_obj('body', bm2)
bm3 = bmesh.new(); bm3.from_mesh(body_hi.data)
subsurf(body_hi, 1)
finish(body_hi, FEATHER)

# ---------------- head (sculpted, eye sockets, brow, cheeks)
HC = V((0, -1.55, 5.15))
def head_warp(p):
    x, y, z = p; n = p.normalized()
    x *= 1 + 0.12 * smooth(-0.2, 0.5, abs(y))            # fuller cheeks
    y *= 1 - 0.10 * smooth(0.2, 1.0, -z + 0.0)
    if y < 0: x *= 1 - 0.30 * smooth(0.1, 1.0, -y)         # tapering muzzle
    z += 0.10 * smooth(-0.6, -0.9, y) * 0                  # brow handled by socket
    q = Vector((x, y, z))
    for s in (-1, 1):
        c = V((0.50 * s, -0.78, 0.16)); d = (q - c).length
        q -= q.normalized() * 0.13 * math.exp(-(d / 0.30) ** 2)          # eye socket
        cb = V((0.50 * s, -0.66, 0.50)); db = (q - cb).length
        q += q.normalized() * 0.07 * math.exp(-(db / 0.34) ** 2)        # brow ridge
    return q
head_bm = ellipsoid((1.08, 1.12, 1.05), 30, 20, head_warp)
head_bm.transform(Matrix.Translation(HC))
head_src = to_obj('HeadSrc', head_bm.copy())
head = to_obj('head', head_bm); subsurf(head, 1); finish(head, FEATHER)

def head_pt(th, ph):
    u = V(math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph))
    p = head_warp(V(u.x * 1.08, u.y * 1.12, u.z * 1.05)) + HC
    return p, u.normalized()

# neck
neck_bm = loft([(V((0, -0.7, 3.9)), 0.95, 0.9), (V((0, -1.05, 4.4)), 0.82, 0.80), (V((0, -1.4, 4.75)), 0.78, 0.74), (V((0, -1.5, 5.0)), 0.75, 0.72)], ring=20)
neck = to_obj('neck', neck_bm); subsurf(neck, 1); finish(neck, FEATHER)

# beak: upper + lower, hooked tip
def beak(pts, ring=14):
    bm = loft(pts, ring=ring); return bm
up_bm = beak([(V((0, -2.30, 5.03)), .44, .34), (V((0, -2.70, 5.00)), .40, .29), (V((0, -3.10, 4.92)), .29, .22), (V((0, -3.42, 4.78)), .13, .13), (V((0, -3.55, 4.62)), .04, .05)])
upper = to_obj('beak_upper', up_bm); subsurf(upper, 1); finish(upper, HORN)
lo_bm = beak([(V((0, -2.30, 4.84)), .34, .17), (V((0, -2.72, 4.80)), .30, .14), (V((0, -3.08, 4.73)), .19, .11), (V((0, -3.30, 4.68)), .07, .07)])
lower = to_obj('beak_lower', lo_bm); subsurf(lower, 1); finish(lower, HORN)

# eyes + determined lids
for s in (-1, 1):
    e = bmesh.new(); bmesh.ops.create_uvsphere(e, u_segments=22, v_segments=16, radius=0.34)
    e.transform(Matrix.Translation(HC + V((0.50 * s, -0.83, 0.16)))); eye = to_obj('eye', e); finish(eye, EYE)
    lid = bmesh.new(); bmesh.ops.create_uvsphere(lid, u_segments=24, v_segments=14, radius=0.395)
    keep = [f for f in lid.faces if f.calc_center_median().z > -0.02 + 0.12 * abs(f.calc_center_median().x) * 0]
    bmesh.ops.delete(lid, geom=[f for f in lid.faces if f.calc_center_median().z < 0.13], context='FACES')
    lid.transform(Matrix.Rotation(math.radians(-24 * s), 4, 'Y') @ Matrix.Rotation(math.radians(14), 4, 'X'))   # brows slope inward = determined
    lid.transform(Matrix.Translation(HC + V((0.50 * s, -0.85, 0.20))))
    lo = to_obj('lid', lid); solidify(lo, 0.03, 1); finish(lo, FEATHER)

# ---------------- comb: crown integrated (gold band grown from the skull + petals)
cb = bmesh.new()
n = 9
for i in range(n):
    a = 2 * math.pi * i / n + math.pi / 2          # ring around the crown of the head, tallest at the front-centre
    fw = (math.cos(a) * -1)                            # -1..1 : front (+) / back (-)
    center = 0.5 + 0.5 * math.cos(a - math.pi / 2 + math.pi)  # placeholder, overwritten below
    rad = V(math.sin(a), -math.cos(a), 0)
    tall = 0.55 + 0.55 * max(0.0, -rad.y * 0.6 + 0.4) + (0.35 if i == 0 else 0)
    pos = HC + V(rad.x * 0.58, rad.y * 0.50 - 0.1, 0.88)
    d = (V(0, 0, 1) + rad * 0.22).normalized()
    feather(cb, pos, d, 0.85 + 0.75 * tall * 0.9, 0.52, up=rad, bend=-0.10, tip=0.60, crease=0.0, seg_u=6, seg_v=2)
comb = to_obj('comb', cb); solidify(comb, 0.09); bevel(comb, 0.02, 2); finish(comb, GOLD)
band = shell_from(head_src, lambda c, n: (c.z - HC.z) > 0.62 and c.y > HC.y - 0.85, offset=0.05)
bo = to_obj('crown_band', band); solidify(bo, 0.07); bevel(bo, 0.015, 2); finish(bo, GOLD)


def ring_tube(center, axis, R, r, seg=36, sides=8, arc=2 * math.pi):
    bm = bmesh.new(); frame = rot_to(axis)
    rows = []
    for i in range(seg + (0 if arc >= 2 * math.pi - 1e-3 else 1)):
        a = arc * i / seg; c = V(0, math.cos(a) * R, math.sin(a) * R); tang = V(0, -math.sin(a), math.cos(a))
        row = []
        for k in range(sides):
            b = 2 * math.pi * k / sides; nrm = V(0, math.cos(a), math.sin(a))
            row.append(bm.verts.new(c + nrm * math.cos(b) * r + V(1, 0, 0) * math.sin(b) * r))
        rows.append(row)
    cnt = len(rows)
    for i in range(cnt if arc >= 2 * math.pi - 1e-3 else cnt - 1):
        for k in range(sides): bm.faces.new((rows[i][k], rows[i][(k + 1) % sides], rows[(i + 1) % cnt][(k + 1) % sides], rows[(i + 1) % cnt][k]))
    bm.transform(Matrix.Translation(center) @ frame); bmesh.ops.recalc_face_normals(bm, faces=bm.faces); return bm

# ================= layered chest / body feathers
def in_ell(x, z, cx, cz, rx, rz): return ((x - cx) / rx) ** 2 + ((z - cz) / rz) ** 2 < 1
BODY_R = (1.55, 1.75, 1.9)
def body_pt(th, ph):
    """point + outward normal on the body surface. th: azimuth (0 = front, -Y), ph: elevation"""
    u = Vector((math.sin(th) * math.cos(ph), -math.cos(th) * math.cos(ph), math.sin(ph)))
    p = body_warp(Vector((u.x * BODY_R[0], u.y * BODY_R[1], u.z * BODY_R[2])))
    m = Matrix.Translation((0, 0.1, 3.1)) @ Matrix.Rotation(math.radians(-10), 4, 'X')
    return m @ p, (m.to_3x3() @ u).normalized()
fb = bmesh.new(); rng = random.Random(3)
for row, ph in enumerate([1.05, 0.85, 0.65, 0.45, 0.25, 0.05, -0.15, -0.35, -0.55, -0.75, -0.95]):
    circ = 2 * math.pi * BODY_R[0] * math.cos(ph) * 1.05
    cnt = max(6, int(circ / 0.50)); off = 0.5 if row % 2 else 0.0
    for k in range(cnt):
        th = (k + off) / cnt * 2 * math.pi
        if math.cos(th) > 0.55 and ph > 0.7: continue      # keep the back clear where the cape sits
        p, n = body_pt(th, ph)
        if n.y < -0.3 and (in_ell(p.x, p.z, 0, 3.55, 1.34, 1.37) or in_ell(p.x, p.z, 0, 2.28, 1.12, 0.42) or in_ell(p.x, p.z, 0, 1.78, 0.92, 0.36)): continue   # plate covers this
        p0, _ = body_pt(th, ph + 0.03); tang = (p - p0).normalized()   # points down the surface
        d = (tang * math.cos(math.radians(13)) + n * math.sin(math.radians(13))).normalized()
        L = 0.62 + rng.random() * 0.10 + 0.08 * (1 - abs(ph))
        feather(fb, p - n * 0.06, d, L, 0.58, up=n, bend=0.16, tip=0.32, crease=0.02, seg_u=4, seg_v=1)
body_feathers = to_obj('body_feathers', fb); finish(body_feathers, FEATHER)

# ================= armour: breastplate cut from the body surface (fits the chest, not a box)
def breast(c, n): return n.y < -0.35 and in_ell(c.x, c.z, 0, 3.55, 1.22, 1.25)
def lame1(c, n): return n.y < -0.3 and in_ell(c.x, c.z, 0, 2.28, 1.05, 0.34)
def lame2(c, n): return n.y < -0.25 and in_ell(c.x, c.z, 0, 1.78, 0.85, 0.28)
def plate(name, pt, th, ph, rth, rph, off, thick, mat_i, sup=2.6, dome=0.0, rings=9, bev=0.02):
    o = to_obj(name, surf_patch(pt, th, ph, rth, rph, off, rings=rings, sup=sup, dome=dome))
    solidify(o, thick); bevel(o, bev, 2); return finish(o, mat_i)
lea = to_obj('leather_under', surf_patch(body_pt, 0.0, 0.05, 0.98, 1.0, 0.05, rings=9, sup=2.2)); solidify(lea, 0.05); finish(lea, LEATHER)
plate('breastplate', body_pt, 0.0, 0.30, 0.70, 0.58, 0.17, 0.09, GOLD, sup=2.4, dome=0.10)
plate('lame1', body_pt, 0.0, -0.20, 0.72, 0.17, 0.16, 0.08, GOLD, sup=3.0, dome=0.05)
plate('lame2', body_pt, 0.0, -0.50, 0.62, 0.15, 0.15, 0.08, GOLD, sup=3.0, dome=0.05)
plate('chest_ridge', body_pt, 0.0, 0.30, 0.10, 0.52, 0.26, 0.05, GOLD, sup=2.0, dome=0.06)
plate('rarity_crest', body_pt, 0.0, 0.34, 0.22, 0.24, 0.31, 0.05, GOLD, sup=2.0, dome=0.08)
gp, gn = body_pt(0, 0.34)
gem = bmesh.new(); bmesh.ops.create_icosphere(gem, subdivisions=2, radius=0.2)
gem.transform(Matrix.Translation(gp + gn * 0.40)); gemo = to_obj('gem_center', gem)
for pl in gemo.data.polygons: pl.use_smooth = False
finish(gemo, GEMR)

# gorget: a proper collar ring seated on the shoulders, plus wrapped cheek guards
col = to_obj('gorget', ring_tube(V(0, -0.98, 4.30), V(0, -0.35, 1.0), 0.98, 0.17, seg=36, sides=10)); subsurf(col, 1); finish(col, GOLD)
for s_ in (-1, 1):
    plate('cheek', head_pt, 1.30 * s_, -0.34, 0.34, 0.30, 0.05, 0.05, GOLD, sup=2.2, dome=0.04, bev=0.015)

# ================= wings: articulated feathered wing + layered gold guards
def wing(s):
    wb = bmesh.new(); R = V(1.72 * s, 0.35, 3.60)
    prim = 9
    for i in range(prim):
        t = i / (prim - 1)
        d = V(s * (0.30 - 0.18 * t), 0.50 + 0.65 * t, -0.42 - 0.72 * t).normalized()
        L = 3.55 - 0.85 * abs(t - 0.35)
        feather(wb, R + V(0, 0.05 * i, -0.04 * i), d, L, 0.78, up=V(s, 0, 0.5), bend=0.09, tip=0.55, crease=0.04, seg_u=8, seg_v=2)
    for i in range(7):
        t = i / 6
        d = V(s * (0.26 - 0.16 * t), 0.48 + 0.62 * t, -0.36 - 0.68 * t).normalized()
        feather(wb, R + V(0, 0.06 * i + 0.15, 0.10), d, 2.35 - 0.5 * abs(t - 0.4), 0.72, up=V(s, 0, 0.6), bend=0.13, tip=0.5, seg_u=7, seg_v=2)
    for i in range(6):
        t = i / 5
        d = V(s * (0.24 - 0.16 * t), 0.45 + 0.6 * t, -0.30 - 0.62 * t).normalized()
        feather(wb, R + V(0, 0.08 * i + 0.25, 0.20), d, 1.45 - 0.3 * abs(t - 0.4), 0.62, up=V(s, 0, 0.7), bend=0.16, tip=0.5, seg_u=6, seg_v=2)
    wo = to_obj('wing_feathers', wb); wo.location = (0, 0, 0); finish(wo, FEATHER)
    # arm mass
    arm = loft([(R + V(-0.35 * s, -0.25, 0.15), 0.55, 0.62), (R + V(0.30 * s, 0.05, -0.05), 0.55, 0.60), (R + V(1.05 * s, 0.50, -0.30), 0.42, 0.46)], ring=14)
    ao = to_obj('wing_arm', arm); subsurf(ao, 1); finish(ao, FEATHER)
    # articulated guards along the leading edge
    for i in range(5):
        u = i / 4; base = R + V((0.05 + 1.05 * u) * s, 0.10 + 0.55 * u, 0.55 - 0.32 * u)
        gb = bmesh.new()
        feather(gb, base, V(s * 0.28, 0.66, -0.55), 1.30 - 0.12 * i, 0.70 - 0.05 * i, up=V(s, 0, 1), bend=0.26, tip=0.42, crease=0.0, seg_u=6, seg_v=2, cup=0.25)
        go2 = to_obj('wing_guard', gb); solidify(go2, 0.07); bevel(go2, 0.02, 2); finish(go2, GOLD)
    # layered pauldron over the shoulder
    for i in range(3):
        e = ellipsoid((0.95 - 0.12 * i, 1.10 - 0.10 * i, 0.72 - 0.06 * i), 22, 14)
        e.transform(Matrix.Translation((1.62 * s + 0.04 * s * i, 0.02 + 0.42 * i, 4.02 - 0.28 * i)))
        eo = to_obj('pauld_src', e)
        sh = shell_from(eo, lambda c, n: n.z > 0.10, offset=0.0); bpy.data.objects.remove(eo)
        po = to_obj('pauldron', sh); solidify(po, 0.08); subsurf(po, 1); bevel(po, 0.02, 2); finish(po, GOLD)
wing(-1); wing(1)

# ================= tail fan through an armour opening
tb = bmesh.new(); TR = V(0, 1.55, 3.40)
for i in range(9):
    a = math.radians(-64 + i * 16); c = 1 - abs(i - 4) / 4.5
    d = V(math.sin(a) * 0.95, math.cos(a) * 0.85, 0.52 + 0.16 * c).normalized()
    feather(tb, TR, d, 3.6 + 1.3 * c, 1.15, up=V(0, 0, 1), bend=-0.08, tip=0.5, crease=0.03, seg_u=9, seg_v=2)
tail = to_obj('tail', tb); finish(tail, FEATHER)
tring = to_obj('tail_ring', ring_tube(TR + V(0, -0.15, 0.0), V(0, 1, 0.1), 0.95, 0.13, arc=math.radians(250))); subsurf(tring, 1); finish(tring, GOLD)

# ================= cape (cloth), attached under the collar
cape = bmesh.new(); NU, NV = 22, 16; grid = []
for i in range(NU + 1):
    u = i / NU * 2 - 1; th = u * 1.05; row = []
    for j in range(NV + 1):
        v = j / NV; hem = 1 - 0.07 * abs(math.sin(u * 6.5)) * smooth(0.6, 1, v)
        r = 1.78 + 0.30 * v + 0.07 * math.sin(th * 8 + v * 2) * v
        z = 4.55 - v * 2.5 * hem
        y = 0.25 + math.cos(th) * r * 0.95
        grid.append(cape.verts.new((math.sin(th) * r, y, z)))
for i in range(NU):
    for j in range(NV):
        cape.faces.new((grid[i * (NV + 1) + j], grid[(i + 1) * (NV + 1) + j], grid[(i + 1) * (NV + 1) + j + 1], grid[i * (NV + 1) + j + 1]))
capeo = to_obj('cape', cape); solidify(capeo, 0.05); subsurf(capeo, 1); finish(capeo, CLOTH)

# ================= legs, greaves, claws
def toe(base, ang, L, s):
    d = V(math.sin(ang), -math.cos(ang), 0)
    pts = [(base, .24, .20), (base + d * L * 0.4 + V(0, 0, 0.02), .21, .17), (base + d * L * 0.75 + V(0, 0, 0.03), .17, .14), (base + d * L * 0.95 + V(0, 0, -0.05), .10, .09), (base + d * (L * 1.12) + V(0, 0, -0.22), .035, .035)]
    return loft(pts, ring=10)
for s in (-1, 1):
    hip = V(0.78 * s, -0.05, 1.75)
    thigh = ellipsoid((0.62, 0.72, 0.95), 20, 14); thigh.transform(Matrix.Translation(hip + V(0, 0, -0.1))); to = to_obj('thigh', thigh); subsurf(to, 1); finish(to, FEATHER)
    leg = loft([(V(0.78 * s, -0.2, 1.25), .34, .34), (V(0.78 * s, -0.42, 0.7), .25, .28), (V(0.78 * s, -0.55, 0.32), .20, .22)], ring=12)
    lo2 = to_obj('leg', leg); subsurf(lo2, 1); finish(lo2, HORN)
    gr = shell_from(lo2, lambda c, n, s=s: c.z > 0.42 and n.y < 0.25, offset=0.06)
    gro = to_obj('greave', gr); solidify(gro, 0.06); bevel(gro, 0.02, 2); finish(gro, GOLD)
    kn = bmesh.new(); bmesh.ops.create_uvsphere(kn, u_segments=16, v_segments=10, radius=0.33); kn.transform(Matrix.Translation((0.78 * s, -0.5, 1.22)))
    kno = to_obj('knee', kn); finish(kno, GOLD)
    fb_ = V(0.78 * s, -0.55, 0.26)
    for ang in (-0.55, 0.0, 0.55):
        t = to_obj('toe', toe(fb_, ang, 1.25, s)); subsurf(t, 1); finish(t, HORN)
        cg = shell_from(t, lambda c, n, fb_=fb_: (c - fb_).length > 0.55 and n.z > -0.3, offset=0.035)
        cgo = to_obj('claw_guard', cg); solidify(cgo, 0.045); bevel(cgo, 0.012, 2); finish(cgo, GOLD)
    sp = to_obj('spur', loft([(fb_ + V(0, 0.15, 0.05), .16, .14), (fb_ + V(0, 0.5, 0.05), .12, .10), (fb_ + V(0, 0.75, 0.0), .04, .04)], ring=8)); finish(sp, HORN)

# ================= halo: two broken arcs of a vertical ring behind the head (slow rotation about Y in-game)
for a0, a1 in ((25, 150), (200, 330)):
    h = ring_tube(V(0, 0, 0), V(0, 1, 0), 2.05, 0.11, seg=28, sides=8, arc=math.radians(a1 - a0))
    h.transform(Matrix.Rotation(math.radians(a0), 4, 'Y'))
    h.transform(Matrix.Translation(HC + V(0, 0.95, 0.35)))
    ho = to_obj('halo', h); subsurf(ho, 1); finish(ho, GOLD)
    inner = ring_tube(V(0, 0, 0), V(0, 1, 0), 2.05, 0.03, seg=28, sides=6, arc=math.radians(a1 - a0 - 24))
    inner.transform(Matrix.Rotation(math.radians(a0 + 12), 4, 'Y')); inner.transform(Matrix.Translation(HC + V(0, 0.90, 0.35)))
    io = to_obj('halo_rune', inner); finish(io, RUNE)

if __name__ == '__main__':
    for o in list(bpy.data.objects):
        if o.name.startswith('BodySrc') or o.name.startswith('HeadSrc'): bpy.data.objects.remove(o)
    setup_scene()
    for f in render_views('renders/golden_d', target=V((0, 0.4, 3.8)), dist=15): print(f)
    for p in parts: print(p.name, tri_count(p))
