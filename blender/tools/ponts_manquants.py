# GTB : comble les coupures du reseau routier (demande d'Olympe du 21/10/2026 : "voies qui ne menent nulle part").
# Lit godot/assets/data/zone_aeroport.json (routes deja importees), cherche les extremites de routes qui ne touchent aucune
# autre route (hors bord de carte) et qui sont tout pres d'une autre route :
#   - routes principales / secondaires / tertiaires de meme nom : jusqu'a 450 m (morceaux d'un meme axe coupes par
#     l'extraction par morceaux de l'API OSM) ;
#   - rues residentielles et non classees : jusqu'a 60 m ;
# a condition que le raccord droit ne traverse ni batiment ni mur d'enceinte. Les raccords sont ecrits en OSM XML
# (nouveaux noeuds et chemins a identifiants negatifs, tag gtb:raccord=1) a fusionner avec osm_fusion.py :
#   python3 ponts_manquants.py godot/assets/data/zone_aeroport.json refs/osm/ponts-manquants.osm
#   python3 osm_fusion.py refs/osm/zone-gtb-complet.osm refs/osm/zone-gtb-ouest-est.osm refs/osm/ponts-manquants.osm
# puis relancer osm_import.py sur zone-gtb-complet.osm. Donnees OSM : (c) les contributeurs d'OpenStreetMap, licence ODbL.
import collections
import json
import math
import sys

JSON_IN, OSM_OUT = sys.argv[1], sys.argv[2]
LAT0, LON0 = 6.3498725, 2.3813795
KX = 111320.0 * math.cos(math.radians(LAT0))
KY = 110540.0
d = json.load(open(JSON_IN))
b = d["bounds"]
roads = d["roads"]
CELL = 40
IMPORTANTES = ("primary", "secondary", "tertiary", "trunk")
LOCALES = ("residential", "unclassified")


def seg_dist(p, a, c):
    ax, ay = a
    cx, cy = c
    px, py = p
    dx, dy = cx - ax, cy - ay
    L = dx * dx + dy * dy
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
    return math.dist(p, (ax + t * dx, ay + t * dy)), (ax + t * dx, ay + t * dy)


