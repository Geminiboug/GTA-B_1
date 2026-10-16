# GTB (Gbê Town Bénin) : Roadmap et prompt de passation

Derniere mise a jour : 16/10/2026
Phase en cours : playtest et validation par Olympe (phases 0 a 10 faites techniquement)

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
- [x] Locomotion facon GTA V (etape 16) : squelette standard, clips Quaternius (CC0), AnimationTree, sprint, saut, escalade, accroupi, IK, chutes captees, ragdoll, entree / sortie de vehicule animees ; etape 17 (LOD) faite
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
- [x] Remplacer le blockout par des batiments detailles (hauteurs reelles, toits en tole, bandeaux, balcons, auvents, piscines, concessions avec murs et portails ; kit modulaire de facades non fait)
- [x] Echelle reelle verifiee par test (tests/test_echelle.gd) et noms fictifs partout (docs/correspondance_noms.md)
- [x] Props locaux (etals, poteaux, lampadaires, enseignes fictives, vehicules, ordures, kpayo, maquis, cabines, avions) : build_props.py + props.gd
- [ ] Textures reelles issues des photos (en attente des releves terrain d Olympe ; harmattan ajoute)
- [x] Optimisation (instances, LOD, occlusion) : MultiMesh, zone en tuiles de 500 m, occultation, LOD et ombres des PNJ, ombres reduites en interieur

### Phase 7 : Gameplay de base
- [x] Systeme d argent (FCFA), inventaire, interactions (acheter, parler)
- [x] UI : HUD, carte, menu (mini-carte, grande carte, GPS, HUD de jeu, ecran titre, pause, options)
- [x] 3 premieres missions (livraison en zem, course client, achat au marche), dans l histoire "Le Dernier Vol"
- [x] Sauvegarde et chargement

### Phase 8 : Tension et consequences
- [x] Systeme de police / danger
- [x] Poursuites, amendes
- [ ] Equilibrage (prix, amendes, chronos, vitesse de la police : valeurs en @export, a ajuster apres le playtest)

### Phase 9 : Extension
- [x] Deuxieme quartier, raccord par route (Haie Verte et Cadjehoue au nord, zone agrandie a 1,35 x 1,6 km)
- [x] Carte globale, deplacement rapide (grande carte de toute la zone, zems depuis les stations)
- [x] Plus de vehicules et de missions (pick-up, missions de Maman Fifi, petits boulots de zem)

