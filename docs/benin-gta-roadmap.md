# GTB (Gbê Town Bénin) : Roadmap et prompt de passation

Derniere mise a jour : 15/10/2026
Phase en cours : validation des jalons 3, 4 et 5 par Olympe, animations Quaternius a integrer, puis Phase 7 (gameplay)

---

## 1. Vision

Un jeu open world 3D type GTA, ancre dans le Benin. On commence par UNE zone (aeroport de Cotonou, Erevan, la plage), jouable de bout en bout, puis on etend.

## 2. Decisions actees

- Cible : PC d'abord, export web possible plus tard (hypothese par defaut, a confirmer)
- Moteur : Godot 4.7
- Modelisation : Blender, export glTF 2.0 (.glb)
- Echelle : 1 unite = 1 metre, axe Z vers le haut dans Blender, export en Y up
- Premiere zone : aeroport de Cotonou (Cadjehoun), Erevan, la plage (remplace Zogbo, decision du 14/10/2026)
- Style : semi-realiste, low a mid poly pour tenir sur PC modeste
- Pas de textures image avant la Phase 6 : materiaux proceduraux (shaders godot/shaders/*.gdshader : facades, sols, mer, ciel)
- Nom : GTB, Gbê Town Bénin (ne jamais utiliser GTA ni "Grand Theft" pour eviter un conflit de marque)
- Langue du jeu : francais (et possibilite d'ajouter fon/anglais plus tard)

## 3. Ce dont tu as besoin

Logiciels (tous gratuits) :
- Blender 4.x
- Godot 4.x (version standard, pas .NET sauf si tu veux du C#)
- Git + GitHub (depot prive du projet)
- Krita ou GIMP (textures), Audacity (sons)
- Import OSM : importeur maison blender/tools/osm_import.py (Blender-OSM non disponible)

Ressources :
- Photos et videos de reference de la zone aeroport (rues, enseignes, zem, Erevan, plage, poteaux, maisons)
- Releve terrain : prendre des photos a plat de facades, carrefours, sols
- Animations humanoides : Mixamo (gratuit)
- Sons ambiance : enregistrements terrain (klaxons, zem, marche, appels a la priere, musique) + libres de droits
- Textures : ambientCG, Poly Haven (CC0), plus tes propres photos

Materiel :
- Verifier GPU et RAM (voir ton PC) : fixe le budget de polygones et la taille des textures

## 4. Roadmap

### Phase 0 : Cadrage et setup
- [x] Creer le depot Git (structure : /blender, /godot, /docs, /refs)
- [x] Installer Blender, Godot, Blender-OSM
- [x] Choisir le nom du projet : GTB (Gbê Town Bénin)
- [x] Definir la zone exacte aeroport / Erevan / plage : bbox N 6.353365, S 6.346380, O 2.375259, E 2.387500 (environ 1,35 km x 0,78 km), fichier refs/osm/zone-aeroport.osm
- [x] Collecter 50+ photos de reference classees par type (57 images Wikimedia Commons, sources et licences dans refs/SOURCES.md ; photos terrain perso a ajouter)

### Phase 1 : Pipeline assets
- [x] Conventions : echelle, nommage (prefixes bld_, prop_, veh_, chr_), origines des objets (docs/PIPELINE.md)
- [x] Test complet : un cube modelise sous Blender, exporte en .glb, importe dans Godot avec collision
- [x] Script ou procedure d export en un clic (blender/tools/export_glb.py)
- [x] Bibliotheque de materiaux de base (20 materiaux, blender/materials/lib_materiaux.blend et godot/assets/materials/)

### Phase 2 : Blockout de la zone aeroport
- [x] Import du plan des rues (importeur maison blender/tools/osm_import.py, Blender-OSM indisponible)
- [x] Ajustement des rues, carrefours, trottoirs, relief reel (littoral Sentinel-2, batiments Overture, relief plat conserve)
- [x] Blockout des batiments (volumes simples, hauteurs estimees, a affiner)
- [x] Placement des reperes importants (terminal, tour, Ararat, ronds-points, Epave Volante, plage, maquis : blender/tools/landmarks.py)
- [x] Import dans Godot, test de balade en camera libre
- [x] Jalon : "le quartier est reconnaissable en blockout" (valide par Olympe le 14/10/2026)

### Phase 3 : Joueur a pied
- [x] Personnage 3e personne (marche, course, saut, camera) : godot/scenes/player.tscn, godot/scripts/player.gd (capsule en attendant le modele)
- [x] Animations (idle, walk, run, jump) : humanoide fait par script + animation procedurale (provisoire)
- [ ] Locomotion facon GTA V (etape 16) : squelette humanoide standard + clips mocap Quaternius (CC0), machine a etats avec root motion, demarrages, arrets, pivots, IK, ragdoll. Diagnostic fait (docs/diagnostic_locomotion.md), en attente du pack
- [x] Mode debug (F1 : infos, chemins des PNJ ; touches 1 a 8 : teleportation) et checklist docs/validation_phases_3_5.md
- [x] Collisions propres avec le decor (test auto godot/tests/test_player.gd ; murs OSM obsoletes sur la plage retires, promenade sans collision)
- [ ] Jalon : balade fluide dans tout le quartier (a valider par Olympe)

### Phase 4 : Le zem (premier vehicule)
- [x] Modele de moto-taxi (blender/tools/build_zem.py, 125 cc generique)
- [x] Controleur (acceleration, freinage, virages, inclinaison) : godot/scripts/zem.gd
- [x] Monter / descendre (E), camera vehicule (zem_camera.gd)
- [x] Sons moteur et klaxon (synthese temps reel, zem_audio.gd)
- [ ] Jalon : conduire un zem de l aeroport a la plage (a valider par Olympe)

### Phase 5 : Ville vivante
- [x] PNJ pietons (marche sur les bas-cotes, vendeurs assis, porteuses de bassine, plateau ou glaciere, sacs, telephones) : pedestrians.gd
- [x] Personnages realistes (etapes 12 a 15) : tailles et mensurations reelles, 10 morphologies (minces, forts, ages, enfants), 7 traits du visage par PNJ, 10 teintes de peau, coiffures (implantation reelle, tresses, vanilles, foulards, bonnet, casque), tenues (wax, boubou, maillots de clubs fictifs, zemidjans casques numerotes, police fictive, agents de l aeroport)
- [x] Avions de ligne (decollage, atterrissage, roulage, retour au poste), balisage et PAPI
- [x] Interieurs : maison du joueur, Ararat Hypermarket, terminal
- [x] Trafic (zems avec conducteur, voitures, sur le reseau reel) : traffic.gd
- [x] Cycle jour/nuit et eclairage (lampadaires, coupures de courant)
- [x] Ambiances sonores (ressac, ville, oiseaux, grillons, moteurs, klaxons) synthetisees
- [ ] Jalon : le quartier "respire"

### Phase 6 : Modelisation detaillee et textures
- [ ] Remplacer le blockout par des batiments detailles (fait en partie : hauteurs reelles mesurees, toits en tole, bandeaux, balcons, auvents, piscines et bassins ; reste : kit modulaire de facades, portails, clotures)
- [x] Echelle reelle verifiee par test (tests/test_echelle.gd) et noms fictifs partout (docs/correspondance_noms.md)
- [x] Props locaux (etals, poteaux, lampadaires, enseignes fictives, vehicules, ordures, kpayo, maquis, cabines, avions) : build_props.py + props.gd
- [ ] Textures reelles issues des photos
- [ ] Optimisation (instances, LOD, occlusion) [MultiMesh par quartiers + distances d affichage faits ; 86-97 img/s dehors, 67-71 en interieur en 1280x720 ; LOD des personnages a l etape 17]

### Phase 7 : Gameplay de base
- [ ] Systeme d'argent (FCFA), inventaire, interactions (acheter, parler)
- [ ] UI : HUD, carte, menu (fait : mini-carte, grande carte, GPS ; reste : menus, pause, options, sauvegarde)
- [ ] 3 premieres missions (livraison en zem, course client, achat au marche)
- [ ] Sauvegarde et chargement

### Phase 8 : Tension et consequences
- [ ] Systeme de police / danger
- [ ] Poursuites, amendes
- [ ] Equilibrage

### Phase 9 : Extension
- [ ] Deuxieme quartier, raccord par route
- [ ] Carte globale, deplacement rapide
- [ ] Plus de vehicules et de missions

### Phase 10 : Finition et sortie
- [ ] Optimisation finale, tests sur PC modestes
- [ ] Export (Windows, web si possible)
- [ ] Page de presentation, trailer (contenu TikTok/YouTube pendant le dev)
- [ ] Playtest avec des amis

Option plus tard : multijoueur.

## 5. Journal d'avancement

- 14/10/2026 : roadmap creee, aucune tache faite.
- 14/10/2026 : depot Git local initialise (branche main), structure /blender /godot /docs /refs (sous-dossiers refs par type), .gitignore Godot+Blender, .gitattributes, README. Roadmap deplacee dans docs/.
- 14/10/2026 : depot pousse sur GitHub, logiciels installes.
- 14/10/2026 : premiere zone changee, Zogbo remplace par aeroport / Erevan / plage.
- 14/10/2026 : bbox de la zone fixee, export OSM (186 batiments, 95 routes, piste, Erevan, Route des Peches, plage) dans refs/osm/.
- 14/10/2026 : nom choisi, GTB (Gbê Town Bénin). Decision : pas de textures avant la Phase 6.
- 14/10/2026 : 57 photos de reference collectees sur Wikimedia Commons (aeroport, erevan, plage, rues, vehicules, facades, props). Phase 0 terminee.
- 14/10/2026 : ajout de docs/LEGAL.md (regles legales, noms fictifs) et docs/CREDITS.md (OSM ODbL).
- 14/10/2026 : noms fictifs des lieux de la zone definis dans docs/LEGAL.md.
- 14/10/2026 : projet Godot cree (godot/, scene test_pipeline avec sol, boule physique et camera libre), script d export Blender, docs/PIPELINE.md.
- 14/10/2026 : Blender 5.2 (Microsoft Store) trouve. Cube de test genere et exporte en headless (blender/test/prop_cube_test.blend, godot/assets/models/prop_cube_test.glb), ajoute a test_pipeline.tscn. Godot introuvable sur le PC.
- 14/10/2026 : test du cube valide dans Godot 4.7 (collision OK). Pipeline Blender vers Godot fonctionnel.
- 14/10/2026 : 20 materiaux de base en couleurs unies generes depuis blender/tools/materials.json (Blender + Godot). Phase 1 terminee.
- 14/10/2026 : importeur OSM maison ecrit. Blockout de la zone genere (180 batiments, routes, piste, tarmac, plage, mer, murs) : blender/zone/zone_aeroport_blockout.blend, godot/scenes/zone_aeroport.tscn.
- 14/10/2026 : retour Olympe : OSM pas a jour. Batiments remplaces par Overture Maps (594 dans la zone, dont detections Google 2023), plage continue jusqu a la mer, promenade et piste cyclable (amenagement Route des Peches, largeurs estimees). Bug de la plage corrige.
- 14/10/2026 : littoral mesure sur image Copernicus Sentinel-2 du 24/01/2026 (legal) : cote reelle ~120 m plus au sud qu OSM, plage 150 a 250 m. Blockout regenere (545 batiments).
- 14/10/2026 : blockout valide par Olympe ("ressemblant"). Reperes ajoutes (blender/tools/landmarks.py). Phase 2 terminee.
- 14/10/2026 : joueur 3e personne (capsule, ZQSD, Shift course, Espace saut, camera orbitale souris + molette) place dans zone_aeroport.tscn. A tester par Olympe.
- 14/10/2026 : Godot 4.7.2 trouve (Telechargements). Test auto du joueur OK : marche 4 m/s, course 8,5 m/s, saut, aucun blocage depuis la plage. Apparition deplacee sur la plage.
- 14/10/2026 : personnage humanoide low poly (blender/tools/build_character.py) + animation procedurale (character_anim.gd), verifies par captures et test auto. Bug corrige : un objet nomme *_col cree une collision cachee dans Godot.
- 14/10/2026 : retour Olympe (saccades, course pas credible, gigote en l air). Interpolation physique, camera lissee, vitesses reelles (marche 1,6 / trot 4,2 / sprint 7 m/s, Ctrl pour marcher), 3 allures avec phase de vol, saut fige, reception amortie, inertie et inclinaison en virage.
- 14/10/2026 : animations encore jugees pas assez realistes par Olympe -> passage prevu a la Universal Animation Library de Quaternius (CC0, motion capture), Olympe telecharge le pack.
- 14/10/2026 : Phase 4 zem : modele, conduite (bicyclette, adherence, inclinaison), monter/descendre, camera, son synthetise. Tests auto OK (0-65 km/h en 6 s, virage 32 deg, freinage).
- 14/10/2026 : support manette (Xbox / PlayStation / generique) facon GTA V : sticks, gachettes analogiques pour le zem. Test auto tests/test_manette.gd OK.
- 14/10/2026 : limites du monde (murs invisibles, fond marin, retour si chute), ciel realiste avec nuages qui derivent (shader), soleil corrige (il eclairait vers le haut), tonemapping AgX. Olympe signale des erreurs dans l editeur : capture demandee.
- 14/10/2026 : zem ne s enfonce plus dans le sol. Realisme passe 1 : materiaux proceduraux (facades, toits, laterite, sable, bitume, mer animee), SSAO/SSIL. Suite : vegetation, mobilier urbain.
- 14/10/2026 : realisme passe 2 : vegetation (cocotiers de plage, arbres, buissons) repartie automatiquement, troncs avec collision.
- 14/10/2026 : realisme passe 3 : toits (tole 2 pans, parapets, fers en attente, citernes, clims), routes (paves, sable, marquage, bas-cotes, piste d aviation), facades enrichies, etalonnage sRGB des couleurs.
- 14/10/2026 : realisme passe 4 : poteaux et cables, lampadaires, kpayo, vendeuses, maquis, cabines, ordures, voitures et zems gares, panneaux pub et enseignes fictifs, avions aux postes OSM, terminal vitre, hangars, tarmac en dalles.
- 14/10/2026 : realisme passe 5 : cycle jour/nuit (soleil reel, coucher, etoiles, lune), eclairage de nuit, fenetres allumees, delestages. Correction : requetes physiques des props limitees a la couche du decor (presque tout le mobilier de bord de route etait rejete). Suppression du singleton LampRegistry (erreurs dans l editeur reste ouvert).
- 15/10/2026 : passes 6 et 7 : circulation (46 vehicules), pietons (36) et vendeurs assis (56), ambiance sonore synthetisee. Tous les tests passent, aucune erreur.
- 15/10/2026 : passe 8 : decollages et atterrissages sur la vraie piste. Mesure : 120-135 images/s en 1600x900 sur la RTX 2050 d Olympe.
- 15/10/2026 : passe 9 : meteo tropicale (averses, orages avec eclairs et tonnerre, sol et murs mouilles, flaques, sechage). Prompt de passation reecrit. Tous les tests passent.
- 15/10/2026 : passe coherence : couches au sol a plat (joueur et zem poses sur la route, plus dedans), 30 batiments retires de la chaussee (maisons demolies pour la Route des Peches) et 18 retrecis, chaussees separees a la bonne largeur avec terre-plein central ouvert aux carrefours, rues coupees au front de mer, circulation sur le graphe des vrais carrefours (cede-le-passage), pietons sur les trottoirs (traversees aux carrefours, les voitures s arretent), voitures garees sur le bas-cote. Nouveau test tests/test_coherence.gd : tout est coherent.
- 15/10/2026 : passe 11 : mini-carte en haut a gauche, grande carte (M), destination et itineraire GPS (A*), marqueurs (P).
- 15/10/2026 : passes 12 a 14 : hommes, femmes et enfants (6 morphologies, corps continu anime par squelette, vetements ajustes, coiffures), toutes les voitures conduisibles (berline, 4x4, minibus : physique, roulis, freinage, frein a main, degats), reactions des PNJ (klaxon, insultes, chute, fuite, attroupement, coups).
- 15/10/2026 : passe 15 : lieux a interieur. Maison du joueur (concession avec portail, salon, cuisine, chambre, douche, toit-terrasse ; le joueur y commence, lit pour dormir), Ararat Hypermarket (facade vitree face au parking, porte automatique, rayons, primeurs, boulangerie, gros conditionnement, caisses, clients, caissieres, vigile), terminal de l aeroport (comptoirs des compagnies, files, tableau des departs a l heure du jeu, salle d attente, controle de securite, cafe, librairie, voyageurs). Tous les tests passent, 61 images/s minimum.
- 15/10/2026 : passe 16 : avions de ligne (modele Blender detaille, livrees fictives, repoussage, roulage, decollage, approche a 3 degres, arrondi, inverseurs, retour au poste), balisage et PAPI, horizon a 6 km, bandeaux, balcons et auvents. Postes trop etroits pour l envergure exclus automatiquement. test_avion OK sur les deux pistes.
- 15/10/2026 : echelle reelle : reference dans PIPELINE.md ; personnages aux tailles beninoises (homme 1,71 m, femme 1,61 m, enfants 1,27 a 1,30 m ; avant 1,80 et 1,71), portes automatiques de l Ararat (2,8 x 2,5 au lieu de 6 x 3) et du terminal (3,0 x 2,6 au lieu de 8 x 3,2, plus haute que son ouverture), porte de maison 2,10 m, ancien avion de 44 m retire des props. Nouveau test tests/test_echelle.gd : tout est a l echelle.
- 15/10/2026 : carte reelle : hauteurs des batiments mesurees (Google Open Buildings 2.5D 2023, CC BY 4.0 : 169 plain-pied, 232 R+1, 80 R+2, une vingtaine de 12 a 18 m, au lieu d un tirage au hasard), margelles des 14 piscines et bordures beton des 2 bassins (au lieu d aplats bleus), relief Copernicus teste et ecarte (toits et arbres dans le modele), noms verifies fictifs. Credits mis a jour.
- 15/10/2026 : maison du joueur (signale par Olympe) : buffet vitre deplace (il bloquait la porte d entree), poteau de veranda retire de l axe de la porte (4 poteaux). Test : passage libre de la veranda au salon (test_echelle.gd).
- 15/10/2026 : etape 12, corps de base : mensurations reelles (homme poitrine 0,88 / taille 0,80 / hanches 0,85 m, femme 0,83 / 0,73 / 0,88 m, bras et cuisses epaissis ; avant silhouette en baton), pente des epaules, tapettes a la longueur du pied avec bride en V (avant des plaques), tresses sur cheveux (avant crane chauve). Outils : tests/mesure_corps.gd, tests/capture_studio.gd.
- 15/10/2026 : etape 13, morphologies : homme et femme minces, homme et femme ages (dos voute, cheveux poivre et sel, couronne degarnie a la place de la calotte en casque), repartition realiste ; passagers de zem mains sur les cuisses (avant : bras a travers le conducteur), pagnes qui enveloppent les cuisses assis. FPS 74-90 dehors, 67-68 interieurs.
- 15/10/2026 : noms reels renommes (Boulevard de l Envol, Route des Filets, La voix de Gbe Town, immatriculations GB-), mode debug F1 + teleportation 1-8, checklist docs/validation_phases_3_5.md.
- 15/10/2026 : etape 14, visages : 7 traits par PNJ cuits a la creation (aucun cout en jeu), nez ouest-africain, 10 teintes de peau, ligne d implantation reelle (plus de frange en bol), vanilles, bonnet, couronne poivre et sel. FPS 76-88 dehors, 61-72 interieurs.
- 15/10/2026 : etape 15, vetements : epaules propres, zemidjans casques avec numero fictif GT, maillots de clubs fictifs, police fictive et agents de l aeroport, visages varies pour le personnel, plateaux, glacieres, sacs et telephones. FPS 86-97 dehors, 67-71 interieurs.
- 15/10/2026 : etape 16, diagnostic du controleur (docs/diagnostic_locomotion.md : mouvement pilote par la physique, pas de demarrage / arret / pivot, rotation en toupie, cycles sinusoidaux, squelette de 15 os trop simple). Decision d Olympe : squelette humanoide standard + Universal Animation Library de Quaternius (CC0), qu Olympe telecharge.
- 15/10/2026 : roadmap mise a jour (phases, etat actuel).
- 15/10/2026 : etape 16, controles et camera facon GTA V (sans attendre les clips) : sprint en tapotant, endurance cachee et essoufflement, marche lente sur Alt, camera qui se recentre, FOV en sprint, secousse a l atterrissage, 3 vues (V), regard qui suit la camera et les avions. Nouveau test tests/test_controles.gd.

---

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : GTB (Gbê Town Bénin), un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo).

STACK
- Modelisation : Blender 5.2 (Microsoft Store), export glTF 2.0 (.glb), tout par script (blender/tools/)
- Moteur : Godot 4.7.2 (Forward+), physique interpolee, RTX 2050 chez Olympe
- Echelle : 1 unite = 1 metre
- Premiere zone : aeroport de Cotonou (Cadjehoun), Erevan, la plage. Bbox N 6.353365, S 6.346380, O 2.375259, E 2.387500 (environ 1,35 km x 0,78 km), OSM dans refs/osm/zone-aeroport.osm
- Cible : PC d'abord, web ensuite

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly, materiaux proceduraux (pas de textures image) jusqu a la Phase 6
- Nom : GTB (Gbê Town Bénin), jamais GTA ni "Grand Theft"
- Couleurs dans les shaders : ecrites en sRGB, converties en lineaire a la fin (pow 2.2)
- Objets : jamais de nom en *_col / *-col pour un objet decoratif (Godot cree une collision)
- Tout son est synthetise (godot/scripts/audio_synth.gd) ; tout modele est fait par script Blender (blender/tools/)

ETAT ACTUEL (15/10/2026)
- Phases 0, 1, 2 terminees. Phases 3, 4, 5 techniquement faites, jalons a valider par Olympe en jeu avec le mode debug
  (F1, teleportation 1 a 8) et la checklist docs/validation_phases_3_5.md. Phase 6 bien avancee.
- Fait :
  - Monde : zone OSM + batiments Overture + littoral Sentinel-2 + hauteurs reelles Google Open Buildings 2.5D
    (blender/tools/osm_import.py, ob25d_*.py -> godot/assets/data/zone_aeroport.json), piscines et bassins, horizon a 6 km,
    materiaux proceduraux, vegetation, mobilier, enseignes fictives, cycle jour/nuit, meteo, ambiance sonore, coherence.
  - Jeu : joueur a pied, zem et voitures conduisibles, circulation, pietons et reactions, mini-carte + grande carte + GPS,
    interieurs (maison, Ararat Hypermarket, terminal), avions de ligne (air_traffic.gd, avion.gd), balisage et PAPI.
  - Personnages (etapes 12 a 15, blender/tools/build_character.py + godot/scripts/pnj_util.gd) : tailles et mensurations
    reelles, 10 morphologies, visages (7 traits cuits a la creation), 10 teintes de peau, coiffures, tenues, uniformes,
    accessoires. Noms reels remplaces (docs/correspondance_noms.md).
  - Tests : godot/tests/test_*.gd (11 suites : coherence, echelle, vehicules, player, zem, circulation, limites, avion,
    manette, debug) tous OK ; captures : tests/capture_*.gd (planches studio, visages, tenues) ; performances :
    tests/perf_fps.gd en 1280x720 : 86 a 97 images/s dehors, 67 a 71 dans les interieurs.
- Outils : Godot 4.7.2 dans Telechargements (utiliser le _console.exe pour la ligne de commande) ; Blender 5.2 lance via
  %LOCALAPPDATA%/Microsoft/WindowsApps/blender-launcher.exe -b --python ... (voir docs/PIPELINE.md) ; Python geo dans WSL
  (~/.venvs/geo). Envoi git : depuis le git Windows (le git de WSL n'a pas les identifiants), jamais de ligne Co-Authored-By.
- Plan valide par Olympe (une etape a la fois, captures a chaque etape dans docs/images/) :
  - fait : A avions, B echelle reelle, C carte reelle, etapes 12 a 15 (personnages), noms fictifs, mode debug ;
  - en cours : etape 16, locomotion facon GTA V (diagnostic fait ; en attente du pack Quaternius dans Telechargements) :
    squelette humanoide standard, retargeting des clips, AnimationTree en machine a etats avec root motion, controles GTA V
    (sprint en tapotant, marche lente, endurance, saut contextuel, accroupi), IK des pieds, regard, idles, reactions
    physiques et ragdoll, camera GTA V, vehicules (entree / sortie animees, passager), PNJ sur le meme systeme ;
  - ensuite : etape 17 (LOD des personnages et de la simulation), pente reelle de la plage (optionnel), phase 6
    (audit de fidelite des reperes, details urbains, harmattan, kit modulaire), phase 7 (menus, options, sauvegarde,
    interactions, dialogues, missions, histoire "Le Dernier Vol" : prologue et acte 1), phase 8 (police fictive,
    niveau de recherche), phases 9 et 10.
- Reste a faire, signale : cheveux mouilles sous la pluie, casquette de la policiere, traversees du corps pendant la marche
  (a verifier avec les animations de l'etape 16).
- Regles d'Olympe : tout ce qui n'est pas fidele a Cotonou est corrige ou supprime ; aucun nom reel en jeu (signaler
  avant de renommer) ; budget 70 images/s dehors et 60 en interieur ; tests au vert a chaque commit ; demander avant
  tout choix structurant.
- Attention mesures : arreter les Blender / Godot restes en fond avant perf_fps.gd (sinon 10 images/s dans les interieurs).
- Bloquants : aucun. Attention : si l editeur Godot est ouvert pendant qu on modifie project.godot, il faut le fermer et
  rouvrir le projet (sinon erreurs "global uniform does not exist", fichiers non importes).
ROADMAP
Phase 0 Setup, 1 Pipeline assets, 2 Blockout zone aeroport, 3 Joueur a pied, 4 Zem, 5 Ville vivante, 6 Modelisation detaillee, 7 Gameplay de base, 8 Police/danger, 9 Extension, 10 Finition et sortie.

REGLES DE TRAVAIL AVEC OLYMPE
- Repondre en francais, de facon courte et directe, orientee action
- Jamais de tirets cadratins ni de ponctuation "style IA"
- Changements de code minimaux et cibles, pas de reecriture complete
- Livrables prets a copier-coller
- Ne pas lui expliquer ce qu'il peut ou non faire : il vise un vrai GTA du Benin, on avance par petites etapes
- A la fin de chaque tache : dire ce qui est fait, mettre a jour la section ETAT ACTUEL, proposer la suite

LEGALITE (obligatoire)
- Rester dans une stricte legalite. Lire et appliquer docs/LEGAL.md avant tout ajout d asset, nom ou lieu.
- Aucune marque, logo, personne ou lieu reel nomme sans autorisation : utiliser les noms fictifs de docs/LEGAL.md.
- Dans le jeu : uniquement nos creations ou du CC0. Tout asset tiers est note dans docs/CREDITS.md.
- Jamais de co-auteur dans les commits.

MISE A JOUR OBLIGATOIRE DE CE PROMPT
- Ce prompt est un relais entre agents. Avant de terminer ta session (ou quand tu finis une tache), tu dois reecrire ce meme prompt en entier, a jour, pour le prochain agent.
- Mets a jour : ETAT ACTUEL (phase en cours, ce qui est fait, prochaine tache, bloquants), la date, les decisions prises, les conventions ajoutees et les chemins de fichiers importants.
- Garde toutes ces regles, y compris celle-ci, dans la nouvelle version, pour que le suivant fasse pareil.
- Ajoute une ligne au journal d'avancement de benin-gta-roadmap.md et coche les taches terminees.
- Rends le nouveau prompt complet dans un bloc de code, pret a copier-coller.

Commence par lire ETAT ACTUEL et execute la prochaine tache.
```
