# GTB : importeur OpenStreetMap maison pour le blockout (remplace Blender-OSM).
# Donnees OSM : Â© les contributeurs d'OpenStreetMap, licence ODbL.
#
# Lancement :
#   blender -b --python blender/tools/osm_import.py -- <fichier.osm> <lib_materiaux.blend> <sortie.blend> <sortie.glb>
#
# Genere : sol (terre ferme) avec collision, mer, plage, zones (herbe, eau, piscines, parkings),
# routes en rubans, piste et taxiways, batiments extrudes avec collision, murs d'enceinte.
# Repere : origine au centre de la zone, X = est, Y = nord, 1 unite = 1 metre.
import bpy
import math
import os
import sys
import xml.etree.ElementTree as ET
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

args = sys.argv[sys.argv.index("--") + 1:]
OSM, MATLIB, OUT_BLEND, OUT_GLB = args[:4]
OVERTURE = args[4] if len(args) > 4 and args[4] != "-" else None  # optionnel : batiments Overture (GeoJSON)
LITTORAL = args[5] if len(args) > 5 and args[5] != "-" else None  # optionnel : trait de cote + limite de plage (GeoJSON Sentinel-2)
OUT_JSON = args[6] if len(args) > 6 else None  # optionnel : donnees de la zone pour Godot (routes, batiments, ...)
HEIGHTS = args[7] if len(args) > 7 and args[7] != "-" else None  # optionnel : grille Open Buildings 2.5D (ob25d_grille.py)
TILES_DIR = args[8] if len(args) > 8 and args[8] != "-" else None  # optionnel : un .glb par tuile (chargement par morceaux)

import json
import zlib


def stable_hash(s, mod=100):
    """Hasard stable d'un import a l'autre (meme id -> meme resultat)."""
    return zlib.crc32(str(s).encode()) % mod

# ---------- Reglages ----------
ROAD_WIDTH = {
    "primary": 14.0, "secondary": 10.0, "tertiary": 8.0, "residential": 6.0,
    "unclassified": 6.0, "service": 4.0, "living_street": 5.0, "track": 3.0,
    "footway": 2.0, "path": 1.5, "pedestrian": 4.0,
}
# Couches au sol presque a plat (quelques mm au-dessus du sol physique z = 0) : joueur, vehicules et pietons
# posent les pieds sur la chaussee au lieu de s'y enfoncer. L'ordre d'affichage des couches est garanti par
# sol.gdshader (petit decalage de profondeur proportionnel a la hauteur), pas par l'ecart en metres.
ROAD_Z = {"primary": 0.024, "secondary": 0.022, "tertiary": 0.02}
ROAD_Z_DEFAULT = 0.018
MARK_DZ = 0.003
# Chaussees separees (deux sens uniques paralleles) : largeur deduite de l'ecart entre les deux axes
ONEWAY_WIDTH = {"primary": 9.0, "secondary": 7.5, "tertiary": 7.0}
MEDIAN_H = 0.12
AEROWAY_WIDTH = {"runway": 45.0, "stopway": 45.0, "taxiway": 23.0}
WALL = {"wall": (0.2, 2.2), "fence": (0.1, 1.8)}
LEVEL_H = 3.0
# noms de rue reels (tags OSM) -> noms fictifs affiches en jeu (docs/correspondance_noms.md)
NOM_FICTIF = {"Avenue Pape Jean-Paul II": "Boulevard de l'Envol", "Route des Pêches": "Route des Filets",
              "Carrefour Plage de Fidjrossé": "Carrefour Plage de Fidjrossa"}
SEA_EXTRA = 400.0
# Front de mer apres l'amenagement de la Route des Peches (travaux depuis 2023) :
# plage continue depuis la mer, puis promenade pietonne et piste cyclable.
# Largeurs estimees d'apres la carte OSM et la description publique du projet, pas un releve exact.
BEACH_W = 90.0
PROMENADE_W = 8.0
BIKE_W = 3.0
# Pente de la plage (phase 12) : le haut de plage est plat, l'estran descend sur les FORESHORE derniers metres jusqu'a
# FORESHORE_DROP sous le niveau de la terre au trait de cote (l'eau est a -0.3), puis le fond continue a descendre
# sous la mer (profil des plages sableuses du golfe de Guinee : estran court et raide, houle forte).
FORESHORE = 40.0
FORESHORE_DROP = 0.8
SEABED_SLOPE = 0.035

# ---------- Lecture OSM ----------
root = ET.parse(OSM).getroot()
b = root.find("bounds")
minlat, minlon = float(b.get("minlat")), float(b.get("minlon"))
maxlat, maxlon = float(b.get("maxlat")), float(b.get("maxlon"))
# origine figee au centre de la premiere zone (aeroport, bounds 6.34638-6.353365 / 2.375259-2.3875) : agrandir la
# zone (phase 9, Cadjehoun - Haie Vive au nord) ne deplace rien de ce qui existe deja dans le jeu
lat0, lon0 = 6.3498725, 2.3813795
KX = 111320.0 * math.cos(math.radians(lat0))
KY = 110540.0


def proj(lat, lon):
    return ((lon - lon0) * KX, (lat - lat0) * KY)


XMIN, YMIN = proj(minlat, minlon)
XMAX, YMAX = proj(maxlat, maxlon)

nodes = {n.get("id"): proj(float(n.get("lat")), float(n.get("lon"))) for n in root.iter("node")}


def tags_of(e):
    return {t.get("k"): t.get("v") for t in e.findall("tag")}


ways = {}
for w in root.iter("way"):
    refs = [nd.get("ref") for nd in w.findall("nd")]
    pts = [nodes[r] for r in refs if r in nodes]
    ways[w.get("id")] = {"pts": pts, "closed": len(refs) > 3 and refs[0] == refs[-1], "tags": tags_of(w)}


# ---------- Geometrie 2D ----------
def area(poly):
    return sum(poly[i][0] * poly[(i + 1) % len(poly)][1] - poly[(i + 1) % len(poly)][0] * poly[i][1] for i in range(len(poly))) / 2


def ccw(poly):
    return poly if area(poly) > 0 else poly[::-1]


def clean(poly):
    out = []
    for p in poly:
        if not out or (abs(p[0] - out[-1][0]) > 0.01 or abs(p[1] - out[-1][1]) > 0.01):
            out.append(p)
    if len(out) > 1 and abs(out[0][0] - out[-1][0]) < 0.01 and abs(out[0][1] - out[-1][1]) < 0.01:
        out.pop()
    return out


def clip_poly(poly, ymin=None):
    """Sutherland-Hodgman sur le rectangle de la zone (ymin permet d'etendre vers le sud)."""
    y_lo = YMIN if ymin is None else ymin
    def clip(pts, inside, inter):
        out = []
        for i in range(len(pts)):
            cur, prev = pts[i], pts[i - 1]
            if inside(cur):
                if not inside(prev):
                    out.append(inter(prev, cur))
                out.append(cur)
            elif inside(prev):
                out.append(inter(prev, cur))
        return out

    def ix(x):
        return lambda a, c: (x, a[1] + (c[1] - a[1]) * (x - a[0]) / (c[0] - a[0]))

    def iy(y):
        return lambda a, c: (a[0] + (c[0] - a[0]) * (y - a[1]) / (c[1] - a[1]), y)

    for inside, inter in (
        (lambda p: p[0] >= XMIN, ix(XMIN)), (lambda p: p[0] <= XMAX, ix(XMAX)),
        (lambda p: p[1] >= y_lo, iy(y_lo)), (lambda p: p[1] <= YMAX, iy(YMAX)),
    ):
        if not poly:
            break
        poly = clip(poly, inside, inter)
    return clean(poly)


def inside_box(p):
    return XMIN <= p[0] <= XMAX and YMIN <= p[1] <= YMAX


def clip_line(pts):
    """Decoupe une polyligne au rectangle (Liang-Barsky par segment). Renvoie une liste de morceaux."""
    pieces, cur = [], []
    for a, c in zip(pts, pts[1:]):
        t0, t1 = 0.0, 1.0
        dx, dy = c[0] - a[0], c[1] - a[1]
        ok = True
        for p, q in ((-dx, a[0] - XMIN), (dx, XMAX - a[0]), (-dy, a[1] - YMIN), (dy, YMAX - a[1])):
            if p == 0:
                if q < 0:
                    ok = False
                    break
            else:
                t = q / p
                if p < 0:
                    t0 = max(t0, t)
                else:
                    t1 = min(t1, t)
        if not ok or t0 > t1:
            if len(cur) > 1:
                pieces.append(cur)
            cur = []
            continue
        s = (a[0] + t0 * dx, a[1] + t0 * dy)
        e = (a[0] + t1 * dx, a[1] + t1 * dy)
        if not cur:
            cur = [s]
        cur.append(e)
        if t1 < 1.0:
            pieces.append(cur)
            cur = []
    if len(cur) > 1:
        pieces.append(cur)
    return pieces


def ribbon(pts, width):
    """Polyligne -> rectangles joints (sommets, faces) a plat."""
    h = width / 2
    n = len(pts)
    left, right = [], []
    for i in range(n):
        if i == 0:
            dx, dy = pts[1][0] - pts[0][0], pts[1][1] - pts[0][1]
        elif i == n - 1:
            dx, dy = pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1]
        else:
            ax, ay = pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]
            bx, by = pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]
            la, lb = math.hypot(ax, ay) or 1, math.hypot(bx, by) or 1
            dx, dy = ax / la + bx / lb, ay / la + by / lb
        l = math.hypot(dx, dy) or 1
        nx, ny = -dy / l, dx / l
        # facteur d'onglet limite pour eviter les pointes
        scale = 1.0
        if 0 < i < n - 1:
            bx, by = pts[i + 1][0] - pts[i][0], pts[i + 1][1] - pts[i][1]
            lb = math.hypot(bx, by) or 1
            cosang = abs(nx * (-by / lb) + ny * (bx / lb))
            scale = min(1.0 / max(cosang, 0.3), 3.0)
        left.append((pts[i][0] + nx * h * scale, pts[i][1] + ny * h * scale))
        right.append((pts[i][0] - nx * h * scale, pts[i][1] - ny * h * scale))
    verts = left + right
    faces = [(i + n, i + n + 1, i + 1, i) for i in range(n - 1)]  # normales vers le haut
    return verts, faces


# ---------- Construction Blender ----------
bpy.ops.wm.read_homefile(use_empty=True)
scene = bpy.context.scene

