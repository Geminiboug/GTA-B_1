# Photos de terrain : liste complète

Le but : rendre le jeu fidèle à Cotonou. Les photos servent à fabriquer les textures (murs, sols, toits) et à corriger les formes et les couleurs. Elles ne sont jamais publiées telles quelles.

Coche au fur et à mesure (`[x]`). Les sections sont rangées de la plus utile à la moins urgente. Même une partie de la liste m'aide déjà beaucoup.

## Règles pour toutes les photos

- **Heure** : entre 9 h et 11 h, ou entre 15 h et 16 h 30. Pas en plein midi (ombres trop dures), pas en contre-jour.
- **Ciel** : un ciel légèrement voilé est idéal, car il donne peu d'ombres. Évite la pluie.
- **Cadrage** :
  - de **face** : le téléphone droit, parallèle au mur, ni penché ni en biais ;
  - pour les sols : le téléphone à **plat au-dessus du sol**, à environ 1 m de hauteur.
- **Distance** : une photo **d'ensemble** (tout l'objet), plus une ou deux photos **de près** (la matière, à 1 m).
- **Échelle** : quand c'est possible, mets un objet connu dans le cadre (ta chaussure, une bouteille d'eau, un mètre). Ça me donne les vraies dimensions.
- **Personnes** : évite les visages reconnaissables et les plaques d'immatriculation lisibles. Attends que la rue se vide, ou cadre sans eux.
- **Marques et enseignes** : prends-les quand même. Je les remplace toujours par des noms inventés dans le jeu, mais j'ai besoin de voir le style (couleurs, taille des lettres, matériau).
- **Qualité** : la résolution maximale du téléphone, sans filtre, sans mode portrait, sans zoom numérique (avance-toi plutôt).
- **Nommage** : `lieu_sujet_numero.jpg`, par exemple `fidjrosse_facade_boutique_01.jpg`. Si c'est compliqué, mets juste chaque série dans le bon dossier.
- **Rangement** : `refs/terrain/<dossier>/`, avec les dossiers indiqués à chaque section.
- **Note de lieu** : pour chaque série, écris en une ligne le quartier et la rue (ou « près de … »). Un fichier `notes.txt` dans le dossier suffit.

## 1. La question en attente (5 minutes)

Dossier : `refs/terrain/marquage/`

- [ ] **Ligne au milieu d'un grand axe** : est-elle jaune ou blanche ? Une photo de la Route des Pêches, et une du boulevard de l'aéroport (avenue Jean-Paul II).
- [ ] **Bords de chaussée** : ligne de rive (continue ou absente ?), bordures peintes rouge et blanc (où en voit-on ?).
- [ ] **Passage piéton** : s'il y en a un près de l'aéroport ou d'une école.
- [ ] **Terre-plein central** : vue d'ensemble et de près (bordure, sol, plantes).

## 2. Façades (le plus visible dans le jeu)

Dossier : `refs/terrain/facades/`. Pour chaque façade : une photo entière de face, une de près sur l'enduit (1 m), une sur une fenêtre et une sur la porte.

