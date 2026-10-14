# GTB : genere blender/materials/lib_materiaux.blend depuis materials.json.
# Chaque materiau est marque comme Asset : visible dans l'Asset Browser de Blender.
# Lancement : blender -b --python blender/tools/build_materials.py -- <materials.json> <sortie.blend>
import bpy
import json
import sys

args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
data = json.load(open(src, encoding="utf-8"))


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


bpy.ops.wm.read_homefile(use_empty=True)
x = 0.0
for name, p in data.items():
    if name.startswith("_"):
        continue
    mat = bpy.data.materials.new(name)
    if hasattr(mat, "use_nodes"):
        mat.use_nodes = True
    nodes = mat.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        # Blender 5 : un nouveau materiau n'a plus forcement de Principled BSDF
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        output.location = (300, 0)
        mat.node_tree.links.new(bsdf.outputs["BSDF"], output.inputs["Surface"])
    rgba = [to_linear(c) for c in p["color"]] + [1.0]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = p.get("roughness", 0.8)
    bsdf.inputs["Metallic"].default_value = p.get("metallic", 0.0)
    if "alpha" in p:
        bsdf.inputs["Alpha"].default_value = p["alpha"]
    mat.diffuse_color = rgba
    mat.use_fake_user = True
    mat.asset_mark()
    # Sphere d'apercu pour voir toute la palette d'un coup
    bpy.ops.mesh.primitive_uv_sphere_add(radius=0.4, location=(x, 0, 0.4))
    sphere = bpy.context.active_object
    sphere.name = "apercu_" + name
    sphere.data.materials.append(mat)
    bpy.ops.object.shade_smooth()
    x += 1.0

bpy.ops.wm.save_as_mainfile(filepath=out)
print("Materiaux :", len(bpy.data.materials), "->", out)
