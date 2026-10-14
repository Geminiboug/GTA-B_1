# GTB : personnage humanoide low poly (blockout), fait par script, sans asset externe.
# Lancement : blender -b --python blender/tools/build_character.py -- <sortie.blend> <sortie.glb>
#
# Construction en pieces rigides accrochees a des pivots (Empties) places aux articulations.
# Les animations (idle, marche, course, saut) sont procedurales dans Godot (godot/scripts/character_anim.gd)
# qui tourne ces pivots : pas de squelette a gerer, et remplacable plus tard par un modele Mixamo.
# Orientation : le personnage regarde +Y dans Blender (= -Z, l'avant, dans Godot). Pieds a Z = 0. Taille 1,75 m.
import bpy
import sys

args = sys.argv[sys.argv.index("--") + 1:]
OUT_BLEND, OUT_GLB = args[:2]

bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene


def to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(name, srgb, rough=0.8):
    m = bpy.data.materials.new(name)
    if hasattr(m, "use_nodes"):
        m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        bsdf = nodes.new("ShaderNodeBsdfPrincipled")
        out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
        m.node_tree.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    rgba = [to_linear(c) for c in srgb] + [1.0]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = rgba
    return m


SKIN = material("chr_peau", (0.36, 0.22, 0.15), 0.6)
SHIRT = material("chr_chemise", (0.95, 0.75, 0.10))   # jaune, couleur des zems
PANTS = material("chr_pantalon", (0.18, 0.22, 0.30))
SHOES = material("chr_chaussures", (0.12, 0.10, 0.09))
HAIR = material("chr_cheveux", (0.06, 0.05, 0.05))


def pivot(name, loc, parent=None):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.05
    scene.collection.objects.link(e)
    if parent:
        e.parent = parent
    e.location = loc  # relatif au parent
    return e


def part(name, size, loc, mat, parent, bevel=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.name = name
    ob.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 1
    ob.data.materials.append(mat)
    ob.parent = parent
    ob.location = loc
    return ob


root = pivot("chr_racine", (0, 0, 0))

# Bassin et tronc
hips = pivot("piv_bassin", (0, 0, 0.95), root)
part("chr_bassin", (0.34, 0.2, 0.18), (0, 0, -0.02), PANTS, hips)
spine = pivot("piv_tronc", (0, 0, 0.06), hips)
part("chr_torse", (0.40, 0.22, 0.46), (0, 0, 0.24), SHIRT, spine)
part("chr_cou", (0.12, 0.12, 0.06), (0, 0, 0.49), SKIN, spine)
head = pivot("piv_tete", (0, 0, 0.52), spine)
part("chr_tete", (0.21, 0.23, 0.25), (0, 0.01, 0.13), SKIN, head, bevel=0.03)
part("chr_cheveux", (0.22, 0.22, 0.06), (0, -0.01, 0.255), HAIR, head, bevel=0.02)
part("chr_nez", (0.04, 0.04, 0.05), (0, 0.13, 0.12), SKIN, head, bevel=0)

# Bras (pivot a l'epaule, puis au coude)
for side, sx in (("G", -1), ("D", 1)):
    sh = pivot(f"piv_epaule_{side}", (sx * 0.255, 0, 0.44), spine)
    part(f"chr_manche_{side}", (0.12, 0.13, 0.16), (0, 0, -0.06), SHIRT, sh)
    part(f"chr_bras_{side}", (0.09, 0.09, 0.16), (0, 0, -0.2), SKIN, sh)
    el = pivot(f"piv_coude_{side}", (0, 0, -0.29), sh)
    part(f"chr_avantbras_{side}", (0.085, 0.085, 0.25), (0, 0, -0.12), SKIN, el)
    part(f"chr_main_{side}", (0.08, 0.05, 0.09), (0, 0, -0.29), SKIN, el)

# Jambes (pivot a la hanche, puis au genou)
for side, sx in (("G", -1), ("D", 1)):
    hp = pivot(f"piv_hanche_{side}", (sx * 0.095, 0, -0.06), hips)
    part(f"chr_cuisse_{side}", (0.15, 0.16, 0.44), (0, 0, -0.21), PANTS, hp)
    kn = pivot(f"piv_genou_{side}", (0, 0, -0.43), hp)
    part(f"chr_tibia_{side}", (0.13, 0.14, 0.41), (0, 0, -0.2), PANTS, kn)
    part(f"chr_pied_{side}", (0.11, 0.25, 0.07), (0, 0.05, -0.425), SHOES, kn)

bpy.ops.object.select_all(action="DESELECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print("Personnage :", len([o for o in bpy.data.objects if o.type == "MESH"]), "pieces,",
      len([o for o in bpy.data.objects if o.type == "EMPTY"]), "pivots")
