# Audit : GTB ressemble-t-il à Cotonou ? (Phase 12, 18/10/2026)

Jalon : un Cotonois doit reconnaître le quartier sur une capture, sans indice.

## Méthode

- **Références utilisées** : les 57 photos Wikimedia Commons de `refs/`. Leurs licences sont dans `refs/SOURCES.md`. Elles servent d'observation uniquement, aucune n'est copiée dans le jeu.
- **Photos les plus utiles** :
  - Voie de Fidjrossè et carrefour du Calvaire de Fidjrossè : quartier voisin de la zone du jeu ;
  - rue d'Avotrou ;
  - scène de rue avec zems au feu ;
  - rue après la pluie.
- **Captures du jeu** : `tests/capture_realisme.gd`, 8 points de vue fixes à 16 h. L'état initial est dans `docs/images/phase12/avant_*.png` et l'état après correction dans `apres_*.png`.
- **Ce qui n'a pas été fait** : aucune vidéo ni vue de rue (Mapillary) n'a été consultée pour cet audit. Les observations ci-dessous viennent uniquement des photos citées.

## 1. Déjà crédible, à garder

- Les murs de concession en parpaings gris, avec portails métalliques peints et affiches déchirées.
- Les rideaux métalliques des boutiques et les auvents en tôle (déjà créés par `osm_import.py`).
- Les zems : nombreux, garés en stations, conducteurs en chemise jaune.
- Les câbles électriques en chaînette entre les poteaux.
- La répartition des revêtements : pavés et sable dans les rues de quartier, bitume sur les grands axes (`osm_import.py`, `road_surface`).

## 2. Générique ou faux, avec la référence qui le montre

| Élément du jeu | Référence réelle | Écart | Correction | Fichier | Coût | Impact | Risque perf | Statut |
|---|---|---|---|---|---|---|---|---|
| Sol nu rouge orangé partout (latérite) | Fidjrossè, Avotrou, Calvaire : sable gris-beige du cordon littoral | Couleur dominante fausse, sur toutes les captures | Sable gris-beige, rares remblais de latérite ocre | `shaders/sol.gdshader` (modes 0, 5, 7, 8, poussière du bitume), poussière des voitures | faible | très fort | aucun | **fait** |
| Poteaux électriques en bois brun | Avotrou, Calvaire : poteaux en béton gris à section carrée, boîtiers de branchement | Matériau et silhouette | Poteau béton effilé, boîtiers | `blender/tools/build_props.py` | faible | fort | aucun | **fait** |
| Lampadaires gris à bras | Fidjrossè, rue après la pluie : grands mâts blancs avec panneau solaire au sommet | Le lampadaire solaire est un signe très visible de Cotonou aujourd'hui | Mât blanc, panneau incliné, batterie, tête LED | `build_props.py` | faible | fort | aucun | **fait** |
| Façades entières en couleurs vives (1 sur 6 bleue, 1 sur 6 verte, 1 sur 6 ocre) | Toutes les photos de rue : surtout enduit gris, crème, beige, blanc ; couleur minoritaire et fanée | Trop saturé, aspect « jouet » | 6 façades colorées sur 10 passées en enduit, les autres fanées | `scripts/realism.gd` (`_teinte_cotonou`) | faible | fort | aucun | **fait** |
| Murs d'une seule couleur | Scène de rue au feu, Avotrou : soubassement peint (bas bleu ou vert, haut blanc) | Détail très typique absent | Soubassement de 0,9 à 1,4 m sur 2 bâtiments sur 5 | `shaders/facade.gdshader` | faible | moyen | aucun | **fait** |
| Toits plats nus | Calvaire, Avotrou : citernes noires, fers d'attente, antennes | Silhouette des toits trop propre | Citerne noire sur 1 toit plat sur 2, fers d'attente sur les maisons à étage | `scripts/props.gd` (`_place_toits`, MultiMesh) | faible | moyen | faible (instancié) | **fait** |
| Acrotères droits | Calvaire : acrotères à créneaux arrondis, balustres | Silhouette | Créneaux et balustres sur les parapets | `osm_import.py` (régénérer la zone) | moyen | moyen | faible | à faire |
| Grands axes en bitume avec beaucoup de marquage | Voie de Fidjrossè : pavés autobloquants gris-beige, bordures peintes rouge et blanc, peu de marquage | Revêtement des axes secondaires et bordures | Axes secondaires et tertiaires en pavés, bordures rouge et blanc aux terre-pleins | `osm_import.py` (régénérer la zone) | moyen | fort | aucun | à faire |
| Ligne axiale jaune sur certaines routes | Aucune photo ne montre de ligne jaune | Hypothèse non vérifiée : le marquage serait blanc au Bénin | Vérifier sur d'autres photos avant de changer | `osm_import.py` | faible | faible | aucun | à vérifier |
| Arbres en boules low poly | Photos : cocotiers, badamiers (branches en étages horizontaux), manguiers, neems | Arbres génériques | Badamier et neem modélisés | `build_vegetation.py` | moyen | moyen | faible | à faire |
| Rues de quartier vides et propres | Avotrou, scène de rue : parasols, tables, bancs, bouteilles de gaz, tas de sable, flaques | Peu de vie au sol | Kit d'objets de rue placé devant les boutiques et les portails | `props.gd` + `build_props.py` | moyen | fort | moyen | à faire |
| Fenêtres carrées noires régulières | Photos : persiennes métalliques, grilles décoratives, climatiseurs, paraboles | Façades en grille | Persiennes et grilles plus fréquentes, climatiseurs et paraboles | `facade.gdshader`, `props.gd` | moyen | moyen | faible | à faire |

## 3. Zone pilote

**Choix** : la rue résidentielle autour de (300, 120), vue « maisons ».

**Pourquoi** :
- elle réunit des concessions, des boutiques, une rue pavée, du sable, des poteaux et des façades à étage ;
- tous les défauts du tableau y sont visibles ;
- les corrections qu'on y teste s'appliquent ensuite à toute la ville, parce qu'elles sont faites dans les shaders et les générateurs.

## 4. Résultat (avant / après)

Les comparaisons sont dans `docs/images/phase12/`, en paires `avant_<vue>.png` / `apres_<vue>.png` :
- rue ;
- maisons ;
- Route des Filets ;
- axe principal ;
- vue haute.

Les changements les plus visibles :
- le sol passe du rouge au sable gris-beige ;
- les poteaux en béton et les lampadaires solaires sont en place ;
- les façades sont moins saturées ;
- le soubassement bleu apparaît sur les boutiques.

## 5. Ce qui reste et ce qu'il faut obtenir

- **Test à l'aveugle** : montrer les captures « après », mélangées à d'autres images, à 2 ou 3 personnes qui connaissent Cotonou. Leur poser la question : « À quel type de lieu cette image te fait-elle penser ? Qu'est-ce qui te fait penser cela ? ». Noter les réponses spontanées sans souffler la réponse.
- **Références manquantes** :
  - des photos de portails et de façades en gros plan, prises de face ;
  - des photos de stations de zems ;
  - des photos de devantures de boutiques et de maquis le soir ;
  - le marquage routier réel.

  Le plus simple est que Olympe prenne ces photos sur place. À distance, on peut chercher des photos sous licence libre sur Mapillary (vérifier la licence de chaque image).
- **Prochaines corrections**, par rentabilité :
  1. kit d'objets de rue ;
  2. pavés et bordures des axes secondaires ;
  3. acrotères à créneaux ;
  4. arbres locaux ;
  5. persiennes, climatiseurs et paraboles.