### Phase 10 : Finition et sortie
- [x] Optimisation finale, tests sur PC modestes (prereglage Bas : 83-104 img/s dehors, 66-70 en interieur ; Haut a remesurer editeur ferme)
- [x] Export (Windows verifie ; web exporte, a verifier dans un vrai navigateur)
- [x] Page de presentation (docs/presentation.html) ; trailer a faire (capture video par Olympe)
- [ ] Playtest avec des amis (fiche prete : docs/playtest.md)

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
- 15/10/2026 : etape 16, controles et camera facon GTA V (sans attendre les clips) : sprint en tapotant, endurance cachee et essoufflement, marche lente sur Alt, camera qui se recentre, FOV en sprint, secousse a l atterrissage, 3 vues (V), regard qui suit la camera et les avions, postures des PNJ (ages voutes et plus lents, porteuses au buste droit, main sur la tete sous l averse). Nouveau test tests/test_controles.gd.
- 15/10/2026 : etape 16, squelette standard : personnages reconstruits sur le squelette Quaternius (23 os), retargeting Godot (profil humanoide), 86 clips de capture de mouvement CC0 verifies sur nos morphologies ; ancien code compatible (squelette.gd). Tests au vert, FPS 74-94 dehors, 66-69 interieurs.
- 15/10/2026 : etape 16, joueur anime par les clips (anim_ctrl.gd : marche, trot, sprint, saut, conduite, regard), lecture calee sur la vitesse reelle des pieds (glissement 0,3 a 0,8 m/s). Nouveau test tests/test_animation.gd.
- 15/10/2026 : retours d Olympe : saut a la gravite terrestre (0,48 m, 0,6 s en l air, freinage a la reception : plus de glissade de 8 m), montee automatique des marches et seuils (30 cm), capsule du joueur 0,60 m ; PNJ du supermarche et de l aerogare qui reagissent (chute, fuite, vigile qui intervient, remarques quand on les frole) ; conducteur vole qui se bat et reprend son vehicule (il sort le joueur et repart dans la circulation) ; zem ejecte qui garde sa tenue ; conducteurs visibles dans les voitures de la circulation ; virages des PNJ en modele bicyclette (rayon de braquage reel, plus de glissade laterale) ; voitures refaites (carrosserie lissee d un seul tenant, passages de roue, pare-chocs, optiques, interieur, pneus profiles) ; epave de la plage refaite a partir de l avion du jeu (vieillie, rouille, sur cales, escalier) ; avions visitables (porte avant ouverte au poste, cabine de 27 rangees, poste de pilotage, collision exacte) ; frequence des vols reelle de Cotonou (~35 mouvements par jour, pointe le soir, aeroport ferme de 2 h a 5 h, piste 24 dominante). Nouveaux tests : test_saut, test_interieurs, test_carjack, test_cabine.
- 16/10/2026 : joueur bien assis (bassin sur le siege, IK des mains au guidon / volant, pieds aux repose-pieds / pedales). Personnages refaits sur la base Quaternius Universal Base Characters (CC0) : corps et visage sculptes cales sur nos articulations et nos 10 morphologies, musculature ramenee a un corps ordinaire, texture de peau teintee par nos 10 teintes, coiffures reposees sur le crane. Vetements amples (le haut tombe droit depuis la poitrine, pantalon droit avec plis au bas). Chutes des PNJ en clips captes (Death01 puis LayToIdle, Hit_Chest), rue et interieurs. Escaliers des avions au poste depuis le sol (28 degres).
- 16/10/2026 : fin de l etape 16 : accroupi (C / R3, capsule basse, impossible de se relever sous un plafond), saut contextuel qui escalade les rebords de 0,5 a 1,6 m (clip ClimbUp_1m, corps cale sur la racine du clip), PNJ de la rue et des interieurs sur les clips captes comme le joueur (postures reprises : dos voute, charge sur la tete, main sur le crane sous la pluie, dispute avec IK des bras), posture de repos corrigee (pieds a 0,26 m au lieu d une garde a 0,52 m, jambes tendues), niveau de detail de l animation des PNJ eloignes. Nouveau test tests/test_accroupi.gd. FPS 76-94 dehors, 65-73 interieurs. Reste de l etape : ragdoll, entree / sortie animees des vehicules.
- 16/10/2026 : vetements refaits (retour d Olympe : rabat dans le dos) : haut et pantalon decoupes dans la peau par plans (bords nets, d un seul tenant, poids de la peau, ourlet au-dessus de l entrejambe, tissu visible des deux cotes). Phase 7 : argent en FCFA, inventaire, sante, achats (etals, maquis, kpayo, cabines, caisses de l Ararat, cafe de l aerogare), HUD de jeu, ecran titre, pause, options (qualite Bas / Moyen / Haut), sauvegarde et chargement (lit ou menu), histoire "Le Dernier Vol" (docs/histoire.md : prologue et acte 1, 8 missions, GPS, chrono) puis petits boulots de zem. Phase 8 : police fictive (etoiles, patrouilles en pilote automatique sur les rues, agent a pied, arrestation et amende, police semee hors de vue, contraventions pour exces de vitesse), degats de chute, malaise. Nouveau test tests/test_jeu.gd (19 suites au vert).
- 16/10/2026 : fin de l etape 16 (ragdoll des pietons percutes, entree / sortie de vehicule animees), etape 17 (LOD : animation et ombres des PNJ), phase 6 (concessions avec murs et portails, harmattan), phase 9 (zone agrandie au nord : Haie Verte et Cadjehoue, origine figee, zone en tuiles, occultation ; deplacement rapide en zem ; pick-up ; missions de Maman Fifi), phase 10 (prereglages graphiques mesures, export Windows verifie, export web, page de presentation, fiche de playtest). 19 suites au vert. Mesures perturbees par l editeur et d autres logiciels ouverts : Bas 83-104 / 66-70 img/s, Haut 62-75 / 52-60 img/s, a remesurer.

---

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : GTB (Gbê Town Bénin), un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo).