grid = collections.defaultdict(list)
for i, r in enumerate(roads):
    p = r["pts"]
    for j in range(len(p) - 1):
        x0, y0 = p[j]
        x1, y1 = p[j + 1]
        for cx in range(int(min(x0, x1) // CELL) - 1, int(max(x0, x1) // CELL) + 2):
            for cy in range(int(min(y0, y1) // CELL) - 1, int(max(y0, y1) // CELL) + 2):
                grid[(cx, cy)].append((i, j))


def connecte(pt, ri):
    cx, cy = int(pt[0] // CELL), int(pt[1] // CELL)
    for (i, j) in grid[(cx, cy)]:
        p = roads[i]["pts"]
        if i == ri and j in (0, len(p) - 2):
            continue
        if seg_dist(pt, p[j], p[j + 1])[0] < 4.0:
            return True
    return False


def bord(pt):
    m = 8.0
    return pt[0] < b[0] + m or pt[0] > b[2] - m or pt[1] < b[1] + m or pt[1] > b[3] - m


bl = d["buildings"]
bg = collections.defaultdict(list)
for k, bb in enumerate(bl):
    xs = [q[0] for q in bb["pts"]]
    ys = [q[1] for q in bb["pts"]]
    for cx in range(int(min(xs) // CELL), int(max(xs) // CELL) + 1):
        for cy in range(int(min(ys) // CELL), int(max(ys) // CELL) + 1):
            bg[(cx, cy)].append(k)


def pt_in_poly(x, y, poly):
    c = False
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (y0 > y) != (y1 > y) and x < (x1 - x0) * (y - y0) / (y1 - y0) + x0:
            c = not c
    return c


def coupe_batiment(a, c):
    n = int(math.dist(a, c) / 3) + 1
    for s in range(n + 1):
        x = a[0] + (c[0] - a[0]) * s / n
        y = a[1] + (c[1] - a[1]) * s / n
        for k in bg[(int(x // CELL), int(y // CELL))]:
            if pt_in_poly(x, y, bl[k]["pts"]):
                return True
    return False


def inter(a, c, p, q):
    def o(u, v, w):
        return (v[0] - u[0]) * (w[1] - u[1]) - (v[1] - u[1]) * (w[0] - u[0])
    return o(a, c, p) * o(a, c, q) < 0 and o(p, q, a) * o(p, q, c) < 0


murs = d.get("walls", [])
mg = collections.defaultdict(list)
for k, w in enumerate(murs):
    pts = w["pts"] if isinstance(w, dict) else w
    for j in range(len(pts) - 1):
        for cx in range(int(min(pts[j][0], pts[j + 1][0]) // CELL), int(max(pts[j][0], pts[j + 1][0]) // CELL) + 1):
            for cy in range(int(min(pts[j][1], pts[j + 1][1]) // CELL), int(max(pts[j][1], pts[j + 1][1]) // CELL) + 1):
                mg[(cx, cy)].append((pts[j], pts[j + 1]))


def coupe_mur(a, c):
    vus = set()
    for cx in range(int(min(a[0], c[0]) // CELL), int(max(a[0], c[0]) // CELL) + 1):
        for cy in range(int(min(a[1], c[1]) // CELL), int(max(a[1], c[1]) // CELL) + 1):
            for (p, q) in mg.get((cx, cy), []):
                if (tuple(p), tuple(q)) in vus:
                    continue
                vus.add((tuple(p), tuple(q)))
                if inter(a, c, p, q):
                    return True
    return False


cand = []
for i, r in enumerate(roads):
    kind = r["kind"]
    if kind not in IMPORTANTES + LOCALES:
        continue
    p = r["pts"]
    for k in (0, len(p) - 1):
        pt = p[k]
        if bord(pt) or connecte(pt, i):
            continue
        best = None
        cx, cy = int(pt[0] // CELL), int(pt[1] // CELL)
        R = 12
        for gx in range(cx - R, cx + R + 1):
            for gy in range(cy - R, cy + R + 1):
                for (ii, jj) in grid.get((gx, gy), []):
                    if ii == i:
                        continue
                    q = roads[ii]["pts"]
                    dd, near = seg_dist(pt, q[jj], q[jj + 1])
                    if best is None or dd < best[0]:
                        best = (dd, near, ii)
        nm = r.get("name", "")
        if kind in IMPORTANTES and nm:
            # axe nomme coupe : on relie d'abord l'extremite la plus proche d'un autre morceau du meme nom
            bn = None
            for ii, r2 in enumerate(roads):
                if ii == i or r2.get("name", "") != nm:
                    continue
                for e in (r2["pts"][0], r2["pts"][-1]):
                    dd = math.dist(pt, e)
                    if 4.0 < dd < 450 and (bn is None or dd < bn[0]) and not coupe_batiment(pt, e):
                        bn = (dd, e, ii)
            if bn:
                best = bn
        if not best:
            continue
        meme_nom = (nm == roads[best[2]].get("name", "")) if nm else False
        limite = 450 if (kind in IMPORTANTES and meme_nom) else (60 if kind in LOCALES else 0)
        if best[0] <= limite and not coupe_batiment(pt, best[1]) and not coupe_mur(pt, best[1]):
            cand.append((kind, nm, pt, best[1], r.get("width", 6.0)))
# OSM XML
lignes = ["<?xml version='1.0' encoding='UTF-8'?>", "<osm version=\"0.6\" generator=\"gtb ponts_manquants\">"]
nid = -1000000
for n, (kind, nm, a, c, w) in enumerate(cand):
    ids = []
    for pt in (a, c):
        nid -= 1
        ids.append(nid)
        x, y = pt[0], -pt[1]                      # le JSON porte (x, -y) : y vers le nord dans Blender
        lignes.append(f'<node id="{nid}" visible="true" version="1" lat="{LAT0 + y / KY:.7f}" lon="{LON0 + x / KX:.7f}"/>')
    lignes.append(f'<way id="{-2000000 - n}" visible="true" version="1"><nd ref="{ids[0]}"/><nd ref="{ids[1]}"/>'
                  f'<tag k="highway" v="{kind}"/>' + (f'<tag k="name" v="{nm}"/>' if nm else '') + '<tag k="gtb:raccord" v="1"/></way>')
lignes.append("</osm>")
open(OSM_OUT, "w", encoding="utf-8").write("\n".join(lignes))
c = collections.Counter(x[0] for x in cand)
print("raccords :", len(cand), dict(c))
