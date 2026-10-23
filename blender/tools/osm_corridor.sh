#!/bin/bash
# GTB : telecharge par morceaux (Overpass API, donnees OpenStreetMap ODbL) le couloir qui va de l'est de la zone actuelle
# (lon 2,414) jusqu'a Seme City (EPITECH Benin, ~lon 2,64), en tranches de 0,036 degre de longitude (~4 km) : l'API refuse
# les trop grandes emprises. Sortie : refs/osm/est/est_<lon_min>_<lon_max>.osm (routes, batiments, eau, plage, usages du sol).
# Ensuite : python3 blender/tools/osm_fusion.py refs/osm/zone-gtb-<palier>.osm refs/osm/zone-gtb-complet.osm refs/osm/est/est_*.osm
# puis osm_import.py sur ce fichier (voir docs/agrandissement_est.md).
# Lancement : bash blender/tools/osm_corridor.sh [lat_min] [lat_max]
set -e
LAT_MIN=${1:-6.33}
LAT_MAX=${2:-6.40}
cd "$(dirname "$0")/../.."
mkdir -p refs/osm/est
LON=2.414
while awk "BEGIN{exit !($LON < 2.65)}"; do
  NEXT=$(awk "BEGIN{printf \"%.3f\", $LON + 0.036}")
  OUT="refs/osm/est/est_${LON}_${NEXT}.osm"
  if [ ! -s "$OUT" ]; then
    echo "tranche $LON -> $NEXT"
    B="$LAT_MIN,$LON,$LAT_MAX,$NEXT"
    curl -s -m 300 -A 'GTB-gamedev/1.0 (import hors ligne)' --data-urlencode \
      "data=[out:xml][timeout:240];(way[\"highway\"]($B);way[\"building\"]($B);way[\"natural\"~\"water|beach|wetland\"]($B);way[\"landuse\"]($B);way[\"leisure\"]($B);way[\"amenity\"]($B););(._;>;);out meta;" \
      https://overpass-api.de/api/interpreter -o "$OUT"
    sleep 5
  fi
  LON=$NEXT
done
ls -la refs/osm/est
