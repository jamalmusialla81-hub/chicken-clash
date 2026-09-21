"""Procedural PBR material graphs + baker. Each builder returns sockets/values for
color, rough, metal, height. Passes rebuild the graph as Emission (albedo / roughness / metalness) or
Diffuse+Bump (tangent normal), then bake into one atlas."""
import bpy, math
import numpy as np

class G:
    def __init__(s, mat):
        mat.use_nodes = True; s.mat = mat; s.n = mat.node_tree.nodes; s.l = mat.node_tree.links; s.n.clear()
    def new(s, kind, **kw):
        x = s.n.new(kind)
        for k, v in kw.items(): setattr(x, k, v)
        return x
    def coord(s): return s.new('ShaderNodeTexCoord').outputs['Object']
    def noise(s, scale, detail=5.0, rough=0.55, vec=None):
        n = s.new('ShaderNodeTexNoise'); n.inputs['Scale'].default_value = scale; n.inputs['Detail'].default_value = detail; n.inputs['Roughness'].default_value = rough
        s.l.new(vec or s.coord(), n.inputs['Vector']); return n.outputs['Fac']
    def voro_edge(s, scale, vec=None):
        v = s.new('ShaderNodeTexVoronoi', feature='DISTANCE_TO_EDGE'); v.inputs['Scale'].default_value = scale
        s.l.new(vec or s.coord(), v.inputs['Vector']); return v.outputs['Distance']
    def voro(s, scale, vec=None):
        v = s.new('ShaderNodeTexVoronoi', feature='F1'); v.inputs['Scale'].default_value = scale
        s.l.new(vec or s.coord(), v.inputs['Vector']); return v.outputs['Distance']
    def ramp(s, fac, stops):
        r = s.new('ShaderNodeValToRGB'); e = r.color_ramp.elements
        e[0].position, e[0].color = stops[0][0], (*stops[0][1], 1); e[1].position, e[1].color = stops[-1][0], (*stops[-1][1], 1)
        for pos, col in stops[1:-1]:
            el = e.new(pos); el.color = (*col, 1)
        s.l.new(fac, r.inputs['Factor']); return r.outputs['Color']
    def mix(s, a, b, fac, blend='MIX'):
        m = s.new('ShaderNodeMixRGB', blend_type=blend)
        if isinstance(fac, (int, float)): m.inputs['Factor'].default_value = fac
        else: s.l.new(fac, m.inputs['Factor'])
        for name, v in (('Color1', a), ('Color2', b)):
            if isinstance(v, tuple): m.inputs[name].default_value = (*v, 1)
            else: s.l.new(v, m.inputs[name])
        return m.outputs['Color']
    def math(s, op, a, b=None, clamp=False):
        m = s.new('ShaderNodeMath', operation=op, use_clamp=clamp)
        for i, v in enumerate((a, b)):
            if v is None: continue
            if isinstance(v, (int, float)): m.inputs[i].default_value = v
            else: s.l.new(v, m.inputs[i])
        return m.outputs['Value']
    def gray(s, fac, lo, hi):   # map 0..1 -> lo..hi
        return s.math('ADD', s.math('MULTIPLY', fac, hi - lo), lo)
    def pointiness(s): return s.new('ShaderNodeNewGeometry').outputs['Pointiness']
    def wear(s, lo=0.5, hi=0.62):   # edge wear mask from mesh curvature
        r = s.new('ShaderNodeMapRange'); r.inputs['From Min'].default_value = lo; r.inputs['From Max'].default_value = hi
        s.l.new(s.pointiness(), r.inputs['Value']); return r.outputs['Result']

# ---------- material builders  ->  dict(color, rough, metal, height)
def m_skin(g):
    n = g.noise(5.5, 6); v = g.voro_edge(15.0)
    col = g.ramp(n, [(0.0, (0.30, 0.13, 0.035)), (0.5, (0.62, 0.33, 0.09)), (1.0, (0.92, 0.66, 0.26))])
    col = g.mix(col, (0.10, 0.045, 0.012), g.math('SUBTRACT', 1.0, g.math('MULTIPLY', v, 3.0, True), True), 'MULTIPLY') if False else g.mix(col, g.ramp(v, [(0.0, (0.35, 0.16, 0.05)), (0.35, (1.0, 0.92, 0.8))]), 0.55, 'MULTIPLY')
    return dict(color=col, rough=0.78, metal=0.0, height=g.math('ADD', g.math('MULTIPLY', v, 0.6), g.math('MULTIPLY', n, 0.25)))
def m_leather(g):
    n = g.noise(9, 7, 0.6); w = g.noise(40, 3)
    col = g.ramp(n, [(0.0, (0.06, 0.03, 0.02)), (1.0, (0.20, 0.10, 0.06))])
    return dict(color=col, rough=g.gray(n, 0.62, 0.9), metal=0.0, height=g.math('ADD', g.math('MULTIPLY', n, 0.6), g.math('MULTIPLY', w, 0.3)))
