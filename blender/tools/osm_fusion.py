# GTB : fusion de plusieurs extraits OSM (.osm XML de l'API 0.6) en un seul, sans doublons (meme id = meme objet,
# la version la plus recente est gardee). Sert a agrandir la zone par morceaux (l'API refuse les trop grandes emprises).
# Lancement : python3 osm_fusion.py <sortie.osm> <entree1.osm> <entree2.osm> [...]
import sys
import xml.etree.ElementTree as ET

out, entrees = sys.argv[1], sys.argv[2:]
objets = {"node": {}, "way": {}, "relation": {}}
bornes = None
for f in entrees:
    racine = ET.parse(f).getroot()
    for el in racine:
        if el.tag == "bounds":
            b = [float(el.get(k)) for k in ("minlat", "minlon", "maxlat", "maxlon")]
            bornes = b if bornes is None else [min(bornes[0], b[0]), min(bornes[1], b[1]), max(bornes[2], b[2]), max(bornes[3], b[3])]
        elif el.tag in objets:
            i = el.get("id")
            old = objets[el.tag].get(i)
            if old is None or int(el.get("version", "0")) >= int(old.get("version", "0")):
                objets[el.tag][i] = el
racine = ET.Element("osm", {"version": "0.6", "generator": "gtb osm_fusion"})
if bornes:
    ET.SubElement(racine, "bounds", {"minlat": str(bornes[0]), "minlon": str(bornes[1]), "maxlat": str(bornes[2]), "maxlon": str(bornes[3])})
for tag in ("node", "way", "relation"):
    for i in sorted(objets[tag], key=int):
        racine.append(objets[tag][i])
ET.ElementTree(racine).write(out, encoding="UTF-8", xml_declaration=True)
print("fusion :", {k: len(v) for k, v in objets.items()}, "bornes", bornes)
