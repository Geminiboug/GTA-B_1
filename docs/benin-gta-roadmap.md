# BENIN GTA (nom provisoire) : Roadmap et prompt de passation

Derniere mise a jour : 14/10/2026
Phase en cours : Phase 0 (cadrage et setup)

---

## 1. Vision

Un jeu open world 3D type GTA, ancre dans le Benin. On commence par UN quartier (Zogbo, Cotonou), jouable de bout en bout, puis on etend.

## 2. Decisions actees

- Cible : PC d'abord, export web possible plus tard (hypothese par defaut, a confirmer)
- Moteur : Godot 4.x
- Modelisation : Blender, export glTF 2.0 (.glb)
- Echelle : 1 unite = 1 metre, axe Z vers le haut dans Blender, export en Y up
- Premier quartier : Zogbo
- Style : semi-realiste, low a mid poly pour tenir sur PC modeste
- Langue du jeu : francais (et possibilite d'ajouter fon/anglais plus tard)

## 3. Ce dont tu as besoin

Logiciels (tous gratuits) :
- Blender 4.x
- Godot 4.x (version standard, pas .NET sauf si tu veux du C#)
- Git + GitHub (depot prive du projet)
- Krita ou GIMP (textures), Audacity (sons)
- Plugin Blender : Blender-OSM (import de la geometrie des rues depuis OpenStreetMap)

Ressources :
- Photos et videos de reference de Zogbo (rues, enseignes, zem, marches, poteaux, maisons)
- Releve terrain : prendre des photos a plat de facades, carrefours, sols
- Animations humanoides : Mixamo (gratuit)
- Sons ambiance : enregistrements terrain (klaxons, zem, marche, appels a la priere, musique) + libres de droits
- Textures : ambientCG, Poly Haven (CC0), plus tes propres photos

Materiel :
- Verifier GPU et RAM (voir ton PC) : fixe le budget de polygones et la taille des textures

## 4. Roadmap

### Phase 0 : Cadrage et setup
- [x] Creer le depot Git (structure : /blender, /godot, /docs, /refs)
- [ ] Installer Blender, Godot, Blender-OSM
- [ ] Choisir le nom du projet
- [ ] Definir la zone exacte de Zogbo (limites, environ 500 m x 500 m pour commencer)
- [ ] Collecter 50+ photos de reference classees par type

### Phase 1 : Pipeline assets
- [ ] Conventions : echelle, nommage (prefixes bld_, prop_, veh_, chr_), origines des objets
- [ ] Test complet : un cube modelise sous Blender, exporte en .glb, importe dans Godot avec collision
- [ ] Script ou procedure d'export en un clic
- [ ] Bibliotheque de materiaux de base (beton, tole, terre rouge, bitume, peinture ecaillee)

### Phase 2 : Blockout de Zogbo
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
- [ ] Jalon : conduire un zem dans Zogbo

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

---

## 6. PROMPT DE PASSATION (a copier tel quel dans un autre Claude ou agent IA)

```
Tu reprends un projet en cours : un jeu open world 3D type GTA ancre dans le Benin, developpe par Olympe (Lib), etudiant Tek3 a Epitech Benin, qui vit a Cotonou (quartier Zogbo).

STACK
- Modelisation : Blender 4.x, export glTF 2.0 (.glb)
- Moteur : Godot 4.x
- Echelle : 1 unite = 1 metre
- Premier quartier : Zogbo (Cotonou), zone d'environ 500 m x 500 m
- Cible : PC d'abord, web ensuite

CONVENTIONS
- Nommage : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages)
- Depot : /blender, /godot, /docs, /refs
- Style : semi-realiste, low a mid poly

ETAT ACTUEL
- Phase en cours : Phase 0 (cadrage et setup)
- Fait : depot Git local cree (main), structure en place, roadmap dans docs/benin-gta-roadmap.md
- Prochaine tache : creer le depot prive GitHub et pousser, installer Blender, Godot et Blender-OSM, definir les limites exactes de Zogbo
- Bloquants : aucun

ROADMAP
Phase 0 Setup, 1 Pipeline assets, 2 Blockout Zogbo, 3 Joueur a pied, 4 Zem, 5 Ville vivante, 6 Modelisation detaillee, 7 Gameplay de base, 8 Police/danger, 9 Extension, 10 Finition et sortie.

REGLES DE TRAVAIL AVEC OLYMPE
- Repondre en francais, de facon courte et directe, orientee action
- Jamais de tirets cadratins ni de ponctuation "style IA"
- Changements de code minimaux et cibles, pas de reecriture complete
- Livrables prets a copier-coller
- Ne pas lui expliquer ce qu'il peut ou non faire : il vise un vrai GTA du Benin, on avance par petites etapes
- A la fin de chaque tache : dire ce qui est fait, mettre a jour la section ETAT ACTUEL, proposer la suite

MISE A JOUR OBLIGATOIRE DE CE PROMPT
- Ce prompt est un relais entre agents. Avant de terminer ta session (ou quand tu finis une tache), tu dois reecrire ce meme prompt en entier, a jour, pour le prochain agent.
- Mets a jour : ETAT ACTUEL (phase en cours, ce qui est fait, prochaine tache, bloquants), la date, les decisions prises, les conventions ajoutees et les chemins de fichiers importants.
- Garde toutes ces regles, y compris celle-ci, dans la nouvelle version, pour que le suivant fasse pareil.
- Ajoute une ligne au journal d'avancement de benin-gta-roadmap.md et coche les taches terminees.
- Rends le nouveau prompt complet dans un bloc de code, pret a copier-coller.

Commence par lire ETAT ACTUEL et execute la prochaine tache.
```