with bpy.data.libraries.load(MATLIB, link=False) as (src, dst):
    dst.materials = [m for m in src.materials if m.startswith("mat_")]
MAT = {m.name: m for m in bpy.data.materials}
for m in MAT.values():
    m.asset_clear() if m.asset_data else None

COLS = {}


def col(name):
    if name not in COLS:
        c = bpy.data.collections.new(name)
        scene.collection.children.link(c)
        COLS[name] = c
    return COLS[name]


def make_obj(name, verts, faces, mat, collection):
    me = bpy.data.meshes.new(name)
    me.from_pydata([v if len(v) == 3 else (v[0], v[1], 0.0) for v in verts], [], faces)
    me.validate(clean_customdata=False)
    me.update()
    me.materials.append(MAT[mat])
    ob = bpy.data.objects.new(name, me)
    col(collection).objects.link(ob)
    return ob


class Batch:
    """Regroupe plusieurs morceaux de meme materiau dans un seul objet."""

    def __init__(self):
        self.verts, self.faces = [], []

    def add(self, verts, faces):
        o = len(self.verts)
        self.verts += verts
        self.faces += [tuple(i + o for i in f) for f in faces]


def triangulate(poly):
    """Triangles orientes vers le haut ; fiable meme pour les grands polygones concaves."""
    tris = tessellate_polygon([[Vector((x, y, 0.0)) for x, y in poly]])
    return [t if area([poly[i] for i in t]) > 0 else t[::-1] for t in tris]


def flat(poly, z):
    return [(x, y, z) for x, y in poly], triangulate(poly)


def prism(poly, z0, z1):
    poly = ccw(poly)
    n = len(poly)
    verts = [(x, y, z0) for x, y in poly] + [(x, y, z1) for x, y in poly]
    top = triangulate(poly)
    faces = [t[::-1] for t in top] + [tuple(i + n for i in t) for t in top]
    faces += [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    return verts, faces


TILE = 500.0   # m : maillages decoupes en tuiles (Godot ignore celles hors champ et simplifie les lointaines)


def batch_obj(name, batch, mat, collection, z):
    if not batch.faces:
        return None
    verts = [(v[0], v[1], z) if len(v) == 2 else v for v in batch.verts]
    # une tuile par carre de 500 m (selon le centre de chaque face) ; le suffixe -col reste a la fin du nom
    tiles = {}
    for f in batch.faces:
        cx = sum(verts[i][0] for i in f) / len(f)
        cy = sum(verts[i][1] for i in f) / len(f)
        tiles.setdefault((int(math.floor(cx / TILE)), int(math.floor(cy / TILE))), []).append(f)
    if len(tiles) == 1:
        return make_obj(name, verts, batch.faces, mat, collection)
    base, suffix = (name[:-4], "-col") if name.endswith("-col") else ((name[:-8], "-colonly") if name.endswith("-colonly") else (name, ""))
    last = None
    for (tx, ty), faces in sorted(tiles.items()):
        used = sorted({i for f in faces for i in f})
        remap = {old: k for k, old in enumerate(used)}
        last = make_obj("%s_t%d_%d%s" % (base, tx, ty, suffix), [verts[i] for i in used],
                        [[remap[i] for i in f] for f in faces], mat, collection)
    return last


# --- Multipolygones (plage, zone humide...) : on recoud les anneaux exterieurs ---
def stitch(segments):
    rings, segs = [], [s[:] for s in segments if len(s) > 1]
    while segs:
        ring = segs.pop(0)
        changed = True
        while changed and ring[0] != ring[-1]:
            changed = False
            for s in segs:
                if s[0] == ring[-1]:
                    ring += s[1:]
                elif s[-1] == ring[-1]:
                    ring += s[::-1][1:]
                elif s[-1] == ring[0]:
                    ring = s[:-1] + ring
                elif s[0] == ring[0]:
                    ring = s[::-1][:-1] + ring
                else:
                    continue
                segs.remove(s)
                changed = True
                break
        rings.append(ring)
    return rings


areas = []  # (tags, polygone)
for w in ways.values():
    if w["closed"] and len(w["pts"]) > 2:
        areas.append((w["tags"], w["pts"]))
for r in root.iter("relation"):
    t = tags_of(r)
    if t.get("type") != "multipolygon":
        continue
    outers = [ways[m.get("ref")]["pts"] for m in r.findall("member")
              if m.get("type") == "way" and m.get("role") == "outer" and m.get("ref") in ways]
    for ring in stitch(outers):
        if len(ring) > 3:
            areas.append((t, ring))


# --- Sol et mer a partir du trait de cote ---
def perim_t(p):
    """Position sur le contour du rectangle, sens horaire depuis le coin nord-ouest."""
    w, h = XMAX - XMIN, YMAX - YMIN
    x, y = p
    if abs(y - YMAX) < 0.5:
        return x - XMIN
    if abs(x - XMAX) < 0.5:
        return w + (YMAX - y)
    if abs(y - YMIN) < 0.5:
        return w + h + (XMAX - x)
    return 2 * w + h + (y - YMIN)


CORNERS = [(0.0, (XMIN, YMAX))]
CORNERS += [(XMAX - XMIN, (XMAX, YMAX)), ((XMAX - XMIN) + (YMAX - YMIN), (XMAX, YMIN)),
            (2 * (XMAX - XMIN) + (YMAX - YMIN), (XMIN, YMIN))]
PERIM = 2 * ((XMAX - XMIN) + (YMAX - YMIN))


def walk_cw(t_from, t_to):
    """Coins rencontres en tournant dans le sens horaire de t_from a t_to."""
    out, span = [], (t_to - t_from) % PERIM
    for tc, c in sorted(CORNERS, key=lambda k: (k[0] - t_from) % PERIM):
        if 0 < (tc - t_from) % PERIM < span:
            out.append(c)
    return out


coast = None
for w in ways.values():
    if w["tags"].get("natural") == "coastline" and len(w["pts"]) > 1:
        if coast is None or len(w["pts"]) > len(coast):
            coast = w["pts"]

# Trait de cote et limite de plage mesures sur image Sentinel-2 (plus recents qu'OSM)
beach_inner = None
if LITTORAL:
    import json
    for f in json.load(open(LITTORAL, encoding="utf-8"))["features"]:
        line = [proj(lat, lon) for lon, lat in f["geometry"]["coordinates"]]
        if f["properties"]["name"] == "trait_de_cote":
            coast = line
        elif f["properties"]["name"] == "limite_plage":
            beach_inner = line

def offset_line(pts, d):
    """Decale une polyligne de d metres vers la gauche (cote terre pour un trait de cote OSM)."""
    out = []
    for i in range(len(pts)):
        a, c = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dx, dy = c[0] - a[0], c[1] - a[1]
        l = math.hypot(dx, dy) or 1
        out.append((pts[i][0] - dy / l * d, pts[i][1] + dx / l * d))
    return out


land_poly = [(XMIN, YMIN), (XMAX, YMIN), (XMAX, YMAX), (XMIN, YMAX)]
sea_poly = None
if coast:
    s, e = coast[0], coast[-1]
    FAR = 5000.0
    if min(s[0], e[0]) <= XMIN and max(s[0], e[0]) >= XMAX:
        # Cote qui traverse toute la zone d'ouest en est (cas de Cotonou).
        # OSM : terre a gauche du sens du trait, mer a droite.
        sea_y = -FAR if s[0] < e[0] else FAR
        # la mer deborde de SEA_EXTRA metres au sud du cadre pour voir l'ocean depuis la plage
        sea_poly = clip_poly(clean(coast + [(e[0], sea_y), (s[0], sea_y)]), ymin=YMIN - SEA_EXTRA)
        land_poly = clip_poly(clean(offset_line(coast, FORESHORE) + [(e[0], -sea_y), (s[0], -sea_y)]))
    else:
        piece = max(clip_line(coast), key=len)
        ps, pe = piece[0], piece[-1]
        sea_poly = clean(piece + walk_cw(perim_t(pe), perim_t(ps)))
        land_poly = clean(piece[::-1] + walk_cw(perim_t(ps), perim_t(pe)))

make_obj("sol_terre-col", *flat(ccw(land_poly), 0.0), "mat_terre_rouge", "Sol")
if sea_poly:
    sv, sf = flat(ccw(sea_poly), -0.3)
    make_obj("mer", sv, sf, "mat_eau", "Sol")
    # fond marin pour ne pas voir le vide sous l'eau
    fv, ff = flat(ccw(sea_poly), -3.0)
    make_obj("fond_marin", fv, ff, "mat_sable", "Sol")

# --- Front de mer : plage continue, promenade, piste cyclable ---
def coast_y_at(x, line=None):
    """Ordonnee d'une ligne orientee ouest -> est (par defaut le trait de cote) a l'abscisse x."""
    line = line or coast
    pts = line if line[0][0] < line[-1][0] else line[::-1]
    for a, c in zip(pts, pts[1:]):
        if a[0] <= x <= c[0]:
            return a[1] + (c[1] - a[1]) * (x - a[0]) / ((c[0] - a[0]) or 1)
    return pts[0][1] if x < pts[0][0] else pts[-1][1]


WATERFRONT = BEACH_W + PROMENADE_W + BIKE_W + 2.0


def on_waterfront(x, y):
    if coast is None:
        return False
    if beach_inner:
        return y < coast_y_at(x, beach_inner) + PROMENADE_W + BIKE_W + 2.0
    return y < coast_y_at(x) + WATERFRONT


if coast:
    # limite de plage mesuree si disponible, sinon largeur estimee
    beach_edge = beach_inner or offset_line(coast, BEACH_W)
    band = clip_poly(clean(offset_line(coast, FORESHORE) + beach_edge[::-1]), ymin=YMIN - SEA_EXTRA)
    # estran en pente (avec collision) : du haut de l'estran (z 0) au trait de cote, puis sous l'eau
    rows = [FORESHORE, 30.0, 20.0, 12.0, 6.0, 0.0, -10.0, -25.0, -45.0]
    def shore_z(d):
        if d >= 0.0:
            return -FORESHORE_DROP * (1.0 - d / FORESHORE) ** 1.4
        return -FORESHORE_DROP + d * SEABED_SLOPE
    pts = [q for q in coast if XMIN - 60.0 <= q[0] <= XMAX + 60.0]
    lines = [offset_line(pts, d) for d in rows]
    sv, sfc = [], []
    for r, d in enumerate(rows):
        for q in lines[r]:
            sv.append((q[0], q[1], shore_z(d)))
    n = len(pts)
    for r in range(len(rows) - 1):
        for i in range(n - 1):
            a, b = r * n + i, r * n + i + 1
            c, e2 = (r + 1) * n + i + 1, (r + 1) * n + i
            sfc.append((a, e2, c, b))
    if sfc:
        a0, b0, c0 = sv[sfc[0][0]], sv[sfc[0][1]], sv[sfc[0][2]]
        nz = (b0[0] - a0[0]) * (c0[1] - a0[1]) - (b0[1] - a0[1]) * (c0[0] - a0[0])
        if nz < 0:
            sfc = [f[::-1] for f in sfc]   # normales vers le haut
    make_obj("plage_estran-col", sv, sfc, "mat_sable", "Sol")
    if len(band) > 2:
        make_obj("plage_front_de_mer", *flat(ccw(band), 0.004), "mat_sable", "Zones")
    for name, d, w, mat, z in (("promenade", BEACH_W + PROMENADE_W / 2, PROMENADE_W, "mat_paves", 0.016),
                               ("piste_cyclable", BEACH_W + PROMENADE_W + BIKE_W / 2, BIKE_W, "mat_peinture_vert", 0.017)):
        bt = Batch()
        base, dd = (beach_inner, d - BEACH_W) if beach_inner else (coast, d)
        for piece in clip_line(offset_line(base, dd)):
            if len(piece) > 1:
                bt.add(*ribbon(piece, w))
        batch_obj(name, bt, mat, "Front de mer", z)

# --- Zones au sol ---
ZONE_RULES = [
    (lambda t: t.get("natural") == "beach" or t.get("surface") == "sand", "mat_sable", 0.004, "zone_plage"),
    (lambda t: t.get("natural") == "wetland", "mat_vegetation", 0.006, "zone_humide"),
    (lambda t: t.get("landuse") in ("grass", "meadow") or t.get("leisure") in ("park", "garden"), "mat_vegetation", 0.007, "zone_herbe"),
    (lambda t: t.get("aeroway") == "apron", "mat_beton", 0.01, "aeroport_tarmac"),
    (lambda t: t.get("amenity") in ("parking", "motorcycle_parking") and "building" not in t, "mat_bitume", 0.012, "zone_parking"),
    (lambda t: t.get("natural") == "water", "mat_eau", 0.008, "zone_eau"),
    (lambda t: t.get("leisure") == "swimming_pool", "mat_eau", 0.009, "zone_piscine"),
]
zone_batches = {}
zone_data = []  # pour la carte du jeu (mini-carte)
zone_polys = []  # contours (repere Blender) : la concession du joueur ne doit en recouvrir aucun (piscine, parking...)
for t, poly in areas:
    if "building" in t:
        continue
    for rule, mat, z, name in ZONE_RULES:
        if rule(t):
            p = clip_poly(clean(poly))
            if len(p) > 2:
                zone_batches.setdefault((name, mat, z), Batch()).add(*flat(ccw(p), z))
                zone_data.append({"kind": name, "pts": [[round(q[0], 2), round(-q[1], 2)] for q in p]})
                zone_polys.append(p)
            break
for (name, mat, z), bt in zone_batches.items():
    batch_obj(name, bt, mat, "Zones", z)
# margelles des piscines (dalles claires) et bordures beton des bassins de retention : l'eau n'est plus un aplat au sol
rims = {}
for t, poly in areas:
    if "building" in t:
        continue
    kind = "piscine" if t.get("leisure") == "swimming_pool" else ("bassin" if t.get("natural") == "water" else None)
    if kind is None:
        continue
    p = ccw(clip_poly(clean(poly)))
    if len(p) < 3:
        continue
    w, hgt = (0.4, 0.12) if kind == "piscine" else (0.8, 0.35)
    for i in range(len(p)):
        a, c = p[i], p[(i + 1) % len(p)]
        L = math.hypot(c[0] - a[0], c[1] - a[1])
        if L < 0.05:
            continue
        nx, ny = (c[1] - a[1]) / L, -(c[0] - a[0]) / L        # normale exterieure (contour anti-horaire)
        ex, ey = (c[0] - a[0]) / L * w, (c[1] - a[1]) / L * w  # prolonge aux angles
        quad = [(a[0] - ex, a[1] - ey), (c[0] + ex, c[1] + ey),
                (c[0] + ex + nx * w, c[1] + ey + ny * w), (a[0] - ex + nx * w, a[1] - ey + ny * w)]
        rims.setdefault(kind, Batch()).add(*prism(quad, 0.0, hgt))
for kind, bt in rims.items():
    batch_obj("margelle_piscine" if kind == "piscine" else "bordure_bassin-col", bt,
              "mat_peinture_blanc" if kind == "piscine" else "mat_beton", "Zones", 0.0)

# --- Routes, piste, taxiways ---
def tag_width(t, default):
    try:
        return float(t.get("width", "").split()[0])
    except (ValueError, IndexError):
        return default


def road_surface(hw, t, wid):
    """Revetement : tag OSM si present, sinon repartition realiste pour Cotonou
    (grands axes bitumes, rues de quartier souvent pavees ou en sable)."""
    s = t.get("surface", "")
    if s == "asphalt":
        return "bitume"
    if s in ("paving_stones", "sett", "concrete", "concrete:plates", "unhewn_cobblestone"):
        return "paves"
    if s in ("sand", "unpaved", "dirt", "ground", "earth", "compacted", "gravel", "fine_gravel"):
        return "terre"
    r = stable_hash("route" + str(wid))
    if hw in ("primary", "trunk"):
        return "bitume"
    # axes secondaires et tertiaires : souvent en paves autobloquants (Voie de Fidjrosse, refs/rues/, audit Cotonou)
    if hw == "secondary":
        return "paves" if r < 30 else "bitume"
    if hw == "tertiary":
        return "paves" if r < 60 else "bitume"
    if hw in ("footway", "path", "pedestrian"):
        return "paves"
    if hw == "track":
        return "terre"
    if hw in ("residential", "unclassified", "living_street"):
        return "paves" if r < 45 else ("terre" if r < 75 else "bitume")
    if hw == "service":
        return "terre" if r < 55 else ("paves" if r < 80 else "bitume")
    return "bitume"


def dashes(pts, on, off):
    """Decoupe une polyligne en tirets (on metres traces, off metres vides)."""
    out, cur, state_on, remain = [], [pts[0]], True, on
    for a, b in zip(pts, pts[1:]):
        seg = math.hypot(b[0] - a[0], b[1] - a[1])
        pos = 0.0
        while seg - pos > remain:
            pos += remain
            p = (a[0] + (b[0] - a[0]) * pos / seg, a[1] + (b[1] - a[1]) * pos / seg)
            if state_on:
                cur.append(p)
                out.append(cur)
                cur = []
            else:
                cur = [p]
            state_on = not state_on
            remain = on if state_on else off
        remain -= seg - pos
        if state_on:
            cur.append(b)
    if state_on and len(cur) > 1:
        out.append(cur)
    return out


SURFACE_MAT = {"bitume": "mat_bitume", "paves": "mat_paves", "terre": "mat_sable"}
SURFACE_DZ = {"bitume": 0.0, "paves": -0.001, "terre": -0.002}
NOT_CAR = ("footway", "path", "pedestrian", "steps")
line_batches = {}
marking_batches = {}
road_data = []
runway_data = []


def add_marking(name, mat, z, piece, width):
    if len(piece) > 1:
        marking_batches.setdefault((name, mat, z), Batch()).add(*ribbon(piece, width))


def seg_dist(p, a, c):
    dx, dy = c[0] - a[0], c[1] - a[1]
    l2 = dx * dx + dy * dy or 1e-9
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)