def m_gold(g):
    wear = g.wear(); n = g.noise(4.0, 4); scr = g.voro_edge(60.0); hm = g.voro_edge(18.0)
    base = g.ramp(n, [(0.0, (0.86, 0.50, 0.09)), (0.6, (1.0, 0.68, 0.17)), (1.0, (1.0, 0.82, 0.36))])
    col = g.mix(base, (1.0, 0.90, 0.60), wear)                                        # bright worn edges
    engr = g.new('ShaderNodeTexWave', wave_type='BANDS', bands_direction='Z'); engr.inputs['Scale'].default_value = 9.0; engr.inputs['Distortion'].default_value = 3.0
    g.l.new(g.coord(), engr.inputs['Vector'])
    cut = g.math('LESS_THAN', engr.outputs['Fac'], 0.10)                              # engraved lines
    col = g.mix(col, (0.30, 0.16, 0.03), g.math('MULTIPLY', cut, 0.8))
    rough = g.math('ADD', g.gray(n, 0.24, 0.44), g.math('MULTIPLY', g.math('LESS_THAN', scr, 0.04), 0.25))
    height = g.math('SUBTRACT', g.math('MULTIPLY', hm, 0.05), g.math('MULTIPLY', cut, 0.45))
    return dict(color=col, rough=rough, metal=1.0, height=height)
def m_gem_red(g):
    n = g.noise(6, 3); return dict(color=g.ramp(n, [(0.0, (0.45, 0.0, 0.02)), (1.0, (0.95, 0.06, 0.10))]), rough=0.08, metal=0.0, height=0.0)
def m_gem_blue(g):
    n = g.noise(6, 3); return dict(color=g.ramp(n, [(0.0, (0.02, 0.10, 0.45)), (1.0, (0.10, 0.55, 1.0))]), rough=0.08, metal=0.0, height=0.0)
def m_cloth(g):
    n = g.noise(6, 3); ch = g.new('ShaderNodeTexChecker'); ch.inputs['Scale'].default_value = 90.0; g.l.new(g.coord(), ch.inputs['Vector'])
    col = g.mix(g.ramp(n, [(0.0, (0.30, 0.02, 0.05)), (1.0, (0.58, 0.07, 0.11))]), (0.0, 0.0, 0.0), g.math('MULTIPLY', ch.outputs['Fac'], 0.18))
    return dict(color=col, rough=0.9, metal=0.0, height=g.math('MULTIPLY', ch.outputs['Fac'], 0.3))
def m_rune(g): return dict(color=(1.0, 0.80, 0.30), rough=0.4, metal=0.0, height=0.0)
def m_horn(g):
    n = g.noise(12, 4); l = g.noise(70, 2)
    return dict(color=g.ramp(n, [(0.0, (0.62, 0.30, 0.06)), (0.6, (0.90, 0.55, 0.16)), (1.0, (0.98, 0.82, 0.50))]), rough=g.gray(n, 0.4, 0.6), metal=0.0, height=g.math('MULTIPLY', l, 0.3))
def m_eye(g): return dict(color=(1.0, 0.7, 0.1), rough=0.15, metal=0.0, height=0.0)
BUILDERS = [m_skin, m_leather, m_gold, m_gem_red, m_gem_blue, m_cloth, m_rune, m_horn, m_eye]

def _emit(g, socket_or_val):
    e = g.new('ShaderNodeEmission'); out = g.new('ShaderNodeOutputMaterial')
    if isinstance(socket_or_val, (int, float)): e.inputs['Color'].default_value = (socket_or_val,) * 3 + (1,)
    elif isinstance(socket_or_val, tuple): e.inputs['Color'].default_value = (*socket_or_val, 1)
    else: g.l.new(socket_or_val, e.inputs['Color'])
    g.l.new(e.outputs['Emission'], out.inputs['Surface']); return out

def build_pass(mat, idx, kind, image):
    g = G(mat); r = BUILDERS[idx](g)
    if kind == 'normal':
        d = g.new('ShaderNodeBsdfDiffuse'); out = g.new('ShaderNodeOutputMaterial')
        if not isinstance(r['height'], (int, float)):
            b = g.new('ShaderNodeBump'); b.inputs['Strength'].default_value = 1.0; b.inputs['Distance'].default_value = 0.012
            g.l.new(r['height'], b.inputs['Height']); g.l.new(b.outputs['Normal'], d.inputs['Normal'])
        g.l.new(d.outputs['BSDF'], out.inputs['Surface'])
    else:
        _emit(g, {'albedo': r['color'], 'rough': r['rough'], 'metal': r['metal']}[kind])
    tex = g.new('ShaderNodeTexImage'); tex.image = image; g.n.active = tex
    for n in g.n: n.select = False
    tex.select = True

