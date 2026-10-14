# GTB : export en un clic vers Godot.
# Blender > onglet Scripting > ouvrir ce fichier > Run Script (ou Alt+P).
# Exporte les objets selectionnes (ou toute la scene si rien n'est selectionne)
# vers godot/assets/models/<nom_du_fichier_blend>.glb
import bpy
import os

blend_path = bpy.data.filepath
if not blend_path:
    raise RuntimeError("Enregistre d'abord le fichier .blend dans le dossier blender/ du depot.")

name = os.path.splitext(os.path.basename(blend_path))[0]
repo = os.path.dirname(blend_path)
while not os.path.isdir(os.path.join(repo, "godot")):
    parent = os.path.dirname(repo)
    if parent == repo:
        raise RuntimeError("Dossier godot/ introuvable : le .blend doit etre dans le depot GTB.")
    repo = parent

out = os.path.join(repo, "godot", "assets", "models", name + ".glb")
os.makedirs(os.path.dirname(out), exist_ok=True)

bpy.ops.export_scene.gltf(
    filepath=out,
    export_format="GLB",
    use_selection=bool(bpy.context.selected_objects),
    export_apply=True,
    export_yup=True,
)
print("Exporte :", out)