STACK
- Modelisation : Blender 5.2 (Microsoft Store), export glTF 2.0 (.glb), tout par script (blender/tools/)
- Moteur : Godot 4.7.2 (Forward+), physique interpolee, RTX 2050 chez Olympe
- Echelle : 1 unite = 1 metre
- Zone : aeroport de Cotonou, Erevan, la plage, Haie Verte et Cadjehoue. Bbox N 6.3610, S 6.346380, O 2.375259, E 2.387500 (1,35 x 1,6 km), OSM dans refs/osm/zone-gtb.osm ; origine figee au centre de la premiere zone (6.3498725, 2.3813795)
- Cible : PC d'abord, web ensuite

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly, materiaux proceduraux (pas de textures image) jusqu a la Phase 6
- Nom : GTB (Gbê Town Bénin), jamais GTA ni "Grand Theft"
- Couleurs dans les shaders : ecrites en sRGB, converties en lineaire a la fin (pow 2.2)
- Objets : jamais de nom en *_col / *-col pour un objet decoratif (Godot cree une collision)
- Tout son est synthetise (godot/scripts/audio_synth.gd) ; tout modele est fait par script Blender (blender/tools/)

ETAT ACTUEL (16/10/2026, fin de session)
- Phases 0 a 10 faites techniquement (voir les cases de la roadmap). Restent : jalons des phases 3, 4, 5 a valider par
  Olympe en jeu, textures issues de photos (releves terrain), equilibrage et playtest (docs/playtest.md), trailer.
- Fait :
  - Monde : zone agrandie au nord en phase 9 (1,35 x 1,6 km : aeroport, Erevan, plage, Haie Verte, Cadjehoue ; origine
    figee), OSM + Overture + Open Buildings 2.5D + littoral Sentinel-2 (osm_import.py -> zone_aeroport.glb/.json), zone en
    tuiles de 500 m, occultation, concessions avec portails, harmattan, horizon a 6 km, meteo, jour / nuit, sons.
  - Jeu : joueur (sprint, saut, escalade, accroupi, ragdoll des PNJ, entree / sortie de vehicule animees), zem, berline,
    4x4, minibus, pick-up, circulation, pietons, interieurs, avions, argent FCFA, achats, sante, HUD, ecran titre, pause,
    options (qualite Bas / Moyen / Haut), sauvegarde, histoire "Le Dernier Vol" (docs/histoire.md : prologue, acte 1,
    missions de Maman Fifi, petits boulots de zem), deplacement rapide en zem, police fictive (etoiles, patrouilles,
    arrestation, amendes, contraventions).
  - Personnages : corps Quaternius cales sur 10 morphologies, vetements decoupes dans la peau (bords nets), clips captes
    pour le joueur et les PNJ (LOD d'animation et d'ombre).
  - Tests : godot/tests/test_*.gd (19 suites, dont test_jeu) tous OK. Performances (tests/perf_fps.gd [-- qualite]) :
    Bas 83-104 img/s dehors, 66-70 en interieur ; Haut 62-75 dehors, 52-60 en interieur, mesures faites avec l'editeur
    Godot, un navigateur et CapCut ouverts : a remesurer machine degagee avant de conclure sur le budget en Haut.
  - Export : builds/windows/GTB.exe verifie (ecran titre) ; builds/web exporte, non verifie dans un vrai navigateur.
    Page de presentation : docs/presentation.html (publiee aussi en artefact prive).
- Outils : Godot 4.7.2 dans Telechargements (utiliser le _console.exe pour la ligne de commande ; modeles d'export dans
  %APPDATA%/Godot/export_templates/4.7.2.stable) ; Blender 5.2 lance via
  %LOCALAPPDATA%/Microsoft/WindowsApps/blender-launcher.exe -b --python ... (voir docs/PIPELINE.md) ; Python geo dans WSL
  (~/.venvs/geo, overturemaps installe). Envoi git : depuis le git Windows (le git de WSL n'a pas les identifiants),
  jamais de ligne Co-Authored-By.
- Plan valide par Olympe (une etape a la fois, captures a chaque etape dans docs/images/) :
  - fait : A avions, B echelle reelle, C carte reelle, etapes 12 a 15 (personnages), noms fictifs, mode debug ;
  - fait aussi : etapes 16 et 17, phases 6 a 10 (sauf textures photo, equilibrage, playtest, trailer) ;
  - ensuite : validation des jalons 3 a 5 par Olympe, playtest avec des amis (docs/playtest.md), equilibrage d'apres
    leurs retours, releves photo pour les textures, acte 2 de l'histoire, kit modulaire de facades, pente reelle de la plage.
- Personnages : base Quaternius Universal Base Characters (refs/ubc, non versionne) calee par blender/tools/ubc_body.py.
- Reste a faire, signale : bout de pagne visible sous les voitures avec certaines conductrices, cheveux mouilles sous la pluie, casquette de la policiere, traversees du corps pendant la marche
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
