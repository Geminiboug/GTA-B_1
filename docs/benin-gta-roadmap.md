# GTB (Gbê Town Bénin) : Roadmap et prompt de passation

Derniere mise a jour : 18/10/2026
Phase en cours : Phase 11, validation et playtest (phases 0 a 10 faites techniquement, acte 1 jouable de bout en bout)

## 1. Vision

Un jeu open world 3D type GTA, ancre dans le Benin. Objectif long terme : le niveau de contenu et de profondeur d'un GTA San Andreas, a notre sauce, sur Cotonou puis ses environs. On avance zone par zone et version par version : chaque version est jouable et publiable.

Ce qui fait l'identite de GTB :
- le zem au coeur du jeu (deplacement, metier, bande, territoires) ;
- la vie reelle de Cotonou : delestages, harmattan, marches, maquis, funerailles, foot au maquis ;
- l'aeroport comme terrain de jeu (avions, zone cargo, ecole de pilotage) ;
- le francais de Cotonou, le fon et le mina dans les dialogues, la musique beninoise dans les radios.

## 2. Decisions actees

- Cible : Android, Windows et Linux (decision d'Olympe du 17/10/2026). Pas d'Apple. Web abandonne.
- Moteur : Godot 4.7
- Modelisation : Blender, export glTF 2.0 (.glb)
- Echelle : 1 unite = 1 metre, axe Z vers le haut dans Blender, export en Y up
- Premiere zone : aeroport de Cotonou (Cadjehoue), Erevan, la plage (remplace Zogbo, decision du 14/10/2026), etendue a Haie Verte et Cadjehoue
- Style : semi-realiste, low a mid poly pour tenir sur PC modeste
- Materiaux proceduraux jusqu'aux releves photo (Phase 12)
- Nom : GTB, Gbê Town Bénin (ne jamais utiliser GTA ni "Grand Theft" pour eviter un conflit de marque)
- Langue du jeu : francais (et possibilite d'ajouter fon/anglais plus tard)
- Histoire : "Le Dernier Vol" (docs/histoire.md), prologue et acte 1 faits

## 2 bis. Decisions d'Olympe (validees le 17/10/2026)

- Plateformes de la demo : smartphone Android, PC Windows et Linux. Pas d'Apple (iOS, macOS), trop lourd a gerer. Web abandonne (7 a 10 img/s).
- Distribution : itch.io tout de suite, page Steam "bientot disponible" quand le trailer existe.
- Modele : demo gratuite, jeu complet payant a petit prix (10 a 15 EUR) avec prix regionaux bas en Afrique de l'Ouest.
- Armes et violence (niveau PEGI 16) : armes blanches et improvisees (baton, machette, bouteille, coupe-coupe), quelques armes a feu fictives rares et cheres (pistolet, fusil a pompe, fusil de chasse artisanal) ; pas de flaques de sang, pas de demembrement, aucune violence sur les enfants ; PNJ K.-O. ou blesses ; option "violence reduite".
- Voix : comediens amateurs pour la demo (amis, etudiants, troupes de theatre de Cotonou), en fon, francais et mina, avec contrat de cession de droits ; professionnels pour le jeu complet si le budget le permet.
- Musique des radios : compositions originales libres de droits + quelques artistes locaux sous contrat simple.
- Ordre de l'extension : centre de Cotonou d'abord (grand marche fictif facon Dantokpa), bord de lagune ensuite.
- Police : aucun policier a l'ecran tant que le joueur n'a rien fait et que personne n'a appele.
- Agrandir la carte (validee le 18/10/2026) : d'abord le chargement par morceaux (Phase 17 bis), puis Fidjrosse a l'ouest (photos dans refs/, import deja pret), puis le centre avec le grand marche, relie par le boulevard cotier. Commence apres les taches en cours des Phases 11 et 12.

## 3. Ce dont tu as besoin

Logiciels (tous gratuits) :
- Blender 4.x / 5.x
- Godot 4.x (version standard, pas .NET sauf si tu veux du C#)
- Git + GitHub (depot prive du projet)
- Krita ou GIMP (textures), Audacity (sons et voix), OBS (trailer et captures)
- Import OSM : importeur maison blender/tools/osm_import.py

Ressources :
- Releve terrain photo : facades a plat, sols (bitume, paves, laterite, sable), portails, enseignes, toits, en plein jour sans ombre forte
- Enregistrements terrain : zems, klaxons, marches, maquis, appels a la priere, eglises, vendeuses
- Animations humanoides : Quaternius (CC0), Mixamo
- Textures : ambientCG, Poly Haven (CC0), plus tes propres photos
- Testeurs : 2 ou 3 amis pour l'acte 1, puis 10 a 20 pour la demo
- Plus tard : comediens pour les voix, musiciens pour les radios (contrats ecrits, voir docs/LEGAL.md)

Materiel :
- RTX 2050 chez Olympe : budget 70 images/s dehors, 60 en interieur
- Un PC plus modeste (ou un ami) pour verifier le prereglage Bas
- Un micro correct pour les voix (Phase 19)

## 4. Roadmap

### Versions

- v0.1 "Demo Acte 1" : phases 11 a 13 (validation, Cotonou reel, demo publique)
- v0.2 "Systemes" : phases 14 a 17 (combat, progression, personnalisation, territoires de zems) et chargement par zones (Phase 17 bis)
- v0.3 "Acte 2" : phases 18 et 19 (histoire, cinematiques, voix, radios)
- v0.5 "Cotonou" : phases 20 et 21 (activites secondaires, extension de la ville)
- v1.0 "Le Dernier Vol" : phases 22 a 24 (fin de l'histoire, hors de Cotonou, sortie)

Vocabulaire : les "etapes 12 a 17" du journal sont des sous-etapes de l'ancienne Phase 3 (personnages et animation), a ne pas confondre avec les Phases 12 a 17 ci-dessous.

Regle pour toutes les phases : test de fluidite automatique (tests/perf_fps.gd) avant chaque version, en echec sous 70 img/s dehors ou 60 en interieur.

### Phases 0 a 10 : socle (fait techniquement)

- [ ] Jalon phase 3 : balade fluide dans tout le quartier (a valider par Olympe, Phase 11)
- [ ] Jalon phase 4 : conduire un zem de l'aeroport a la plage (a valider par Olympe, Phase 11)
- [ ] Jalon phase 5 : le quartier "respire" (a valider par Olympe, Phase 11)

### Phase 11 : Validation et playtest (v0.1)
- Photos du net : libres comme references (on refait nous-memes) ; comme textures, seulement sous licence libre (Wikimedia Commons, Mapillary...) avec credit dans docs/CREDITS.md, ou photos d'Olympe
- [ ] Olympe joue l'acte 1 en entier (1 h minimum) et note tout ce qui cloche dans docs/retours_olympe.md
- [ ] Validation des jalons des phases 3, 4 et 5 avec docs/validation_phases_3_5.md
- [ ] Playtest avec 2 ou 3 amis (docs/playtest.md), observer sans aider, noter ou ils bloquent
- [ ] Equilibrage : prix, amendes, chronos, vitesse et agressivite de la police, salaires des courses de zem
- [ ] Jalon : 3 testeurs finissent l'acte 1 sans aide, sans bug bloquant, et ont envie de continuer

### Phase 12 : Cotonou reel (v0.1)
- [ ] Releves photo d'Olympe (facades, sols, portails, enseignes, toits) classes dans refs/terrain/ par type
- [ ] Textures tirees des photos (redressement, suppression des ombres, raccord sans couture), versions basse et haute resolution selon la qualite
- [ ] Kit modulaire de facades (rez-de-chaussee boutique, etages, balcons, grilles, climatiseurs) assemble avec variation controlee
- [ ] Sols reels : bitume use, paves, laterite rouge, sable, caniveaux, flaques qui suivent le relief
- [ ] Jalon : un Cotonois reconnait le quartier sur une capture, sans indice (test a l'aveugle avec 2 ou 3 Cotonois, voir docs/audit_cotonou.md)

### Phase 13 : Demo publique "Acte 1" (v0.1)
- [ ] Trailer de 60 a 90 s (captures OBS par Olympe, montage CapCut), sans nom ni marque reels
- [ ] Page itch.io (et page Steam si decide) a partir de docs/presentation.html
- [ ] Export Android : commandes tactiles faites (scripts/tactile.gd : joystick virtuel, camera au doigt, boutons a pied / en vehicule, carte, sac, telephone, pause ; qualite Basse au premier lancement ; aide clavier masquee ; capture_tactile), preset Android et orientation paysage prets ; SDK Android et Java installes (18/10), compression ETC2/ASTC activee, APK de debug exporte (builds/android/GTB.apk, 86 Mo ; procedure : docs/android.md) ; reste : icone du jeu, mesurer 30 img/s sur un telephone de milieu de gamme
- [ ] Jalon : demo publiee, 20 premiers retours de joueurs recus et tries

### Phase 14 : Combat et armes (v0.2)
- [ ] Jalon : un combat de rue et une poursuite a 3 etoiles sont lisibles et amusants

### Phase 15 : Progression du personnage (v0.2)
- [ ] Jalon : apres 2 h de jeu, le joueur sent que son personnage a progresse

### Phase 16 : Personnalisation et proprietes (v0.2)
- [ ] Jalon : deux joueurs n'ont pas le meme Sena ni le meme zem

### Phase 17 : Territoires des zems (v0.2)
- [ ] Jalon : prendre et tenir 3 stationnements change la vie du quartier (plus de zems de ta couleur, salutations)

### Phase 17 bis : Chargement par zones (v0.2)
- [ ] Chargement et dechargement des tuiles de 500 m en arriere-plan, sans saccade (docs/chargement_par_morceaux.md). Fait : etape 1 (un .glb par tuile, osm_import.py), etape 2 (19/10 : monde.gd pose les 16 tuiles + le fichier commun, prechargees en arriere-plan par l'ecran de chargement ; test_tuiles), etape 3 (19/10 : props.gd et vegetation.gd posent le decor tuile par tuile, une graine par objet, conteneurs par tuile ; realism.gd suit les tuiles chargees ; concessions et occultation restent globales, sans lancer de rayons). Reste : liberation au-dela de 900 m (etape 4)
- [ ] Jalon : 70 img/s en Haut avec la zone cargo et les evenements prevus, avant de commencer l'acte 2

### Retours d'Olympe du 21/10/2026 : coherence et realisme (prioritaire, avant l'acte 2)
Bugs de coherence d'abord, nouvelles fonctions ensuite.

A verifier par Olympe en jeu (fait et teste automatiquement, 22/10/2026) : pistes de l'aeroport (piste unique 06/24, taxiways OSM), ecran de preparation anime, vendeuses assises, cortege sans fanfare, PNJ qui contournent objets et passants, repliques plus lentes, plein ecran, escalade jusqu'a 2,8 m, pieds plantes pendant un coup, sortie de vehicule sans traverser un mur, chocs contre les murs hauts, perso droit dans les virages, tenue de depart, logo anime (proposition 2), zones jaunes recalees, feu puis explosion des vehicules, zem a heler (H) avec trajet en direct, direction progressive des vehicules, densite de passants et de vehicules avec recyclage, carburant (reservoir, panne seche, stations Bon Plein, pompistes, bouteille du kpayo), supermarche par rayons, etals par marchandise (modele, prix et cris coherents), portes articulees des voitures (ouvrent a la montee et a la descente), avion leger pilotable "Colibri C-4" a l'aeroport (E pour monter, W / S tangage, A / D roulis, Z / X palonnier, gaz avec accelerer / freiner), Bio Guera au rond-point Erevan.

En cours ou a corriger :
- [ ] Vendeuse egaree : test_vendeurs donne 162 / 163 (une vendeuse hors tuile chargee)
- [ ] Logo : image de 444 px seulement (assets/ui/logo_gtb.png) ; fournir le fichier en haute resolution, variantes et icone ; menu et chargement a verifier
- [ ] Tenue : motif wax a affiner, logo GTB a verifier de pres, baskets
- [x] Glitch de la main / avant-bras qui se plisse bras leve : torsion de l'avant-bras transferee a la main (anim_ctrl._detordre_bras, 22/10) ; a verifier en jeu
- [x] Tenue : pagne et logo GTB de la planche d'Olympe appliques (assets/textures/pagne_gtb.png, logo_tshirt_gtb.png) ; textures de l'aeroport (piste, parking, tarmac) et de l'epave (assets/textures/aeroport, epave)
- [ ] Explosion : flammes plus vives ; vehicules de la circulation pas encore abimables
- [ ] Avion leger : portes du pilote et du passager a animer a la montee (le modele les a), cockpit a habiller, atterrissage a regler sur le terrain, ecole de pilotage, puis helicopteres pilotables (decision d'Olympe 22/10 : seuls de petits avions et des helicopteres sont pilotables, jamais les avions de ligne)
- [x] Lag et chutes brutales d'images (retour d'Olympe 22/10) : cause isolee et corrigee (22/10). Chaque nouveau passant avec AnimCtrl reecrivait loop_mode sur les clips partages (anim_ctrl.gd _ready) : l'Animation emettait "changed" et tous les lecteurs deja en scene reconstruisaient leurs caches (400 a 500 ms par vendeur dans une foule). Garde `if loop_mode != LINEAR`. Vendeurs poses un par image sans fil de travail (pedestrians.gd _vendeur_cree), dix morphologies prechargees au chargement. tests/perf_saccades.gd : pire image 500-730 ms -> ~200 ms, restent des images de 34-50 ms dans les zones denses (~25 i/s) et des pics 100-200 ms a l'arrivee des grosses tuiles (a reduire : budget des taches de tuile, densite 90 / 60 / 36). Outils : tests/mesure_pnj.gd, liste_noeuds.gd, perf_saccades.gd (argument court + nom de noeud a retirer).
- [ ] Voitures : portes arriere et cote passager pour les passagers PNJ ; motos : montee avec enjambement et mains sur le guidon a affiner
- [ ] Stations-service : icone sur la mini-carte (faite le 23/10), essence pour l avion

A faire :
- [ ] Voies qui ne menent nulle part ou s'arretent bizarrement : revue de la carte morceau par morceau contre les references (OSM, satellite, photos) (22/10 : 81 vues du dessus produites par tests/capture_carte_tuiles.gd + tools/planche_tuiles.py ; la colonne ouest x=-7 est noire = hors carte ; routes principales continues ; reste a comparer finement les impasses avec OSM)
- [ ] ETIPECH = palier final de progression (decision d'Olympe 22/10) : le joueur evolue dans la map jusqu'a atteindre son niveau ; pas de campus pose d'un coup. A concevoir : paliers de zones/missions, puis batiment visitable avec les photos d'Olympe (docs/LEGAL.md)
- [ ] Revue morceau par morceau etendue a tout : batiments, murs, vegetation, routes
- [ ] Beaucoup plus d'animations pour des mouvements naturels
- [ ] Motos : montee naturelle, mains sur le guidon, bras qui suivent la direction
- [ ] Monuments fideles restants : l'Amazone, memorial de la place du Souvenir (trois personnages), Parc Cardinal Cotodji (photos ou references a fournir)
- [ ] Vehicules : silhouettes plus fideles, barre de feux arriere de la Koralo invisible, zem Haojin, Landa garee immobile en (95, -934)
- [ ] Android : le chargement echoue ; le nouvel APK affiche la raison, Olympe teste puis on corrige
- [ ] Temps de chargement : 67 s contre 35 s avant l'extension de la carte
- [ ] Reexporter Windows, Linux et Android apres ce lot


### Retours d'Olympe du 22/10/2026 (apres-midi) : realisme visuel (prioritaire apres le lag)
- [ ] Epave de la plage : refaire d'apres le TriStar de reference (refs/modeles/l1011_cotty, CC-BY-4.0 lourencolaio543, credit dans docs/LEGAL.md et l'ecran de credits ; pas de livree ni de nom reels) : fuselage et ailes de TriStar, moteur de queue et entree d'air en S, empennage, train, escalier de bois, cabine visitable (porte avant gauche decoupee), textures de planche. L'epave actuelle est un biréacteur etroit sans moteur de queue.
- [ ] Tous les vehicules plus realistes (voitures, minibus, pickup, 4x4, zems, vehicules de police, avion leger) : formes, proportions, vitrages, optiques, pare-chocs, jantes, interieurs, saletes et usures de Cotonou, comparer aux photos de refs/ ; un vehicule a la fois, avec capture avant / apres.
- [ ] Personnages : geometrie plus fine (mains, visage, epaules, vetements), realisme de la peau, des cheveux et des tissus, plis ; comparer a la planche de personnage ; plusieurs morphologies.
- [x] Nouvelle animation de debut et de chargement : "Aube sur Cotonou" (maquette validee par Olympe le 22/10, scripts/aube_cotonou.gd) utilisee a l'ecran de chargement, a l'ecran titre (menu qui apparait apres 5 s ou sur une touche) et a la preparation du quartier ; carrousel de captures retire ; a verifier en jeu par Olympe
- [ ] Textures des murs et toits de la planche de l'aeroport (enduits, tole, toit-terrasse : extraits dans assets/textures/aeroport/, pas encore appliques) ; interieur de l'epave (hublots, plafond, moquette) d'apres la planche d'interieur.
- [ ] ETIPECH = palier final de progression (pas de campus pose d'un coup).
### Phase 18 : Acte 2 "Sous les ailes" (v0.3)
- [ ] Ecriture complete de l'acte 2 dans docs/histoire.md (15 a 20 missions), validee par Olympe avant production
- [ ] Zone cargo de l'aeroport en interieur et exterieur (hangars, entrepots, controles, chariots, camions)
- [ ] Animations faciales simples (clignements, regard ; bouche synchronisee en Phase 19 avec les voix)
- [ ] Types de missions varies : infiltration, filature, escorte, course, defense, mission en avion au sol
- [ ] Commissaire Adjovi et le Patron mis en scene, revelations de Tonton Codjo
- [ ] Jalon : l'acte 2 se joue d'une traite et la fin donne envie de l'acte 3

### Phase 19 : Son, voix et radios (v0.3)
- [ ] Voix des personnages principaux (Sena, Tonton Codjo, Afi, Pipo, Mama Rose, Adjovi, le Patron), contrats ecrits avec les comediens
- [ ] Bouches synchronisees sur les voix dans les cinematiques de l'acte 2
- [ ] Phrases des PNJ (vendeuses qui interpellent, clients du zem, disputes, insultes, remarques) en francais de Cotonou, fon et mina
- [ ] Radios dans les vehicules : 3 a 5 stations fictives (musique beninoise et africaine, talk-show, infos du quartier qui commentent les actions du joueur), musique originale ou sous contrat
- [ ] Remplacement des sons synthetises les plus visibles par des enregistrements terrain (zem, klaxons, marche, ambiance)
- [ ] Jalon : fermer les yeux 30 s dans le quartier, on se croit a Cotonou

### Phase 20 : Activites secondaires (v0.5)
- [ ] Ecole de pilotage a l'aeroport (rouler, decoller, atterrir, puis avion pilotable)
- [ ] Missions de metier : chauffeur de minibus fait (T au volant d'un minibus : 6 arrets, passagers qui paient 200 F, prime de fin de ligne ; scripts/metiers.gd, test_metiers), livreur (courses de zem) fait ; ambulance, pompier, vigile a faire
- [ ] Jalon : un joueur peut passer 5 h sans toucher a l'histoire

### Phase 21 : Extension de Cotonou (v0.5)
- [ ] Pipeline d'import entierement automatise et documente (OSM, Overture, Open Buildings, Sentinel-2) pour une nouvelle zone
- [ ] Centre et grand marche (le chaos ultime pour les poursuites), quartier d'affaires, port
- [ ] Lagune et ponts, Akpakpa
- [ ] Noms fictifs de toutes les nouvelles zones dans docs/correspondance_noms.md
- [ ] Jalon : traverser Cotonou d'ouest en est a zem sans chargement ni chute sous 60 img/s

### Phase 22 : Acte 3 et final (v1.0)
- [ ] Acte 3 "La saison des pluies" : menace sur la famille, alliance avec les zems, choix moral
- [ ] Final "Le Dernier Vol" : nuit d'orage, poursuite sur la piste pendant le decollage de l'avion-cargo
- [ ] Deux fins selon les choix, epilogue et jeu libre apres la fin
- [ ] Jalon : l'histoire complete se finit en 25 a 30 h avec les activites

### Phase 23 : Hors de Cotonou (v1.0)
- [ ] Route cotiere et routes de campagne (villages, palmeraies, barrages de police, stations de carburant en bord de route)
- [ ] Une ville historique facon Ouidah et une capitale facon Porto-Novo, sous noms fictifs
- [ ] Village lacustre facon Ganvie : pirogues et bateaux pilotables, missions sur l'eau
- [ ] Nouveaux vehicules : camions (fait le 23/10 : veh_camion), bus, bateaux, avion leger
- [ ] Jalon : trois "villes" et de la campagne, comme San Andreas, a notre sauce

### Phase 24 : Finition et sortie v1.0
- [ ] Traduction anglaise faite (i18n/en.po : 542 textes traduits sur 679, les noms propres et le fon restent ; godot/tools/faire_po.py ; choix Automatique / Francais / English dans les options ; capture_anglais) ; fon pour les menus et une partie des dialogues : a faire avec un locuteur (relecture d'Olympe)
- [ ] Accessibilite : taille de l'interface (0,8 a 1,6), aide a la visee a la souris (et verrouillage a la manette), reaffectation des touches du clavier, sous-titres reglables : faits (test_finition) ; daltonisme a faire
- [ ] Succes (13, gardes pour tout le jeu, page dans le menu) et 3 emplacements de sauvegarde (resume chapitre / missions / argent / date) : faits ; mode photo complet a faire
- [ ] Optimisation finale sur 3 configurations (PC modeste, moyen, Olympe)
- [ ] Bêta publique, correction des retours, version 1.0
- [ ] Trailer de lancement, page de vente, presse et createurs de contenu
- [ ] Jalon : GTB 1.0 publie

Option plus tard : multijoueur (balade et courses de zems entre amis, puis missions en cooperation).

## 4 bis. Mission technique du 23/10/2026 (collisions, circulation, personnage, nouveautes)
Etat apres le premier passage de l'agent (tests dans godot/tests/, tous verts sauf mention) :
- [x] Marqueur de police : les agents a pied clignotent sur la mini-carte comme les patrouilles (police.gd, hud_carte.gd) ; verification a l'oeil a faire
- [x] Eau : plans d'eau, bassins et piscines praticables en pataugeant (vitesse x0,45, corps enfonce de 0,6 m) au lieu d'etre des sols (carte.gd dans_eau, player.gd, test_eau) ; nage complete a faire
- [x] Vehicules de la circulation qui renversent les passants, points de vie retires aux passants touches (pedestrians.gd _trafic_heurte, test_pieton_heurte)
- [x] Passants jamais dans un batiment ou un mur, tous etats confondus (pedestrians.gd _eviter, test_pieton_batiment)
- [x] Feux tricolores (121 carrefours) et STOP (256 branches) sur le reseau : scripts/signalisation.gd, lus par traffic.gd, test_feux ; emplacements calcules par le reseau (voies principales), a verifier a l'oeil
- [x] Trafic variable selon l'heure (nuit un tiers, pointes 7 h a 9 h et 16 h a 19 h : tout le monde roule), sans apparition devant le joueur (traffic.gd _densite_horaire, test_densite_horaire)
- [x] Feux de freinage des vehicules de la circulation (traffic.gd _feux_stop) ; phares de zem, voitures et lampadaires (voir journal du 23/10)
- [x] Camions : veh_camion.glb (blender/tools/build_vehicles.py CAMION), dans la circulation et conduisible (test_camions)
- [x] Braquage des commerces (caisse, cafe, maquis, quincaillerie) : arme a feu en joue, E, 5 s, butin, delit "braquage" +3, temoins, recharge de 8 min (scripts/braquage.gd, test_braquage) ; reaction des passants a ajouter
- [x] Taxis et zems refusent le joueur pendant une recherche de police (deja en place : taxi.gd, zem_taxi.gd)
- [ ] Evitement d'obstacles par contournement et demi-tours injustifies : a faire
- [ ] Priorites aux passages pietons, panneaux de limitation de vitesse, sens interdits, marquages au sol : a faire
- [x] Marche arriere des voitures : derapage supprime (voiture.gd, test_marche_arriere) ; virages a mesurer
- [ ] Deplacements du personnage (recul, lateral, arret, saut, rotation, bras, reaction aux degats) : a mesurer un par un
- [ ] Montee, position et descente de moto (mains sur le guidon) : a affiner
- [x] Portails battants qui s ouvrent en s ecartant de la personne (lieux.gd, test_portail_sens)
- [ ] Aeroport (hangars, passerelles, parkings, cloture), vegetation moins geometrique, facades : a faire (references de terrain)
- [ ] Animations d'inactivite variees (telephone, etirements, pompes) : une partie existe deja (player.gd _prochain_geste)

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
- 16/10/2026 : nouvelle roadmap pour la suite : phases 11 a 24 regroupees en versions (v0.1 demo acte 1, v0.2 systemes, v0.3 acte 2, v0.5 Cotonou, v1.0), section "Decisions a prendre", vision San Andreas a notre sauce.
- 16/10/2026 : roadmap ajustee : chargement par zones avance en v0.2 (Phase 17 bis), version des sauvegardes et test de fluidite automatique en Phase 11, textes dans un fichier de traduction en Phase 13, sous-titres en Phase 18, synchro labiale deplacee en Phase 19, cible web a trancher apres verification.
- 16/10/2026 : premiere partie d'Olympe : bloquee au prologue (pain introuvable). Retours ajoutes en Phase 11 (prologue, commandes a l'ecran, carte, police, avions, epave, animations).
- 16/10/2026 : retours de la premiere partie d'Olympe traites (points 1 a 7). Prologue : les etals n'etaient jamais connus du commerce (poses apres lui) et l'etal le plus proche etait derriere un mur ; vendeuse de pain devant le portail, fleche au-dessus de l'objectif, distance affichee, GPS qui sort de la cour par le portail, etals jamais derriere un mur (test_prologue : prologue joue au clavier en 17 s). Aide aux commandes a gauche (a pied, zem, voiture ; clavier ou manette ; F2). Saut : foulee gardee en l'air, plus de glissade ni de pose acrobatique, reception lourde seulement apres une vraie chute ; marche : buste redresse, tete a l'horizontale, jambe d'appui tendue. Carte : murs OSM coupes au bord des chaussees, batiments testes sur tout leur contour (53 retires ou retrecis), test_voirie. Police : appel puis depart du commissariat apres 1 min, trajet visible, points clignotants sur les cartes, plus de rattrapage par teleportation. Avions : allee de 0,73 m, plancher du poste de pilotage ; epave refaite en gros-porteur facon TriStar (recherche : epave reelle de la plage d'Erevan) ; test_cabine : allee, poste, sortie et escalier dans les deux. Gestes : portiere, conducteur tire dehors, proprietaire qui sort le joueur, enjamber le zem, acheter et manger, parler, s'asseoir sur le lit.
- 16/10/2026 : Phase 11 (validation). Journal de partie automatique ecrit au fil de l'eau (godot/scripts/journal.gd, user://logs/partie_<date>.jsonl) et resume dense (user://logs/resume_<date>.json) connecte a Partie, Histoire et Police (test_journal OK). Defauts visibles corriges : bout de pagne sous les voitures masque (player.gd, traffic.gd), chevelure mouillee sous la pluie (shaders/cheveux.gdshader relie a gtb_wet), casquette police generee sur toutes les variantes feminines (build_character.py), traversees du corps reduites (poids pagne et degagement bras). Numero de version v0.1.0 et log disque (user://logs/godot.log) configures, version affichee dans les menus, conversion ascendante des sauvegardes (SAVE_VERSION = 2). Mesures de performance sur RTX 2050 et profilage CPU/GPU des interieurs realises.
- 17/10/2026 : Phase 11, fluidite. tests/perf.sh lance perf_fps.gd dans les trois qualites (echec sous 70 img/s dehors, 60 dedans) ; perf_fps affiche aussi le temps GPU et CPU de rendu. Outils de profil : tests/ab_gpu.gd (A/B alterne, insensible a la chauffe de la machine, mode cpu) et tests/profil_vue.gd. Cause principale trouvee : les ~3 500 arbres lointains (Horizon) dessines en modele complet dans un seul MultiMesh (7 ms de GPU) ; desormais par tuiles de 250 m avec silhouette simplifiee au-dela de 250 m. Aussi : murs des lieux en occulteurs, pas d'ombre du soleil pour les produits, le mobilier et les PNJ d'interieur, radiance du ciel incrementale, circulation lointaine (> 120 m) mise a jour un pas sur 4, Haut sans SSIL et ombre a 160 m. Resultat (RTX 2050, 1600x900) : Bas 65-133, Moyen 66-101, Haut 69-111 img/s, tout au budget. Police a 5 niveaux (agent a pied, patrouilles, barrage, unite speciale 4x4, motos) ; test_police_niveaux.
- 17/10/2026 : Phase 14 (corps a corps, sans armes en attendant le choix d'Olympe) : enchainements, garde, roulade, coups au sol, passants avec caractere et points de vie (riposte, fuite, appel a la police), gestes telephone et torche du joueur ; test_combat, capture_combat.
- 17/10/2026 : Phase 12 (partie sans photos) : plage en pente avec sable mouille et ressac, usure des facades (coulures, rouille, affiches dechirees) ; tests/capture_plage.gd. A surveiller : test_prologue echoue parfois quand la machine est chargee (robot coince au portail de la cour au retour), OK seul.
- 17/10/2026 : vehicules realistes : zem refait en detail, voitures plus nettes (plis, montants, optiques, roues, vernis), conduite avec moteur, boite, transfert de charge et suspension ; test_conduite, capture_modeles.
- 17/10/2026 : inventaire du joueur (scripts/inventaire.gd) avec torche et smartphone (scripts/telephone.gd) au depart, sauvegarde version 3 ; test_inventaire.
- 17/10/2026 : Phase 13 (partie code) : credits en jeu, ecran de fin de demo, mode photo F12, fichier de traduction i18n/gtb.pot ; test_demo. Verification legale : docs/verification_legale.md et test_legal (aucun nom reel ni marque visible).
- 17/10/2026 : version web verifiee dans Chrome (index.html?test lance une partie et ecrit les images/s dans la console) : chargement complet, son des flux synthetises corrige (audio web en mode flux), mais 7 a 10 img/s. Retrait de la v0.1 propose a Olympe.
- 18/10/2026 : export Android (APK de debug, docs/android.md). Ecran de chargement (scenes/chargement.tscn) : carrousel de captures, vraie progression, mise en place de la zone etalee sur plusieurs images (Partie.chantier) ; test_chargement. Options appliquees en direct (test_options_direct). Tenue de route : braquage limite a l'adherence, ESP, bordures franchies sans degats (test_tenue_route, test_bordure). Voitures : contact et demarreur, clignotants automatiques. Zem : bequille animee, passager qui penche, conducteur sans gigotement (test_zem_bequille). Sprint sans a-coups. Armoire (test_armoire). Trafic aerien plus dense et survols (test_survols). Tissus des vetements (shaders/tissu.gdshader). Animations de vie : arret apres une course, gestes d'attente, passants qui s'arretent et discutent (test_vie). Audit Cotonou (docs/audit_cotonou.md).
- 18/10/2026 (suite) : liste des taches d'Olympe regroupee dans docs/a_faire_olympe.md, modele docs/retours_olympe.md. Virages sur place (test_virage), fondu de sortie des clips, s'asseoir annule tout de suite un geste en cours (sinon le joueur restait debout dans la voiture jusqu'a 3 s apres un sprint). Suite de l'audit Cotonou (voir Phase 12) ; zone regeneree (paves, creneaux : 24,8 Mo au lieu de 22) et vegetation refaite. Defaut corrige : aucune inscription murale n'etait jamais posee (murs lus segment par segment de 0,5 m). Essai d'ourlets epais sur les vetements abandonne (bords irreguliers apres subdivision). Decision d'Olympe : agrandir la carte (section 2 bis).
- 18/10/2026 (fin) : chargement sans grosse saccade (jeu exporte, disque local) : passants instancies dans des fils de travail, vendeurs assis, enseignes, ville lointaine et sons d'ambiance etales sur plusieurs etapes ; il reste 5 etapes de 120 a 210 ms (contre une vingtaine jusqu'a 970 ms) ; scene en 1,7 s, mise en place 20 s (14 s avant le nouveau decor, a reduire). chargement.gd signale les etapes de plus de etape_lente_ms. Langue de secours = francais (project.godot) : en francais, des textes s'affichaient en anglais (aide aux commandes). La tete suit la camera pendant un geste. Etape 1 du chargement par morceaux faite (osm_import.py, 9e argument : un .glb par tuile) ; scripts/monde.gd ecrit, pas encore branche.
- 19/10/2026 : mesure de fluidite apres le nouveau decor (machine chaude apres plusieurs heures de tests) : Bas et Haut au budget, Moyen entre 60 et 98 img/s selon les vues avec des echecs differents d'une mesure a l'autre (Route des Peches 67-70, vue d'ensemble 65-82, terminal 60-66) ; rendu CPU + GPU stable (~12 ms). A remesurer machine froide avant de conclure ; si Moyen reste sous le budget, reduire la distance d'affichage du kit de rue et des paraboles.
- 19/10/2026 : chargement par morceaux etape 2 (zone = 16 tuiles + fichier commun via monde.gd, l'ancien fichier unique n'est plus exporte). Ecran de chargement : 5 nouvelles captures sans HUD (epave, quartier, Ararat, Route des Peches, aeroport ; tests/capture_ecran_chargement.gd), zoom adouci (pas de saut apres une etape lente, mipmaps). Mise en place mesuree (tests/bench_chargement.gd) : les tuiles, lieux, vehicules et personnages sont precharges en arriere-plan (avant : lus d'un bloc au _ready, 9 s fige depuis le disque WSL) et la circulation prepare ses modeles image par image (avant : 3,3 s fige) ; _ready de la zone 9 s -> 2,9 s, plus long arret de l'ecran 3,3 s -> 0,3 s. test_prologue echoue parfois dans la suite complete (jamais seul, 4 essais) : a surveiller, le test affiche maintenant l'obstacle.
- 19/10/2026 : chargement par morceaux etape 3 : decor (poteaux, cables, commerces, enseignes, kit de rue, toits, vegetation) pose tuile par tuile avec une graine par objet ; les cables passent d'une tuile a l'autre ; les etals se groupent en petits marches (props.gd grappe_chance, la cachette du marche de la police en depend). Donnees de Fidjrosse telechargees (OSM, Overture 15 439 batiments, Open Buildings 2.5D, littoral Sentinel-2 ; scripts parametres par GTB_BBOX).
- 20/10/2026 : textures de sols et de murs tirees des refs generees (blender/tools/textures_planches.py, melangees au detail procedural dans sol et facade). Rodage sous l'ecran de chargement (la 3D tourne cachee jusqu'a des images stables, 12 s au plus) : plus de lag au debut de partie. Pietons : le geste s'arrete quand ils repartent (plus de glissade), cortege dans le bon sens (test_pietons_anim). Main qui se dechire de la tante : amplitude des gestes de dialogue reduite (geste_amplitude). Tete des PNJ redressee vers l'horizontale (test_tete). Tous les PNJ a pied ont un corps solide (PnjUtil.ajouter_corps). Avions et epave : collisions double face et montants ronds aux portes (plus de joueur coince dans la carlingue, passages en biais dans test_cabine), vitres du poste plaquees sur la coque, cloisons au contour du fuselage. test_prologue contourne les PNJ, test_vie rapproche deux marcheurs, test_decor compte les tuiles de depart.
- 23/10/2026 : correctifs des 5 captures d'Olympe : zone de prise d'article du supermarche a hauteur atteignable (lieux.gd), toits qui flottent recales sur le polygone (props.gd, tests/mesure_toits.gd), logo du maillot et textes des murs colles au support (player.gd, tests/mesure_murs.gd), zem a heler : appel, montee et arrivee corriges, la touche E ne fait plus monter le joueur conducteur (zem_taxi.gd, meta taxi_zem, test_zem_entrees). Nuit : phares de zem (zem.gd), phares de voiture plus longs (voiture.gd, 70 m), phares de la circulation en pool de 12 (traffic.gd), 40 vraies lumieres de lampadaires plus taches de lumiere au sol sur TOUS les lampadaires dans 300 m (day_night.gd). Tests OK : jeu, zem_entrees, zem_taxi, decor, densite, tuiles, pietons_anim, perso, circulation.
- 23/10/2026 (mission technique) : eau praticable en pataugeant (carte.gd dans_eau, player.gd), vehicules de la circulation qui renversent les passants avec perte de points de vie (pedestrians.gd), filet anti-batiment pour tous les etats des passants, feux tricolores (121) et STOP (256) lus par la circulation (scripts/signalisation.gd), trafic variable selon l'heure (traffic.gd _densite_horaire), feux de freinage des PNJ, camion veh_camion (Blender CAMION) dans la circulation et conduisible, braquage des commerces (scripts/braquage.gd), marche arriere des voitures sans derapage (voiture.gd : geometrie d'Ackermann des qu'on recule, derive 0,40 rad -> 0,00 mesuree par test_marche_arriere), portails battants qui s'ouvrent en s'ecartant de la personne (lieux.gd), policiers a pied clignotants sur la mini-carte, stations-service sur la mini-carte. Nouveaux tests : test_eau, test_pieton_heurte, test_pieton_batiment, test_feux, test_densite_horaire, test_camions, test_braquage, test_marche_arriere, test_portail_sens.

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : GTB (Gbê Town Bénin), un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo). Objectif long terme : le niveau d'un GTA San Andreas, a notre sauce, sur Cotonou puis ses environs.

STACK
- Modelisation : Blender 5.2 (Microsoft Store), export glTF 2.0 (.glb), tout par script (blender/tools/)
- Moteur : Godot 4.7.2 (Forward+), physique interpolee, RTX 2050 chez Olympe
- Echelle : 1 unite = 1 metre
- Zone : aeroport de Cotonou, Erevan, la plage, Haie Verte, Cadjehoue et l'extension est (7 081 x 2 321 m), OSM dans refs/osm/ (fusion par blender/tools/osm_fusion.py) ; origine figee au centre de la premiere zone (6.3498725, 2.3813795)
- Cible : Android, Windows et Linux ; pas d'Apple, pas de web

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly, materiaux proceduraux jusqu'aux releves photo (Phase 12)
- Nom : GTB (Gbê Town Bénin), jamais GTA ni "Grand Theft"
- Couleurs dans les shaders : ecrites en sRGB, converties en lineaire a la fin (pow 2.2)
- Objets : jamais de nom en *_col / *-col pour un objet decoratif (Godot cree une collision)
- Tout son est synthetise (godot/scripts/audio_synth.gd) jusqu'a la Phase 19 ; tout modele est fait par script Blender (blender/tools/)

ETAT ACTUEL (23/10/2026)
- 23/10 : nuit eclairee, bugs zem/supermarche/toits/textes, puis mission technique (section 4 bis de la roadmap) : eau, collisions PNJ/vehicules, feux tricolores et STOP, trafic horaire, camions, feux de freinage, braquage des commerces, marche arriere, portails. Reste de la section 4 bis a faire (evitement par contournement, passages pietons, limitations, deplacements du personnage, moto, aeroport, vegetation, facades). A refaire : exports apres ce lot, mesure de fluidite de nuit, test_tenue et test_circulation sans ligne RESULTAT.
- Le jeu est jouable du lancement (ecran titre au logo anime, Nouvelle partie) a la fin de l'acte 1 ("A suivre"). Plein ecran par
  defaut. Exports Windows (0.7.1), Linux et Android (APK de debug 0.1.5, code 7) refaits le 22/10 apres le correctif de lag ; icone = nouveau logo GTB (godot/icone.png). Amelioration des personnages (visage, baskets, fesses) : maquette validee mais integration abandonnee par Olympe le 22/10 (resultat juge pire dans le jeu), scripts gardes dans blender/tools/maquette_perso*.py, modeles du jeu inchanges. test_tenue (voitures) ne se termine pas : a examiner.
- Systemes ajoutes depuis le 16/10 (tous testes par godot/tests/test_*.gd) :
  - Monde : carte de 7 081 x 2 321 m en 81 tuiles streamees (monde.gd), cache de la carte (tests/outil_cache_carte.gd a relancer
    apres chaque import), mini-carte plafonnee a 8192 px. Chargement ~67 s a l'export a optimiser. Raccords de routes coupees :
    blender/tools/ponts_manquants.py (genere refs/osm/ponts-manquants.osm, fusionne dans zone-gtb-complet.osm).
  - Commandes reaffectables (menus.gd, partie.gd TOUCHES_REGLABLES : actions creees par le code avec touche par defaut).
  - Vehicules : marques parodiques (docs/LEGAL.md 6 bis), direction progressive, carburant (reservoir, panne seche), degats,
    feu puis explosion (feu_vehicule.gd, explosion.gd), epaves, portes articulees des voitures (modele : percer_portes dans
    blender/tools/build_vehicles.py ; voiture.gd ouvrir_porte), sortie sans traverser un mur.
  - Stations-service "Bon Plein" (stations.gd), supermarche par rayons (commerce.gd rayon_*), etals par marchandise
    (build_props.py etal_*, props.gd vendor_types, dialogues vendeuse_*).
  - Zem a heler (zem_taxi.gd, touche H) : arrive par les rues, trajet en direct ; le joueur passager = player.enter_vehicle(v, true).
  - Avion leger pilotable (avion_leger.gd, avion_camera.gd, modele build_avion_leger.py) pose a l'aeroport ; avions de ligne
    pas encore pilotables.
  - PNJ : vendeuses de vrais personnages assis, cortege reactif sans fanfare, evitement des objets, densite avec recyclage
    autour du joueur (pedestrians.gd / traffic.gd _recycler), cris selon la marchandise.
  - Aeroport : une seule piste 06/24 de 2 400 m, avions sur les vrais taxiways OSM (air_traffic.gd).
  - Monuments : Place Calvaire (monuments.gd), Bio Guera (monument_bio_guera.gd, rond-point en (679, -30)).
  - Missions : objectifs recales sur le sol libre (histoire.gd _degager).
- En cours : import des routes raccordees (osm_import.py sur zone-gtb-complet.osm), puis relancer tests/outil_cache_carte.gd,
  test_zones_missions, test_circulation, test_densite ; reexporter.
- A faire (liste complete a jour dans la roadmap, section "Retours d'Olympe du 21/10/2026") : glitch de la main (poche), tenue (motif
  wax), logo en haute resolution, ETIPECH (EPITECH Benin est a Seme City, ~20 km a l'est : progression par paliers, voir la roadmap),
  monuments restants (l'Amazone, place du Souvenir, parc), animations (montee a moto, passagers PNJ), helicopteres pilotables,
  revue de la carte morceau par morceau (batiments, murs, vegetation), Android (le chargement echoue ; l'APK affiche la raison),
  temps de chargement, vehicules de la circulation abimables.
- Taches d'Olympe (ne pas les faire a sa place) : docs/a_faire_olympe.md (jouer, retours, photos dont ETIPECH, tests Android).
- Outils : Godot 4.7.2 (exe sur le Bureau : Godot_v4.7.2-stable_win64.exe, --headless --path godot --script res://tests/xxx.gd ;
  ajouter --resolution 1280x720 sans --headless pour les captures tests/capture_*.gd) ; modeles d'export dans
  %APPDATA%/Godot/export_templates/4.7.2.stable ; Blender 5.2 via PowerShell : & "$env:LOCALAPPDATA\Microsoft\WindowsApps\blender-launcher.exe"
  -b --python script -- args (le lanceur n'affiche rien : utiliser blender/tools/run_logged.py pour un journal) ; Python geo dans
  WSL (~/.venvs/geo) ; Python Windows absent : wsl.exe -e python3 ; ecrire les scripts Python avec l'outil Write (les heredocs
  multiples avec apostrophes cassent le shell). Envoi git : git -c safe.directory=* push depuis Git Bash, jamais de ligne Co-Authored-By.
- Regles d'Olympe : tout ce qui n'est pas fidele a Cotonou est corrige ou supprime ; noms fictifs pour les lieux, marques et
  personnes (monuments et statues publics gardent leur nom reel) ; donnees ouvertes seulement ; 70 images/s dehors et 60 en
  interieur ; tests au vert a chaque commit ; roadmap et ce prompt mis a jour a chaque travail fini.
- Attention mesures : arreter les Blender / Godot restes en fond avant perf_fps.gd.
- Bloquants : aucun. Si l'editeur Godot est ouvert pendant qu'on modifie project.godot, le fermer et rouvrir le projet.

ROADMAP
Socle fait : 0 Setup, 1 Pipeline, 2 Blockout, 3 Joueur, 4 Zem, 5 Ville vivante, 6 Modelisation, 7 Gameplay, 8 Police, 9 Extension, 10 Finition.
Suite : v0.1 (11 Validation et playtest, 12 Cotonou reel, 13 Demo publique), v0.2 (14 Combat, 15 Progression, 16 Personnalisation et proprietes, 17 Territoires des zems, 17 bis Chargement par zones), v0.3 (18 Acte 2, 19 Son, voix et radios), v0.5 (20 Activites secondaires, 21 Extension de Cotonou), v1.0 (22 Acte 3 et final, 23 Hors de Cotonou, 24 Finition et sortie).

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
- Voix et musique (Phase 19) : uniquement avec un contrat ecrit de cession de droits, archive dans docs/contrats/ (non versionne si donnees personnelles).
- Jamais de co-auteur dans les commits.

MISE A JOUR OBLIGATOIRE DE CE PROMPT
- Ce prompt est un relais entre agents. Avant de terminer ta session (ou quand tu finis une tache), tu dois reecrire ce meme prompt en entier, a jour, pour le prochain agent.
- Mets a jour : ETAT ACTUEL (phase en cours, ce qui est fait, prochaine tache, bloquants), la date, les decisions prises, les conventions ajoutees et les chemins de fichiers importants.
- Garde toutes ces regles, y compris celle-ci, dans la nouvelle version, pour que le suivant fasse pareil.
- Ajoute une ligne au journal d'avancement de benin-gta-roadmap.md et coche les taches terminees.
- Rends le nouveau prompt complet dans un bloc de code, pret a copier-coller.

Commence par lire ETAT ACTUEL et execute la prochaine tache.
```