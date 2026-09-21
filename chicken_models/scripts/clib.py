"""Original chicken modelling library (Blender). All shapes here are authored procedurally from
lofted cross-sections, sculpted spheres, curved feather blades and armour shells cut from the body
surface. No external assets."""
import bpy, bmesh, math, random
from mathutils import Vector, Matrix, Euler

def clear():
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete()
    for c in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures):
        for x in list(c): c.remove(x)

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a))); return t * t * (3 - 2 * t)

def to_obj(name, bm, mat_index=0, collection=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    for p in me.polygons: p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    (collection or bpy.context.scene.collection).objects.link(ob)
    return ob

def set_mat(ob, mats, index):
    """ensure ob has the full material list, assign every face to `index`"""
    if not ob.data.materials:
        for m in mats: ob.data.materials.append(m)
    for p in ob.data.polygons: p.material_index = index

def activate(ob):
    bpy.ops.object.select_all(action='DESELECT'); ob.select_set(True)
    bpy.context.view_layer.objects.active = ob

def modifier(ob, kind, **kw):
    activate(ob)
    m = ob.modifiers.new(kind.title(), kind)
    for k, v in kw.items(): setattr(m, k, v)
    bpy.ops.object.modifier_apply(modifier=m.name)

def subsurf(ob, levels=1): modifier(ob, 'SUBSURF', levels=levels, render_levels=levels)
def solidify(ob, t, offset=0.0): modifier(ob, 'SOLIDIFY', thickness=t, offset=offset, use_even_offset=True)
def bevel(ob, w, seg=2, angle=40):
    modifier(ob, 'BEVEL', width=w, segments=seg, limit_method='ANGLE', angle_limit=math.radians(angle))

def rot_to(direction, up=Vector((0, 0, 1))):
    """matrix whose +X points along `direction`, +Z as close to `up` as possible"""
    x = Vector(direction).normalized()
    if abs(x.dot(up)) > 0.98: up = Vector((0, 1, 0))
    y = up.cross(x).normalized(); z = x.cross(y).normalized()
    return Matrix(((x.x, y.x, z.x), (x.y, y.y, z.y), (x.z, y.z, z.z))).to_4x4()

# ---------- lofted tube: sections = [(centre, rx, rz, twist?)...] cross-section ring in local XZ, path along `axis`
def loft(sections, ring=16, cap_start=True, cap_end=True, up=Vector((0, 0, 1)), profile=None):
    """sections: list of (centre Vector, rw, rh) ; cross-sections are perpendicular to the path.
    profile(theta)-> radius scale gives non-elliptical shapes (e.g. flat undersides)."""
    bm = bmesh.new(); rings = []
    n = len(sections)
    for i, (c, rw, rh) in enumerate(sections):
        c = Vector(c)
        t = (Vector(sections[min(i + 1, n - 1)][0]) - Vector(sections[max(i - 1, 0)][0])).normalized()
        side = up.cross(t)
        if side.length < 1e-4: side = Vector((1, 0, 0))
        side.normalize(); upv = t.cross(side).normalized()
        r = []
        for k in range(ring):
            a = 2 * math.pi * k / ring
            s = profile(a) if profile else 1.0
            r.append(bm.verts.new(c + side * (math.cos(a) * rw * s) + upv * (math.sin(a) * rh * s)))
        rings.append(r)
    for i in range(n - 1):
        for k in range(ring):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % ring], rings[i + 1][(k + 1) % ring], rings[i + 1][k]))
    if cap_start: bm.faces.new(rings[0][::-1])
    if cap_end: bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# ---------- sculpted ellipsoid
