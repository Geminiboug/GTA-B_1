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

## Reperes (separes de l'import OSM)
blender/tools/landmarks.py : terminal (auvent, enseigne, tour de controle), Ararat Hypermarket (totem),
ronds-points (terre-plein, stele), L'Epave Volante (avion), Sweet Dream Beach (paillotes), Maquis La Plaja.
  blender -b --python blender/tools/landmarks.py -- blender/materials/lib_materiaux.blend blender/zone/zone_aeroport_reperes.blend godot/assets/models/zone_aeroport_reperes.glb
Chaque repere est un Empty "rep_*" : deplacer / tourner l'Empty deplace tout le repere. Positions OSM, "approx" dans le code = estime.
Apercus : docs/images/repere_*.png

## Tests automatiques Godot
Godot 4.7.2 : C:\Users\La Paix Technology\Downloads\Godot_v4.7.2-stable_win64.exe\ (utiliser le _console.exe pour la ligne de commande)
  Godot_v4.7.2-stable_win64_console.exe --headless --path godot --import
  Godot_v4.7.2-stable_win64_console.exe --headless --path godot --script res://tests/test_player.gd
test_player.gd : chute, 3 s de marche, 3 s de course, saut, avec les collisions rencontrees.
Regle : pas de collision sur les surfaces plates posees au sol (routes, promenade, parvis), le joueur bute sur leur rebord.
Piege : Godot lit les suffixes -col ET _col (et -colonly, -convcol...) dans les noms d objets. Ne jamais nommer un objet decoratif en *_col (ex : un cou "chr_col" a cree un mur invisible dans le joueur).

## Personnage joueur (blockout)
blender/tools/build_character.py -> blender/chr/chr_joueur.blend + godot/assets/models/chr_joueur.glb
Pieces rigides sur pivots aux articulations (piv_bassin, piv_tronc, piv_tete, piv_epaule_G/D, piv_coude_G/D, piv_hanche_G/D, piv_genou_G/D).
Animation procedurale : godot/scripts/character_anim.gd. 3 allures melangees selon la vitesse (marche 1,6 / trot 4,2 / sprint 7 m/s), phase de vol en course,
pose de saut figee (montee / chute), reception amortie, inclinaison virages et acceleration. Tourne dans _physics_process (interpolation physique active).
Controles : ZQSD trot, Shift sprint, Ctrl marche, Espace saut. Inertie : 9 m/s2 au demarrage, 14 au freinage, virages plus larges en sprint.
Captures des poses : godot --path godot --script res://tests/capture_anim.gd -- <dossier> (ouvre une fenetre quelques secondes). Apercus : docs/images/chr_pose_*.png
Remplacement futur par Mixamo : garder player.gd, remplacer Body/Model et character_anim.gd par un AnimationTree.

## Zem (Phase 4)
Modele : blender/tools/build_zem.py -> blender/veh/veh_zem.blend + godot/assets/models/veh_zem.glb (125 cc generique, sans marque).
Pivots animes : piv_guidon (direction, colonne inclinee), piv_roue_av, piv_roue_ar. Reperes : pt_conducteur, pt_passager.
Scene : godot/scenes/zem.tscn (groupe "vehicules"). Scripts :
- zem.gd : modele bicyclette, couple decroissant, ~80 km/h max, freins, marche arriere lente, adherence limitee (~0,7 g),
  inclinaison physique tan(angle) = v * lacet / g, choc frontal qui coupe la vitesse.
- zem_audio.gd : son synthetise en temps reel (monocylindre 4 temps, boite 4 vitesses, klaxon 2 tons). Aucun fichier audio.
- zem_camera.gd : camera de conduite, se replace derriere la moto, recule et elargit le champ avec la vitesse.
Joueur : E pour monter / descendre (rayon 2,5 m), pose assise dans character_anim.gd (seated).
Controles moto : Z gaz, S frein puis marche arriere, Q / D direction, Espace frein arriere, H klaxon, E descendre.
Tests : tests/test_zem.gd (headless), tests/capture_zem.gd (captures). Apercus : docs/images/zem_*.png

