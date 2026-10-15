# GTB : correspondance lieux reels / noms fictifs

Document interne (jamais affiche en jeu). Regle : aucun nom reel de lieu, de route, de commerce ou de marque en jeu.
Tout nom reel trouve est signale a Olympe avant d'etre renomme. Statut : **en jeu** (deja fictif et utilise),
**a valider** (nom reel encore affiche, proposition en attente), **non represente**.

## Lieux et commerces

| Lieu reel | Nom dans GTB | Statut |
|---|---|---|
| Aeroport International Cardinal Bernardin Gantin | Aeroport International Cardinal Cotodji | en jeu |
| Erevan Hypermarket | Ararat Hypermarket | en jeu |
| Base aerienne de Cotonou | Base Aerienne du Littoral (reproduction vague, pas d'etiquette en jeu) | en jeu |
| Banque Atlantique | Banque Oceanique | en jeu |
| Societe Generale | Societe Generique | en jeu |
| Dream Beach | Sweet Dream Beach | en jeu |
| Maquis de la Playa | Maquis La Plaja | en jeu |
| Code Bar | Mot de Passe Bar | en jeu |
| Avion sur la plage | L'Epave Volante | en jeu |
| Wellness Fitness Center | Wellbeing Gym | en jeu |
| Nico s Hair | Coco s Hair | en jeu |
| FADOUL | Fadil Market | en jeu |
| JNP | JMP | en jeu |
| Consulat de l'Armenie | - | non represente |
| Compagnies aeriennes | Air Gbe, Atlantique Express, Sahel Airways, Golfe Aviation, Trans-Ouest, Air Lagune (inventees) | en jeu |
| Cafe et librairie du terminal | Cafe du Littoral, Librairie Presse (inventes) | en jeu |
| Maison du joueur | terrain vide choisi par le script | en jeu |

## Noms reels encore affiches (releve du 15/10/2026)

| Nom reel | Ou il apparait | Proposition | Statut |
|---|---|---|---|
| Avenue Pape Jean-Paul II | mini-carte, nom de rue (donnees OSM) | Boulevard de l'Envol | a valider |
| Route des Peches | mini-carte, nom de rue (donnees OSM) | Route des Filets | a valider |
| Cotonou | panneau publicitaire "La voix de Cotonou" (props.gd) | "La voix de Gbe Town" | a valider |
| Lagos, Accra, Lome, Abidjan, Dakar, Douala, Ouagadougou, Casablanca, Paris, Bruxelles | tableau des departs du terminal (lieux.gd) | garder les vraies villes (hors du quartier) ou villes fictives | a valider |
| Littoral (departement reel, nom generique) | "Pharmacie du Littoral", "Cafe du Littoral", base aerienne | garder (nom commun, aucun commerce reel vise) | a valider |
| Immatriculations d'avions TY- (prefixe reel du Benin) | livrees des avions (avion.gd) | prefixe invente, par ex. "GB-" | a valider |

Les noms de rue viennent des tags `name` d'OpenStreetMap : le renommage se fera a l'import (osm_import.py, table
de correspondance), pour que la carte, le GPS et les etiquettes restent coherents.
