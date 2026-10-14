# GTB : importeur OpenStreetMap maison pour le blockout (remplace Blender-OSM).
# Donnees OSM : © les contributeurs d'OpenStreetMap, licence ODbL.
#
# Lancement :
#   blender -b --python blender/tools/osm_import.py -- <fichier.osm> <lib_materiaux.blend> <sortie.blend> <sortie.glb>
#
# Genere : sol (terre ferme) avec collision, mer, plage, zones (herbe, eau, piscines, parkings),
# routes en rubans, piste et taxiways, batiments extrudes avec collision, murs d'enceinte.
# Repere : origine au centre de la zone, X = est, Y = nord, 1 unite = 1 metre.
import bpy
import math
import sys
import xml.etree.ElementTree as ET
from mathutils import Vector
from mathutils.geometry import tessellate_polygon

args = sys.argv[sys.argv.index("--") + 1:]
OSM, MATLIB, OUT_BLEND, OUT_GLB = args[:4]
OVERTURE = args[4] if len(args) > 4 else None  # optionnel : batiments Overture (GeoJSON)

# ---------- Reglages ----------
ROAD_WIDTH = {
    "primary": 14.0, "secondary": 10.0, "tertiary": 8.0, "residential": 6.0,
    "unclassified": 6.0, "service": 4.0, "living_street": 5.0, "track": 3.0,
    "footway": 2.0, "path": 1.5, "pedestrian": 4.0,
}
# Hauteurs des couches au sol : assez espacees pour eviter le scintillement (z-fighting) de loin.
ROAD_Z = {"primary": 0.2, "secondary": 0.18, "tertiary": 0.16}
ROAD_Z_DEFAULT = 0.14
AEROWAY_WIDTH = {"runway": 45.0, "stopway": 45.0, "taxiway": 23.0}
WALL = {"wall": (0.2, 2.2), "fence": (0.1, 1.8)}
LEVEL_H = 3.0
SEA_EXTRA = 400.0
# Front de mer apres l'amenagement de la Route des Peches (travaux depuis 2023) :
# plage continue depuis la mer, puis promenade pietonne et piste cyclable.
# Largeurs estimees d'apres la carte OSM et la description publique du projet, pas un releve exact.
BEACH_W = 90.0
PROMENADE_W = 8.0
BIKE_W = 3.0

# ---------- Lecture OSM ----------
root = ET.parse(OSM).getroot()
b = root.find("bounds")
minlat, minlon = float(b.get("minlat")), float(b.get("minlon"))
maxlat, maxlon = float(b.get("maxlat")), float(b.get("maxlon"))
lat0, lon0 = (minlat + maxlat) / 2, (minlon + maxlon) / 2
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


def batch_obj(name, batch, mat, collection, z):
    if not batch.faces:
        return None
    verts = [(v[0], v[1], z) if len(v) == 2 else v for v in batch.verts]
    return make_obj(name, verts, batch.faces, mat, collection)


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
        land_poly = clip_poly(clean(coast + [(e[0], -sea_y), (s[0], -sea_y)]))
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
def offset_line(pts, d):
    """Decale une polyligne de d metres vers la gauche (cote terre pour un trait de cote OSM)."""
    out = []
    for i in range(len(pts)):
        a, c = pts[max(i - 1, 0)], pts[min(i + 1, len(pts) - 1)]
        dx, dy = c[0] - a[0], c[1] - a[1]
        l = math.hypot(dx, dy) or 1
        out.append((pts[i][0] - dy / l * d, pts[i][1] + dx / l * d))
    return out


def coast_y_at(x):
    """Ordonnee du trait de cote a l'abscisse x (cote orientee ouest -> est)."""
    pts = coast if coast[0][0] < coast[-1][0] else coast[::-1]
    for a, c in zip(pts, pts[1:]):
        if a[0] <= x <= c[0]:
            return a[1] + (c[1] - a[1]) * (x - a[0]) / ((c[0] - a[0]) or 1)
    return pts[0][1] if x < pts[0][0] else pts[-1][1]


WATERFRONT = BEACH_W + PROMENADE_W + BIKE_W + 2.0


def on_waterfront(x, y):
    return coast is not None and y < coast_y_at(x) + WATERFRONT


if coast:
    beach_edge = offset_line(coast, BEACH_W)
    band = clip_poly(clean(coast + beach_edge[::-1]), ymin=YMIN - SEA_EXTRA)
    if len(band) > 2:
        make_obj("plage_front_de_mer", *flat(ccw(band), 0.03), "mat_sable", "Zones")
    for name, d, w, mat, z in (("promenade-col", BEACH_W + PROMENADE_W / 2, PROMENADE_W, "mat_paves", 0.15),
                               ("piste_cyclable", BEACH_W + PROMENADE_W + BIKE_W / 2, BIKE_W, "mat_peinture_vert", 0.16)):
        bt = Batch()
        for piece in clip_line(offset_line(coast, d)):
            if len(piece) > 1:
                bt.add(*ribbon(piece, w))
        batch_obj(name, bt, mat, "Front de mer", z)

