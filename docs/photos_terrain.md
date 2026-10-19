# Photos de terrain : liste complète, avec les endroits

Le but : rendre le jeu fidèle à Cotonou. Les photos servent à fabriquer les textures (murs, sols, toits) et à corriger les formes et les couleurs. Elles ne sont jamais publiées telles quelles.

Coche au fur et à mesure (`[x]`). Les sections sont rangées de la plus utile à la moins urgente. Même une partie de la liste m'aide déjà beaucoup.

## Comment lire les emplacements

- Chaque photo a un **endroit précis** : les coordonnées GPS, cliquables, ouvrent Google Maps sur le point. Sur le téléphone, tu peux aussi coller les deux nombres dans la barre de recherche de Google Maps.
- Le **nom entre guillemets** est un repère réel tout proche (bar, pharmacie, école…), tiré d'OpenStreetMap. Il sert à te situer, et la distance indique à combien de mètres il se trouve. Ces noms restent dans ce document interne : dans le jeu, tout est renommé.
- La plupart des rues de ces quartiers **n'ont pas de nom** sur les cartes. Je donne alors le type de rue (rue de quartier, grand axe) et le repère le plus proche.
- Le GPS est précis à 10 ou 20 m près. Si le point tombe au milieu d'un pâté de maisons, photographie le bâtiment qui correspond à la description, **depuis la rue**.
- Les maisons sont des propriétés privées : reste toujours sur la voie publique, et ne vise ni les fenêtres ni les personnes.
- Je les ai choisies dans les **4 secteurs du jeu**, pour que chacun ait ses vraies références :
  - **Aéroport / Route des Pêches** : le quartier de départ ;
  - **Haie Vive / Cadjehoun** : au nord ;
  - **Fiyégnon** : à l'ouest de l'aéroport ;
  - **Fidjrossè** : la nouvelle zone, à l'ouest.

## Règles pour toutes les photos

- **Heure** : entre 9 h et 11 h, ou entre 15 h et 16 h 30. Pas en plein midi (ombres trop dures), pas en contre-jour.
- **Ciel** : un ciel légèrement voilé est idéal, car il donne peu d'ombres. Évite la pluie.
- **Cadrage** :
  - de **face** : le téléphone droit, parallèle au mur, ni penché ni en biais ;
  - pour les sols : le téléphone à **plat au-dessus du sol**, à environ 1 m de hauteur.
- **Distance** : une photo **d'ensemble** (tout l'objet), plus une ou deux photos **de près** (la matière, à 1 m).
- **Échelle** : quand c'est possible, mets un objet connu dans le cadre (ta chaussure, une bouteille d'eau, un mètre).
- **Personnes** : évite les visages reconnaissables et les plaques d'immatriculation lisibles.
- **Marques et enseignes** : prends-les quand même, je les remplace toujours par des noms inventés. J'ai besoin du style (couleurs, taille des lettres, matériau).
- **Qualité** : la résolution maximale, sans filtre, sans mode portrait, sans zoom numérique (avance-toi plutôt). Active la **localisation des photos** dans l'appareil photo : je retrouverai ainsi l'endroit exact.
- **Nommage** : `lieu_sujet_numero.jpg`, par exemple `fidjrosse_facade_r1_01.jpg`. Si c'est compliqué, mets juste chaque série dans le bon dossier.
- **Rangement** : `refs/terrain/<dossier>/`, avec les dossiers indiqués à chaque section, et un `notes.txt` d'une ligne par série si tu as photographié ailleurs que prévu.

## 1. La question en attente (5 minutes)

Dossier : `refs/terrain/marquage/`

