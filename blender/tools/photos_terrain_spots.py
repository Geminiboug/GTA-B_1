# GTB : emplacements reels pour les photos de terrain (docs/photos_terrain.md), a partir de la carte du jeu.
# Lancement (WSL) : ~/.venvs/geo/bin/python blender/tools/photos_terrain_spots.py  (tableaux markdown sur la sortie)
import json, math, sys
import xml.etree.ElementTree as ET
import numpy as np

R = '/home/olympe/GTA-B_1/'
lat0, lon0 = 6.3498725, 2.3813795
KX = 111320.0 * math.cos(math.radians(lat0))
KY = 110540.0


def gps(x, z):
    return (lat0 - z / KY, x / KX + lon0)


def lien(x, z):
    la, lo = gps(x, z)
    return "[%.5f, %.5f](https://www.google.com/maps?q=%.6f,%.6f)" % (la, lo, la, lo)


d = json.load(open(R + 'godot/assets/data/zone_aeroport.json'))
g = np.load(R + 'refs/open_buildings/hauteurs_locales-fidjrosse.npz')
H, X0, Y0 = g['height'], float(g['x0']), float(g['y0'])

osm = ET.parse(R + 'refs/osm/zone-gtb-fidjrosse.osm').getroot()
nodes = {}
for n in osm.iter('node'):
    nodes[n.get('id')] = (float(n.get('lat')), float(n.get('lon')))


def game(la, lo):
    return ((lo - lon0) * KX, -(la - lat0) * KY)


# rues OSM nommees et points d'interet nommes (pour situer)
rues = []      # (nom, [(x, z)])
for w in osm.iter('way'):
    t = {x.get('k'): x.get('v') for x in w.iter('tag')}
    if 'highway' in t:
        pts = [game(*nodes[nd.get('ref')]) for nd in w.iter('nd') if nd.get('ref') in nodes]
        rues.append((t.get('name', ''), t['highway'], t.get('surface', ''), pts))
poi = []       # (nom, genre, x, z)
for el in list(osm.iter('node')) + list(osm.iter('way')):
    t = {x.get('k'): x.get('v') for x in el.iter('tag')}
    genre = t.get('amenity') or t.get('shop') or t.get('place') or t.get('tourism') or t.get('leisure') or t.get('natural')
    if not genre:
        continue
    if el.tag == 'node':
        x, z = game(float(el.get('lat')), float(el.get('lon')))
    else:
        ps = [game(*nodes[nd.get('ref')]) for nd in el.iter('nd') if nd.get('ref') in nodes]
        if not ps:
            continue
        x, z = sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps)
    poi.append((t.get('name', ''), genre, x, z))


def dseg(p, a, b):
    ax, az = a; bx, bz = b; px, pz = p
    vx, vz = bx - ax, bz - az
    L = vx * vx + vz * vz
    t = 0 if L == 0 else max(0, min(1, ((px - ax) * vx + (pz - az) * vz) / L))
    return math.hypot(px - ax - t * vx, pz - az - t * vz)


def rue_proche(x, z):
    best = (1e9, '', '')
    for nom, hw, surf, pts in rues:
        if hw in ('footway', 'path', 'cycleway', 'construction'):
            continue
        for i in range(len(pts) - 1):
            dd = dseg((x, z), pts[i], pts[i + 1])
            if dd < best[0]:
                best = (dd, nom, hw)
    return best


def repere(x, z):
    best = None
    for nom, genre, px, pz in poi:
        if not nom:
            continue
        dd = math.hypot(px - x, pz - z)
        if best is None or dd < best[0]:
            best = (dd, nom, genre)
    return best


def situe(x, z):
    dd, nom, hw = rue_proche(x, z)
    r = repere(x, z)
    s = "rue : %s" % (nom if nom else "sans nom (%s)" % {"residential": "rue de quartier", "service": "voie de service", "tertiary": "rue principale du quartier", "secondary": "grand axe", "primary": "grand axe", "unclassified": "rue"}.get(hw, hw))
    if r and r[0] < 250:
        s += ", a %d m de « %s » (%s)" % (r[0], r[1], r[2])
    return s