def line_dist(p, pts):
    return min(seg_dist(p, a, c) for a, c in zip(pts, pts[1:]))


def closest_on_line(p, pts):
    best, bq = 1e18, None
    for a, c in zip(pts, pts[1:]):
        dx, dy = c[0] - a[0], c[1] - a[1]
        l2 = dx * dx + dy * dy or 1e-9
        t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2))
        q = (a[0] + t * dx, a[1] + t * dy)
        d = math.hypot(p[0] - q[0], p[1] - q[1])
        if d < best:
            best, bq = d, q
    return bq, best


def resample(pts, step):
    """Points tous les 'step' metres le long d'une polyligne (extremites incluses)."""
    out = [pts[0]]
    acc = 0.0
    for a, c in zip(pts, pts[1:]):
        seg = math.hypot(c[0] - a[0], c[1] - a[1])
        pos = step - acc
        while pos < seg:
            out.append((a[0] + (c[0] - a[0]) * pos / seg, a[1] + (c[1] - a[1]) * pos / seg))
            pos += step
        acc = (acc + seg) % step
    out.append(pts[-1])
    return out


def at_border(p, m=0.5):
    return not (XMIN + m < p[0] < XMAX - m and YMIN + m < p[1] < YMAX - m)


def disc(cx, cy, r, n=14):
    return [(cx + r * math.cos(i / n * math.tau), cy + r * math.sin(i / n * math.tau)) for i in range(n)]


def cut_waterfront(pts):
    """Rues tracees avant l'amenagement du front de mer : elles continuaient sur ce qui est aujourd'hui la plage.
    On les arrete au bord de la piste cyclable (cote terre) ; elles debouchent sur la promenade."""
    if coast is None:
        return [pts]
    pieces, cur = [], []
    for k, p in enumerate(pts):
        if not on_waterfront(*p):
            if cur == [] and k > 0:
                cur.append(edge_cross(pts[k - 1], p))
            cur.append(p)
        else:
            if cur:
                cur.append(edge_cross(cur[-1], p))
                pieces.append(cur)
                cur = []
    if cur:
        pieces.append(cur)
    return [c for c in pieces if len(c) > 1]


def edge_cross(land, sea):
    """Point de passage terre -> front de mer sur le segment (dichotomie)."""
    a, b = land, sea
    if on_waterfront(*a):
        a, b = b, a
    for _ in range(20):
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if on_waterfront(*m):
            b = m
        else:
            a = m
    return a


