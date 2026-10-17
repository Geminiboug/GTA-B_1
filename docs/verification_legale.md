# GTB : verification legale avant la demo (Phase 13)

Faite le 17/10/2026 avec docs/LEGAL.md. Controle automatique : godot/tests/test_legal.gd (a relancer avant chaque version).

## Resultat

| Point (LEGAL.md) | Etat | Detail |
|---|---|---|
| 1. Nom : jamais GTA / Grand Theft / Rockstar | OK | Aucune occurrence visible par le joueur. "facon GTA" reste dans les commentaires du code et les groupes de reglages de l'editeur (non publies dans le jeu) |
| 2. Assets tiers | OK | Seuls assets tiers integres : Quaternius (CC0). Textures et sons : procedurales ou synthetises. Photos de refs/ non integrees |
| 3. OpenStreetMap, Overture, Open Buildings, Sentinel-2 | OK | Mentions completes dans Credits (menu titre et pause), godot/assets/data/credits.txt |
| 3. Images satellite Google / Bing / Esri | OK | Non utilisees (littoral mesure sur Sentinel-2) |
| 4. Marques et lieux reels | OK | Tous les lieux du tableau ont leur nom fictif ; aucun nom reel du tableau dans les textes, la carte ni les donnees de la zone |
| 4. Aeroport | OK | "Aeroport International Cardinal Cotodji" |
| 4. Lieu reel associe a une activite criminelle | A surveiller | L'histoire passe par l'aeroport (nom fictif) et l'epave (nom fictif) ; aucun lieu reel nomme n'est implique |
| 5. Personnes, plaques, telephones | OK | Personnages inventes, plaques "GT 0000" generees, aucun numero de telephone |
| Rues | A noter | Les rues de la carte gardent leur numero officiel ("Rue 12.355") tire d'OSM, les deux grands axes ont un nom fictif. Un numero de rue n'est ni une marque ni une personne : garde tel quel |
| Musique | OK | Aucune musique pour l'instant (sons synthetises) |

## Reste a faire (hors code)

- Validation par un avocat en propriete intellectuelle avant toute sortie commerciale (LEGAL.md). La demo gratuite peut sortir sans, mais l'avis est recommande.
- Formulaire de retours : le creer (Google Forms, Tally...) puis renseigner son lien dans Menus > formulaire_retours.
- Page itch.io : reprendre les credits de godot/assets/data/credits.txt dans la description.