def ellipsoid(radii, seg=40, rings=28, warp=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        p = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
        v.co = warp(p) if warp else p
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm

# ---------- feather blade: root at origin, points along +X, curls up in +Z
def blade(length, width, bend=0.25, tip=0.55, crease=0.05, seg_u=10, seg_v=4, sweep=0.0, cup=0.0):
    bm = bmesh.new(); grid = []
    for i in range(seg_u + 1):
        u = i / seg_u; row = []
        w = width * (math.sin(math.pi * min(1.0, u ** 0.75 * (1.0 - tip * 0.0))) ** 0.6 if u < 1 else 0.0)
        w = width * max(0.012, smooth(0.0, 0.16, u) * max(0.0, 1.0 - u ** (1.15 + (1.0 - tip) * 3.4)) ** 0.62)
        for j in range(seg_v * 2 + 1):
            v = (j / (seg_v * 2)) * 2 - 1
            x = length * u
            y = v * w * 0.5 + sweep * length * u * u
            z = bend * length * u * u - crease * abs(v) * w + cup * (v * v) * w
            row.append(bm.verts.new((x, y, z)))
        grid.append(row)
    uvl = bm.loops.layers.uv.new('UVMap')
    for i in range(seg_u):
        for j in range(seg_v * 2):
            f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
            for lp, (ii, jj) in zip(f.loops, ((i, j), (i, j + 1), (i + 1, j + 1), (i + 1, j))):
                # feather tile lives in the left half of the atlas: v across the vane, u along the shaft
                lp[uvl].uv = (0.015 + 0.47 * (jj / (seg_v * 2)), 0.015 + 0.97 * (ii / seg_u))
    return bm

def merge_bm(dst, src, matrix):
    """append src bmesh transformed into dst (keeps UVs); returns list of new faces"""
    vmap = {}
    for v in src.verts: vmap[v] = dst.verts.new(matrix @ v.co)
    suv = src.loops.layers.uv.active
    duv = dst.loops.layers.uv.get('UVMap') or dst.loops.layers.uv.new('UVMap')
    out = []
    for f in src.faces:
        try:
            nf = dst.faces.new([vmap[v] for v in f.verts])
        except ValueError:
            continue
        if suv:
            for a, b in zip(f.loops, nf.loops): b[duv].uv = a[suv].uv
        out.append(nf)
    src.free(); return out

def feather(dst, base, direction, length, width, up=Vector((0, 0, 1)), roll=0.0, **kw):
    b = blade(length, width, **kw)
    m = Matrix.Translation(base) @ rot_to(direction, up) @ Matrix.Rotation(roll, 4, 'X')
    return merge_bm(dst, b, m)

# ---------- armour shell cut from a source mesh: faces chosen by predicate, pushed out along normals
def shell_from(src_obj, pred, offset=0.06, thick=0.05, name='shell'):
    bm = bmesh.new(); bm.from_mesh(src_obj.data)
    bm.transform(src_obj.matrix_world)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    drop = [f for f in bm.faces if not pred(f.calc_center_median(), f.normal)]
    bmesh.ops.delete(bm, geom=drop, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    for v in bm.verts:
        v.co += v.normal * offset
    return bm

def uv_smart(ob, angle=66, margin=0.004):
    activate(ob); bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin)
    bpy.ops.object.mode_set(mode='OBJECT')

def join(objs, name):
    activate(objs[0])
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join(); objs[0].name = name; objs[0].data.name = name
    return objs[0]

def tri_count(ob):
    dg = bpy.context.evaluated_depsgraph_get(); me = ob.evaluated_get(dg).to_mesh()
    n = sum(len(p.vertices) - 2 for p in me.polygons); ob.evaluated_get(dg).to_mesh_clear(); return n


def surf_patch(pt, cth, cph, rth, rph, off, rings=9, seg=36, sup=2.6, dome=0.0):
    """armour plate wrapped over a surface: pt(th, ph) -> (point, outward normal). Concentric grid with a
    superellipse outline, so edges are clean curves and the plate follows the anatomy."""
    bm = bmesh.new(); grid = []
    c, n = pt(cth, cph); center = bm.verts.new(c + n * (off + dome))
    for i in range(1, rings + 1):
        t = i / rings; row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            r = t / (abs(math.cos(a)) ** sup + abs(math.sin(a)) ** sup) ** (1.0 / sup)
            p, nn = pt(cth + rth * r * math.cos(a), cph + rph * r * math.sin(a))
            row.append(bm.verts.new(p + nn * (off + dome * (1 - t * t))))
        grid.append(row)
    for k in range(seg):
        bm.faces.new((center, grid[0][(k + 1) % seg], grid[0][k]))
    for i in range(rings - 1):
        for k in range(seg):
            bm.faces.new((grid[i][k], grid[i][(k + 1) % seg], grid[i + 1][(k + 1) % seg], grid[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm
