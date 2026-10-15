# GTB : corps de base "Universal Base Characters" de Quaternius (CC0, refs/ubc/), cale sur nos articulations.
# Utilise par build_character.py : le maillage sculpte (visage, mains, pieds, oreilles) remplace notre corps procedural ;
# chaque os du squelette Quaternius est envoye sur le segment correspondant de nos articulations (longueur reelle,
# epaisseur ramenee a un corps ordinaire : le modele d'origine est "Superhero"), puis la musculature est adoucie.
import bpy
import bmesh
import math
import os
from mathutils import Matrix, Vector

UBC_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "refs", "ubc", "Universal Base Characters[Standard]",
                       "Base Characters", "Godot - UE")
# epaisseur relative (perpendiculaire a l'os) : corps ordinaire au lieu du corps de super-heros
SLIM = {"m": {"pelvis": 0.93, "spine": 0.84, "neck_01": 0.85, "clavicle": 0.82, "upperarm": 0.76, "lowerarm": 0.84,
              "thigh": 0.9, "calf": 0.9, "foot": 1.0},
        "f": {"pelvis": 0.98, "spine": 0.9, "neck_01": 0.9, "clavicle": 0.88, "upperarm": 0.84, "lowerarm": 0.88,
              "thigh": 0.95, "calf": 0.93, "foot": 1.0}}


def _key(bone):
    for k in ("spine", "clavicle", "upperarm", "lowerarm", "thigh", "calf", "foot", "ball"):
        if bone.startswith(k):
            return "foot" if k == "ball" else k
    return bone


def _affine(s0, s1, t0, t1, along, perp):
    """Matrice qui envoie le segment source (s0 -> s1) sur la cible (t0 -> t1) : rotation minimale, echelle 'along'
    le long de l'os, 'perp' en travers."""
    u = (s1 - s0).normalized()
    rot = u.rotation_difference((t1 - t0).normalized()).to_matrix().to_4x4()
    sc = Matrix.Identity(3) * perp
    for i in range(3):
        for j in range(3):
            sc[i][j] += (along - perp) * u[i] * u[j]
    return Matrix.Translation(t0) @ rot @ sc.to_4x4() @ Matrix.Translation(-s0)