# --- Zones au sol ---
ZONE_RULES = [
    (lambda t: t.get("natural") == "beach" or t.get("surface") == "sand", "mat_sable", 0.03, "zone_plage"),
    (lambda t: t.get("natural") == "wetland", "mat_vegetation", 0.04, "zone_humide"),
    (lambda t: t.get("landuse") in ("grass", "meadow") or t.get("leisure") in ("park", "garden"), "mat_vegetation", 0.05, "zone_herbe"),
    (lambda t: t.get("aeroway") == "apron", "mat_beton", 0.08, "aeroport_tarmac"),
    (lambda t: t.get("amenity") in ("parking", "motorcycle_parking") and "building" not in t, "mat_bitume", 0.09, "zone_parking"),
    (lambda t: t.get("natural") == "water", "mat_eau", 0.06, "zone_eau"),
    (lambda t: t.get("leisure") == "swimming_pool", "mat_eau", 0.1, "zone_piscine"),
]
zone_batches = {}
for t, poly in areas:
    if "building" in t:
        continue
    for rule, mat, z, name in ZONE_RULES:
        if rule(t):
            p = clip_poly(clean(poly))
            if len(p) > 2:
                zone_batches.setdefault((name, mat, z), Batch()).add(*flat(ccw(p), z))
            break
for (name, mat, z), bt in zone_batches.items():
    batch_obj(name, bt, mat, "Zones", z)

# --- Routes, piste, taxiways ---
def tag_width(t, default):
    try:
        return float(t.get("width", "").split()[0])
    except (ValueError, IndexError):
        return default


line_batches = {}
for w in ways.values():
    t = w["tags"]
    hw, aw = t.get("highway"), t.get("aeroway")
    if hw in ROAD_WIDTH and not (w["closed"] and t.get("area") == "yes"):
        width = tag_width(t, ROAD_WIDTH[hw])
        key = ("route_" + hw, "mat_paves" if hw in ("footway", "path", "pedestrian") else "mat_bitume", ROAD_Z.get(hw, ROAD_Z_DEFAULT), "Routes")
    elif aw in AEROWAY_WIDTH:
        width = tag_width(t, AEROWAY_WIDTH[aw])
        key = ("aeroport_" + aw, "mat_bitume", 0.12 if aw != "taxiway" else 0.11, "Aeroport")
    else:
        continue
    for piece in clip_line(w["pts"]):
        piece = clean(piece) if not w["closed"] else piece
        if len(piece) > 1:
            line_batches.setdefault(key, Batch()).add(*ribbon(piece, width))
for (name, mat, z, collection), bt in line_batches.items():
    batch_obj(name, bt, mat, collection, z)

# --- Murs et clotures ---
wall_batches = {}
for w in ways.values():
    kind = w["tags"].get("barrier")
    if kind not in WALL:
        continue
    thick, height = WALL[kind]
    for piece in clip_line(w["pts"]):
        piece = clean(piece) if len(piece) > 2 else piece
        if len(piece) < 2 or all(on_waterfront(*p) for p in piece):
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

bld_batches = {}
nb_bld = 0
for wid, t, pts in buildings:
    poly = clean(pts)
    if len(poly) < 3 or abs(area(poly)) < 4.0:
        continue
    cx = sum(p[0] for p in poly) / len(poly)
    cy = sum(p[1] for p in poly) / len(poly)
    if not inside_box((cx, cy)) or on_waterfront(cx, cy):
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
    elif kind == "retail":
        h = 8.0
    else:
        h = (1 + seed % 3) * LEVEL_H  # 1 a 3 niveaux, varie mais stable d'un import a l'autre
    if kind == "hangar":
        mat = "mat_tole"
    elif kind == "roof" or t.get("amenity") == "shelter":
        mat = "mat_tole_rouillee"
    elif t.get("aeroway") == "terminal":
        mat = "mat_peinture_blanc"
    else:
        mat = PAINTS[seed % len(PAINTS)]
    # Regroupes par materiau : quelques objets au lieu de milliers (bien plus leger pour Godot)
    bld_batches.setdefault(mat, Batch()).add(*prism(poly, 0.0, h))
    nb_bld += 1
for mat, bt in bld_batches.items():
    batch_obj("bld_" + mat[4:] + "-col", bt, mat, "Batiments", 0)

# ---------- Sauvegarde et export ----------
for m in MAT.values():
    m.use_fake_user = False
bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
bpy.ops.export_scene.gltf(filepath=OUT_GLB, export_format="GLB", export_apply=True, export_yup=True)
print(f"Zone : {XMAX - XMIN:.0f} m x {YMAX - YMIN:.0f} m, batiments : {nb_bld}, routes : {len(line_batches)} types, cote : {'oui' if coast else 'non'}")
