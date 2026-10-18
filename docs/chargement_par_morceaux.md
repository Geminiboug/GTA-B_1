# Chargement par morceaux (Phase 17 bis) : conception

Décision d'Olympe du 18/10/2026 : agrandir la carte (Fidjrossè, puis le centre et le grand marché), et d'abord charger la ville par morceaux.

## Point de départ (mesuré le 18/10/2026)

- Zone actuelle : 1 354 x 1 616 m, un seul fichier `zone_aeroport.glb` de 24,8 Mo, déjà découpé en tuiles de 500 m à l'intérieur (Godot ignore les tuiles hors champ).
- Jeu exporté : la scène se charge en 1,4 s, la mise en place (décor, piétons, circulation) prend environ 12 s, total 14 s.
- Ce qui coûte, c'est la mise en place, pas le chargement des maillages. Les objets de décor sont posés au lancement par des lancers de rayons sur les collisions de toute la zone : props, végétation, concessions, occultation.
- Données de la ville : un seul JSON (`zone_aeroport.json`, 0,55 Mo) lu par 21 scripts via `Carte.zone()`.
- La circulation suit les rues sans physique (positions calculées le long des polylignes) : elle ne tombe pas si une tuile n'est pas chargée. Les piétons naissent près du joueur.

## Principe retenu

1. **Données globales** : un seul JSON pour toute la ville (rues, bâtiments, murs...). Il reste léger, même doublé, et la circulation, la police, la carte et les missions continuent de tout voir.
2. **Maillages par tuile** : un fichier `.glb` par tuile de 500 m, chargé en arrière-plan quand le joueur s'approche et libéré quand il s'éloigne. Il y a deux rayons pour ne pas osciller en bord de tuile : chargement à 650 m, libération à 900 m.
3. **Décor par tuile** : chaque système de décor sait poser et retirer le décor d'un rectangle, avec un tirage propre à la tuile (graine tirée des coordonnées de la tuile). Recharger une tuile redonne exactement le même décor.
4. **Consommateurs prévenus** : les listes partagées (`shops`, `vendor_spots`, `parked`, `lamp_positions`) sont mises à jour tuile par tuile, et les scripts qui les lisent (commerce, piétons, taxi, jour et nuit, joueur) écoutent les signaux `tuile_chargee` et `tuile_dechargee`.
5. **Pas de saccade** : le chargement des fichiers se fait dans un fil, et l'instanciation et la pose du décor sont étalées sur plusieurs images avec un budget en millisecondes, comme l'écran de chargement actuel (`Partie.chantier`).

## Étapes, chacune vérifiable seule

1. **Export par tuile** : `osm_import.py` écrit un `.glb` par tuile et un index des tuiles dans le JSON. Le fichier unique reste utilisé, donc le jeu ne change pas.
2. **Gestionnaire de tuiles** (`monde.gd`) : il charge toutes les tuiles pendant l'écran de chargement. Le résultat doit être identique à aujourd'hui (tests au vert, mêmes captures).
3. **Décor par tuile** : réalisme, concessions, occultation, props et végétation passent à `charger_tuile(rect)`. On mesure le temps par tuile et on vérifie que le décor ne bouge pas d'une partie à l'autre.
4. **Libération** au-delà de 900 m, avec la mise à jour des consommateurs. Nouveau test `test_tuiles` : traverser la zone à zem puis en voiture, sans chute et sans image de plus de 50 ms.
5. **Extension Fidjrossè** : import de la nouvelle emprise, fusionnée dans les données globales, et ses tuiles chargées comme les autres. Noms fictifs dans `docs/correspondance_noms.md`.
6. **Mesures** : mémoire et images par seconde sur PC (Bas, Moyen, Haut) et sur un téléphone Android de milieu de gamme (à faire par Olympe).

## Risques

- Les objets posés par lancers de rayons ont besoin des collisions de leur tuile : on pose le décor après l'ajout de la tuile, jamais avant.
- Un objet à cheval sur deux tuiles appartient à la tuile de son centre.
- Pendant une mission, sa zone ne doit pas être libérée : les missions peuvent épingler une tuile.
- La sauvegarde ne contient pas de décor, donc rien à migrer.