def build(sex, targets, scale, girth, scene):
    """Importe le corps Quaternius (sex 'm' / 'f'), le tourne vers +Y et le cale sur targets (os -> (tete, queue)).
    scale : echelle globale (taille), girth : corpulence de la variante. Renvoie (corps, [yeux, sourcils])."""
    path = os.path.join(UBC_DIR, "Superhero_Male_FullBody.gltf" if sex == "m" else "Superhero_Female_FullBody.gltf")
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next(o for o in new if o.type == "ARMATURE")
    meshes = [o for o in new if o.type == "MESH" and o.vertex_groups]
    body = next(o for o in meshes if o.name.lower().startswith("superhero"))
    extras = [o for o in meshes if o is not body]
    # repere : sommets et os en coordonnees monde, puis demi-tour si le personnage regarde -Y
    rest = {b.name: (arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local) for b in arm.data.bones}
    # glTF ne stocke pas la queue des os (Blender en invente une) : queue = tete de l'os enfant de la chaine
    CHILD = {"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "Head"}
    for s in ("l", "r"):
        CHILD.update({f"clavicle_{s}": f"upperarm_{s}", f"upperarm_{s}": f"lowerarm_{s}", f"lowerarm_{s}": f"hand_{s}",
                      f"hand_{s}": f"middle_01_{s}", f"thigh_{s}": f"calf_{s}", f"calf_{s}": f"foot_{s}", f"foot_{s}": f"ball_{s}",
                      f"ball_{s}": f"ball_leaf_{s}"})
    for n, c in CHILD.items():
        if n in rest and c in rest:
            rest[n] = (rest[n][0], rest[c][0])
    eyes = next((o for o in extras if o.name.startswith("Eyes")), None)
    flip = Matrix.Identity(4)
    if eyes:
        ey = sum(((eyes.matrix_world @ v.co).y for v in eyes.data.vertices), 0.0) / len(eyes.data.vertices)
        if ey < rest["Head"][0].y:
            flip = Matrix.Rotation(math.pi, 4, "Z")
    rest = {n: (flip @ h, flip @ t) for n, (h, t) in rest.items()}
    for o in meshes:
        o.data.transform(flip @ o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
        o.parent = None
    top = max(v.co.z for v in body.data.vertices)
    for n in ("pelvis", "spine_03", "Head", "upperarm_l", "hand_l", "thigh_l", "foot_l"):
        print("UBC", n, tuple(round(x, 3) for x in rest[n][0]), tuple(round(x, 3) for x in rest[n][1]), "->", tuple(round(x, 3) for x in targets[n][0]), tuple(round(x, 3) for x in targets[n][1]))
    print("UBC top", top, "flip", flip != Matrix.Identity(4), "zmin", min(v.co.z for v in body.data.vertices))
    # matrices par os
    slim = SLIM[sex]
    mats = {}
    for name, (h, t) in rest.items():
        k = _key(name)
        if name in targets:
            t0, t1 = targets[name]
            ln = max((t - h).length, 1e-4)
            along = (t1 - t0).length / ln
            perp = scale * slim.get(k, 1.0) * girth ** (0.6 if k in ("spine", "pelvis", "thigh", "upperarm") else 0.35)
            mats[name] = _affine(h, t, t0, t1, along, perp)
    # tete : echelle uniforme (crane -> sommet) ; mains et doigts : echelle uniforme, orientation de l'avant-bras
    hh, ht = rest["Head"]
    t0, t1 = targets["Head"]
    hs = (t1.z - t0.z) / max(top - hh.z, 1e-4)
    mats["Head"] = Matrix.Translation(t0) @ Matrix.Scale(hs, 4) @ Matrix.Translation(-hh)
    for s in ("l", "r"):
        lh, lt = rest[f"lowerarm_{s}"]
        f0, f1 = targets[f"lowerarm_{s}"]
        rot = (lt - lh).normalized().rotation_difference((f1 - f0).normalized()).to_matrix().to_4x4()
        wh = rest[f"hand_{s}"][0]
        mats[f"hand_{s}"] = Matrix.Translation(targets[f"hand_{s}"][0]) @ rot @ Matrix.Scale(scale * 0.97, 4) @ Matrix.Translation(-wh)
        for name in rest:
            if name.endswith("_" + s) and any(name.startswith(f) for f in ("index", "middle", "ring", "pinky", "thumb")):
                mats[name] = mats[f"hand_{s}"]
        mats[f"ball_leaf_{s}"] = mats.get(f"ball_{s}", mats[f"foot_{s}"])
    mats.setdefault("root", mats["pelvis"])
    for name in rest:
        mats.setdefault(name, mats["Head"] if name in ("Head",) else mats["pelvis"])
    # habillage lineaire avec les poids d'origine (64 os)
    for o in meshes:
        groups = {g.index: g.name for g in o.vertex_groups}
        for v in o.data.vertices:
            acc = Vector((0, 0, 0))
            tot = 0.0
            for g in v.groups:
                n = groups.get(g.group)
                if n in mats and g.weight > 0.0:
                    acc += (mats[n] @ v.co) * g.weight
                    tot += g.weight
            if tot > 0.0:
                v.co = acc / tot
    # musculature de heros adoucie : lissage laplacien (volume conserve) sur le tronc, les bras et les cuisses
    bm = bmesh.new()
    bm.from_mesh(body.data)
    dl = bm.verts.layers.deform.active
    gname = {g.index: g.name for g in body.vertex_groups}
    soft = []
    for v in bm.verts:
        d = v[dl] if dl else {}
        if not d:
            continue
        main = gname.get(max(d.keys(), key=lambda i: d[i]), "")
        if _key(main) in ("spine", "pelvis", "clavicle", "upperarm", "lowerarm", "thigh", "calf"):
            soft.append(v)
    for _ in range(int(os.environ.get("UBC_SMOOTH", "0"))):
        bmesh.ops.smooth_laplacian_vert(bm, verts=soft, lambda_factor=0.6, lambda_border=0.0,
                                        use_x=True, use_y=True, use_z=True, preserve_volume=True)
    bm.to_mesh(body.data)
    bm.free()
    # nettoyage : plus d'armature Quaternius ni de poids d'origine (build_character recalcule les poids)
    for o in meshes:
        o.vertex_groups.clear()
        for m in list(o.modifiers):
            o.modifiers.remove(m)
    for o in new:
        if o not in meshes:
            bpy.data.objects.remove(o, do_unlink=True)
    # allege pour la foule (budget 70 images/s) : ~4 000 faces au lieu de 12 600, formes et UV conservees
    # la tete garde toute sa definition (visage), seul le corps sous le cou est allege
    vg = body.vertex_groups.new(name="allege")
    neck_z = rest["neck_01"][0].z if "neck_01" in rest else 1.4
    neck_z = (mats["neck_01"] @ rest["neck_01"][0]).z if "neck_01" in mats else neck_z
    vg.add([v.index for v in body.data.vertices if v.co.z < neck_z], 1.0, "REPLACE")
    if float(os.environ.get("UBC_DECIMATE", "1.0")) >= 1.0:
        body.vertex_groups.remove(vg)
        for p in body.data.polygons:
            p.use_smooth = True
        return body, extras
    md = body.modifiers.new("allege", "DECIMATE")
    md.vertex_group = "allege"
    md.ratio = float(os.environ.get("UBC_DECIMATE", "1.0"))
    md.use_symmetry = True
    md.symmetry_axis = "X"
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=md.name)
    body.vertex_groups.remove(body.vertex_groups["allege"])
    for p in body.data.polygons:
        p.use_smooth = True
    return body, extras
