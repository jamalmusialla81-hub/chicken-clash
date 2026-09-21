import bpy, sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(ROOT, 'scripts')); os.chdir(os.path.join(ROOT, 'stylised'))
from render import setup_scene, render_views
from mathutils import Vector
bpy.ops.wm.open_mainfile(filepath=os.path.abspath('blend/golden_toon_rigged.blend'))
setup_scene(); 
for o in bpy.data.objects:
    if o.type == 'MESH' and o.name.endswith('_Preview'): o.hide_render = True
render_views('renders/GoldenStylised_combat', target=Vector((0, 0.2, 3.6)), dist=16)
# silhouette: black objects on white
mat = bpy.data.materials.new('sil'); mat.use_nodes = True
n = mat.node_tree.nodes; n.clear(); e = n.new('ShaderNodeEmission'); e.inputs['Color'].default_value = (0, 0, 0, 1); out = n.new('ShaderNodeOutputMaterial'); mat.node_tree.links.new(e.outputs[0], out.inputs[0])
for o in bpy.data.objects:
    if o.type == 'MESH':
        o.data.materials.clear(); o.data.materials.append(mat)
    if o.type == 'LIGHT': o.hide_render = True
bg = bpy.context.scene.world.node_tree.nodes['Background']; bg.inputs[0].default_value = (1, 1, 1, 1); bg.inputs[1].default_value = 1.0
bpy.context.scene.view_settings.view_transform = 'Standard'
render_views('renders/GoldenStylised_silhouette', target=Vector((0, 0.2, 3.6)), dist=16)