def bake_atlas(objs, size=1024, samples=6, margin=8):
    ob = objs[0]
    sc = bpy.context.scene; sc.render.engine = 'CYCLES'; sc.cycles.samples = samples; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
    sc.render.bake.margin = margin; sc.render.bake.normal_space = 'TANGENT'
    imgs = {}
    for kind in ('albedo', 'rough', 'metal', 'normal'):
        img = bpy.data.images.new('bake_' + kind, size, size, alpha=False)
        img.colorspace_settings.name = 'sRGB' if kind == 'albedo' else 'Non-Color'
        if kind == 'normal': img.generated_color = (0.5, 0.5, 1.0, 1.0)
        else: img.generated_color = (0.0, 0.0, 0.0, 1.0)
        imgs[kind] = img
        for i, m in enumerate(ob.data.materials): build_pass(m, i, kind, img)
        bpy.ops.object.select_all(action='DESELECT')
        for o_ in objs: o_.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.bake(type='NORMAL' if kind == 'normal' else 'EMIT', margin=margin, use_clear=False)
        print('baked', kind)
        img.filepath_raw = '/Users/jakoblal/Roblox/chicken_models/textures/_raw_' + kind + '.png'; img.file_format = 'PNG'; img.save()
    return imgs

# ---------- authored feather tile (left half of the atlas): rachis, barbs, colour progression
def feather_tile(size, palette):
    """returns dict of float arrays (rows=u along the shaft 0..1, cols=v across) for albedo(3), rough, metal, height"""
    H = size; W = size // 2
    v, u = np.meshgrid(np.linspace(0, 1, W), np.linspace(0, 1, H))
    cx = np.abs(v - 0.5) * 2.0                       # 0 at shaft, 1 at vane edge
    rng = np.random.default_rng(7)
    barb_phase = u * 62.0 - cx * 15.0                # barbs sweep from shaft toward the tip
    barbs = 0.5 + 0.5 * np.sin(barb_phase * 2 * math.pi + rng.random() * 6.0)
    fine = 0.5 + 0.5 * np.sin((u * 210.0 - cx * 52.0) * 2 * math.pi)
    grain = rng.random((H, W)) * 0.5
    shaft = np.exp(-((v - 0.5) / 0.012) ** 2)        # bright rachis
    a, b, c, edge = (np.array(x)[None, None, :] for x in palette)   # root, mid, tip, edge colours
    t1 = np.clip(u * 2.0, 0, 1)[..., None]; t2 = np.clip(u * 2.0 - 1.0, 0, 1)[..., None]
    col = a * (1 - t1) + b * t1
    col = col * (1 - t2) + c * t2
    col = col * (0.82 + 0.18 * barbs[..., None]) * (0.94 + 0.06 * fine[..., None])
    rim = np.clip((cx - 0.78) / 0.22, 0, 1) ** 1.5
    col = col * (1 - rim[..., None] * 0.5) + edge * (rim[..., None] * 0.5)
    tipband = np.exp(-((u - 0.90) / 0.05) ** 2) * 0.55                # dark banding near the tip
    col = col * (1 - tipband[..., None]) + edge * tipband[..., None] * 0.9
    col = col + shaft[..., None] * 0.35 * np.array([1.0, 0.92, 0.75])
    height = 0.45 * barbs + 0.2 * fine + 0.1 * grain + 0.9 * shaft
    return dict(albedo=np.clip(col, 0, 1), rough=np.clip(0.70 + 0.10 * barbs - 0.15 * shaft, 0, 1), metal=np.zeros((H, W)), height=height)

def normal_from_height(h, strength=2.0):
    gy, gx = np.gradient(h)
    n = np.dstack((-gx * strength * 8, -gy * strength * 8, np.ones_like(h)))
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return n * 0.5 + 0.5

def img_to_np(img):
    a = np.array(img.pixels[:], dtype=np.float32).reshape(img.size[1], img.size[0], 4); return a
def np_to_img(name, arr, colorspace):
    h, w = arr.shape[:2]
    img = bpy.data.images.new(name, w, h, alpha=False)
    img.colorspace_settings.name = colorspace          # must precede the pixel write or the buffer is reinterpreted
    rgba = np.ones((h, w, 4), dtype=np.float32); rgba[..., :3] = arr[..., :3] if arr.ndim == 3 else arr[..., None]
    img.pixels.foreach_set(rgba.ravel())
    return img
def srgb_to_lin(x): return np.where(x <= 0.04045, x / 12.92, ((x + 0.055) / 1.055) ** 2.4)
def lin_to_srgb(x): return np.where(x <= 0.0031308, x * 12.92, 1.055 * np.power(np.maximum(x, 0), 1 / 2.4) - 0.055)
