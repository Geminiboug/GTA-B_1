# GTB : liste le materiau des yeux et le maillage de chr_corps qui l'utilise (aide a la maquette des personnages).
import bpy

c = bpy.data.objects["chr_corps"]
for i, m in enumerate(c.data.materials):
    print("mat", i, m.name if m else None)
    if m and m.node_tree and m.name.startswith("MI_Eyes"):
        for n in m.node_tree.nodes:
            print("  noeud", n.type, n.name, getattr(n, "image", None) and n.image.name)
            if n.type == "BSDF_PRINCIPLED":
                for k in ("Base Color", "Roughness", "Coat Weight", "Specular IOR Level", "Emission Strength"):
                    if k in n.inputs:
                        print("   ", k, n.inputs[k].default_value if hasattr(n.inputs[k].default_value, "__len__") else n.inputs[k].default_value)
        npoly = sum(1 for p in c.data.polygons if p.material_index == i)
        print("  polygones", npoly)
