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

## Realisme : batiments et routes (passe 3)
osm_import.py (7e argument : godot/assets/data/zone_aeroport.json, donnees pour Godot : routes, batiments, cote, parkings avions) :
- Hauteurs Cotonou : 50 % plain-pied, 35 % R+1, 15 % R+2.
- Toits a 2 pans en tole (rectangle d'aire minimale, debord 45 cm, pignons) pour ~70 % du plain-pied rectangulaire ;
  toits plats : parapet 0,9 m, fers en attente sur poteaux entames (40 %), citerne noire sur pieds (50 %),
  climatiseurs en facade (R+1 et plus). Abris (amenity=shelter) : toit tole ouvert sur poteaux.
- Routes : revetement (tag OSM sinon : axes bitumes, quartiers paves / sable / bitume), bas-cotes sableux,
  marquage (axe en tirets, rives), piste d'aviation (axe, bords, seuils), axe jaune des taxiways.
Shaders : facade = parpaings bruts (1 batiment sur 5), persiennes peintes, portes peintes, boutiques, portails
dans les murs d'enceinte, fenetres allumees la nuit (globals gtb_night / gtb_power). sol = modes 4 paves autobloquants,
5 piste en sable. Couleurs des shaders ecrites en sRGB et converties en lineaire (correction d'un rendu delave).

## Realisme : mobilier urbain, vehicules, enseignes, avions (passe 4)
Modeles : blender/tools/build_props.py -> blender/props/props.blend + godot/assets/models/props.glb
(poteau bois +/- transformateur, lampadaire, etal de kpayo, etals de vendeuses sous parasol x3, tas d'ordures,
pile de pneus, table de maquis + chaises, cabine de transfert d'argent, panneau publicitaire, berline, 4x4, avion).
Placement : godot/scripts/props.gd (noeud "Props"), a partir de godot/assets/data/zone_aeroport.json :
- poteaux tous les ~35 m le long des rues + cables (chainette), lampadaires en quinconce sur les grands axes et la promenade ;
- commerces de bord de route, voitures et zems gares (stations), panneaux publicitaires fictifs ;
- enseignes de boutiques fictives sur les facades qui donnent sur une rue, inscriptions sur les murs d'enceinte ;
- avions aux postes de stationnement OSM (lignes de guidage), livree fictive "AIR GBE".
MultiMesh decoupes en carres de 160 m (affichage limite par la distance) + collisions simples.
Surfaces a eviter (routes, tarmac, piscines, plage...) : creees une fois par realism.gd sur la couche 10.
Styles de facade : bld_terminal = mur-rideau vitre, bld_hangar = bardage tole. Tarmac = dalles beton 5 m (sol mode 6).
Lampes : godot/shaders/lampe.gdshader (allumees la nuit, eteintes en coupure), positions dans l'autoload LampRegistry.

## Cycle jour / nuit (passe 5)
godot/scripts/day_night.gd (noeud "JourNuit") : soleil de Cotonou (lever ~6 h 30 est, zenith a midi, coucher ~18 h 30 ouest),
lune la nuit, ciel (ciel_nuages.gdshader : uniforms sun_dir_u et night ; coucher dore, etoiles, nuages sombres la nuit),
ambiance et brouillard, variables globales gtb_night / gtb_power, pool de 14 SpotLight3D sous les lampadaires proches
(positions dans Props.lamp_positions), delestages aleatoires la nuit (scintillement puis coupure de 1 a 6 min).
48 min reelles = 24 h de jeu. F2 : +1 heure. Horloge en haut a droite. Captures : tests/capture_heures.gd -> docs/images/cycle_*.png
Note : les variables globales gtb_night / gtb_power sont declarees dans project.godot [shader_globals] ; si l'editeur
etait ouvert pendant une modification de project.godot, il faut le fermer et rouvrir le projet.

## Ville vivante (passes 6 et 7)
- godot/scripts/traffic.gd (noeud "Circulation") : 32 zems (conducteur chemise jaune, 35 % avec passager) et 14 voitures sur
  le reseau reel (json). Conduite a droite, sens uniques respectes, choix aleatoire aux carrefours, ralentissement en virage,
  distances de securite, arret devant le joueur + klaxon, AnimatableBody3D (on ne les traverse pas), phares la nuit,
  son moteur en boucle dont la hauteur suit la vitesse.
- godot/scripts/pedestrians.gd (noeud "Pietons") : 36 pietons animes sur le bas-cote droit, tenues variees, 30 % avec une
  bassine sur la tete ; vendeurs / clients assis aux etals, kpayos et maquis (positions fournies par props.gd, MultiMesh).
  Pietons lointains caches et mis a jour une image sur 4.
- godot/scripts/pnj_util.gd : tenues, poses (assis, vendeur), fusion d'un personnage pose en un seul mesh.
- godot/scripts/audio_synth.gd : sons synthetises (moteurs, klaxons, ressac, rumeur de ville, oiseaux, grillons).
- godot/scripts/ambience.gd (noeud "Ambiance") : ressac le long du trait de cote reel, rumeur, oiseaux le jour, grillons la nuit.
Tests : tests/test_circulation.gd (46/46 vehicules roulent, ~27 km/h, arret + klaxon devant le joueur),
tests/perf_frames.gd (cout CPU : ~9 ms de physique par image avec tout actif). Captures : tests/capture_vie.gd.

## Trafic aerien (passe 8) et performances
- godot/scripts/air_traffic.gd (noeud "TraficAerien") : decollages / atterrissages sur l'axe de piste OSM, toutes les 2 a 5 min
  (premier apres 25 s). Decollage : 2,8 m/s2, rotation a ~270 km/h, montee ~10 degres. Atterrissage : approche a 3 degres
  depuis 7 km, freinage apres le toucher. Son de reacteur synthetise (AudioSynth.jet_loop), feu anticollision la nuit.
  Test : tests/test_avion.gd
- Mesure reelle : tests/perf_fps.gd (fenetre 1600x900, synchro coupee) sur RTX 2050 : 120 a 135 images/s selon la vue
  (750 a 1300 objets dessines, 0,8 a 1,5 M de primitives).

## Meteo tropicale (passe 9)
godot/scripts/weather.gd (noeud "Meteo", apres "JourNuit") : episodes degage / nuageux / averse / orage (4 a 12 min),
transitions douces (le ciel se couvre avant la pluie), pluie en particules autour de la camera (discrete la nuit),
sol et murs mouilles via la variable globale gtb_wet (sol.gdshader : plus sombre, brillant, flaques ; facade.gdshader :
ruissellement, toits luisants), sechage lent apres l'averse, eclairs puis tonnerre avec delai, ciel d'orage (uniform storm).
F3 : declencher / arreter l'averse. Captures : tests/capture_meteo.gd -> docs/images/meteo_*.png

## Coherence du monde (passe 10)
- Couches au sol presque a plat (osm_import.py : 0 a 0,03 m au lieu de 0,1 a 0,2 m) : joueur, zem, vehicules et pietons
  sont poses sur la chaussee. L'ordre d'affichage est garanti par sol.gdshader (vertex : la couche la plus haute est
  avancee de quelques mm vers la camera, meme position a l'ecran), donc pas de scintillement de loin.
  Marquage, piste cyclable, herbe, terre-plein et bassins passent aussi par sol.gdshader (modes 7, 8, 9).
- osm_import.py :
  - chaussees separees (deux sens uniques paralleles) : largeur deduite de l'ecart entre les axes (tag lanes sinon) ;
    terre-plein central biseaute (terre_plein-col) avec ouverture goudronnee aux carrefours ;
  - batiments qui debordent sur une chaussee : retrecis, sinon retires (souvent des maisons demolies pour la Route des Peches) ;
  - rues anterieures au front de mer coupees au bord de la piste cyclable, bouts de rue de moins de 6 m au bord du cadre
    supprimes, impasses terminees par une aire de retournement, rues qui s'arretent pres d'une autre raccordees ;
  - JSON : "medians" (axes des terre-pleins).
- godot/scripts/carte.gd (class_name Carte, Carte.zone()) : donnees partagees. Graphe routier sur les noeuds OSM communs
  (carrefours reels, raccord des impasses a moins de 5 m), masques 1 m (chaussees, batiments/murs, terre-pleins),
  itineraire A* (sens uniques respectes).
- traffic.gd : circulation sur le graphe (voie de droite, deux voies sur les boulevards, plutot tout droit aux carrefours,
  cede-le-passage a celui qui est engage, demi-tour en impasse), s'arrete devant les obstacles (groupe "vehicules",
  pietons qui traversent : groupe "obstacles_route"). Signal honked(body, at_player).
- pedestrians.gd : trottoirs / bas-cotes verifies sur le masque, contournement des maisons au bord de la rue, traversees
  droites aux carrefours, 25 % des pietons sur la promenade du front de mer.
- props.gd : rien sur la chaussee (verification du rayon complet), voitures garees sur le bas-cote (liste props.parked).
- Test : tests/test_coherence.gd (batiments, voitures garees, vehicules, pietons sur la chaussee, joueur et zem au sol).
  Captures : tests/capture_coherence.gd (vues du dessus et au sol).

## Mini-carte, grande carte, GPS (passe 11)
godot/scripts/hud_carte.gd (noeud "HUD", CanvasLayer) + godot/shaders/minicarte.gdshader.
- Fond de carte dessine une seule fois au lancement dans un SubViewport (2 px/m) depuis le JSON : zones, plage, mer,
  promenade, pistes, batiments, rues (grands axes jaune pale, rues grises, pistes en terre brunes).
- Mini-carte ronde en haut a gauche : centree sur le joueur, tourne avec la camera, s'eloigne avec la vitesse ;
  nord, fleche du joueur, destination collee au bord si loin, marqueurs proches, nom de la rue et distance restante.
- Grande carte : M (manette Select/Back), jeu en pause. Clic gauche / Entree / A : destination (re-clic : l'enlever),
  clic droit / P / X : marqueur perso (sauve dans user://marqueurs.json), molette / gachettes : zoom,
  glisser / ZQSD / stick : deplacer, M / Echap / B : fermer. Noms des rues nommees et des lieux (noms fictifs, LEGAL.md).
- Itineraire : Carte.route() (A*, sens uniques respectes en vehicule), recalcule toutes les 1,5 s, ligne violette ;
  colonne de lumiere sur la destination ; arrivee a 12 m : effacee + carillon (AudioSynth.ding).
- Clavier : les deplacements acceptent maintenant aussi les lettres ZQSD (AZERTY) et les fleches.
Captures : tests/capture_carte.gd -> docs/images/carte_mini.png, carte_grande.png

## Personnages hommes / femmes (passe 12)
- blender/tools/build_character.py <homme|femme> <.blend> <.glb> [apercu.png] -> godot/assets/models/chr_homme.glb,
  chr_femme.glb (blender/chr/chr_homme.blend, chr_femme.blend). Pieces lisses (sections elliptiques) : torse, bassin,
  membres, mains avec pouce, pieds et semelles ; visage : nez et narines, oreilles, yeux avec paupieres, sourcils, levres ;
  cheveux en coque decoupee selon une vraie ligne d'implantation. Memes pivots piv_* que l'ancien modele.
  Homme 1,76 m (epaules larges) ; femme 1,66 m (taille marquee, hanches, poitrine, cou fin, mains et pieds plus petits).
  Pieces de tenue optionnelles : homme (tee-shirt / chemise, pantalon ou short, boubou + manches larges, casquette,
  chaussures ou sandales) ; femme (haut, pagne court ou long, foulard noue, chignon ou tresses, sandales).
- godot/shaders/wax.gdshader : tissu wax genere (cercles, losanges, vagues, damier ; 3 couleurs vives, palettes dans pnj_util.gd).
- godot/scripts/pnj_util.gd : make(genre) (meta "genre"), random_look / dress_random (tenues realistes : zemidjans en
  chemise jaune, boubous, pagnes et foulards en wax, jeans), bake_groups (pieces de chaque pivot fusionnees : ~12 objets
  par personnage au lieu de ~45), merge (vendeurs assis).
- character_anim.gd : demarche feminine (bassin qui balance, bras plus pres du corps).
- Pietons : moitie femmes, bassine sur la tete surtout chez les femmes ; vendeurs : 3 sur 4 sont des vendeuses ;
  passagers des zems : hommes et femmes. Vendeurs en MultiMesh decoupes par quartiers de 64 m (avant : un groupe etale sur
  toute la carte disparaissait loin du centre de la carte). Mobilier : quartiers de 80 m.
- Joueur : homme (tee-shirt, jean) ; F4 a pied : passer a un personnage femme (pagne et foulard wax) et inversement.
Captures : tests/capture_pnj.gd -> docs/images/pnj_*.png, apercus Blender docs/images/chr_*.png

## Vehicules conduisibles et reactions des PNJ (passe 13)
- blender/tools/build_vehicles.py <dossier_blend> <dossier_glb> [apercus] -> godot/assets/models/veh_berline.glb, veh_4x4.glb,
  veh_minibus.glb (blender/veh/*.blend). Caisse galbee avec passages de roue, vitres teintees transparentes, interieur
  (sieges, tableau de bord, volant a gauche), phares, feux, clignotants, pare-chocs, retroviseurs, poignees, plaques,
  galerie chargee sur le minibus. Pivots : piv_direction_av* (braquage), piv_roue_* (rotation), pt_conducteur, pt_sortie.
- godot/scripts/voiture.gd : conduite arcade-simulation (boite auto, adherence limitee ~0,9 g, sous-virage, derapage au
  frein a main, transfert de masse visible, chocs avec degats -> fumee -> moteur HS, feux stop, phares la nuit, son moteur
  suivant le regime, crissements, filet de securite sous la carte). Mesures : 0-100 km/h 9,1 s, freinage 100-0 38 m.
- godot/scripts/vehicules.gd (class_name Vehicules) : create(modele, couleur) (voiture ou zem), merged(modele) pour la
  circulation et les voitures garees (memes modeles detailles partout).
- E (Y manette) : le vehicule le plus proche : libre, de la circulation a l'arret ou au pas (conducteur et passager
  ejectes, crient au voleur et courent apres), ou gare au bord de la route (props.parked, zems des stations inclus).
  Un vehicule pris est remplace dans la circulation 25 s plus tard, loin du joueur. Minibus "tokpa-tokpa" dans la circulation.
- Reactions (pedestrians.gd) : salutations selon l'heure (bonjour / bonsoir des l'apres-midi) et le genre du joueur,
  vendeuses qui helent, bousculades (bassine qui tombe et marchandise par terre), coup de poing (F, clic gauche, B) :
  chute, colere ou fuite, poursuite ; pieton renverse par le vehicule du joueur (chute dans le sens du choc, se releve,
  engueule le chauffeur), attroupement des passants, vehicules alentour qui s'arretent ; ecart et cri si on les frole.
  Corps des pietons sur la couche 5 (le joueur les heurte, pas les vehicules).
- Repliques : godot/scripts/dialogues.gd (francais du Benin + fon, a completer), bulles godot/scripts/bulle.gd + sous-titres.
- Circulation : s'arrete et klaxonne apres un choc ou un accident proche, le conducteur engueule le joueur (bulle).
Tests : tests/test_vehicules.gd (tout fonctionne), tests/test_coherence.gd. Captures : tests/capture_vehicules.gd.

## Personnages version 3 : corps continu anime par squelette (passe 14)
- blender/tools/build_character.py <homme|homme_fort|femme|femme_ronde|garcon|fille> <.blend> <.glb> [apercu.png]
  -> godot/assets/models/chr_<variante>.glb. Corps d'un seul tenant (modificateur Skin + subdivision 1 : ~4 000 faces),
  formes (poitrine, fesses, ventre), tete detaillee, 15 os (piv_*), pose de repos en A (12 degres).
  Poids : chaque sommet est rattache a la branche du squelette la plus proche (tronc, epaule, bras, hanche, jambe),
  fondus aux articulations ; un sommet dans le volume du torse reste au torse (bras colle au corps).
  Vetements : haut (manches courtes / longues) construit comme un vrai vetement (tube autour du torse et manches,
  plaque sur le corps par lancer de rayons depuis l'axe, ourlets droits) ; pantalon, short, chaussures derives du corps ;
  jupe, pagne long, boubou lestes sur le bassin et les cuisses ; coiffures (courts, afro, tresses, chignon, meches,
  foulard, casquette). Enfants : uniforme scolaire kaki (chemise + short ou jupe).
- godot/scripts/squelette.gd : pilote les os avec des angles dans le repere du personnage (compense la pose en A).
- character_anim.gd : calcule sur des pivots "fantomes" puis recopie sur les os (memes allures qu'avant).
- pnj_util.gd : morphologies au hasard (25 % d'hommes forts, 38 % de femmes rondes, 12 % d'enfants chez les pietons),
  poses fixes via Squelette.pose, fusion des personnages poses (bake_mesh_from_current_skeleton_pose) une fois la pose
  appliquee (2 images plus tard) ; tests sans fenetre : pose de repos.
- Mesure : 96 a 112 images/s en 1600x900 (RTX 2050).
