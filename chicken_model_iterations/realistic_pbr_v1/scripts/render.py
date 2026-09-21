import bpy, math
from mathutils import Vector
def setup_scene(res=(640, 800)):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.device = 'CPU'
    sc.cycles.use_denoising = False
    sc.render.resolution_x, sc.render.resolution_y = res; sc.render.film_transparent = False
    w = bpy.data.worlds.new('w'); w.use_nodes = True; sc.world = w
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.16, 0.18, 0.24, 1); bg.inputs[1].default_value = 1.0
    for name, loc, energy, size in (('key', (-6, -8, 10), 900, 6), ('fill', (8, -4, 5), 350, 8), ('rim', (2, 9, 8), 700, 6)):
        l = bpy.data.lights.new(name, 'AREA'); l.energy = energy; l.size = size
        o = bpy.data.objects.new(name, l); bpy.context.scene.collection.objects.link(o); o.location = loc
        o.rotation_euler = (Vector((0, 0, 3)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
def render_views(path, target=Vector((0, 0, 3.4)), dist=17, views=(('front', -90), ('side', 0), ('three', -50)), elev=10, lens=60):
    sc = bpy.context.scene
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
    cam.data.lens = lens
    files = []
    for name, az in views:
        a = math.radians(az); e = math.radians(elev)
        cam.location = target + Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))) * dist
        cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
        f = f'{path}_{name}.png'; sc.render.filepath = f; bpy.ops.render.render(write_still=True); files.append(f)
    return files
