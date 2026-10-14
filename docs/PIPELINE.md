# GTB : pipeline Blender vers Godot

## Conventions
- Echelle : 1 unite = 1 metre. Blender : Z en haut. L'export glTF convertit en Y en haut.
- Origine des objets : au sol, au centre de la base (un batiment pose a Z = 0).
- Appliquer echelle et rotation avant export : Ctrl+A > All Transforms.
- Nommage des fichiers et objets : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages), en minuscules, sans accents ni espaces. Ex : bld_terminal_aeroport, prop_poteau_sbee.
- Sources : blender/<categorie>/<nom>.blend. Exports : godot/assets/models/<nom>.glb (genere, ne pas modifier a la main).
- Pas de textures avant la Phase 6 : un materiau Principled BSDF avec une couleur unie.

## Collisions (suffixes reconnus par Godot a l'import)
- objet-col : mesh visible + collision exacte (trimesh). Pour le decor statique simple.
- objet-colonly : collision seule, invisible. Pour une forme simplifiee a cote du mesh detaille.
- objet-convcol : collision convexe, plus legere.
Regle : decor detaille = mesh visible sans suffixe + une boite simplifiee en -colonly.

## Test du cube (Phase 1)
1. Blender : nouveau fichier General. Garder le cube par defaut (2 m de cote).
2. Le renommer prop_cube_test-col (double-clic dans l'Outliner).
3. Le monter de 1 m (G, Z, 1, Entree) pour que sa base soit au sol, puis Ctrl+A > All Transforms.
4. Material : couleur unie au choix.
5. Enregistrer sous blender/test/prop_cube_test.blend.
6. Onglet Scripting > Open > blender/tools/export_glb.py > Run Script.
   Resultat : godot/assets/models/prop_cube_test.glb
7. Godot : Import > choisir godot/project.godot.
8. Ouvrir scenes/test_pipeline.tscn, glisser prop_cube_test.glb dans la scene, le placer en (0, 0, 0). Ctrl+S.
9. F5 : la boule tombe et doit rester posee sur le cube. Camera : ZQSD, clic droit maintenu pour tourner, Shift pour accelerer.
Si la boule traverse le cube : le suffixe -col manque ou est mal tape.

## Materiaux de base
- Source unique : blender/tools/materials.json (couleurs sRGB, rugosite, metal, transparence).
- Blender : blender/materials/lib_materiaux.blend. Chaque materiau est un Asset (Asset Browser) avec une sphere d'apercu.
  Pour l'utiliser : Edit > Preferences > File Paths > Asset Libraries > ajouter le dossier blender/materials, puis glisser le materiau depuis l'Asset Browser.
- Godot : godot/assets/materials/<nom>.tres, memes noms que dans Blender.
- Ajouter ou modifier un materiau : editer materials.json, puis regenerer les deux :
  blender -b --python blender/tools/build_materials.py -- blender/tools/materials.json blender/materials/lib_materiaux.blend
  python3 blender/tools/build_godot_materials.py

## Import OpenStreetMap (blockout de zone)
Importeur maison (pas de plugin) : blender/tools/osm_import.py
  blender -b --python blender/tools/osm_import.py -- refs/osm/zone-aeroport.osm blender/materials/lib_materiaux.blend blender/zone/zone_aeroport_blockout.blend godot/assets/models/zone_aeroport.glb
Option : 5e argument = refs/overture/building.geojson (batiments Overture, plus recents qu OSM).
Telechargement : overturemaps download --bbox=2.370,6.343,2.392,6.356 -f geojson --type=building -o refs/overture/building.geojson
Genere : sol (sol_terre-col), mer (prolongee de 400 m au sud), plage continue + promenade-col + piste cyclable (front de mer apres travaux de la Route des Peches, largeurs estimees), zones, routes, piste et taxiways,
batiments extrudes regroupes par materiau (bld_<materiau>-col), murs d enceinte (mur_wall-col).
- Hauteur des batiments : tag height, sinon building:levels x 3 m, sinon 3 a 9 m (stable d'un import a l'autre).
- Repere : origine au centre de la zone, X = est, Y = nord (Blender).
- Le .blend genere est ecrase a chaque import : les retouches manuelles se font dans un autre fichier.
- Godot : scenes/zone_aeroport.tscn (scene principale, F5).
Apercus : docs/images/blockout_zone_aeroport_dessus.png et blockout_zone_aeroport_3d.png

## Littoral mesure par satellite (Sentinel-2, legal)
1. Chercher une image recente sans nuages (STAC earth-search.aws.element84.com, collection sentinel-2-l2a).
2. python blender/tools/s2_crop.py <url TCI.tif> refs/sentinel2/s2_<date>.png
3. python blender/tools/s2_littoral_run.py -> refs/sentinel2/littoral_<date>.geojson (trait de cote + limite de plage)
4. Import avec 6e argument : ... godot/assets/models/zone_aeroport.glb refs/overture/building.geojson refs/sentinel2/littoral_20260124.geojson
Resolution 10 m : bon pour cote, plage, grandes zones ; jamais pour le detail des batiments.
Constat 01/2026 : la cote reelle est ~120 m plus au sud que dans OSM (plage elargie depuis les epis), plage de 150 a 250 m.
