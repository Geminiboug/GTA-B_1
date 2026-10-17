# GTB (Gbê Town Bénin) : Roadmap et prompt de passation

Derniere mise a jour : 16/10/2026
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

- [x] Phase 0 : cadrage et setup (depot, logiciels, nom, bbox, 57 photos de reference)
- [x] Phase 1 : pipeline assets (conventions, export en un clic, 20 materiaux)
- [x] Phase 2 : blockout de la zone aeroport (OSM, Overture, Sentinel-2, reperes) ; jalon valide le 14/10/2026
- [x] Phase 3 : joueur a pied facon GTA V (clips Quaternius, sprint, saut, escalade, accroupi, IK, ragdoll, mode debug)
- [ ] Jalon phase 3 : balade fluide dans tout le quartier (a valider par Olympe, Phase 11)
- [x] Phase 4 : le zem (modele, conduite, camera, son)
- [ ] Jalon phase 4 : conduire un zem de l'aeroport a la plage (a valider par Olympe, Phase 11)
- [x] Phase 5 : ville vivante (pietons, 10 morphologies, visages, tenues, trafic, avions, interieurs, jour/nuit, sons)
- [ ] Jalon phase 5 : le quartier "respire" (a valider par Olympe, Phase 11)
- [x] Phase 6 : modelisation detaillee (sauf textures photo et kit modulaire de facades, passes en Phase 12)
- [x] Phase 7 : gameplay de base (FCFA, inventaire, HUD, menus, options, sauvegarde, prologue et acte 1 : 8 missions)
- [x] Phase 8 : police et danger (equilibrage passe en Phase 11)
- [x] Phase 9 : extension (Haie Verte, Cadjehoue, deplacement rapide en zem, pick-up, missions de Maman Fifi)
- [x] Phase 10 : finition (prereglages, export Windows, export web, page de presentation, fiche de playtest)