## Commandes (clavier AZERTY + manette)
Nommage Xbox ; PlayStation : A = Croix, B = Rond, X = Carre, Y = Triangle, LB/RB = L1/R1, LT/RT = L2/R2, L3 = clic stick gauche.
| Action | Clavier | Manette |
|---|---|---|
| Bouger / diriger | ZQSD | stick gauche |
| Camera | souris | stick droit |
| Sprint | Shift | A |
| Marcher | Ctrl | L3 |
| Sauter | Espace | X |
| Monter / descendre | E | Y |
| Gaz (zem) | Z | RT (analogique) |
| Frein / marche arriere (zem) | S | LT (analogique) |
| Frein arriere (zem) | Espace | RB |
| Klaxon (zem) | H | L3 |
Les actions sont dans godot/project.godot (generees par un script, voir l historique). Test : tests/test_manette.gd

## Ciel et limites du monde
- Ciel : godot/shaders/ciel_nuages.gdshader (atmosphere, soleil lie a la DirectionalLight3D, cumulus + cirrus en bruit fractal
  qui derivent avec le vent). Reglages dans l'inspecteur du ShaderMaterial : cloud_coverage, wind, cloud_scale, high_cloud_amount.
- Soleil : 55 deg de hauteur, apres-midi. Tonemapping AgX.
- Limites : godot/scripts/world_bounds.gd (noeud "Limites") : murs invisibles x [-677, 677], z [-386, 786], fond marin a -1,2 m
  (on entre dans l'eau jusqu'aux cuisses). Joueur : retour au dernier point sur s'il passe sous y = -20.
- Test : tests/test_limites.gd. Captures du ciel : tests/capture_ciel.gd, docs/images/ciel_*.png
- Avertissement connu : "1 ObjectDB instance was leaked" a la fermeture = AudioStreamGeneratorPlayback du son du zem
  retenu par le serveur audio de Godot. Sans effet en jeu.

## Realisme : materiaux proceduraux (passe 1)
godot/scripts/realism.gd (noeud "Realisme" de la scene) applique au lancement, d'apres le nom des objets importes :
- bld_* : godot/shaders/facade.gdshader (etages de 3 m, fenetres cadre + vitre + grille, rez-de-chaussee portes /
  rideaux metalliques, bandeaux, peinture ecaillee, salissure en bas, toits tole ondulee ou dalle beton)
- mur_* : facade.gdshader en mode plain_wall (enduit sans ouverture)
- sol_terre / plages / routes / tarmac-promenade : godot/shaders/sol.gdshader modes 0 a 3 (laterite, sable, bitume, beton)
- mer : remplacee par une surface subdivisee + godot/shaders/mer.gdshader (houle, ecume du rivage, reflets)
Eclairage : soleil 1,6, ambiance ciel reduite, SSAO + SSIL, leger glow. Apercus : docs/images/realisme_*.png
Zem : collision abaissee au niveau des roues (il ne s'enfoncait plus de 15 cm).

## Realisme : vegetation (passe 2)
Modeles : blender/tools/build_vegetation.py -> blender/veg/vegetation.blend + godot/assets/models/vegetation.glb
(veg_cocotier : tronc courbe annele + palmes + noix ; veg_arbre : neem / manguier ; veg_buisson).
Repartition : godot/scripts/vegetation.gd (noeud "Vegetation"), deterministe (seed) :
- cocotiers en ligne cote mer de la promenade, penches vers la mer ;
- arbres, buissons, quelques cocotiers dans les espaces libres a terre (grille 9 m + hasard).
Jamais sur batiment / mur (requete physique), ni sur route, piste, tarmac, plage, piscine (surfaces temporaires sur la couche 10).
Rendu MultiMesh + collisions cylindriques sur les troncs. Resultat actuel : 258 cocotiers, 531 arbres, 557 buissons.