nb_cut = 0
# --- 1) Morceaux de routes (decoupes au cadre de la zone et au front de mer) ---
road_pieces = []
for wid, w in ways.items():
    t = w["tags"]
    hw = t.get("highway")
    if hw not in ROAD_WIDTH or (w["closed"] and t.get("area") == "yes"):
        continue
    raw = clip_line(w["pts"])
    clipped = []
    for piece in raw:
        cut = cut_waterfront(piece)
        if len(cut) != 1 or len(cut[0]) != len(piece):
            nb_cut += 1
        clipped += cut
    for piece in clipped:
        piece = clean(piece) if not w["closed"] else piece
        if len(piece) < 2:
            continue
        L = sum(math.hypot(c[0] - a[0], c[1] - a[1]) for a, c in zip(piece, piece[1:]))
        if L < 6.0 and (at_border(piece[0]) or at_border(piece[-1])):
            continue  # bout de rue coupe par le cadre : une simple tache de bitume au bord de la carte
        road_pieces.append({"wid": wid, "hw": hw, "t": t, "pts": piece, "L": L, "closed": w["closed"],
                            "oneway": t.get("oneway") == "yes", "width": tag_width(t, ROAD_WIDTH[hw]),
                            "surf": road_surface(hw, t, wid),
                            "bb": (min(p[0] for p in piece), min(p[1] for p in piece),
                                   max(p[0] for p in piece), max(p[1] for p in piece))})


def bb_near(a, b, m):
    return a[0] - m <= b[2] and b[0] - m <= a[2] and a[1] - m <= b[3] and b[1] - m <= a[3]

# --- 2) Chaussees separees : OSM dessine les boulevards comme deux sens uniques paralleles. La largeur par
# defaut (route a double sens) les faisait se chevaucher : on la deduit de l'ecart entre les deux axes. ---
def lanes_width(t):
    try:
        return int(t.get("lanes", "")) * 3.5 + 0.5
    except ValueError:
        return None


