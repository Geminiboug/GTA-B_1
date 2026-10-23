# Ce qu'Olympe peut faire (et que je ne peux pas faire à ta place)

Coche au fur et à mesure (`[x]`). Tout est rangé du plus utile au moins urgent. Rien ici ne bloque mon travail : je continue de mon côté, et chaque point que tu fais rend le jeu plus juste.

## 1. Jouer et noter (le plus utile)

- [ ] **Jouer l'acte 1 en entier** (1 h minimum), avec la dernière version (`builds/windows/GTB.exe`).
  - Note tout ce qui cloche dans [retours_olympe.md](retours_olympe.md) : une ligne par problème, avec l'endroit et ce que tu faisais.
  - Une capture vaut mieux qu'une longue phrase (Impr. écran, ou F12 pour le mode photo sans HUD).
- [ ] **Essayer précisément ce que j'ai corrigé le 18/10** et me dire si c'est bon :
  - écran de chargement : le carrousel tourne-t-il, est-ce qu'il bloque encore ?
  - paramètres : chaque réglage change-t-il tout de suite ?
  - voitures : dérapent-elles encore toutes seules ? Les trottoirs passent-ils sans dégâts ?
  - zem : béquille, passager qui penche, conducteur qui ne tremble plus ;
  - sprint (Maj) sans à-coups ;
  - armoire près du lit pour changer de tenue ;
  - avions visibles dans le ciel.
- [ ] **Valider les jalons des phases 3, 4 et 5** avec [validation_phases_3_5.md](validation_phases_3_5.md) (cocher OK ou noter).
- [ ] **Faire jouer 2 ou 3 amis** avec [playtest.md](playtest.md). Regarde sans aider et note où ils bloquent.

## 2. Cotonou réel (photos et test à l'aveugle)

- [ ] **Test à l'aveugle** avec 2 ou 3 personnes qui connaissent Cotonou.
  - Montre-leur les images `apres_*.png` de [images/phase12/](images/phase12/), mélangées à d'autres images.
  - Demande : « À quel type de lieu cette image te fait-elle penser ? Qu'est-ce qui te fait penser cela ? ».
  - Note leurs réponses mot pour mot, sans souffler.
- [ ] **Photos sur le terrain** : liste complète et détaillée dans [photos_terrain.md](photos_terrain.md). Résumé :
  - `facades` : façades entières, de face (maison basse, maison à étage, boutique) ;
  - `portails` : portails de concession en gros plan ;
  - `sols` : bitume usé, pavés, sable, caniveaux (photo à la verticale, à 1 m du sol) ;
  - `toits` : toits vus d'un étage (citernes, fers d'attente, acrotères) ;
  - `boutiques` : devantures, de jour et le soir ;
  - `zems` : une station de zems ;
  - `arbres` : badamier, neem, manguier, cocotier ;
  - `marquage` : **la ligne au milieu de la route, est-elle jaune ou blanche ?** Une photo d'un grand axe suffit. C'est la seule question de l'audit que je n'ai pas pu trancher.
- [ ] **Sons sur le terrain** (téléphone suffit, 30 s à 1 min chacun, sans parler) : zem qui passe et qui démarre, klaxons, marché, maquis, rue le soir. Dans `refs/sons/`.

## 3. Matériel et appareils

- [ ] **Tester l'APK** (`builds/android/GTB.apk`) sur un téléphone Android de milieu de gamme. Le mode débug (F1 sur clavier, sinon dis-moi ce que tu ressens) : est-ce fluide ? Les boutons tactiles sont-ils bien placés ?
- [ ] **Tester la qualité « Bas »** sur un PC modeste (le tien en Bas, ou celui d'un ami) et me dire si ça saccade.
## 4. Publication de la démo

- [ ] **Logo et icône du jeu** : il y a une icône provisoire (`godot/icone.png`, « GTB » jaune sur fond nuit, faite par `godot/tools/faire_icone.gd`). Si tu fais un vrai logo (palette donnée plus tôt), mets-le en PNG carré 1024 x 1024 à la place.
- [ ] **Formulaire de retours des joueurs** (Google Forms, par exemple) : envoie-moi le lien, je le branche sur l'écran de fin de démo.
- [ ] **Compte itch.io** : crée le compte et la page (en brouillon). Je peux préparer les textes et les images à partir de [presentation.html](presentation.html).
- [ ] **Captures pour le trailer** avec OBS (60 à 90 s au final, montage CapCut). Je peux te faire une liste de plans à filmer.

## 4 bis. Valider un nom

- [x] **Fidjrossè devient « Fidjrossa »** dans le jeu (même principe que Haie Verte et Cadjehoue). D'accord, ou tu préfères un autre nom ?

## 4 ter. Demandes du 22/10/2026 : a trancher ou a fournir

- [ ] **Emplacement d'ETIPECH** : EPITECH Benin est a Seme City, a environ 20 km a l'est de l'aeroport (la carte actuelle s'arrete a 3,6 km). Je propose de placer le campus ETIPECH dans la carte existante (licence artistique), pres de l'extremite est, avec un batiment visitable. D'accord, ou tu preferes etendre la carte vers l'est ?
- [ ] **Photos d'ETIPECH** (facade, entree, hall, salles, escalier) pour que je fasse l'interieur, dans `refs/etipech/`.
- [ ] **Logo en haute resolution** : la planche donne un logo de 444 px seulement. Si tu as le fichier du logo (PNG transparent 2048 px) et les variantes (icone ronde, version blanche), mets-les dans `refs/logo/`.
- [ ] **Tester le pilotage** de l'avion leger a l'aeroport (E pour monter ; Accelerer / Freiner = gaz ; W piquer, S cabrer ; A / D incliner ; Z / X palonnier ; Espace freins de roues) et me dire si les reglages te conviennent (vitesse de rotation, assistance dans les virages).
- [ ] **Tester le zem a heler** (touche H pres d'une rue), les stations Bon Plein (carburant) et le supermarche par rayons.
- [ ] **Photos de l'Amazone, de la place du Souvenir et du parc** pour les monuments (comme pour Bio Guera).

## 5. Plus tard (pas urgent)

- [ ] Un locuteur fon pour relire les menus et quelques dialogues (Phase 24).
- [ ] Comédiens pour les voix et musiciens pour les radios, avec un contrat écrit (Phase 19, voir [LEGAL.md](LEGAL.md)).
- [ ] Avis d'un avocat avant une sortie payante.

## Décisions déjà prises (rappel)

- Agrandir la carte (validé le 18/10/2026) : d'abord Fidjrossè à l'ouest, puis le centre avec le grand marché, et avant ça le chargement par morceaux. Je m'y mets après avoir fini les tâches en cours des Phases 11 et 12.
 QW26P0-K
## 4 quater. Photos et verifications demandees par le travail du 23/10/2026
- Photos du monument aux Amazones (face, profil, dos, socle) dans refs/monuments/amazone/ : la statue actuelle est une forme simplifiee.
- Photos d'EPITECH Benin / Seme City (batiments, entree, routes d'acces) dans refs/etipech/ ; coordonnees exactes du campus (clic droit sur la carte).
- Photos des feux tricolores, STOP, ralentisseurs et marquages de Fidjrosse (refs/rues/) pour affiner la signalisation.
- Regarder en jeu : le camion, la citadine, le monospace, l'autobus, les motos civiles et les velos ; les poteaux de feux et leurs emplacements ; les phares de nuit ;
  l'interieur de la maison (lit, armoire, cuisine) ; la mort du joueur (chute et ralenti) ; l'eau des bassins.
