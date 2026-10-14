# GTB (Gbê Town Bénin) : Roadmap et prompt de passation

Derniere mise a jour : 14/10/2026
Phase en cours : Phase 1 (pipeline assets)

---

## 1. Vision

Un jeu open world 3D type GTA, ancre dans le Benin. On commence par UNE zone (aeroport de Cotonou, Erevan, la plage), jouable de bout en bout, puis on etend.

## 2. Decisions actees

- Cible : PC d'abord, export web possible plus tard (hypothese par defaut, a confirmer)
- Moteur : Godot 4.x
- Modelisation : Blender, export glTF 2.0 (.glb)
- Echelle : 1 unite = 1 metre, axe Z vers le haut dans Blender, export en Y up
- Premiere zone : aeroport de Cotonou (Cadjehoun), Erevan, la plage (remplace Zogbo, decision du 14/10/2026)
- Style : semi-realiste, low a mid poly pour tenir sur PC modeste
- Pas de textures avant la Phase 6 : couleurs unies (beton gris, tole bleu-gris, terre rouge, sable, bitume, eau)
- Nom : GTB, Gbê Town Bénin (ne jamais utiliser GTA ni "Grand Theft" pour eviter un conflit de marque)
- Langue du jeu : francais (et possibilite d'ajouter fon/anglais plus tard)

## 3. Ce dont tu as besoin

Logiciels (tous gratuits) :
- Blender 4.x
- Godot 4.x (version standard, pas .NET sauf si tu veux du C#)
- Git + GitHub (depot prive du projet)
- Krita ou GIMP (textures), Audacity (sons)
- Plugin Blender : Blender-OSM (import de la geometrie des rues depuis OpenStreetMap)

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
- [ ] Test complet : un cube modelise sous Blender, exporte en .glb, importe dans Godot avec collision
- [x] Script ou procedure d export en un clic (blender/tools/export_glb.py)
- [ ] Bibliotheque de materiaux de base (beton, tole, terre rouge, bitume, peinture ecaillee)

### Phase 2 : Blockout de la zone aeroport
- [ ] Import du plan des rues via Blender-OSM
- [ ] Ajustement des rues, carrefours, trottoirs, relief reel
- [ ] Blockout des batiments (volumes simples, bonnes hauteurs)
- [ ] Placement des reperes importants (marche, carrefour principal, stations, eglises, etc.)
- [ ] Import dans Godot, test de balade en camera libre
- [ ] Jalon : "le quartier est reconnaissable en blockout"

### Phase 3 : Joueur a pied
- [ ] Personnage 3e personne (marche, course, saut, camera)
- [ ] Animations Mixamo (idle, walk, run)
- [ ] Collisions propres avec le decor
- [ ] Jalon : balade fluide dans tout le quartier

### Phase 4 : Le zem (premier vehicule)
- [ ] Modele de moto-taxi (cadre, jaune/vert selon reference locale)
- [ ] Controleur (acceleration, freinage, virages, inclinaison)
- [ ] Monter / descendre, camera vehicule
- [ ] Sons moteur et klaxon
- [ ] Jalon : conduire un zem de l aeroport a la plage

### Phase 5 : Ville vivante
- [ ] PNJ pietons (marche sur trottoirs, vendeurs, groupes)
- [ ] Trafic simple (zem, voitures, taxis sur chemins definis)
- [ ] Cycle jour/nuit et eclairage (lampadaires, coupures de courant)
- [ ] Ambiances sonores par zone
- [ ] Jalon : le quartier "respire"

### Phase 6 : Modelisation detaillee et textures
- [ ] Remplacer le blockout par des batiments detailles (facades, portes, toits en tole)
- [ ] Props locaux (etals, poteaux SBEE, enseignes, vehicules, ordures, barrieres)
- [ ] Textures reelles issues des photos
- [ ] Optimisation (instances, LOD, occlusion)

### Phase 7 : Gameplay de base
- [ ] Systeme d'argent (FCFA), inventaire, interactions (acheter, parler)
- [ ] UI : HUD, carte, menu
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

---

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : GTB (Gbê Town Bénin), un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo).

STACK
- Modelisation : Blender 4.x, export glTF 2.0 (.glb)
- Moteur : Godot 4.x
- Echelle : 1 unite = 1 metre
- Premiere zone : aeroport de Cotonou (Cadjehoun), Erevan, la plage. Bbox N 6.353365, S 6.346380, O 2.375259, E 2.387500 (environ 1,35 km x 0,78 km), OSM dans refs/osm/zone-aeroport.osm
- Cible : PC d'abord, web ensuite

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly, couleurs unies sans textures jusqu a la Phase 6
- Nom : GTB (Gbê Town Bénin), jamais GTA ni "Grand Theft"

ETAT ACTUEL
- Phase en cours : Phase 1 (pipeline assets)
- Fait : depot GitHub https://github.com/Geminiboug/GTA-B_1 (main), structure en place, roadmap dans docs/benin-gta-roadmap.md, Blender, Godot et Blender-OSM installes, limites de la zone fixees et export OSM recupere, nom GTB choisi, 57 photos de reference dans refs/ (Phase 0 terminee)
- Prochaine tache : Olympe fait le test du cube (docs/PIPELINE.md), puis bibliotheque de materiaux de base, puis import OSM dans Blender
- Bloquants : aucun

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
