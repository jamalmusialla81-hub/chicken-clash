import bpy, sys, os
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE); os.chdir(os.path.dirname(HERE))
from render import setup_scene, render_views
from mathutils import Vector
blend, prefix = sys.argv[sys.argv.index('--') + 1], sys.argv[sys.argv.index('--') + 2]
bpy.ops.wm.open_mainfile(filepath=os.path.abspath(blend))
setup_scene()
for f in render_views(prefix, target=Vector((0, 0.4, 3.8)), dist=15): print(f)