- [ ] **Maison de plain-pied ordinaire**, avec enduit : 3 maisons différentes (couleurs différentes si possible).
- [ ] **Maison en parpaings non enduits** (brute ou en construction) : 2 maisons.
- [ ] **Maison à un étage (R+1)** avec balcon : 2 maisons.
- [ ] **Immeuble R+2 ou R+3** : 2 immeubles.
- [ ] **Maison avec créneaux sur le toit-terrasse** (petits murets en dents) : 1 ou 2.
- [ ] **Boutique au rez-de-chaussée** avec rideau métallique, **ouvert** et **fermé** si possible.
- [ ] **Fenêtres** : de près, persiennes métalliques, naco (lames de verre), grilles (losanges, carreaux, barreaux). Une photo de chaque type.
- [ ] **Portes** : porte métallique peinte, porte en bois, porte vitrée de boutique.
- [ ] **Climatiseurs et compteurs** accrochés au mur : 2 ou 3 exemples.
- [ ] **Traces d'usure** : bas des murs salis par la pluie et la terre, peinture écaillée, fissures, de près.
- [ ] **Inscriptions peintes** sur les murs (« À VENDRE », « DÉFENSE D'URINER », numéros de téléphone…) : 3 à 5.

## 3. Murs d'enceinte et portails (concessions)

Dossier : `refs/terrain/portails/`

- [ ] **Mur de concession** enduit : vue d'ensemble, hauteur avec un repère (toi ou une porte à côté), de près sur l'enduit, le dessus du mur (tessons, fers, rien ?).
- [ ] **Mur en parpaings bruts** : une vue d'ensemble, une de près.
- [ ] **Portail en tôle peinte** : 4 ou 5 couleurs différentes, de face entier, puis de près (motifs, gonds, serrure).
- [ ] **Portail avec portillon** (petite porte dans le grand portail) : 1 ou 2.
- [ ] **Clôture en grillage ou en bambou**, si tu en vois.

## 4. Sols et routes

Dossier : `refs/terrain/sols/`. Le téléphone à plat, à 1 m du sol, sans ton ombre dans le cadre. Pour chaque sol : une photo à plat, plus une photo en biais qui montre la rue entière.

- [ ] **Bitume neuf** (grand axe).
- [ ] **Bitume usé** : nids-de-poule, rapiéçages, bords effrités.
- [ ] **Pavés** : rue pavée de quartier, motif des pavés de près, avec ta chaussure pour l'échelle.
- [ ] **Sable gris-beige des rues** de quartier, sec, et mouillé après la pluie si possible.
- [ ] **Latérite rouge** (terre rouge), si tu en trouves.
- [ ] **Bas-côté** : là où se garent les zems, entre la chaussée et les maisons.
- [ ] **Caniveaux** : ouvert, couvert par des dalles, avec une grille.
- [ ] **Flaques et zones boueuses** : où l'eau stagne-t-elle ?
- [ ] **Trottoir** : y en a-t-il un ? Hauteur et bordure de près.

## 5. Toits

Dossier : `refs/terrain/toits/`. Si tu as accès à un étage ou à une terrasse, vue plongeante sur les toits voisins.

- [ ] **Vue d'ensemble des toits** d'un quartier, depuis un étage : 2 ou 3 photos dans des directions différentes.
- [ ] **Toits en tôle ondulée** : rouille, pierres posées dessus, de près.
- [ ] **Toits-terrasses** : citernes d'eau (couleur, socle), fers d'attente (barres qui dépassent des poteaux), paraboles, linge.
- [ ] **Acrotère** (petit muret autour du toit plat) : hauteur et finition.

## 6. Boutiques, marchés et vie de rue

Dossier : `refs/terrain/boutiques/`

- [ ] **Devantures de boutiques** de jour : 5 boutiques différentes (alimentation, coiffure, couture, quincaillerie, téléphone…).
- [ ] **Les mêmes le soir**, avec l'éclairage : 2 ou 3.
- [ ] **Enseignes** : panneau peint, bâche imprimée, enseigne lumineuse. De face, entières.
- [ ] **Étals de rue** : table de vendeuse, parasol, tabouret. Vue d'ensemble et de près.
- [ ] **Kiosque de transfert d'argent ou de crédit** téléphonique (cabine colorée).
- [ ] **Vendeur d'essence au bord de la route** (bouteilles, bidons, table).
- [ ] **Maquis** (petit restaurant de rue) : bancs, tables, auvent.
- [ ] **Petit marché de rue** : plusieurs étals groupés, vue d'ensemble depuis le trottoir.
- [ ] **Panneaux publicitaires** au bord des grands axes : taille, pieds, hauteur.

## 7. Zems et circulation

Dossier : `refs/terrain/zems/`

- [ ] **Station de zems** : motos garées, conducteurs (de dos), abri s'il y en a.
- [ ] **Une moto de zem** de côté, de face, de dos (les plus courantes : Bajaj, Haojue…).
- [ ] **Gilet jaune de zémidjan** : de dos, de près (numéro, couleur).
- [ ] **Minibus de transport** et **taxi** : de côté.
- [ ] **Voitures garées** au bord des rues : où, comment (parallèle, en épi ?).

## 8. Mobilier urbain et réseaux

Dossier : `refs/terrain/mobilier/`

- [ ] **Poteau électrique en bois ou en béton** : entier, le haut (isolateurs, transformateur), la hauteur avec un repère.
- [ ] **Câbles** entre les poteaux : combien, quel affaissement.
- [ ] **Lampadaire** : solaire et classique, entier et la tête.
- [ ] **Panneaux de signalisation** : stop, sens interdit, panneaux de rue.
- [ ] **Poubelles et tas d'ordures**, **ralentisseurs**, **feux tricolores** s'il y en a.

## 9. Arbres et végétation

Dossier : `refs/terrain/arbres/`. Pour chaque arbre : l'arbre entier (recule assez), le tronc de près, une branche avec les feuilles.

- [ ] **Badamier** (amandier tropical).
- [ ] **Neem**.
- [ ] **Manguier**.
- [ ] **Cocotier** : droit et penché, sur la plage et dans une cour.
- [ ] **Buissons et haies** des cours.
- [ ] **Herbe et terrain vague** : à quoi ressemble un terrain non construit.

## 10. Plage et front de mer

Dossier : `refs/terrain/plage/`

- [ ] **Route des Pêches** : vue d'ensemble dans les deux sens, la promenade, la piste cyclable.
- [ ] **Plage** : largeur (depuis la route jusqu'à l'eau), sable de près, pente vers la mer.
- [ ] **Paillotes, buvettes, chaises** sur la plage.
- [ ] **Pirogues de pêche** et filets, si tu en vois.
- [ ] **Plage de Fidjrossè** : vue d'ensemble, l'animation (de loin, sans visages).

## 11. Lieux précis du jeu

Dossier : `refs/terrain/lieux/<nom>/`. Pour chaque lieu : la façade entière de face, de biais des deux côtés, l'entrée de près, et ce qu'il y a autour (rue, parking).

- [ ] **Aéroport** : façade de l'aérogare, entrée, parking, abords, clôture de la piste.
- [ ] **Hypermarché Erevan** (Ararat dans le jeu) : façade, entrée, parking.
- [ ] **Avion sur la plage** (L'Épave Volante dans le jeu) : vue d'ensemble, escalier, tables autour.
- [ ] **Haie Vive** (Haie Verte) : une rue animée, un carrefour, les maquis.
- [ ] **Cadjehoun** (Cadjehoue) : une rue, un carrefour.
- [ ] **Fidjrossè** (Fidjrossa) : le carrefour de la plage, une rue de quartier, une rue commerçante.
- [ ] **Fiyégnon** (Fiyégnan-Jacot) et **Djako** (Djaka Daho) : une rue de quartier chacun.

## 12. Le soir et la nuit (bonus)

Dossier : `refs/terrain/nuit/`

- [ ] **Rue éclairée** : couleur de la lumière des lampadaires et des boutiques.
- [ ] **Rue pendant un délestage** (coupure de courant) : ce qui reste allumé (groupes, lampes torches).
- [ ] **Maquis le soir**.

## Pour m'envoyer les photos

Copie les dossiers dans `refs/terrain/` du projet, puis dis-moi ce que tu as ajouté. Si c'est plus simple, envoie-les en vrac dans un seul dossier, avec le fichier `notes.txt` : je les trierai.