### Phase 11 : Validation et playtest (v0.1)
- Retours d'Olympe du 16/10/2026 (premiere partie), a traiter dans cet ordre :
  - [x] 1. Prologue : objectif affiche, marqueur sur la carte, la mini-carte et dans le monde (vendeuse de pain), touche affichee a proximite ("T : acheter le pain"), parcours maison -> pain -> retour verifie par un test
  - [x] 2. Commandes a l'ecran : rappel au debut (bouger, courir, sauter, camera, interagir) puis aides selon la situation (a pied, pres d'un vehicule, zem, voiture, vendeur), clavier ou manette selon l'appareil utilise
  - [x] 2 bis. Mouvement du joueur plus naturel : analyse image par image comparee a de vraies personnes (bras, buste, pieds qui glissent, demi-tours, demarrages, transitions entre allures, inclinaison)
  - [x] 2 ter. Saut : plus de glissade a la reception ni de pose "Spider-Man" ; reception selon la hauteur et la vitesse (enchainement en course, petite flexion, reception lourde apres grande chute)
  - [x] 3. Carte : detection automatique des clotures et maisons sur la chaussee (comparaison a la largeur reelle des routes), recul ou suppression, test pour que ca ne revienne pas
  - [x] 4. Police : delai d'arrivee realiste apres un appel (1 min reelle, decision d'Olympe du 16/10/2026, reglable), depart d'un commissariat fictif ou du bord de la zone, trajet visible sur la route, la carte et la mini-carte ; reaction immediate seulement si un policier voit l'infraction
  - [x] 5. Avions : dimensions comparees aux vrais avions (largeur de cabine, allee, hauteur, porte du cockpit) et agrandies si besoin, collisions refaites pour circuler partout (allee, cockpit, sortie par la porte, escalier)
  - [x] 6. Epave de la plage : recherche de son etat reel actuel (type d'avion, morceaux restants, position, couleurs, rouille, vegetation), refaite a l'identique, interieur praticable
  - [x] 7. Animations visibles pour chaque action : vol de voiture (ouvrir, sortir le conducteur, chute ou fuite), PNJ qui reprend sa voiture (ouvrir, sortir le joueur, monter), moto (enjamber, descendre), voiture (ouvrir, s'asseoir, fermer, sortir), acheter, parler, dormir, s'asseoir, frapper, tomber, se relever ; clips Quaternius sinon clips composes avec l'IK
  - Photos du net : libres comme references (on refait nous-memes) ; comme textures, seulement sous licence libre (Wikimedia Commons, Mapillary...) avec credit dans docs/CREDITS.md, ou photos d'Olympe
- [ ] Olympe joue l'acte 1 en entier (1 h minimum) et note tout ce qui cloche dans docs/retours_olympe.md
- [ ] Validation des jalons des phases 3, 4 et 5 avec docs/validation_phases_3_5.md
- [ ] Playtest avec 2 ou 3 amis (docs/playtest.md), observer sans aider, noter ou ils bloquent
- [x] Journal de partie automatique (temps par mission, morts, arrestations, argent gagne et depense, endroits ou le joueur se perd) dans user://logs/, pour equilibrer sur des chiffres
- [ ] Equilibrage : prix, amendes, chronos, vitesse et agressivite de la police, salaires des courses de zem
- [x] Defauts visibles : bout de pagne sous les voitures, cheveux secs sous la pluie, casquette de la policiere, traversees du corps pendant la marche
- [x] Remesurer les performances machine degagee ; si Haut descend sous 60 img/s dans l'Ararat et l'aerogare : profiler et corriger (ombres, lumieres, nombre de PNJ, occultation)
- [x] Verifier la version web dans Chrome et Firefox (chargement, controles, son, performances), ou la retirer de la cible v0.1 : Chrome verifie le 17/10 (chargement complet, son corrige, mais 7 a 10 img/s : un seul fil, pas d'occultation, WebGL) ; Firefox absent de la machine. web retire de la cible (decision d'Olympe du 17/10/2026)
- [x] Rapport de crash : log d'erreurs ecrit sur disque et numero de version affiche dans le menu
- [x] Numero de version dans le fichier de sauvegarde et conversion des anciennes sauvegardes (une sauvegarde de la demo doit se charger en v0.2 et apres)
- [x] Test de fluidite automatique : perf_fps.gd lance par un script, echec sous 70 / 60 img/s
- [ ] Retours d'Olympe du 17/10/2026 :
  - [x] Torche tenue a l'envers dans la main (le faisceau etait bon) : modele retourne
  - [x] Police visible seulement apres une betise signalee : plus de patrouilles stationnees au niveau 0 (reglage police.patrouilles_sans_recherche)
  - [x] Prologue bloque au riz de l'Ararat (4 500 F pour 3 000 F en poche) : tante Mireille donne 5 000 F, puis 2 000 F pour la sauce ; Maman Fifi avance 2 000 F
  - [x] Limiteur de vitesse (K, manette croix bas) a 50 km/h, sous le seuil des contraventions, compteur de vitesse a l'ecran (test_limiteur)
  - [x] Fleches qui faisaient bouger le joueur pendant un achat : deplacement bloque tant qu'un menu est ouvert (achat, inventaire, telephone)
  - [x] Nom de l'assistant retire des credits
  - [x] Plage : blocages et sursauts. Le sable n'avait pas de collision (on tombait sur le fond marin a -1,2 m) et le filet de securite des vehicules les ramenait en arriere des que l'estran passait sous -0,6 m. Collision ajoutee, seuil abaisse sous le fond marin, l'eau freine les vehicules (test_plage)
  - [x] Realisme des voitures et minibus beaucoup plus pousse : conduite, apparence, degats, son et effets (voir la deuxieme passe vehicules)
  - [x] Mission de la plage : destination sur un toit (inaccessible), recalee sur la rue devant Sweet Dream Beach (histoire.gd, _rue)
  - [x] Torche : orientee chaque image comme le faisceau, quelle que soit la pose de la main
  - [x] Vetements plus fins : une subdivision de plus sur tous les tissus, plus d'allegement du pantalon (build_character.py) ; niveaux de detail de Godot pour la foule
  - [x] Mouvements naturels : 22 captures Mixamo fournies par Olympe (attentes, marches homme / femme, course, sprint, virages, parler, telephoner, saluer, deux disputes) reunies par blender/tools/build_mixamo.py, retargetees (bonemap_mixamo.tres), mises sur place au chargement avec leur vitesse naturelle mesuree ; attente et demarche propres a chaque PNJ ; tests/mesure_foulee.gd
  - [x] Chute d'images en entrant dans l'Ararat et l'aerogare : les clients et voyageurs etaient fabriques a l'entree (pics de 140 ms) ; ils sont fabriques une fois au chargement puis seulement montres / caches ; tests/perf_entree.gd
  - [ ] Virages sur place et demarrages / arrets avec les clips captes (MX_Tourne_*, MX_Depart, MX_Arret)
- [ ] Jalon : 3 testeurs finissent l'acte 1 sans aide, sans bug bloquant, et ont envie de continuer

### Demande d'Olympe du 17/10/2026 : inventaire et vehicules realistes
- [x] Inventaire du joueur (I, croix gauche) avec torche (L) et smartphone (P) au depart ; anciennes sauvegardes completees (version 3) ; aliments a emporter qui se mangent
- [x] Torche : lampe dans la main droite, faisceau qui suit le regard, eteinte en vehicule
- [x] Smartphone : heure, meteo, argent ; Messages (objectif, dernieres repliques), Carte, Zem a la demande, Contacts, Appareil photo
- [x] Zem refait en detail (moteur a ailettes, echappement, fourche, selle biplace, porte-bagages, clignotants, roues) : blender/tools/build_zem.py, plongee de fourche au freinage
- [x] Voitures, 4x4, minibus, pick-up refaits (carrosserie nette, montants, jours de portes, optiques, roues et freins) : plis vifs, phares qui s'allument la nuit, peinture vernie ; tests/capture_modeles.gd
- [x] Conduite plus realiste : suspension par roue, pneus (adherence selon la charge), boite de vitesses reelle : couple selon le regime, 5 rapports, masse et trainee par modele (Vehicules.TUNING) ; test_conduite (berline 0-80 en 8 s, pointe 166 km/h, plongee 6 degres au freinage)
- [ ] Deuxieme passe (retour d'Olympe du 17/10/2026, voitures et minibus pas assez realistes) :
  - [x] Conduite : modele de pneus (derive, charge par essieu selon la hauteur du centre de gravite, inertie de lacet) : sous-virage, survirage au lever de pied ou au frein a main, contre-braquage ; adherence selon le revetement (goudron, paves, laterite, sable, eau) et la pluie ; ABS ; volant qui revient au centre ; reglages par modele (repartition, hauteur du centre de gravite, rigidite des pneus) ; test_tenue
  - [x] Son : moteur essence (berline) ou diesel qui claque (4x4, minibus, pick-up) par explosions de cylindres, en charge et a vide melanges selon l'accelerateur, accordes sur le regime ; roulement selon le revetement, vent, passages de rapport, petarades, portieres
  - [x] Effets : poussiere de laterite ou de sable, fumee et traces de pneus sur le goudron en glisse, fumees douces
  - [x] Degats : tole froissee au point de choc, pare-brise etoile, phares casses, feu moteur sous 15 %, reparer() pour le garage (phase 16) ; tests/capture_degats.gd
  - [x] Apparence : vitres teintees qui refletent le ciel, poussiere rouge en bas de caisse et rouille propres a chaque voiture (aussi dans la circulation), pick-up a plateau ouvert
  - [ ] Detail des modeles : minibus facon taxi-brousse (porte coulissante, montants plus serres), interieurs, clignotants et feux de recul animes

### Phase 12 : Cotonou reel (v0.1)
- [ ] Releves photo d'Olympe (facades, sols, portails, enseignes, toits) classes dans refs/terrain/ par type
- [ ] Textures tirees des photos (redressement, suppression des ombres, raccord sans couture), versions basse et haute resolution selon la qualite
- [ ] Kit modulaire de facades (rez-de-chaussee boutique, etages, balcons, grilles, climatiseurs) assemble avec variation controlee
- [ ] Sols reels : bitume use, paves, laterite rouge, sable, caniveaux, flaques qui suivent le relief
- [x] Usure : coulures, rouille, peinture ecaillee, affiches dechirees (dans shaders/facade.gdshader plutot que des decals : aucun cout par objet) ; a completer avec les photos d'Olympe
- [x] Pente reelle de la plage : estran de 40 m en pente concave jusqu'a -0,8 m puis fond qui descend sous l'eau (osm_import.py, plage_estran), sable mouille et ressac (shaders/sol.gdshader)
- [ ] Jalon : un Cotonois reconnait le quartier sur une capture, sans indice

### Phase 13 : Demo publique "Acte 1" (v0.1)
- [ ] Trailer de 60 a 90 s (captures OBS par Olympe, montage CapCut), sans nom ni marque reels
- [x] Captures d'ecran soignees (mode photo simple : camera libre, masquer le HUD) : F12 (scripts/mode_photo.gd), captures dans user://captures/ ; les captures elles-memes restent a faire par Olympe
- [ ] Page itch.io (et page Steam si decide) a partir de docs/presentation.html
- [x] Ecran de fin de demo : "A suivre", lien vers un formulaire de retours (menus.gd fin_demo ; lien a renseigner dans Menus > formulaire_retours quand Olympe aura cree le formulaire)
- [x] Tous les textes du jeu (menus, HUD, dialogues, missions) sortis du code dans un fichier de traduction (base de la traduction de la Phase 24) : godot/i18n/gtb.pot (427 textes) genere par godot/tools/extraire_textes.py, francais comme cle, Label / Button / Label3D traduits par Godot ; quelques repliques composees a la volee (prenom, prix) seront a reprendre en Phase 24
- [x] Credits complets en jeu (OSM ODbL, Overture, Open Buildings CC BY 4.0, Sentinel-2, Quaternius CC0, autres de docs/CREDITS.md) : bouton Credits (titre et pause), texte dans godot/assets/data/credits.txt
- [x] Verification legale complete avec docs/LEGAL.md avant publication : docs/verification_legale.md, controle automatique tests/test_legal.gd (avis d'avocat recommande avant une sortie payante)
- [x] Export Linux (x86_64) verifie : builds/linux/GTB.x86_64 lance dans Ubuntu (WSL), partie chargee sans erreur ; preset Web retire
- [ ] Export Android : commandes tactiles faites (scripts/tactile.gd : joystick virtuel, camera au doigt, boutons a pied / en vehicule, carte, sac, telephone, pause ; qualite Basse au premier lancement ; aide clavier masquee ; capture_tactile), preset Android et orientation paysage prets ; reste : installer le SDK Android et un JDK 17 (Olympe), exporter l'APK, mesurer 30 img/s sur un telephone de milieu de gamme
- [ ] Jalon : demo publiee, 20 premiers retours de joueurs recus et tries

### Phase 14 : Combat et armes (v0.2)
- [x] Corps a corps facon San Andreas : enchainements de coups, blocage, esquive, saisie, coups au sol : direct / croise / croise appuye (clic), garde (clic droit, LB) qui pare 85 %, roulade (garde + saut), coups au sol ; la saisie attend un clip adapte (aucun dans les bibliotheques Quaternius) ; test_combat
- [x] Visee : visee libre a la souris (clic droit, camera par-dessus l'epaule, reticule, haut du corps en pose de tir et jambes qui marchent, pose complete a l'arret), verrouillage de cible a la manette (LB) et changement de cible d'un coup de stick droit
- [x] Armes fictives (choix d'Olympe du 17/10/2026) : baton, bouteille (biere du maquis, casse apres 3 coups), machette, coupe-coupe (Quincaillerie Le Bon Clou, de jour) ; pistolet, fusil a pompe, fusil de chasse artisanal et munitions (le Gaou, la nuit pres de la plage) ; Tab / RB change d'arme, R / L3 recharge ; clips d'epee et de pistolet, detonations et echo synthetises, recul, eclair au canon, impacts ; le decor et les voitures arretent les balles ; passants qui fuient, police a 2 etoiles ; option violence reduite ; scripts/armes.gd, test_armes, capture_armes
- [x] Sante, armure, hopital : blouson de moto renforce (Ararat, 12 000 F) qui absorbe 60 % des coups et des chutes (barre bleue), reveil devant le Centre de sante Gbekpo (fictif, croix verte) avec 4 000 F de soins ; test_sante
- [x] PNJ qui se defendent, fuient ou appellent la police selon leur caractere : bagarreur (35 %) en garde qui rend les coups, peureux qui fuit, un sur cinq qui appelle la police au telephone ; points de vie et K.-O.
- [x] Police a 5 niveaux : 1 agent a pied, 2 agent + patrouille, 3 barrage de deux voitures devant le joueur, 4 unite speciale en 4x4, 5 motos de police qui suivent les rues (test_police_niveaux)
- [x] Moyens de semer la police : se cacher au marche (trace perdue 3 fois plus vite au milieu des etals), changer de tenue (une etoile de moins hors de vue), repeindre le vehicule au garage (plus recherche hors de vue)
- [ ] Jalon : un combat de rue et une poursuite a 3 etoiles sont lisibles et amusants

### Phase 15 : Progression du personnage (v0.2)
- [x] Statistiques visibles : endurance, muscles, poids, respect, competences (zem, voiture, tir, natation) ; scripts/stats.gd, sauvegardees (Partie.perso), message a chaque palier de 10
- [x] Le corps change avec les statistiques (morphologies existantes : mince, normal, fort) ; l'arme et la torche reviennent dans la main
- [x] Manger (maquis, etals, Ararat) et faire du sport (salle Gbekpo Fitness, 1 000 F la seance ; footing) influencent le corps
- [x] Competences qui augmentent a l'usage : zem plus stable (guidon), voiture mieux tenue (adherence), visee plus precise (dispersion), muscles qui renforcent les coups, endurance qui allonge le sprint
- [x] Ecran de statistiques dans le menu pause ; test_stats
- [ ] Jalon : apres 2 h de jeu, le joueur sent que son personnage a progresse

### Phase 16 : Personnalisation et proprietes (v0.2)
- [x] Tailleur Chez Dossou (boubou en wax sur mesure), Friperie du Carrefour (t-shirts, jean, sandales, baskets), Maillots Sport 229 (5 clubs fictifs) ; scripts/personnalisation.gd, test_perso
- [x] Coiffeur Salon Elegance : coupe courte, afro, tresses, crane rase (barbe et teintures : il faudra des maillages dans build_character.py)
- [x] Garage de Tonton Codjo : reparer, repeindre (seme la police hors de vue), klaxon deux tons ; pots, jantes et autocollants restent a modeliser
- [x] Proprietes (Agence Immo Gbekpo) : chambre a Cadjehoue (150 000 F), appartement a Haie Verte (600 000 F), planques ou l'on dort et sauvegarde, vehicule gare devant garde
- [x] Garde-robe (Partie.tenue, drapeaux garde_robe) et vehicules gares gardes dans les sauvegardes
- [ ] Jalon : deux joueurs n'ont pas le meme Sena ni le meme zem

### Phase 17 : Territoires des zems (v0.2)
- [x] Carte des stationnements de zems (6 : aeroport, carrefours, marche, Route des Filets) avec un proprietaire par stationnement, pancarte et carre de couleur sur la mini-carte ; scripts/territoires.gd, test_territoires
- [x] Respect du quartier : gagne par les courses, les missions, les stationnements pris ; perdu par les amendes (scripts/stats.gd)
- [x] Bande de Sena : recruter jusqu'a 3 zemidjans (B, a un stationnement tenu, selon le respect), ils suivent (G : suivre / attendre) et se battent ; les equiper reste a faire
- [x] Syndicats rivaux fictifs (Syndicat des Zems Unis, Lions du Littoral) : defi (trois zemidjans a mettre a terre en 90 s), negociation payante avec assez de respect ; courses entre zems a faire
- [x] Revenus passifs (1 500 F par stationnement et par heure de jeu), attaques a defendre en 3 minutes
- [ ] Jalon : prendre et tenir 3 stationnements change la vie du quartier (plus de zems de ta couleur, salutations)

### Phase 17 bis : Chargement par zones (v0.2)
- [ ] Chargement et dechargement des tuiles de 500 m en arriere-plan, sans saccade : reporte a la Phase 21 (la zone actuelle tient en un fichier deja decoupe en tuiles de 500 m, que Godot ignore hors champ ; 70 img/s en Haut mesures le 17/10/2026). Il faudra un fichier par tuile dans osm_import.py quand Cotonou s'etendra
- [x] Sauvegarde de l'etat (vehicules gares aux proprietes, stationnements tenus, tenue, statistiques) ; par zone quand le chargement par tuiles existera
- [x] Interieurs : personnages fabriques une fois au chargement puis montres / caches selon la distance (plus d'a-coup a l'entree, tests/perf_entree.gd)
- [ ] Jalon : 70 img/s en Haut avec la zone cargo et les evenements prevus, avant de commencer l'acte 2

### Phase 18 : Acte 2 "Sous les ailes" (v0.3)
- [ ] Ecriture complete de l'acte 2 dans docs/histoire.md (15 a 20 missions), validee par Olympe avant production
- [ ] Zone cargo de l'aeroport en interieur et exterieur (hangars, entrepots, controles, chariots, camions)
- [x] Systeme de cinematiques (scripts/cinematique.gd) : bandes noires, plan par-dessus l'epaule pendant les dialogues de l'histoire, plans scriptes (jouer), sous-titres avec le nom actives par defaut et taille reglable dans les options, Espace / Entree / A pour passer, interface cachee ; capture_cinematique
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
- [x] Mixage : bus Vehicules / Ambiance / Effets / Voix reglables dans les options, sources rangees automatiquement, reverberation dans l'Ararat et l'aerogare ; test_mixage
- [ ] Jalon : fermer les yeux 30 s dans le quartier, on se croit a Cotonou

### Phase 20 : Activites secondaires (v0.5)
- [ ] Ecole de pilotage a l'aeroport (rouler, decoller, atterrir, puis avion pilotable)
- [ ] Missions de metier : ambulance, pompier, vigile, livreur, chauffeur de minibus
- [x] Courses de zems de nuit (20 h - 5 h, Route des Filets, 8 points de passage, 2 rivaux pilotes, 10 000 F au 1er) ; courses de voitures a faire ; scripts/activites.gd, test_activites
- [x] Paris sur les matchs de foot au maquis (clubs fictifs, cote 3 contre 1, resultat a l'heure de jeu suivante)
- [ ] Evenements de quartier : funerailles avec fanfare, mariages, fetes, coupures de courant qui ouvrent des opportunites
- [x] Collectibles : 15 enseignes peintes (noms fictifs) a photographier avec le telephone ou F12, 1 000 F chacune, 25 000 F la collection ; objets caches et sauts acrobatiques a faire
- [x] Taux de completion (pourcentage) dans le menu Statistiques : missions, stationnements, proprietes, fresques, courses
- [ ] Jalon : un joueur peut passer 5 h sans toucher a l'histoire

### Phase 21 : Extension de Cotonou (v0.5)
- [ ] Pipeline d'import entierement automatise et documente (OSM, Overture, Open Buildings, Sentinel-2) pour une nouvelle zone
- [ ] Centre et grand marche (le chaos ultime pour les poursuites), quartier d'affaires, port
- [ ] Lagune et ponts, Akpakpa, Fidjrosse
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
- [ ] Nouveaux vehicules : camions, bus, bateaux, avion leger
- [ ] Jalon : trois "villes" et de la campagne, comme San Andreas, a notre sauce

### Phase 24 : Finition et sortie v1.0
- [ ] Traduction anglaise (a partir du fichier de traduction de la Phase 13), puis fon pour les menus et une partie des dialogues
- [ ] Accessibilite : taille de l'interface (0,8 a 1,6), aide a la visee a la souris (et verrouillage a la manette), reaffectation des touches du clavier, sous-titres reglables : faits (test_finition) ; daltonisme a faire
- [ ] Succes (13, gardes pour tout le jeu, page dans le menu) et 3 emplacements de sauvegarde (resume chapitre / missions / argent / date) : faits ; mode photo complet a faire
- [ ] Optimisation finale sur 3 configurations (PC modeste, moyen, Olympe)
- [ ] Bêta publique, correction des retours, version 1.0
- [ ] Trailer de lancement, page de vente, presse et createurs de contenu
- [ ] Jalon : GTB 1.0 publie

Option plus tard : multijoueur (balade et courses de zems entre amis, puis missions en cooperation).

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

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : GTB (Gbê Town Bénin), un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo). Objectif long terme : le niveau d'un GTA San Andreas, a notre sauce, sur Cotonou puis ses environs.

STACK
- Modelisation : Blender 5.2 (Microsoft Store), export glTF 2.0 (.glb), tout par script (blender/tools/)
- Moteur : Godot 4.7.2 (Forward+), physique interpolee, RTX 2050 chez Olympe
- Echelle : 1 unite = 1 metre
- Zone : aeroport de Cotonou, Erevan, la plage, Haie Verte et Cadjehoue. Bbox N 6.3610, S 6.346380, O 2.375259, E 2.387500 (1,35 x 1,6 km), OSM dans refs/osm/zone-gtb.osm ; origine figee au centre de la premiere zone (6.3498725, 2.3813795)
- Cible : Android, Windows et Linux ; pas d'Apple, pas de web

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly, materiaux proceduraux jusqu'aux releves photo (Phase 12)
- Nom : GTB (Gbê Town Bénin), jamais GTA ni "Grand Theft"
- Couleurs dans les shaders : ecrites en sRGB, converties en lineaire a la fin (pow 2.2)
- Objets : jamais de nom en *_col / *-col pour un objet decoratif (Godot cree une collision)
- Tout son est synthetise (godot/scripts/audio_synth.gd) jusqu'a la Phase 19 ; tout modele est fait par script Blender (blender/tools/)

ETAT ACTUEL (16/10/2026)
- Phases 0 a 10 faites techniquement. Le jeu est jouable du lancement (builds/windows/GTB.exe, ecran titre, Nouvelle
  partie) a la fin de l'acte 1 ("A suivre").
- Fait :
  - Monde : 1,35 x 1,6 km (aeroport, Erevan, plage, Haie Verte, Cadjehoue), OSM + Overture + Open Buildings 2.5D +
    littoral Sentinel-2 (osm_import.py -> zone_aeroport.glb/.json), tuiles de 500 m, occultation, concessions avec
    portails, harmattan, horizon a 6 km, meteo, jour / nuit, sons synthetises.
  - Jeu : joueur facon GTA V (sprint, saut, escalade, accroupi, ragdoll, entree / sortie de vehicule animees), zem,
    berline, 4x4, minibus, pick-up, zem-taxi (deplacement rapide), circulation, pietons, interieurs (maison, Ararat,
    terminal, avions), argent FCFA, achats, sante, HUD, ecran titre, pause, options (Bas / Moyen / Haut), sauvegarde
    (lit ou menu), histoire "Le Dernier Vol" (docs/histoire.md : 8 missions prologue + acte 1, 2 missions de Maman Fifi
    a Haie Verte, courses de zem a volonte), police fictive (etoiles, patrouilles, arrestation, amendes, contraventions).
  - Personnages : corps Quaternius cales sur 10 morphologies, vetements decoupes dans la peau, clips captes pour le
    joueur et les PNJ (LOD d'animation et d'ombre).
  - Tests : godot/tests/test_*.gd (20 suites) tous OK dont test_journal.
  - Phase 11 : journal de partie automatique (journal.gd), version 0.1.0 et log disque actif, migration sauvegardes v2,
    defauts visuels corriges (pagne sous vehicules, cheveux mouilles sous pluie, casquette policiere, traversees).
- PHASE EN COURS : Phase 11, validation et playtest (voir la roadmap). Prochaines taches pour l'agent :
  1. Fluidite : faite (tests/perf.sh au vert dans les trois qualites, outils tests/ab_gpu.gd et tests/profil_vue.gd).
  2. Equilibrage : prix, amendes, chronos, vitesse et agressivite police, salaires zem.
  3. Web retire de la cible (decision d'Olympe du 17/10/2026) ; demo sur Android, Windows et Linux.
- Taches d'Olympe (ne pas les faire a sa place) : jouer 1 h et remplir docs/retours_olympe.md, valider les jalons 3 a 5,
  faire jouer 2 ou 3 amis avec docs/playtest.md, releves photo pour la Phase 12, captures pour le trailer, decisions de
  la section 2 bis de la roadmap.
- Ensuite : Phase 12 (Cotonou reel), Phase 13 (demo publique), puis v0.2 (phases 14 a 17).
- Personnages : base Quaternius Universal Base Characters (refs/ubc, non versionne) calee par blender/tools/ubc_body.py.
- Outils : Godot 4.7.2 dans Telechargements (utiliser le _console.exe pour la ligne de commande ; modeles d'export dans
  %APPDATA%/Godot/export_templates/4.7.2.stable) ; Blender 5.2 lance via
  %LOCALAPPDATA%/Microsoft/WindowsApps/blender-launcher.exe -b --python ... (voir docs/PIPELINE.md) ; Python geo dans WSL
  (~/.venvs/geo, overturemaps installe). Envoi git : depuis le git Windows (le git de WSL n'a pas les identifiants),
  jamais de ligne Co-Authored-By.
- Regles d'Olympe : tout ce qui n'est pas fidele a Cotonou est corrige ou supprime ; aucun nom reel en jeu (signaler
  avant de renommer) ; budget 70 images/s dehors et 60 en interieur ; tests au vert a chaque commit ; demander avant
  tout choix structurant (en particulier tout ce qui est liste dans "Decisions a prendre").
- Attention mesures : arreter les Blender / Godot restes en fond avant perf_fps.gd (sinon 10 images/s dans les interieurs).
- Bloquants : aucun. Attention : si l editeur Godot est ouvert pendant qu on modifie project.godot, il faut le fermer et
  rouvrir le projet (sinon erreurs "global uniform does not exist", fichiers non importes).

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