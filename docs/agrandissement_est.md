# Agrandissement de la carte vers l'est : Amazone, puis EPITECH (Seme City)

Demande d'Olympe du 23/10/2026 : atteindre la statue de l'Amazone et EPITECH Benin. Etat et plan.

## Ou sont les lieux
- **Monument aux Amazones** : esplanade des Amazones, boulevard de la Marina, lat 6,3489 N, lon 2,4075 E (Wikipedia, "Amazon Monument").
  Il est **deja dans la carte actuelle** (limites lon 2,35 a 2,414) : en coordonnees du jeu (origine 6,3498725 N, 2,3813795 E)
  x = 2890, z = 109. Statue posee par scripts/monument_amazone.gd (monuments.gd _amazone), forme simplifiee en volumes,
  a corriger avec des photos (refs/monuments/amazone/ : a fournir par Olympe).
- **EPITECH Benin** : Seme City (Agence de developpement de Seme City, Seme-Kpodji), a une vingtaine de kilometres a l'est du centre de
  Cotonou (lon ~2,62 a 2,65, lat ~6,38). Coordonnees exactes du campus : a verifier sur OpenStreetMap ou epitech.bj
  (la recherche web n'en donne pas). Les photos du campus (refs/etipech/) sont a fournir par Olympe.

## Principe retenu : un couloir le long de la route
La carte actuelle fait 7 081 x 2 321 m (81 tuiles de 500 m). Aller jusqu'a Seme City ajoute ~23 km de longueur : on n'agrandit pas toute
la zone en largeur, seulement un **couloir** de ~7 km de large en latitude (6,33 a 6,40) le long de la Route des Peches / de la route
nationale, par **paliers** de 4 km. Chaque palier est jouable seul (le joueur y accede par ses vehicules ou l'avion), les tuiles
sont chargees a la demande (monde.gd) et celles qui sont loin sont dechargees.

## Etapes (outils)
1. `bash blender/tools/osm_corridor.sh` : telecharge les tranches de 0,036 degre de longitude (routes, batiments, eau, usages du sol, ODbL)
   dans `refs/osm/est/est_<lon>_<lon>.osm` (non versionne, ~20 Mo par tranche).
2. `python3 blender/tools/osm_fusion.py refs/osm/zone-gtb-palier2.osm refs/osm/zone-gtb-complet.osm refs/osm/est/est_2.414_2.450.osm`
   (fusion sans doublons ; une tranche a la fois : un palier = un fichier).
3. `blender -b --python blender/tools/osm_import.py -- ...` (9 arguments, voir docs/PIPELINE.md) sur le fichier fusionne : tuiles .glb,
   `zone_aeroport.json` (routes, batiments, limites). **L'origine reste figee** (6,3498725 N, 2,3813795 E) : les anciennes positions ne bougent pas.
4. `godot --headless --path godot -s res://tests/outil_cache_carte.gd` (cache de la carte), puis `test_tuiles`, `test_circulation`, `test_densite`.
5. Repeter pour le palier suivant. Les limites du monde (world_bounds.gd) et la mini-carte suivent les limites du JSON.

## Contraintes a surveiller
- Temps de chargement : 67 s actuellement pour 81 tuiles ; ne charger en demarrage que les tuiles autour du joueur (chargement_par_morceaux.md).
- Taille de la carte de grille (carte.gd) et du graphe de rues : a la limite memoire sur mobile.
- Circulation : recyclage autour du joueur deja en place (recycle_dist 320 m).
- Donnees de batiments peu denses a l'est : completer par Overture (overturemaps) comme pour la zone actuelle.
- Noms fictifs pour les lieux et marques (docs/LEGAL.md) ; l'Amazone et EPITECH sont des lieux publics reels, gardes sous leur nom
  (decision d'Olympe pour les monuments ; EPITECH : voir docs/LEGAL.md avant tout logo).
- Progression (docs/benin-gta-roadmap.md) : EPITECH est le palier final ; zones et missions par paliers.

## Etat au 23/10/2026
- Fait : monument aux Amazones dans la carte actuelle, script de telechargement du couloir.
- A faire : fusion + import du palier 2 (lon 2,414 a 2,450) et validation, puis les paliers suivants jusqu'a Seme City ;
  campus EPITECH (batiments Seme One et Seme Two) avec les photos d'Olympe.
