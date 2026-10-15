# Validation en jeu des phases 3 a 5 (a remplir par Olympe)

Lancer `scenes/zone_aeroport.tscn` (F5). **F1** : mode debug (1er appui : infos ; 2e : infos + chemins des PNJ et des
vehicules ; 3e : desactive). En mode debug, **touches 1 a 8** : teleportation (a pied).

| Touche | Zone |
|---|---|
| 1 | Carrefour principal (rond-point) |
| 2 | Route des Filets (front de mer) |
| 3 | Plage |
| 4 | Terminal (parvis) |
| 5 | Terminal (hall) |
| 6 | Ararat Hypermarket (interieur) |
| 7 | Maison du joueur (cour) |
| 8 | Piste (bord, cote aerogare) |

Autres touches utiles : F2 heure (jour / nuit), F3 averse, F4 joueur homme / femme, M grande carte, P marqueur.

Pour chaque ligne : cocher **OK**, ou noter ce qui ne va pas (ce que tu vois, ou, a quelle heure).

## Phase 3 : joueur a pied

| # | Verification | OK | Remarque |
|---|---|---|---|
| 3.1 | Marche (Ctrl / stick peu incline), trot (par defaut), sprint (Maj) : vitesses credibles (panneau : 1,6 / 4,2 / 7 m/s) | [ ] | |
| 3.2 | Demarrage et arret : pas de glissade visible des pieds | [ ] | |
| 3.3 | Demi-tour et virages : le corps ne pivote pas en toupie | [ ] | |
| 3.4 | Saut et reception (sol, trottoir, sable) | [ ] | |
| 3.5 | Camera : suit sans a-coups, ne traverse pas les murs, zoom molette | [ ] | |
| 3.6 | Manette : sticks, gachettes, boutons (A sprint, X saut, Y interagir) | [ ] | |
| 3.7 | Collisions : murs, poteaux, voitures garees, mobilier, portes des lieux | [ ] | |
| 3.8 | Limites du monde : bord de carte, mer (pas de chute sous la carte) | [ ] | |
| 3.9 | Interieurs : entrer et sortir de la maison, de l'Ararat, du terminal (portes) | [ ] | |
| 3.10 | Tailles : joueur face aux portes, comptoirs, PNJ, voitures (rien de disproportionne) | [ ] | |

## Phase 4 : le zem

| # | Verification | OK | Remarque |
|---|---|---|---|
| 4.1 | Monter / descendre (Y ou E) : le joueur se place sur la selle et en redescend sans traverser la moto | [ ] | |
| 4.2 | Acceleration, freinage, vitesse maximale credibles (0 a 65 km/h en ~6 s) | [ ] | |
| 4.3 | Virages : inclinaison de la moto et du pilote, rayon qui s'elargit avec la vitesse | [ ] | |
| 4.4 | Son du moteur qui suit le regime, klaxon | [ ] | |
| 4.5 | Camera en conduite : suit et anticipe les virages | [ ] | |
| 4.6 | Chocs contre un mur, une voiture, un pieton | [ ] | |
| 4.7 | Sable, paves, terre : comportement different (adherence) | [ ] | |

## Phase 5 : ville vivante

| # | Verification | OK | Remarque |
|---|---|---|---|
| 5.1 | Circulation : zems et voitures roulent a droite, cedent le passage aux carrefours, ne se bloquent pas (F1 x2 : chemins orange) | [ ] | |
| 5.2 | Vehicules s'arretent et klaxonnent devant le joueur ou un pieton | [ ] | |
| 5.3 | Pietons : trottoirs, traversees aux carrefours, promenade du front de mer (F1 x2 : chemins cyan) | [ ] | |
| 5.4 | Vendeurs assis, bassines sur la tete, attroupements, insultes, fuites | [ ] | |
| 5.5 | Variete des PNJ : morphologies (minces, forts, ages, enfants), tenues, coiffures | [ ] | |
| 5.6 | Avions : roulage, decollage, atterrissage ; feux de piste la nuit (touche 8 puis F2) | [ ] | |
| 5.7 | Jour / nuit : coucher de soleil, fenetres allumees, delestages | [ ] | |
| 5.8 | Meteo (F3) : averse, sol mouille, flaques, orage | [ ] | |
| 5.9 | Ambiance sonore : ressac, rumeur, oiseaux le jour, grillons la nuit | [ ] | |
| 5.10 | Interieurs : clients et caissieres a l'Ararat, voyageurs au terminal | [ ] | |
| 5.11 | Fluidite : images/s affichees par F1 (objectif : 70 dehors, 60 en interieur) | [ ] | |

## Remarques generales

(Ce qui te frappe en jouant, ce qui ne ressemble pas a Cotonou, ce qui manque.)