twins = []
for i, r in enumerate(road_pieces):
    if not r["oneway"] or r["hw"] not in ONEWAY_WIDTH or "width" in r["t"]:
        continue
    base = lanes_width(r["t"]) or ONEWAY_WIDTH[r["hw"]]
    if r["closed"]:
        r["width"] = base  # rond-point
        continue
    samples = resample(r["pts"], 10.0)
    best = None
    for j, s in enumerate(road_pieces):
        if j == i or not s["oneway"] or s["hw"] not in ONEWAY_WIDTH or s["closed"] or not bb_near(r["bb"], s["bb"], 25.0):
            continue
        ds = [line_dist(p, s["pts"]) for p in samples]
        close = sorted(d for d in ds if 4.0 < d < 25.0)
        if len(close) >= max(2, len(ds) // 2):
            med = close[len(close) // 2]
            if best is None or med < best[0]:
                best = (med, j)
    if best:
        r["width"] = max(5.5, min(10.5, base, best[0] - 1.6))
        if i < best[1]:
            twins.append((i, best[1]))
    else:
        r["width"] = base  # bretelle : une chaussee a sens unique

# --- 2b) Rues qui s'arretent quelques metres avant une autre (trace anterieur aux travaux, ex. le long de la
# nouvelle Route des Peches) : on les prolonge jusqu'a l'axe de la rue qu'elles visaient, pour un vrai carrefour ---
def _ekey(p):
    return (round(p[0], 1), round(p[1], 1))


ends = {}
for r in road_pieces:
    for k, p in enumerate(r["pts"]):
        ends[_ekey(p)] = ends.get(_ekey(p), 0) + (1 if k in (0, len(r["pts"]) - 1) else 2)
joined = set()
nb_ext = 0
for r in road_pieces:
    if r["hw"] in NOT_CAR or r["closed"]:
        continue
    for which in (0, -1):
        p = r["pts"][which]
        if ends.get(_ekey(p), 0) != 1 or at_border(p, 2.0):
            continue
        prev = r["pts"][1] if which == 0 else r["pts"][-2]
        L = math.hypot(p[0] - prev[0], p[1] - prev[1]) or 1
        d = ((p[0] - prev[0]) / L, (p[1] - prev[1]) / L)
        best = None
        for s in road_pieces:
            if s is r or s["hw"] in NOT_CAR:
                continue
            q, dist = closest_on_line(p, s["pts"])
            if 0.3 < dist < 14.0:
                v = ((q[0] - p[0]) / dist, (q[1] - p[1]) / dist)
                if v[0] * d[0] + v[1] * d[1] > 0.7 and (best is None or dist < best[1]):
                    best = (q, dist)
        if best:
            if which == 0:
                r["pts"].insert(0, best[0])
            else:
                r["pts"].append(best[0])
            joined.add(_ekey(best[0]))
            nb_ext += 1

car_lines = [(r["pts"], r["width"] / 2) for r in road_pieces if r["hw"] not in NOT_CAR]

# --- 3) Rubans de chaussee, bas-cotes, marquage, bouts d'impasse arrondis ---
end_count = {}
for r in road_pieces:
    for p in (r["pts"][0], r["pts"][-1]):
        k = (round(p[0], 1), round(p[1], 1))
        end_count[k] = end_count.get(k, 0) + 1
for r in road_pieces:
    for p in r["pts"][1:-1]:
        k = (round(p[0], 1), round(p[1], 1))
        if k in end_count:
            end_count[k] += 2

for r in road_pieces:
    hw, t, piece, width, surf = r["hw"], r["t"], r["pts"], r["width"], r["surf"]
    z = ROAD_Z.get(hw, ROAD_Z_DEFAULT) + SURFACE_DZ[surf]
    key = (f"route_{hw}_{surf}", SURFACE_MAT[surf], z, "Routes")
    bt = line_batches.setdefault(key, Batch())
    bt.add(*ribbon(piece, width))
    # impasse : bout arrondi (aire de retournement) au lieu d'une coupure nette
    if hw not in NOT_CAR and not r["closed"]:
        for p in (piece[0], piece[-1]):
            if end_count.get(_ekey(p), 0) == 1 and _ekey(p) not in joined and not at_border(p, 2.0):
                bt.add(*flat(disc(p[0], p[1], width / 2 + 0.6), z))
    road_data.append({"kind": hw, "surface": surf, "width": round(width, 2),
                      "oneway": r["oneway"], "name": NOM_FICTIF.get(t.get("name", ""), t.get("name", "")),
                      "pts": [[round(p[0], 2), round(-p[1], 2)] for p in piece]})
    if hw in ("primary", "secondary", "tertiary") and surf in ("bitume", "paves"):
        # bas-cotes sableux ou se garent les zems, plus larges que la chaussee
        line_batches.setdefault(("accotement", "mat_sable", 0.014, "Routes"), Batch()).add(*ribbon(piece, width + 5.0))
    if surf == "bitume" and hw in ("primary", "secondary", "tertiary"):
        # marquage : axe en tirets, lignes de rive continues
        mz = z + MARK_DZ
        if not r["oneway"]:
            for d in dashes(piece, 3.0, 6.0):
                add_marking("marquage_route", "mat_marquage_blanc", mz, d, 0.15)
        elif width >= 6.5:
            # deux voies dans le meme sens : ligne de separation en tirets
            for d in dashes(piece, 3.0, 6.0):
                add_marking("marquage_route", "mat_marquage_blanc", mz, d, 0.12)
        for side in (-1, 1):
            add_marking("marquage_route", "mat_marquage_blanc", mz, offset_line(piece, side * (width / 2 - 0.35)), 0.12)

# --- 4) Terre-plein central entre deux chaussees separees : bordure biseautee (on peut monter dessus a pied
# ou en roulant lentement), ouvert aux carrefours pour laisser passer les rues transversales ---
median = Batch()
median_data = []
for i, j in twins:
    r, s = road_pieces[i], road_pieces[j]
    run = []

    def flush(run):
        if len(run) >= 3:
            mid = [q[0] for q in run]
            gaps = [q[1] for q in run]
            n = len(mid)
            top_l, top_r, bot_l, bot_r = [], [], [], []
            for k in range(n):
                a, c = mid[max(k - 1, 0)], mid[min(k + 1, n - 1)]
                dx, dy = c[0] - a[0], c[1] - a[1]
                l = math.hypot(dx, dy) or 1
                nx, ny = -dy / l, dx / l
                hb = gaps[k] / 2 - 0.02
                ht = max(hb - 0.3, hb * 0.5)
                top_l.append((mid[k][0] + nx * ht, mid[k][1] + ny * ht, MEDIAN_H))
                top_r.append((mid[k][0] - nx * ht, mid[k][1] - ny * ht, MEDIAN_H))
                bot_l.append((mid[k][0] + nx * hb, mid[k][1] + ny * hb, 0.0))
                bot_r.append((mid[k][0] - nx * hb, mid[k][1] - ny * hb, 0.0))
            o = len(median.verts)
            median.verts += top_l + top_r + bot_l + bot_r
            TL, TR, BL, BR = o, o + n, o + 2 * n, o + 3 * n
            for k in range(n - 1):
                median.faces.append((TR + k, TR + k + 1, TL + k + 1, TL + k))      # dessus
                median.faces.append((TL + k, TL + k + 1, BL + k + 1, BL + k))      # biseau gauche
                median.faces.append((BR + k, BR + k + 1, TR + k + 1, TR + k))      # biseau droit
            median_data.append([[round(p[0], 2), round(-p[1], 2)] for p in mid])

    opening = []
    road_z = ROAD_Z.get(r["hw"], ROAD_Z_DEFAULT)
    open_bt = line_batches.setdefault((f"route_{r['hw']}_bitume", "mat_bitume", road_z, "Routes"), Batch())

    def flush_opening(op):
        # ouverture du terre-plein au carrefour : goudronnee pour que les vehicules puissent traverser
        if len(op) >= 2:
            open_bt.add(*ribbon([q[0] for q in op], max(q[1] for q in op) + 0.6))

    for p in resample(r["pts"], 3.0):
        q, d = closest_on_line(p, s["pts"])
        gap = d - (r["width"] + s["width"]) / 2
        ok = 0.2 < gap < 12.0
        junction = False
        if ok:
            m = ((p[0] + q[0]) / 2, (p[1] + q[1]) / 2)
            for k, (pts, half) in enumerate(car_lines):
                if pts is r["pts"] or pts is s["pts"]:
                    continue
                if line_dist(m, pts) < half + 4.0:
                    ok = False  # carrefour : ouverture dans le terre-plein
                    junction = True
                    break
        if ok:
            run.append((m, gap))
            flush_opening(opening)
            opening = []
        else:
            flush(run)
            run = []
            if junction:
                opening.append((m, gap))
            else:
                flush_opening(opening)
                opening = []
    flush(run)
    flush_opening(opening)
if median.faces:
    # orientation des faces vers le haut / l'exterieur selon le sens de la polyligne
    me_faces = []
    for f in median.faces:
        a, b, c = (Vector(median.verts[f[0]]), Vector(median.verts[f[1]]), Vector(median.verts[f[2]]))
        nz = (b - a).cross(c - a).z
        me_faces.append(f if nz >= -1e-6 else f[::-1])
    median.faces = me_faces
    make_obj("terre_plein-col", median.verts, median.faces, "mat_beton", "Routes")

# --- 5) Piste et taxiways de l aeroport ---
aero_data = []
for wid, w in ways.items():
    t = w["tags"]
    aw = t.get("aeroway")
    if aw in AEROWAY_WIDTH:
        width = tag_width(t, AEROWAY_WIDTH[aw])
        z = 0.017 if aw != "taxiway" else 0.015
        key = ("aeroport_" + aw, "mat_bitume", z, "Aeroport")
        for piece in clip_line(w["pts"]):
            piece = clean(piece)
            if len(piece) < 2:
                continue
            line_batches.setdefault(key, Batch()).add(*ribbon(piece, width))
            aero_data.append({"kind": aw, "width": width, "pts": [[round(p[0], 2), round(-p[1], 2)] for p in piece]})
            mz = z + MARK_DZ
            if aw == "taxiway":
                add_marking("marquage_taxiway", "mat_marquage_jaune", mz, piece, 0.3)
                continue
            runway_data.append([[round(p[0], 2), round(-p[1], 2)] for p in piece])
            # piste : axe en tirets de 30 m, bords continus, seuil (bandes) aux extremites dans la zone
            for d in dashes(piece, 30.0, 20.0):
                add_marking("marquage_piste", "mat_marquage_blanc", mz, d, 0.9)
            for side in (-1, 1):
                add_marking("marquage_piste", "mat_marquage_blanc", mz, offset_line(piece, side * (width / 2 - 1.0)), 0.9)
            for end, nxt in ((piece[0], piece[1]), (piece[-1], piece[-2])):
                if not (XMIN + 1 < end[0] < XMAX - 1 and YMIN + 1 < end[1] < YMAX - 1):
                    continue
                dx, dy = nxt[0] - end[0], nxt[1] - end[1]
                l = math.hypot(dx, dy) or 1
                ux, uy = dx / l, dy / l
                for k in range(-5, 6):
                    if k == 0:
                        continue
                    off = k * 3.6 + (0.9 if k > 0 else -0.9)
                    a = (end[0] + ux * 6 - uy * off, end[1] + uy * 6 + ux * off)
                    b = (a[0] + ux * 30, a[1] + uy * 30)
                    add_marking("marquage_piste", "mat_marquage_blanc", mz, [a, b], 1.8)
    else:
        continue
# bande d'herbe de l'aerodrome : 110 m de part et d'autre de l'axe de piste, 25 m autour des taxiways
# (pas de laterite nue ni d'arbres cote piste ; la vegetation evite aussi cette bande)
strip_bt = Batch()
for a_ in aero_data:
    half = 110.0 if a_["kind"] in ("runway", "stopway") else 25.0
    pts_b = [(p[0], -p[1]) for p in a_["pts"]]
    for k in range(len(pts_b) - 1):
        p0, p1 = pts_b[k], pts_b[k + 1]
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        if L < 0.5:
            continue
        nx, ny = -(p1[1] - p0[1]) / L * half, (p1[0] - p0[0]) / L * half
        rect = clip_poly([(p0[0] + nx, p0[1] + ny), (p1[0] + nx, p1[1] + ny), (p1[0] - nx, p1[1] - ny), (p0[0] - nx, p0[1] - ny)])
        if len(rect) > 2:
            strip_bt.add(*flat(ccw(rect), 0.007))
            zone_data.append({"kind": "zone_herbe", "pts": [[round(q[0], 2), round(-q[1], 2)] for q in rect]})
batch_obj("zone_herbe_aerodrome", strip_bt, "mat_vegetation", "Zones", 0.007)
for (name, mat, z, collection), bt in line_batches.items():
    batch_obj(name, bt, mat, collection, z)
for (name, mat, z), bt in marking_batches.items():
    batch_obj(name, bt, mat, "Marquage", z)

# --- Murs et clotures ---
# Un mur OSM ne traverse jamais une chaussee (trace ancien, mur demoli pour la route) : on coupe les morceaux qui
# tombent a moins de WALL_ROAD_GAP m du bord de la bande de roulement (retour d'Olympe du 16/10/2026).
WALL_ROAD_GAP = 0.3


def cut_off_road(piece):
    pts = resample(piece, 0.5)
    bb = (min(p[0] for p in pts) - 30, min(p[1] for p in pts) - 30, max(p[0] for p in pts) + 30, max(p[1] for p in pts) + 30)
    near = [(lp, half) for lp, half in car_lines
            if min(q[0] for q in lp) - half < bb[2] and max(q[0] for q in lp) + half > bb[0]
            and min(q[1] for q in lp) - half < bb[3] and max(q[1] for q in lp) + half > bb[1]]
    out, cur = [], []
    for q in pts:
        if any(line_dist(q, lp) < half + WALL_ROAD_GAP for lp, half in near):
            if len(cur) >= 2:
                out.append(cur)
            cur = []
        else:
            cur.append(q)
    if len(cur) >= 2:
        out.append(cur)
    return [c for c in out if math.hypot(c[-1][0] - c[0][0], c[-1][1] - c[0][1]) >= 1.0]


wall_pieces = []      # murs gardes (aussi exportes dans le JSON : carte de marche des pietons)
nb_wall_cut = 0
for w in ways.values():
    if w["tags"].get("barrier") not in WALL:
        continue
    for piece in clip_line(w["pts"]):
        cut = cut_off_road(piece)
        if len(cut) != 1 or len(cut[0]) != len(resample(piece, 0.5)):
            nb_wall_cut += 1
        for c in cut:
            wall_pieces.append((w["tags"]["barrier"], c))
print("Murs coupes au bord des chaussees : %d" % nb_wall_cut)
wall_batches = {}
for kind, piece0 in wall_pieces:
    thick, height = WALL[kind]
    for piece in [piece0]:
        piece = clean(piece) if len(piece) > 2 else piece
        if len(piece) < 2 or any(on_waterfront(*p) for p in piece):  # murs OSM obsoletes sur la plage actuelle
            continue
        rv, rf = ribbon(piece, thick)
        n = len(piece)
        # contour du ruban (gauche puis droite a l'envers) extrude en prisme
        outline = rv[:n] + rv[n:][::-1]
        if abs(area(outline)) > 0.01:
            wall_batches.setdefault(kind, Batch()).add(*prism(outline, 0.0, height))
for kind, bt in wall_batches.items():
    batch_obj("mur_" + kind + "-col", bt, "mat_beton_brut" if kind == "wall" else "mat_metal_peint", "Murs", 0)

# --- Batiments ---
# Source : Overture Maps si fourni (OSM + emprises Google Open Buildings / Microsoft detectees
# sur images satellite recentes), sinon OSM seul. Les tags OSM sont repris quand le batiment vient d'OSM.
PAINTS = ["mat_peinture_blanc", "mat_peinture_ocre", "mat_beton", "mat_peinture_bleu", "mat_peinture_vert", "mat_peinture_ecaillee"]


def overture_buildings(path):
    import json
    out = []
    for i, f in enumerate(json.load(open(path, encoding="utf-8"))["features"]):
        g, p = f["geometry"], f["properties"]
        rings = [g["coordinates"][0]] if g["type"] == "Polygon" else [c[0] for c in g["coordinates"]] if g["type"] == "MultiPolygon" else []
        srcs = p.get("sources") or []
        if isinstance(srcs, str):
            srcs = json.loads(srcs)
        osm_id = None
        for s in srcs:
            rid = s.get("record_id") or ""
            if s.get("dataset") == "OpenStreetMap" and rid.startswith("w"):
                osm_id = rid[1:].split("@")[0]
        tags = dict(ways[osm_id]["tags"]) if osm_id in ways else {"building": p.get("class") or "yes"}
        if p.get("height"):
            tags["height"] = str(p["height"])
        if p.get("num_floors"):
            tags["building:levels"] = str(p["num_floors"])
        for k, ring in enumerate(rings):
            out.append((osm_id or f"ov{i}_{k}", tags, [proj(lat, lon) for lon, lat in ring]))
    return out


if OVERTURE:
    buildings = overture_buildings(OVERTURE)
else:
    buildings = [(wid, w["tags"], w["pts"]) for wid, w in ways.items()
                 if "building" in w["tags"] and w["closed"] and len(w["pts"]) > 3]

# ---------- Toits et details de toiture (realisme) ----------
def convex_hull(pts):
    pts = sorted(set((round(p[0], 3), round(p[1], 3)) for p in pts))
    if len(pts) < 3:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def min_rect(poly):
    """Rectangle d'aire minimale (centre, axe u, axe v, demi-longueurs) : sert a poser les toits a 2 pans."""
    hull = convex_hull(poly)
    best = None
    for i in range(len(hull)):
        a, b = hull[i], hull[(i + 1) % len(hull)]
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        c, s = math.cos(ang), math.sin(ang)
        xs = [p[0] * c + p[1] * s for p in hull]
        ys = [-p[0] * s + p[1] * c for p in hull]
        ar = (max(xs) - min(xs)) * (max(ys) - min(ys))
        if best is None or ar < best[0]:
            best = (ar, c, s, min(xs), max(xs), min(ys), max(ys))
    _, c, s, x0, x1, y0, y1 = best
    cu, cv = (x0 + x1) / 2, (y0 + y1) / 2
    return (cu * c - cv * s, cu * s + cv * c), (c, s), (-s, c), (x1 - x0) / 2, (y1 - y0) / 2


def add_face(bt, pts3, toward):
    """Ajoute un polygone 3D oriente vers 'toward' (pour que la face soit visible du bon cote)."""
    a, b, c = Vector(pts3[0]), Vector(pts3[1]), Vector(pts3[2])
    if (b - a).cross(c - a).dot(Vector(toward)) < 0:
        pts3 = pts3[::-1]
    bt.add([tuple(p) for p in pts3], [tuple(range(len(pts3)))])


def box_at(bt, cx, cy, sx, sy, z0, z1, ang=0.0):
    c, s = math.cos(ang), math.sin(ang)
    corners = [(-sx / 2, -sy / 2), (sx / 2, -sy / 2), (sx / 2, sy / 2), (-sx / 2, sy / 2)]
    poly = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in corners]
    bt.add(*prism(poly, z0, z1))


def cylinder_at(bt, cx, cy, r, z0, z1, n=12):
    bt.add(*prism([(cx + r * math.cos(i / n * math.tau), cy + r * math.sin(i / n * math.tau)) for i in range(n)], z0, z1))


def gable_roof(roof_bt, gable_bt, poly, h, pitch_deg=18.0, over=0.45):
    center, u, v, hu, hv = min_rect(poly)
    if hv > hu:  # faitage dans le sens de la longueur
        u, v, hu, hv = v, (-u[0], -u[1]), hv, hu
    rh = hv * math.tan(math.radians(pitch_deg))
    drop = over * math.tan(math.radians(pitch_deg))

    def P(L, W, z):
        return (center[0] + u[0] * L + v[0] * W, center[1] + u[1] * L + v[1] * W, z)

    L = hu + over
    for side in (1, -1):
        slope = [P(-L, side * (hv + over), h - drop), P(L, side * (hv + over), h - drop), P(L, 0, h + rh), P(-L, 0, h + rh)]
        up = (v[0] * side * 0.3, v[1] * side * 0.3, 1.0)
        add_face(roof_bt, slope, up)
        # dessous de la tole (visible sous le debord)
        under = [(p[0], p[1], p[2] - 0.05) for p in slope]
        add_face(roof_bt, under, (-up[0], -up[1], -1.0))
    for end in (1, -1):
        tri = [P(end * hu, hv, h), P(end * hu, -hv, h), P(end * hu, 0, h + rh)]
        add_face(gable_bt, tri, (u[0] * end, u[1] * end, 0.0))
    return h + rh


def roof_details(det, poly, h, wid, kind):
    """Toit plat : parapet, et selon le batiment fers en attente (etage inacheve), citerne, climatiseurs."""
    r = stable_hash(wid)
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    pc = ccw(poly)
    # parapet de 0,9 m le long de chaque facade ; sur environ une maison a etage sur huit, acrotere a creneaux
    # (muret de 0,6 m et merlons de 0,35 m tous les 1,3 m, carrefour du Calvaire de Fidjrosse, refs/rues/)
    creneaux = kind not in ("hangar",) and h >= 5.9 and stable_hash(f"{wid}cr") < 12
    for i in range(n):
        a, b = pc[i], pc[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 0.3:
            continue
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        if not creneaux or L < 2.5:
            box_at(det["parapet"], (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, L + 0.2, 0.2, h, h + 0.9, ang)
            continue
        box_at(det["parapet"], (a[0] + b[0]) / 2, (a[1] + b[1]) / 2, L + 0.2, 0.2, h, h + 0.6, ang)
        m = max(int(L / 1.3), 1)
        c, sn = math.cos(ang), math.sin(ang)
        for k in range(m + 1):
            u = k / m
            mx, my = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            quad = [(mx + x * c - y * sn, my + x * sn + y * c) for x, y in ((-0.22, -0.12), (0.22, -0.12), (0.22, 0.12), (-0.22, 0.12))]
            v, f = prism(quad, h + 0.6, h + 0.95)
            det["parapet"].add(v, f[2:])     # merlon pose sur le muret : pas de face du dessous
    if kind in ("hangar",):
        return
    # fers en attente : poteaux beton entames + armatures rouillees (tres courant a Cotonou)
    if r < 40 and abs(area(poly)) > 30:
        for i in range(n):
            a = pc[i]
            k = 0.35 / max(math.hypot(cx - a[0], cy - a[1]), 0.01)
            px, py = a[0] + (cx - a[0]) * k, a[1] + (cy - a[1]) * k
            box_at(det["poteau_attente"], px, py, 0.25, 0.25, h, h + 0.6)
            for ox, oy in ((-0.07, -0.07), (0.07, -0.07), (0.07, 0.07), (-0.07, 0.07)):
                box_at(det["fers"], px + ox, py + oy, 0.025, 0.025, h + 0.6, h + 1.5 + 0.2 * ((i + r) % 3))
    # citerne d'eau noire sur pieds
    if r % 2 == 0 and abs(area(poly)) > 40:
        a = pc[0]
        k = 1.6 / max(math.hypot(cx - a[0], cy - a[1]), 0.01)
        tx, ty = a[0] + (cx - a[0]) * k, a[1] + (cy - a[1]) * k
        for ox, oy in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
            box_at(det["fers"], tx + ox, ty + oy, 0.06, 0.06, h, h + 0.6)
        cylinder_at(det["citerne"], tx, ty, 0.62, h + 0.6, h + 2.0)
    # climatiseurs sur les facades des immeubles
    if h >= 5.9:
        for i in range(n):
            a, b = pc[i], pc[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L < 4.0 or stable_hash(f"{wid}-{i}") > 45:
                continue
            ex, ey = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            nx, ny = ey, -ex  # normale exterieure (polygone dans le sens trigo)
            t = 0.3 + 0.4 * stable_hash(f"{wid}+{i}") / 100
            mx, my = a[0] + (b[0] - a[0]) * t + nx * 0.18, a[1] + (b[1] - a[1]) * t + ny * 0.18
            box_at(det["clim"], mx, my, 0.82, 0.3, 3.15, 3.7, math.atan2(ey, ex))


def shelter(det, poly, h):
    """Abri / preau : toit en tole sur poteaux, ouvert (au lieu d'un bloc plein)."""
    det["abri_toit"].add(*prism(poly, h - 0.12, h))
    for p in poly:
        box_at(det["abri_poteaux"], p[0], p[1], 0.12, 0.12, 0.0, h - 0.12)


DETAILS = {k: Batch() for k in ("parapet", "poteau_attente", "fers", "citerne", "clim", "toit_tole", "abri_toit", "abri_poteaux",
                                 "bandeau", "balcon", "auvent", "auvent_console")}
gable_batches = {}
building_data = []

def point_in_poly(p, poly):
    x, y = p
    c = False
    n = len(poly)
    for k in range(n):
        x1, y1 = poly[k]
        x2, y2 = poly[(k + 1) % n]
        if (y1 > y) != (y2 > y) and x < x1 + (y - y1) * (x2 - x1) / (y2 - y1):
            c = not c
    return c


LINE_BB = [((min(p[0] for p in pts) - half, min(p[1] for p in pts) - half,
             max(p[0] for p in pts) + half, max(p[1] for p in pts) + half), pts, half) for pts, half in car_lines]


BLD_ROAD_GAP = 0.7     # m : facade a au moins 70 cm de la chaussee (aire de retournement des impasses : +0,6 m)


def on_road(poly):
    """Le batiment empiete-t-il sur une chaussee ? (sommets, milieux des cotes et centre dans la bande de roulement,
    ou axe de la route qui traverse le batiment)"""
    bb = (min(p[0] for p in poly), min(p[1] for p in poly), max(p[0] for p in poly), max(p[1] for p in poly))
    n = len(poly)
    # tout le contour (un point tous les 0,5 m), pas seulement les coins : un long cote peut couper la route
    probes = resample(list(poly) + [poly[0]], 0.5)
    probes.append((sum(p[0] for p in poly) / n, sum(p[1] for p in poly) / n))
    for lbb, pts, half in LINE_BB:
        if not bb_near(bb, lbb, BLD_ROAD_GAP):
            continue
        if any(line_dist(p, pts) < half + BLD_ROAD_GAP for p in probes):
            return True
        for a, c in zip(pts, pts[1:]):
            sbb = (min(a[0], c[0]), min(a[1], c[1]), max(a[0], c[0]), max(a[1], c[1]))
            if not bb_near(bb, sbb, 0.0):
                continue
            for q in resample([a, c], 1.0):
                if point_in_poly(q, poly):
                    return True
    return False


def fit_off_road(poly):
    """Emprise detectee sur image ou trace OSM ancien qui deborde sur la route : on la retrecit un peu,
    sinon on l'enleve (souvent une maison demolie pour elargir la voie, ex. Route des Peches)."""
    if not on_road(poly):
        return poly
    n = len(poly)
    cx = sum(p[0] for p in poly) / n
    cy = sum(p[1] for p in poly) / n
    for k in (0.94, 0.88, 0.82, 0.76):
        cand = [(cx + (p[0] - cx) * k, cy + (p[1] - cy) * k) for p in poly]
        if not on_road(cand):
            return cand
    return None


# Batiments remplaces par un modele avec interieur (blender/tools/build_interieurs.py) : on ne les extrude pas ici,
# on garde leur emprise (carte, masques) et on la transmet dans le JSON ("lieux").
SPECIAL = {"81766299": ("ararat", 12.0), "273487965": ("terminal", 15.0)}
lieux = {}
all_polys = []
bld_batches = {}
nb_bld = 0
nb_off = 0
nb_fit = 0


def seg_cross(p1, p2, q1, q2):
    def o(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    return (o(p1, p2, q1) * o(p1, p2, q2) < 0) and (o(q1, q2, p1) * o(q1, q2, p2) < 0)


def polys_overlap(a, b):
    if any(point_in_poly(p, b) for p in a) or any(point_in_poly(p, a) for p in b):
        return True
    for i in range(len(a)):
        for j in range(len(b)):
            if seg_cross(a[i], a[(i + 1) % len(a)], b[j], b[(j + 1) % len(b)]):
                return True
    return False


def pbbox(p):
    return (min(q[0] for q in p), min(q[1] for q in p), max(q[0] for q in p), max(q[1] for q in p))


def near_street(m, nrm, dist=7.0):
    """Le point a 'dist' metres devant la facade est-il au bord d'une rue (chaussee a moins de 4 m) ?"""
    q = (m[0] + nrm[0] * dist, m[1] + nrm[1] * dist)
    for lbb, pts, half in LINE_BB:
        if lbb[0] - 6 <= q[0] <= lbb[2] + 6 and lbb[1] - 6 <= q[1] <= lbb[3] + 6 and line_dist(q, pts) < half + 4.0:
            return True
    return False


def facade_details(det, poly, h, wid, t, others):
    """Relief des facades (habitat) : bandeaux d'etage, balcons maconnes cote rue sur les immeubles, auvents en tole
    sur consoles au-dessus des commerces. Rien ne deborde sur une chaussee ni sur un batiment voisin."""
    pc = ccw(poly)
    n = len(pc)
    levels = max(1, int(round(h / LEVEL_H)))
    # bandeaux : une moulure beton en saillie a chaque plancher (immeubles)
    for k in range(1, levels):
        z = k * LEVEL_H
        for i in range(n):
            a, b = pc[i], pc[(i + 1) % n]
            L = math.hypot(b[0] - a[0], b[1] - a[1])
            if L < 0.5:
                continue
            ex, ey = (b[0] - a[0]) / L, (b[1] - a[1]) / L
            nx, ny = ey, -ex
            box_at(det["bandeau"], (a[0] + b[0]) / 2 + nx * 0.05, (a[1] + b[1]) / 2 + ny * 0.05, L + 0.1, 0.12, z - 0.09, z + 0.09, math.atan2(ey, ex))
    # facades sur rue (la plus longue d'abord)
    street = []
    for i in range(n):
        a, b = pc[i], pc[(i + 1) % n]
        L = math.hypot(b[0] - a[0], b[1] - a[1])
        if L < 4.5:
            continue
        ex, ey = (b[0] - a[0]) / L, (b[1] - a[1]) / L
        nx, ny = ey, -ex
        m = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        if near_street(m, (nx, ny)):
            street.append((L, m, (ex, ey), (nx, ny)))
    street.sort(key=lambda e: -e[0])
    if not street:
        return

    def free(rect):
        # on teste l'emprise legerement decollee de la facade (elle touche son propre mur)
        test = [(p[0] + nx * 0.05, p[1] + ny * 0.05) for p in rect]
        if on_road(test):
            return False
        bb = pbbox(test)
        return not any(bb_near(bb, ob, 0.2) and polys_overlap(test, op) for op, ob in others)

    L, m, (ex, ey), (nx, ny) = street[0]
    ang = math.atan2(ey, ex)
    r = stable_hash("facade" + str(wid))
    # balcons : un par etage, sur la facade principale (60 % des immeubles)
    if levels >= 2 and r < 60:
        w = min(L * 0.55, 5.5)
        dep = 1.15
        rect = [(m[0] + ex * sx * w / 2 + nx * dd, m[1] + ey * sx * w / 2 + ny * dd) for sx, dd in ((-1, 0.0), (1, 0.0), (1, dep), (-1, dep))]
        if free(rect):
            for k in range(1, levels):
                z = k * LEVEL_H
                cx, cy = m[0] + nx * dep / 2, m[1] + ny * dep / 2
                box_at(det["balcon"], cx, cy, w, dep, z - 0.16, z, ang)                                     # dalle
                ox, oy = m[0] + nx * (dep - 0.06), m[1] + ny * (dep - 0.06)
                box_at(det["balcon"], ox, oy, w, 0.12, z, z + 1.0, ang)                                      # garde-corps
                for sx in (-1, 1):
                    sxx, syy = m[0] + ex * sx * (w / 2 - 0.06) + nx * dep / 2, m[1] + ey * sx * (w / 2 - 0.06) + ny * dep / 2
                    box_at(det["balcon"], sxx, syy, 0.12, dep, z, z + 1.0, ang)
                box_at(det["bandeau"], ox, oy, w + 0.1, 0.2, z + 1.0, z + 1.07, ang)                          # main courante
    # auvent en tole sur consoles au-dessus d'une boutique (commerces OSM, sinon un rez-de-chaussee sur cinq)
    shop = bool(t.get("shop")) or t.get("amenity") in ("restaurant", "bar", "cafe", "pharmacy", "fast_food", "bank")         or t.get("building") in ("retail", "commercial", "kiosk")
    if shop or r % 5 == 0:
        w = min(L * 0.75, 9.0)
        dep = 1.5
        rect = [(m[0] + ex * sx * w / 2 + nx * dd, m[1] + ey * sx * w / 2 + ny * dd) for sx, dd in ((-1, 0.0), (1, 0.0), (1, dep), (-1, dep))]
        if free(rect):
            z0, z1 = 2.75, 2.42
            pts = [(rect[0][0], rect[0][1], z0), (rect[1][0], rect[1][1], z0), (rect[2][0], rect[2][1], z1), (rect[3][0], rect[3][1], z1)]
            add_face(det["auvent"], pts, (nx * 0.2, ny * 0.2, 1.0))
            add_face(det["auvent"], [(p[0], p[1], p[2] - 0.03) for p in pts], (-nx * 0.2, -ny * 0.2, -1.0))
            for sx in (-1, 1):
                px, py = m[0] + ex * sx * (w / 2 - 0.3), m[1] + ey * sx * (w / 2 - 0.3)
                tri = [(px, py, 2.1), (px, py, z0 - 0.02), (px + nx * (dep - 0.15), py + ny * (dep - 0.15), z1 + 0.02)]
                add_face(det["auvent_console"], tri, (ex, ey, 0.0))
                add_face(det["auvent_console"], tri, (-ex, -ey, 0.0))


# 1re passe : emprises finales (hors chaussee), puis chevauchements entre batiments (doublons OSM / detections
# satellite, batiment qui deborde sur un autre) : le plus petit est retreci, sinon retire.
entries = []
for wid, t, pts in buildings:
    poly = clean(pts)
    if len(poly) < 3 or abs(area(poly)) < 4.0:
        continue
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    if not inside_box((cx, cy)) or on_waterfront(cx, cy):
        continue
    fitted = fit_off_road(poly)
    if fitted is None:
        nb_off += 1
        continue
    if fitted is not poly:
        nb_fit += 1
    poly = fitted
    if abs(area(poly)) < 4.0:
        continue
    entries.append([wid, t, poly])
# les lieux a interieur sont prioritaires, puis les plus grands
entries.sort(key=lambda e: (0 if str(e[0]) in SPECIAL else 1, -abs(area(e[2]))))
kept = []
nb_overlap_fit = 0
nb_overlap_off = 0
for e in entries:
    poly = e[2]
    for k in (1.0, 0.92, 0.84, 0.76):
        n = len(poly)
        ccx = sum(p[0] for p in poly) / n
        ccy = sum(p[1] for p in poly) / n
        cand = poly if k == 1.0 else [(ccx + (p[0] - ccx) * k, ccy + (p[1] - ccy) * k) for p in poly]
        bb = pbbox(cand)
        if not any(bb_near(bb, kb, 0.0) and polys_overlap(cand, kp) for kp, kb in kept):
            if k < 1.0:
                nb_overlap_fit += 1
            e[2] = cand
            kept.append((cand, bb))
            break
    else:
        nb_overlap_off += 1
        e[2] = None
print("Chevauchements entre batiments : %d retrecis, %d retires" % (nb_overlap_fit, nb_overlap_off))

# Hauteurs reelles mesurees (Google Open Buildings 2.5D Temporal 2023, CC BY 4.0) : mediane sous l'emprise
OB = None
if HEIGHTS:
    import numpy as np
    _z = np.load(HEIGHTS)
    OB = (_z["height"], _z["presence"], float(_z["x0"]), float(_z["y0"]))
nb_ob = 0


def measured_height(poly):
    """Hauteur mediane (m) des cellules baties sous l'emprise, ou None si trop peu de mesures."""
    if OB is None:
        return None
    hg, pg, gx0, gy0 = OB
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    c0, c1 = int(min(xs) - gx0), int(max(xs) - gx0) + 1
    r0, r1 = int(min(ys) - gy0), int(max(ys) - gy0) + 1
    if c0 < 0 or r0 < 0 or c1 > hg.shape[1] or r1 > hg.shape[0]:
        return None
    cx = np.arange(c0, c1) + gx0 + 0.5
    cy = np.arange(r0, r1) + gy0 + 0.5
    px, py = np.meshgrid(cx, cy)
    inside = np.zeros(px.shape, bool)
    n = len(poly)
    for i in range(n):                      # point dans polygone (lancer de rayon), vectorise
        xa, ya = poly[i]
        xb, yb = poly[(i + 1) % n]
        cross = (ya > py) != (yb > py)
        xi = xa + (py - ya) * (xb - xa) / ((yb - ya) if yb != ya else 1e-9)
        inside ^= cross & (px < xi)
    sel = inside & (pg[r0:r1, c0:c1] > 0.5)
    if sel.sum() < max(6, 0.3 * inside.sum()):
        return None
    return float(np.median(hg[r0:r1, c0:c1][sel]))
for wid, t, poly in entries:
    if poly is None:
        continue
    all_polys.append(poly)
    if str(wid) in SPECIAL:
        name, hs = SPECIAL[str(wid)]
        gpts = [[round(p[0], 2), round(-p[1], 2)] for p in ccw(poly)]
        lieux[name] = {"pts": gpts, "h": hs}
        building_data.append({"id": str(wid), "h": hs, "roof": "plat", "top": hs, "style": "lieu_" + name, "pts": gpts})
        nb_bld += 1
        continue
    kind = t.get("building", "yes")
    seed = int("".join(ch for ch in str(wid) if ch.isdigit()) or 0) % 97
    if t.get("height", "").replace(".", "").isdigit():
        h = float(t["height"])
    elif t.get("building:levels", "").isdigit():
        h = int(t["building:levels"]) * LEVEL_H
    elif kind == "hangar":
        h = 14.0
    elif kind == "roof" or t.get("amenity") == "shelter":
        h = 3.5
    elif t.get("aeroway") == "terminal":
        h = 15.0
    elif measured_height(poly) is not None:
        # hauteur mesuree, arrondie a l'etage (3 m) pour que fenetres et dalles tombent juste
        h = max(1, min(8, round(measured_height(poly) / LEVEL_H))) * LEVEL_H
        nb_ob += 1
    elif kind == "retail":
        h = 8.0
    else:
        lv = stable_hash("niveaux" + str(wid))  # repartition Cotonou : surtout du plain-pied
        h = (1 if lv < 50 else 2 if lv < 85 else 3) * LEVEL_H
    if kind == "hangar":
        mat = "mat_tole"
    elif kind == "roof" or t.get("amenity") == "shelter":
        mat = "mat_tole_rouillee"
    elif t.get("aeroway") == "terminal":
        mat = "mat_peinture_blanc"
    else:
        mat = PAINTS[seed % len(PAINTS)]
    # --- type de toit ---
    r = stable_hash("toit" + str(wid))
    roof = "plat"
    top = h
    if kind == "roof" or t.get("amenity") == "shelter":
        shelter(DETAILS, ccw(poly), h)
        building_data.append({"id": str(wid), "h": h, "roof": "abri", "pts": [[round(p[0], 2), round(-p[1], 2)] for p in poly]})
        nb_bld += 1
        continue
    # filet de securite : emprise finale (apres les chevauchements) encore sur une chaussee -> retrecie, sinon retiree
    if on_road(poly):
        poly = fit_off_road(poly)
        if poly is None:
            nb_off += 1
            continue
    _, _, _, hu, hv = min_rect(poly)
    rect_fill = abs(area(poly)) / max(4 * hu * hv, 0.01)
    if kind == "hangar" and rect_fill > 0.7:
        roof = "tole"
        top = gable_roof(DETAILS["toit_tole"], gable_batches.setdefault(mat, Batch()), poly, h, pitch_deg=10.0, over=0.3)
    elif h <= 3.5 and r < 70 and rect_fill > 0.75 and min(hu, hv) < 8.0:
        roof = "tole"
        top = gable_roof(DETAILS["toit_tole"], gable_batches.setdefault(mat, Batch()), poly, h)
    else:
        roof_details(DETAILS, poly, h, wid, kind)
    if kind not in ("hangar",) and t.get("aeroway") != "terminal":
        facade_details(DETAILS, poly, h, wid, t, [(op, ob) for op, ob in kept if op is not poly])
    # Regroupes par materiau : quelques objets au lieu de milliers (bien plus leger pour Godot)
    style = "terminal" if t.get("aeroway") == "terminal" else ("hangar" if kind == "hangar" else mat[4:])
    bld_batches.setdefault((style, mat), Batch()).add(*prism(poly, 0.0, h))
    building_data.append({"id": str(wid), "h": h, "roof": roof, "top": round(top, 2), "style": style,
                          "pts": [[round(p[0], 2), round(-p[1], 2)] for p in ccw(poly)]})
    nb_bld += 1
for (style, mat), bt in bld_batches.items():
    batch_obj("bld_" + style + "-col", bt, mat, "Batiments", 0)
for mat, bt in gable_batches.items():
    batch_obj("pignon_" + mat[4:], bt, mat, "Toits", 0)
DETAIL_MATS = {"parapet": "mat_beton", "poteau_attente": "mat_beton_brut", "fers": "mat_rouille", "citerne": "mat_citerne",
               "clim": "mat_blanc_plastique", "toit_tole": "mat_tole_rouillee", "abri_toit": "mat_tole_rouillee",
               "bandeau": "mat_beton", "balcon": "mat_beton", "auvent": "mat_tole_rouillee", "auvent_console": "mat_metal_peint",
               "abri_poteaux": "mat_metal_peint"}
for k, bt in DETAILS.items():
    batch_obj(k + ("-col" if k == "abri_poteaux" else ""), bt, DETAIL_MATS[k], "Toits", 0)

# ---------- Terrain de la maison du joueur ----------
# Une concession (mur d'enceinte + maison) de 20 m de facade sur 17 m de profondeur, face a une rue de quartier,
# sur un terrain ou il n'y a ni batiment, ni mur, ni route : on n'ecrase aucune maison existante.
def find_house_lot(target, W=20.0, D=17.0):
    walls_l = [w["pts"] for w in ways.values() if w["tags"].get("barrier") in WALL]
    pbb = [((min(p[0] for p in q), min(p[1] for p in q), max(p[0] for p in q), max(p[1] for p in q)), q) for q in all_polys + zone_polys]
    cands = []
    for r in road_pieces:
        if r["hw"] not in ("residential", "unclassified", "living_street"):
            continue
        pts = r["pts"]
        for k in range(len(pts) - 1):
            a, c = pts[k], pts[k + 1]
            L = math.hypot(c[0] - a[0], c[1] - a[1])
            if L < 1.0:
                continue
            u = ((c[0] - a[0]) / L, (c[1] - a[1]) / L)
            nrm = (-u[1], u[0])
            t0 = 0.0
            while t0 < L:
                p = (a[0] + u[0] * t0, a[1] + u[1] * t0)
                for sd in (1, -1):
                    n = (nrm[0] * sd, nrm[1] * sd)
                    off = r["width"] / 2 + 1.5 + D / 2
                    cc = (p[0] + n[0] * off, p[1] + n[1] * off)
                    cands.append((math.hypot(cc[0] - target[0], cc[1] - target[1]), cc, u, n))
                t0 += 3.0
    cands.sort(key=lambda e: e[0])
    for score, cc, u, n in cands[:4000]:
        ok = True
        corners = [(cc[0] + u[0] * a2 * W / 2 + n[0] * b2 * D / 2, cc[1] + u[1] * a2 * W / 2 + n[1] * b2 * D / 2)
                   for a2, b2 in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        rb = (min(q[0] for q in corners) - 1, min(q[1] for q in corners) - 1, max(q[0] for q in corners) + 1, max(q[1] for q in corners) + 1)
        if not all(inside_box(q) and not on_waterfront(*q) for q in corners):
            continue
        near_b = [q for bb, q in pbb if bb_near(bb, rb, 0.0)]
        near_r = [(pts, half) for (lbb, pts, half) in LINE_BB if bb_near(lbb, rb, 0.0)]
        gi = 0
        while ok and gi <= 14:
            gj = 0
            while ok and gj <= 12:
                fa, fb = gi / 14 - 0.5, gj / 12 - 0.5
                q = (cc[0] + u[0] * fa * (W + 1) + n[0] * fb * (D + 1), cc[1] + u[1] * fa * (W + 1) + n[1] * fb * (D + 1))
                if any(point_in_poly(q, pb) for pb in near_b):
                    ok = False
                elif any(line_dist(q, pts) < half + 0.6 for pts, half in near_r):
                    ok = False
                elif any(len(wl) > 1 and line_dist(q, wl) < 0.6 for wl in walls_l):
                    ok = False
                gj += 1
            gi += 1
        if ok:
            front = (cc[0] - n[0] * D / 2, cc[1] - n[1] * D / 2)   # milieu de la facade, cote rue
            return {"center": [round(cc[0], 2), round(-cc[1], 2)], "front_dir": [round(-n[0], 3), round(n[1], 3)],
                    "w": W, "d": D, "pts": [[round(q[0], 2), round(-q[1], 2)] for q in ccw(corners)],
                    "front": [round(front[0], 2), round(-front[1], 2)]}
    return None


maison = find_house_lot((300.0, -120.0))
if maison:
    lieux["maison"] = maison
    building_data.append({"id": "maison_joueur", "h": 3.4, "roof": "plat", "top": 3.4, "style": "lieu_maison", "pts": maison["pts"]})
print("Lieux :", {k: (v["center"] if "center" in v else len(v["pts"])) for k, v in lieux.items()})

# ---------- Donnees pour Godot (coordonnees Godot : x = est, z = sud) ----------
if OUT_JSON:
    def gz(line):
        return [[round(p[0], 2), round(-p[1], 2)] for p in line] if line else []

    parking = []
    for n in root.iter("node"):
        tg = tags_of(n)
        if tg.get("aeroway") == "parking_position":
            x, y = proj(float(n.get("lat")), float(n.get("lon")))
            if inside_box((x, y)):
                parking.append([round(x, 2), round(-y, 2), tg.get("ref", "")])
    # postes de stationnement avion dessines en ligne de guidage : l'avion s'arrete au bout, nez dans l'axe
    for w in ways.values():
        if w["tags"].get("aeroway") == "parking_position" and len(w["pts"]) >= 2:
            (ax, ay), (bx, by) = w["pts"][-2], w["pts"][-1]
            if inside_box((bx, by)):
                l = math.hypot(bx - ax, by - ay) or 1
                parking.append([round(bx, 2), round(-by, 2), w["tags"].get("ref", ""), round((bx - ax) / l, 3), round(-(by - ay) / l, 3)])
    data = {
        "bounds": [round(XMIN, 2), round(-YMAX, 2), round(XMAX, 2), round(-YMIN, 2)],
        "roads": road_data, "runways": runway_data, "buildings": building_data,
        "walls": [gz(pc) for _k, pc in wall_pieces],
        "coast": gz(coast), "beach_inner": gz(beach_inner),
        "promenade": gz(offset_line(beach_inner, PROMENADE_W / 2)) if beach_inner else [],
        "parking_positions": parking,
        "medians": median_data,
        "zones": zone_data,
        "aeroways": aero_data,
        "lieux": lieux,
    }
    json.dump(data, open(OUT_JSON, "w", encoding="utf-8"))
    print("Donnees Godot :", OUT_JSON, len(road_data), "routes,", len(building_data), "batiments")

# ---------- Sauvegarde et export ----------
for m in MAT.values():
    m.use_fake_user = False
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
if TILES_DIR:
    # chargement par morceaux (docs/chargement_par_morceaux.md) : les objets decoupes en tuiles (suffixe _tX_Y) vont
    # dans zone_tX_Y.glb, les autres (mer, plage d'un seul tenant...) dans zone_commun.glb, toujours charge ;
    # index des tuiles dans tuiles.json (rectangle de chaque tuile en coordonnees Godot : x, z)
    import re
    os.makedirs(TILES_DIR, exist_ok=True)
    groups = {}
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        m = re.search(r"_t(-?\d+)_(-?\d+)(-col|-colonly)?$", ob.name)
        groups.setdefault((int(m.group(1)), int(m.group(2))) if m else None, []).append(ob)
    index = []
    for key, obs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for ob in obs:
            ob.select_set(True)
        nom = "zone_commun.glb" if key is None else "zone_t%d_%d.glb" % key
        bpy.ops.export_scene.gltf(filepath=os.path.join(TILES_DIR, nom), export_format="GLB", export_apply=True,
                                  export_yup=True, use_selection=True)
        if key is not None:
            tx, ty = key
            index.append({"x": tx, "y": ty, "fichier": nom,
                          "rect": [tx * TILE, -(ty + 1) * TILE, TILE, TILE]})   # Blender y nord -> Godot z = -y
    json.dump({"taille": TILE, "commun": "zone_commun.glb", "tuiles": sorted(index, key=lambda t: (t["x"], t["y"]))},
              open(os.path.join(TILES_DIR, "tuiles.json"), "w", encoding="utf-8"))
    print("Tuiles :", len(index), "+ commun (%d objets)" % len(groups.get(None, [])))
print("Hauteurs mesurees (Open Buildings 2.5D) : %d batiments" % nb_ob)
print(f"Zone : {XMAX - XMIN:.0f} m x {YMAX - YMIN:.0f} m, batiments : {nb_bld} (retires de la chaussee : {nb_off}, "
      f"retrecis : {nb_fit}), routes : {len(line_batches)} types, chaussees separees : {len(twins)}, "
      f"rues arretees au front de mer : {nb_cut}, rues raccordees : {nb_ext}, cote : {'oui' if coast else 'non'}")