- [ ] **Ligne au milieu de la Route des Pêches** : jaune ou blanche ? Debout sur le bas-côté, dans l'axe de la route.
  - Près de « Banque Atlantique » et du « Maquis de la Playa » : [6.34979, 2.38139](https://www.google.com/maps?q=6.349795,2.381388)
  - À Fidjrossè, près du « Regaebar » : [6.34950, 2.36584](https://www.google.com/maps?q=6.349497,2.365836)
- [ ] **Ligne au milieu de l'avenue Pape Jean-Paul II** (le boulevard de l'aéroport), près de « AEROPORT MCA » : [6.35375, 2.38634](https://www.google.com/maps?q=6.353751,2.386342)
- [ ] **Terre-plein central** : vue d'ensemble et de près (bordure peinte ?, sol, plantes).
  - Avenue Pape Jean-Paul II, près de « AEROPORT MCA » : [6.35263, 2.38613](https://www.google.com/maps?q=6.352628,2.386128)
  - Grand axe près de la station « JNP » : [6.35088, 2.38698](https://www.google.com/maps?q=6.350875,2.386978)
  - Route des Pêches, près de « Banque Atlantique » : [6.34978, 2.38091](https://www.google.com/maps?q=6.349782,2.380914)
  - Grand axe de Fidjrossè, près de « Pharmacie Oceane » : [6.35681, 2.36524](https://www.google.com/maps?q=6.356809,2.365237)
- [ ] **Bords de chaussée** (ligne de rive, bordures peintes rouge et blanc) : aux mêmes endroits.
- [ ] **Passage piéton**, devant l'école « Les Lauriers » (Fiyégnon) : [6.35372, 2.37520](https://www.google.com/maps?q=6.353723,2.375201)

## 2. Façades (le plus visible dans le jeu)

Dossier : `refs/terrain/facades/`. Pour chaque maison : une photo entière de face, une de près sur l'enduit (1 m), une sur une fenêtre, une sur la porte. Les hauteurs viennent des mesures satellites (Open Buildings), ce qui me permet de vérifier l'échelle du jeu.

**Maisons de plain-pied** (2 à 4 m)

- [ ] Aéroport, près de « Nico's Hair » (49 m), toit plat : [6.34946, 2.38582](https://www.google.com/maps?q=6.349461,2.385819)
- [ ] Aéroport, près de « Wellness Fitness Center » (134 m), toit plat : [6.34836, 2.38242](https://www.google.com/maps?q=6.348359,2.382416)
- [ ] Haie Vive, près de « Garage Expérience 2000 » (146 m), toit en tôle : [6.35801, 2.37787](https://www.google.com/maps?q=6.358011,2.377870)
- [ ] Haie Vive, près de « Hotel Akwaba » (207 m), toit plat : [6.35905, 2.37563](https://www.google.com/maps?q=6.359047,2.375632)
- [ ] Fiyégnon, à côté du restaurant « Chez Nous » (13 m), toit en tôle : [6.35421, 2.37021](https://www.google.com/maps?q=6.354206,2.370205)
- [ ] Fiyégnon, près du bar « Le Parking » (100 m), toit en tôle : [6.35653, 2.37458](https://www.google.com/maps?q=6.356531,2.374578)
- [ ] Fidjrossè, près de « Le Colibri Guesthouse » (75 m), toit plat : [6.35334, 2.37003](https://www.google.com/maps?q=6.353341,2.370034)
- [ ] Fidjrossè ouest, près de « AHOUANSOU G. » (130 m), toit plat : [6.35475, 2.35458](https://www.google.com/maps?q=6.354747,2.354579)

**Maisons à un étage (R+1)** (6 à 8 m)

- [ ] Aéroport, sur la Route des Pêches, à côté de « Wellness Fitness Center » : [6.34957, 2.38234](https://www.google.com/maps?q=6.349573,2.382335)
- [ ] Aéroport, rue de quartier au nord : [6.35213, 2.38349](https://www.google.com/maps?q=6.352134,2.383493)
- [ ] Haie Vive, près de « Garage Expérience 2000 » (168 m) : [6.35792, 2.37743](https://www.google.com/maps?q=6.357918,2.377425)
- [ ] Haie Vive, près de « Hotel Padelia » (186 m) : [6.35808, 2.37977](https://www.google.com/maps?q=6.358076,2.379768)
- [ ] Fiyégnon, près de l'école « Les Lauriers » (81 m) : [6.35392, 2.37449](https://www.google.com/maps?q=6.353919,2.374489)
- [ ] Fiyégnon, sud de l'école « Les Lauriers » (228 m) : [6.35250, 2.37354](https://www.google.com/maps?q=6.352499,2.373537)
- [ ] Fidjrossè, près de « Pharmacie Oceane » (71 m) : [6.35731, 2.36455](https://www.google.com/maps?q=6.357311,2.364545)
- [ ] Fidjrossè, près du bar « Chez kiki » (84 m) : [6.35099, 2.36611](https://www.google.com/maps?q=6.350987,2.366114)

**Immeubles R+2 ou plus** (8 à 14 m)

- [ ] Aéroport, près de « Banque Atlantique » (57 m), 14 m : [6.34920, 2.38048](https://www.google.com/maps?q=6.349203,2.380482)
- [ ] Haie Vive, rue 12.341, à côté de « Le Prestigieux », 12 m : [6.36013, 2.37941](https://www.google.com/maps?q=6.360129,2.379409)
- [ ] Haie Vive, rue de quartier, 9 m : [6.35704, 2.37772](https://www.google.com/maps?q=6.357043,2.377716)
- [ ] Fiyégnon, cœur du quartier, 10 m : [6.35388, 2.37277](https://www.google.com/maps?q=6.353881,2.372772)
- [ ] Fiyégnon, près du restaurant « Chez Kadi » (164 m), 10 m : [6.35636, 2.37097](https://www.google.com/maps?q=6.356364,2.370969)
- [ ] Fidjrossè, près du bar « Chez kiki » (121 m), 8 m : [6.35135, 2.36612](https://www.google.com/maps?q=6.351347,2.366119)
- [ ] Fidjrossè ouest, près de « G2F Hôtel » (191 m), 11 m : [6.35308, 2.35234](https://www.google.com/maps?q=6.353080,2.352340)

**Détails à prendre sur ces mêmes façades, ou là où tu les vois**

- [ ] **Maison en parpaings non enduits** (brute ou en construction) : 2 exemples, n'importe où.
- [ ] **Créneaux sur un toit-terrasse** (petits murets en dents) : 1 ou 2, surtout à Haie Vive et Fiyégnon.
- [ ] **Fenêtres** de près : persiennes métalliques, naco (lames de verre), grilles en losanges, en carreaux, à barreaux.
- [ ] **Portes** : métallique peinte, en bois, porte vitrée de boutique.
- [ ] **Climatiseurs et compteurs** accrochés au mur.
- [ ] **Usure** : bas des murs salis par la pluie et la terre, peinture écaillée, fissures.
- [ ] **Inscriptions peintes** sur les murs (« À VENDRE », « DÉFENSE D'URINER », numéros de téléphone…) : 3 à 5.

## 3. Murs d'enceinte et portails (concessions)

Dossier : `refs/terrain/portails/`. Les rues de quartier en sont pleines. Les meilleurs endroits :

- [ ] **Rues de quartier de Fiyégnon**, autour de « Fiyégnon-Jacquot » : [6.35444, 2.37184](https://www.google.com/maps?q=6.354443,2.371842)
- [ ] **Rues de quartier de Fidjrossè**, autour du centre du quartier « Fidjrossé » : [6.35250, 2.36755](https://www.google.com/maps?q=6.352503,2.367549)
- [ ] **Djako**, autour de « Djako Daho » : [6.35296, 2.35556](https://www.google.com/maps?q=6.352963,2.355562)

À photographier :

- [ ] **Mur de concession enduit** : vue d'ensemble, hauteur avec un repère, de près sur l'enduit, le dessus du mur (tessons, fers, rien ?).
- [ ] **Mur en parpaings bruts** : vue d'ensemble et de près.
- [ ] **Portails en tôle peinte** : 4 ou 5 couleurs, de face entier, puis de près (motifs, gonds, serrure).
- [ ] **Portail avec portillon** (petite porte dans le grand portail).
- [ ] **Clôture en grillage ou en bambou**, si tu en vois.

## 4. Sols et routes

Dossier : `refs/terrain/sols/`. Pour chaque sol : le téléphone à plat à 1 m du sol, sans ton ombre dans le cadre, puis une photo en biais de toute la rue. Le revêtement indiqué vient d'OpenStreetMap : dis-moi s'il est faux.

- [ ] **Bitume neuf** :
  - Avenue Pape Jean-Paul II, vers l'est : [6.35374, 2.39101](https://www.google.com/maps?q=6.353738,2.391008)
  - Route des Pêches : [6.34979, 2.38139](https://www.google.com/maps?q=6.349795,2.381388)
- [ ] **Bitume usé** (nids-de-poule, rapiéçages, bords effrités) :
  - grand axe près de « AEROPORT MCA » : [6.35217, 2.38618](https://www.google.com/maps?q=6.352172,2.386182)
  - rue goudronnée de Haie Vive : [6.36175, 2.38337](https://www.google.com/maps?q=6.361748,2.383374)
- [ ] **Pavés** (avec ta chaussure pour l'échelle) :
  - devant « Société Générale », à l'aéroport : [6.34978, 2.38680](https://www.google.com/maps?q=6.349784,2.386800)
  - rue pavée de Fidjrossè : [6.35828, 2.36360](https://www.google.com/maps?q=6.358285,2.363596)
  - Fidjrossè ouest : [6.35754, 2.35567](https://www.google.com/maps?q=6.357540,2.355665)
  - grand axe pavé de Fiyégnon : [6.35924, 2.37223](https://www.google.com/maps?q=6.359240,2.372228)
- [ ] **Béton** : voie près de « Société Générale » : [6.34957, 2.38671](https://www.google.com/maps?q=6.349571,2.386709)
- [ ] **Sable des rues de quartier** (sec, et mouillé après la pluie si possible) :
  - Fidjrossè, à côté de « Fidjrossé » : [6.35234, 2.36780](https://www.google.com/maps?q=6.352337,2.367801)
  - Fiyégnon : [6.35318, 2.37271](https://www.google.com/maps?q=6.353178,2.372707)
  - Fidjrossè ouest, près de « AHOUANSOU G. » : [6.35380, 2.35555](https://www.google.com/maps?q=6.353797,2.355554)
- [ ] **Terre** :
  - près du bar « La Tour Eiffel » : [6.35011, 2.36407](https://www.google.com/maps?q=6.350115,2.364075)
  - près de « La Terre des Invités » : [6.35254, 2.35986](https://www.google.com/maps?q=6.352543,2.359856)
- [ ] **Terre damée** (rue principale de quartier) :
  - près de « Loris Poulet » : [6.35014, 2.36863](https://www.google.com/maps?q=6.350140,2.368629)
  - près de « Pharmacie Akogbato » : [6.35804, 2.35658](https://www.google.com/maps?q=6.358036,2.356577)
- [ ] **Bas-côté** où se garent les zems, **caniveaux** (ouvert, couvert, grille), **flaques**, **trottoir** : le long de la Route des Pêches et du grand axe de Fidjrossè, près de « Pharmacie Oceane » : [6.35698, 2.36511](https://www.google.com/maps?q=6.356983,2.365107)

## 5. Toits

Dossier : `refs/terrain/toits/`

- [ ] **Vue plongeante sur les toits**, depuis un étage ou une terrasse. Le « Moonlight Rooftop », à Fidjrossè, est un toit-terrasse ouvert au public : [6.35744, 2.36908](https://www.google.com/maps?q=6.357439,2.369083). Sinon, depuis n'importe quel étage où tu as accès.
- [ ] **Toits en tôle ondulée** (rouille, pierres posées dessus) : depuis la rue, sur les maisons en tôle de la section 2.
- [ ] **Toits-terrasses** : citernes d'eau (couleur, socle), fers d'attente, paraboles, linge.
- [ ] **Acrotère** (petit muret autour du toit plat) : hauteur et finition.

## 6. Boutiques, marchés et vie de rue

Dossier : `refs/terrain/boutiques/`

**Le grand axe de Fidjrossè** est le meilleur endroit : boutiques, pharmacie, boulangerie et marché à moins de 200 m.

- [ ] **Marché de Fidjrossè** : vue d'ensemble depuis le trottoir, étals, parasols, de près : [6.35747, 2.36539](https://www.google.com/maps?q=6.357471,2.365389)
- [ ] **Boutique de vêtements** « Diva d'Afrique » : [6.35724, 2.36738](https://www.google.com/maps?q=6.357238,2.367382)
- [ ] **Boulangerie** « Boulangerie Pâtisserie Lu » : [6.35744, 2.36739](https://www.google.com/maps?q=6.357442,2.367385)
- [ ] **Pharmacie** « Pharmacie Oceane » (enseigne verte, croix) : [6.35698, 2.36511](https://www.google.com/maps?q=6.356983,2.365107)
- [ ] **Supérette** « Nol Market » : [6.35383, 2.36543](https://www.google.com/maps?q=6.353831,2.365430)
- [ ] **Coiffure** :
  - « Golden Hair » (Fidjrossè) : [6.35093, 2.35363](https://www.google.com/maps?q=6.350929,2.353632)
  - « Gloire à Dieu coiffure » : [6.35939, 2.35962](https://www.google.com/maps?q=6.359391,2.359622)
- [ ] **Petite boutique de quartier** « Mark éthic » : [6.35419, 2.36439](https://www.google.com/maps?q=6.354195,2.364394)
- [ ] **Station-service** :
  - « MRS » (Haie Vive) : [6.36089, 2.37476](https://www.google.com/maps?q=6.360886,2.374762)
  - « JNP » (aéroport) : [6.35062, 2.38684](https://www.google.com/maps?q=6.350616,2.386836)
- [ ] **Garage** « Garage Expérience 2000 » (Haie Vive) : [6.35933, 2.37799](https://www.google.com/maps?q=6.359332,2.377986)
- [ ] **Les mêmes boutiques le soir**, avec l'éclairage : 2 ou 3.
- [ ] **Étals de rue isolés, kiosque de crédit ou de transfert d'argent, vendeur d'essence en bouteilles** : le long du grand axe de Fidjrossè et du grand axe de Fiyégnon, près de « Pharmacie la Madone » : [6.35782, 2.37026](https://www.google.com/maps?q=6.357823,2.370258)
- [ ] **Panneaux publicitaires** : le long de l'avenue Pape Jean-Paul II, près de « AEROPORT MCA » : [6.35217, 2.38618](https://www.google.com/maps?q=6.352172,2.386182)

**Maquis et petits restaurants** (bancs, tables, auvent, de jour et le soir)

- [ ] « Chez kiki » et « Ouaga doux gouts », côte à côte à Fidjrossè : [6.35031, 2.36577](https://www.google.com/maps?q=6.350308,2.365770)
- [ ] « Le Parking » (Fiyégnon) : [6.35743, 2.37455](https://www.google.com/maps?q=6.357435,2.374547)
- [ ] « Chez Kadi » (Fiyégnon, grand axe) : [6.35780, 2.37138](https://www.google.com/maps?q=6.357797,2.371378)
- [ ] « Piment Rouge » (Fidjrossè) : [6.35182, 2.36166](https://www.google.com/maps?q=6.351816,2.361659)
- [ ] « Kirikou » (Fidjrossè ouest) : [6.35409, 2.35743](https://www.google.com/maps?q=6.354088,2.357429)

## 7. Zems et circulation

Dossier : `refs/terrain/zems/`

- [ ] **Station de zems** de l'aéroport (parking motos), près de « Code Bar » : [6.35198, 2.38678](https://www.google.com/maps?q=6.351979,2.386777)
- [ ] **Zems qui attendent** au carrefour de la plage de Fidjrossè (Route des Pêches), près de « Regaebar » : [6.34950, 2.36584](https://www.google.com/maps?q=6.349497,2.365836)
- [ ] **Une moto de zem** de côté, de face, de dos, et le **gilet jaune** de dos, de près (numéro, couleur) : à l'une des stations ci-dessus.
- [ ] **Minibus, taxis, voitures garées** (parallèles ou en épi ?) : avenue Pape Jean-Paul II, près de « AEROPORT MCA » : [6.35375, 2.38634](https://www.google.com/maps?q=6.353751,2.386342)

## 8. Mobilier urbain et réseaux

Dossier : `refs/terrain/mobilier/`

- [ ] **Poteau électrique** entier, le haut (isolateurs, transformateur), la hauteur avec un repère, et les **câbles** entre deux poteaux : dans une rue de quartier de Fiyégnon : [6.35318, 2.37271](https://www.google.com/maps?q=6.353178,2.372707)
- [ ] **Lampadaires** (solaire et classique), entier et la tête : Route des Pêches, près de « Banque Atlantique » : [6.34978, 2.38091](https://www.google.com/maps?q=6.349782,2.380914)
- [ ] **Abris de plage** (paillotes), à côté de l'avion : [6.34789, 2.37929](https://www.google.com/maps?q=6.347885,2.379289)
- [ ] **Panneaux de signalisation, poubelles, tas d'ordures, ralentisseurs, feux** : où tu en vois, avec une ligne dans `notes.txt`.

## 9. Arbres et végétation

Dossier : `refs/terrain/arbres/`. Pour chaque arbre : entier (recule assez), le tronc de près, une branche avec les feuilles.

- [ ] **Les arbres repérés à Djako**, près de « Djako Daho » (3 arbres groupés) : [6.35248, 2.35528](https://www.google.com/maps?q=6.352477,2.355281)
- [ ] **Arbre isolé de Fidjrossè ouest** : [6.35724, 2.35491](https://www.google.com/maps?q=6.357243,2.354911)
- [ ] **Badamier, neem, manguier** : les cours et les rues de quartier en ont, dis-moi l'espèce si tu la connais.
- [ ] **Cocotiers** droits et penchés : sur la plage, près de l'avion : [6.34764, 2.37978](https://www.google.com/maps?q=6.347638,2.379780)
- [ ] **Buissons, haies, terrain vague** : n'importe où, avec une ligne dans `notes.txt`.

## 10. Plage et front de mer

Dossier : `refs/terrain/plage/`

- [ ] **Route des Pêches**, vue d'ensemble dans les deux sens, la promenade, la piste cyclable :
  - près du « Maquis de la Playa » : [6.34938, 2.37994](https://www.google.com/maps?q=6.349384,2.379942)
  - à Fidjrossè, près de « Les filles Madeleine » : [6.34991, 2.36039](https://www.google.com/maps?q=6.349911,2.360391)
  - à l'ouest, près de « Nouveaux Alizés » : [6.34989, 2.35543](https://www.google.com/maps?q=6.349888,2.355427)
- [ ] **Plage** (largeur depuis la route jusqu'à l'eau, sable de près, pente vers la mer), près de « Dream beach » : [6.34723, 2.38700](https://www.google.com/maps?q=6.347231,2.387001)
- [ ] **Plage de Fidjrossè** : vue d'ensemble, buvettes, chaises, animation (de loin, sans visages), près de « Resto plage » : [6.34981, 2.36556](https://www.google.com/maps?q=6.349805,2.365561)
- [ ] **Restaurants du front de mer** à l'ouest :
  - « Face à la mer » : [6.35098, 2.35068](https://www.google.com/maps?q=6.350982,2.350680)
  - « Marquis Bar Le Marin » : [6.35097, 2.35183](https://www.google.com/maps?q=6.350965,2.351826)
- [ ] **Pirogues et filets** de pêche, si tu en vois sur la plage.

## 11. Lieux précis du jeu

Dossier : `refs/terrain/lieux/<nom>/`. Pour chaque lieu : la façade entière de face, de biais des deux côtés, l'entrée de près, et ce qu'il y a autour (rue, parking).

- [ ] **Aérogare de l'aéroport** (Aéroport International Cardinal Cotodji dans le jeu) : façade, entrée, parking, abords : [6.35329, 2.38480](https://www.google.com/maps?q=6.353293,2.384801)
- [ ] **Douane de l'aéroport** et **caserne de pompiers**, pour les bâtiments officiels :
  - « Douane Cotonou Aéroport » : [6.35431, 2.38657](https://www.google.com/maps?q=6.354312,2.386568)
  - caserne de pompiers : [6.35564, 2.38760](https://www.google.com/maps?q=6.355640,2.387599)
- [ ] **Erevan Hypermarket** (Ararat dans le jeu) : façade, entrée, parking : [6.34902, 2.38696](https://www.google.com/maps?q=6.349016,2.386957)
- [ ] **Avion sur la plage** (L'Épave Volante dans le jeu) : vue d'ensemble, escalier, tables autour : [6.34764, 2.37978](https://www.google.com/maps?q=6.347638,2.379780)
- [ ] **Dream Beach** (Sweet Dream Beach dans le jeu) : entrée, façade côté plage : [6.34723, 2.38700](https://www.google.com/maps?q=6.347231,2.387001)
- [ ] **Maquis de la Playa** (Maquis La Plaja dans le jeu) : [6.34938, 2.37994](https://www.google.com/maps?q=6.349384,2.379942)
- [ ] **Banque Atlantique** (Banque Océanique dans le jeu), façade : près de [6.34920, 2.38048](https://www.google.com/maps?q=6.349203,2.380482)
- [ ] **Code Bar** (Mot de Passe Bar dans le jeu) : [6.35177, 2.38689](https://www.google.com/maps?q=6.351771,2.386890)
- [ ] **Haie Vive** (Haie Verte dans le jeu), une rue animée et un carrefour : [6.35747, 2.38002](https://www.google.com/maps?q=6.357472,2.380024)
- [ ] **Cadjehoun** (Cadjehoue dans le jeu), une rue et un carrefour : [6.35964, 2.38635](https://www.google.com/maps?q=6.359643,2.386351)
- [ ] **Carrefour de la plage de Fidjrossè** (Fidjrossa dans le jeu), près de « Regaebar » : [6.34950, 2.36584](https://www.google.com/maps?q=6.349497,2.365836)
- [ ] **Centre de Fidjrossè**, une rue de quartier : [6.35250, 2.36755](https://www.google.com/maps?q=6.352503,2.367549)
- [ ] **Fiyégnon-Jacquot** (Fiyégnan-Jacot dans le jeu), une rue de quartier : [6.35444, 2.37184](https://www.google.com/maps?q=6.354443,2.371842)
- [ ] **Djako Daho** (Djaka Daho dans le jeu), une rue de quartier : [6.35296, 2.35556](https://www.google.com/maps?q=6.352963,2.355562)
- [ ] **Écoles** (portail, cour, mur peint), depuis la rue :
  - « Les Lauriers » : [6.35372, 2.37520](https://www.google.com/maps?q=6.353723,2.375201)
  - « CS bilingue Jules William » : [6.35768, 2.36936](https://www.google.com/maps?q=6.357684,2.369360)

## 12. Le soir et la nuit (bonus)

Dossier : `refs/terrain/nuit/`

- [ ] **Grand axe de Fidjrossè éclairé** (couleur des lampadaires et des boutiques), près de « Pharmacie Oceane » : [6.35698, 2.36511](https://www.google.com/maps?q=6.356983,2.365107)
- [ ] **Route des Pêches le soir**, près du « Maquis de la Playa » : [6.34938, 2.37994](https://www.google.com/maps?q=6.349384,2.379942)
- [ ] **Maquis le soir** : « Chez kiki », à Fidjrossè : [6.35031, 2.36577](https://www.google.com/maps?q=6.350308,2.365770)
- [ ] **Rue pendant un délestage** (coupure de courant) : ce qui reste allumé (groupes, lampes torches), n'importe où.

## Pour m'envoyer les photos

Copie les dossiers dans `refs/terrain/` du projet, puis dis-moi ce que tu as ajouté. Si c'est plus simple, envoie-les en vrac dans un seul dossier, avec un `notes.txt` : je les trierai, et la localisation des photos me dira où elles ont été prises.

---

Emplacements calculés le 19/10/2026 à partir de la carte du jeu : OpenStreetMap pour les rues, les revêtements et les repères, Open Buildings 2.5D pour les hauteurs. Script : `blender/tools/photos_terrain_spots.py`.