def secteur(x, z):
    if x < -1250:
        return "Fidjrosse"
    if x < -650:
        return "Fiyegnon / ouest de Cadjehoun"
    if z < -650:
        return "Haie Vive / Cadjehoun"
    return "Aeroport / Route des Peches"


def hauteur(pts):
    vals = []
    xs = [p[0] for p in pts]; zs = [p[1] for p in pts]
    cx, cz = sum(xs) / len(xs), sum(zs) / len(zs)
    for dx in range(-3, 4):
        for dz in range(-3, 4):
            ix = int(cx + dx - X0); iy = int(-(cz + dz) - Y0)
            if 0 <= iy < H.shape[0] and 0 <= ix < H.shape[1]:
                v = H[iy, ix]
                if v == v and v > 0.5:
                    vals.append(v)
    return (float(np.median(vals)) if len(vals) > 20 else -1), cx, cz


def aire(pts):
    a = 0
    for i in range(len(pts)):
        a += pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1]
    return abs(a) / 2


cats = {"plain-pied": (2.5, 4.5), "R+1": (5.5, 7.5), "R+2 ou plus": (8.5, 15)}
choix = {c: {} for c in cats}
for b in d['buildings']:
    if str(b.get('style', '')).startswith('lieu_') or b.get('style') in ('terminal', 'hangar'):
        continue
    if not (60 < aire(b['pts']) < 500):
        continue
    h, cx, cz = hauteur(b['pts'])
    if h < 0:
        continue
    dd, nom, hw = rue_proche(cx, cz)
    if dd > 16 or hw in ('service',):
        continue
    for c, (lo, hi) in cats.items():
        if lo <= h <= hi:
            sec = secteur(cx, cz)
            lst = choix[c].setdefault(sec, [])
            if len(lst) < 2 and all(math.hypot(cx - o[0], cz - o[1]) > 150 for o in lst):
                lst.append((cx, cz, h, b['roof']))

print("## FACADES")
for c in cats:
    for sec, lst in choix[c].items():
        for cx, cz, h, roof in lst:
            print("|", c, "|", sec, "|", lien(cx, cz), "|", "%.0f m mesures, toit %s" % (h, roof), "|", situe(cx, cz), "|")

print("## SOLS (rues OSM avec revetement connu)")
vus = {}
for nom, hw, surf, pts in rues:
    if not surf or hw in ('footway', 'path', 'cycleway', 'construction') or len(pts) < 2:
        continue
    k = surf
    m = pts[len(pts) // 2]
    lst = vus.setdefault(k, [])
    if len(lst) < 3 and all(math.hypot(m[0] - o[0], m[1] - o[1]) > 400 for o in lst):
        lst.append(m)
        print("|", surf, "|", hw, "|", secteur(*m), "|", lien(*m), "|", situe(*m), "|")

print("## POI")
for nom, genre, x, z in poi:
    if genre in ('marketplace', 'fuel', 'school', 'motorcycle_parking', 'restaurant', 'bar', 'pub', 'supermarket', 'tree',
                 'neighbourhood', 'village', 'beach', 'hairdresser', 'clothes', 'bakery', 'convenience', 'car_repair',
                 'pharmacy', 'shelter', 'fire_station', 'police', 'nightclub'):
        print("|", genre, "|", nom or "-", "|", secteur(x, z), "|", lien(x, z), "|", situe(x, z), "|")

print("## MEDIANS")
for m in d['medians'][:31:6]:
    print("|", secteur(*m[0]), "|", lien(*m[len(m) // 2]), "|", situe(*m[len(m) // 2]), "|")

print("## ROUTE DES PECHES / AXES")
for nom, hw, surf, pts in rues:
    if nom in ("Route des Pêches", "Avenue Pape Jean-Paul II"):
        m = pts[len(pts) // 2]
        print("|", nom, "|", secteur(*m), "|", lien(*m), "|")

print("## LIEUX")
for k, v in d['lieux'].items():
    ps = v['pts']
    print("|", k, "|", lien(sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps)), "|")
for nom, x, z in [("epave", -177, 247), ("haie_vive", -150, -840), ("cadjehoun", 550, -1080), ("sweet dream", 622, 292), ("maquis la plaja", -159, 54)]:
    print("|", nom, "|", lien(x, z), "|", situe(x, z), "|")
