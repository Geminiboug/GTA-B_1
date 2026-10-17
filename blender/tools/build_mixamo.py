# GTB : bibliotheque d'animations captees (Mixamo, fournies par Olympe le 17/10/2026, refs/mixamo/*.fbx) reunies dans
# un seul GLB (une action par clip, squelette Mixamo), retargete dans Godot vers le squelette humanoide du jeu
# (godot/assets/animations/bonemap_mixamo.tres), comme les clips Quaternius.
# Lancement : blender -b --python blender/tools/build_mixamo.py -- <dossier fbx> <sortie.glb>
import bpy
import os
import sys

args = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = args[:2]

# nom de fichier -> nom du clip dans le jeu
CLIPS = {
    "Breathing Idle": "MX_Idle_Respire", "Happy Idle": "MX_Idle_Content", "Neutral Idle": "MX_Idle_Neutre",
    "Weight Shift": "MX_Idle_Appui", "Looking Around": "MX_Idle_Regarde",
    "Walking": "MX_Marche", "Female Walk": "MX_Marche_Femme", "Standard Walk": "MX_Marche_Standard",
    "Jogging": "MX_Trot", "Running": "MX_Course", "Fast Run": "MX_Sprint",
    "Start Walking": "MX_Depart", "Stop Walking": "MX_Arret", "Left Turn 90": "MX_Tourne_G90",
    "Right Turn 90": "MX_Tourne_D90", "Walking Turn 180": "MX_DemiTour_Marche", "Running Turn 180": "MX_DemiTour_Course",
    "Talking": "MX_Parle", "Texting While Standing": "MX_Telephone", "Waving": "MX_Salue",
    "Standing Arguing": "MX_Dispute_1", "Standing Arguing (1)": "MX_Dispute_2",
}

bpy.ops.wm.read_factory_settings(use_empty=True)
base = None
for fname, clip in CLIPS.items():
    path = os.path.join(SRC, fname + ".fbx")
    if not os.path.exists(path):
        print("absent :", fname)
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False, ignore_leaf_bones=True)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next((o for o in new if o.type == "ARMATURE"), None)
    if arm is None or arm.animation_data is None or arm.animation_data.action is None:
        print("sans animation :", fname)
        continue
    act = arm.animation_data.action
    act.name = clip
    act.use_fake_user = True
    if base is None:
        base = arm            # premier squelette (avec la peau) : on garde celui-ci
        base.name = "Armature"
        for o in new:
            if o.type == "MESH":
                bpy.data.objects.remove(o, do_unlink=True)
    else:
        for o in new:
            bpy.data.objects.remove(o, do_unlink=True)

# toutes les actions en pistes NLA sur le squelette de base, exportees comme animations separees
base.animation_data.action = None
for act in bpy.data.actions:
    tr = base.animation_data.nla_tracks.new()
    tr.name = act.name
    st = tr.strips.new(act.name, int(act.frame_range[0]), act)
    tr.mute = True
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animations=True, export_animation_mode="NLA_TRACKS",
                          export_nla_strips=True, export_force_sampling=True, export_frame_range=False,
                          export_def_bones=False, export_yup=True)
print("Mixamo :", len(bpy.data.actions), "clips ->", OUT)
