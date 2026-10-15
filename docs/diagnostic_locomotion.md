# Diagnostic du controleur de deplacement (etape 16)

Etat au 15/10/2026 : `godot/scripts/player.gd` (deplacement) + `godot/scripts/character_anim.gd` (animation
procedurale) sur le squelette maison de 15 os (`piv_bassin`, `piv_tronc`, `piv_tete`, epaule / coude / main,
hanche / genou / cheville x 2). Aucune animation enregistree (aucun clip, aucun AnimationTree).

## Pourquoi le personnage parait robotique

1. **Le mouvement est pilote par la physique, pas par l'animation.** La vitesse suit des constantes
   (acceleration 9 m/s2, freinage 14 m/s2) et les jambes s'adaptent ensuite. GTA V fait l'inverse : ce sont les
   clips (demarrage, arret, pivot) qui deplacent le corps. Resultat : le corps « glisse » vers l'arret pendant que
   les jambes continuent leur cycle, aucun pied n'est plante.
2. **Aucun etat de transition.** Il n'y a ni demarrage, ni arret, ni pivot, ni rotation sur place : seulement un
   melange continu de trois allures (marche, trot, sprint) selon la vitesse. Un arret depuis le sprint dure
   0,5 s a deceleration constante, sans freinage ni buste vers l'avant.
3. **Rotation instantanee.** A faible vitesse le corps tourne a 12 rad/s (un demi-tour en 0,26 s) : effet
   « toupie ». En sprint, 4,5 rad/s, et la vitesse est simplement reduite selon l'angle : pas de pivot anime.
4. **Cycles parfaitement sinusoidaux.** Jambes et bras suivent des sinus symetriques : pas de transfert de poids
   d'un pied sur l'autre, pas de deroule talon-pointe, pas d'asymetrie, la meme demarche pour tout le monde (seule
   la femme balance un peu plus le bassin).
5. **Squelette trop simple.** Une seule colonne (`piv_tronc`), pas de cou, pas de clavicules, pas d'orteils, pas
   de doigts : impossible d'avoir un buste qui se tord, des epaules qui roulent ou un pied qui se deroule. Aucune
   animation du commerce (mocap) ne peut s'appliquer telle quelle.
6. **Pas d'IK.** Les pieds ne se posent pas sur les marches, trottoirs ou pentes ; le bassin ne compense pas.
7. **Controles differents de GTA.** Sprint en maintenant (pas en tapotant), marche lente sur Ctrl, aucune
   endurance, pas de saut contextuel (escalade, saut d'obstacle), pas d'accroupi.
8. **Peu de vie a l'arret.** Une respiration, pas d'idles varies, pas de regard vers la camera ou les bruits.
9. **PNJ.** Ils utilisent la meme animation procedurale mais un deplacement a part (`pedestrians.gd`) : vitesse
   constante, demi-tours brusques possibles.
10. **Camera.** Bras a ressort qui suit la souris, sans recentrage automatique ni FOV dynamique.

## Ce qui est deja bien (a garder)

- Phase du pas liee a la distance parcourue : pas de patinage sur les cycles de base.
- Reception amortie selon la hauteur de chute, inclinaison dans les virages, interpolation physique.

## Inventaire des animations (etape 16.10)

Existant : **aucun clip**. Tout est calcule (`character_anim.gd`).

Manquant (liste minimale pour le ressenti GTA V) :

| Famille | Clips |
|---|---|
| Locomotion | idle (x3 a x5 variantes), marche, marche lente, trot, sprint, marche chargee (bassine, sacs), marche agee |
| Demarrages | depart 0 / 90 / 180 degres gauche et droite, pour marche, trot, sprint |
| Arrets | arret pied gauche / pied droit, depuis marche, trot, sprint (freinage avec glissement) |
| Pivots | demi-tour en marche, trot, sprint (pied plante) |
| Rotation sur place | 45 / 90 / 180 degres gauche et droite |
| Saut | impulsion, en l'air, reception souple, reception lourde, roulade |
| Obstacles | saut d'obstacle bas (vault), escalade de muret (climb) |
| Physique | trebuchement, bousculade (epaule), chute, relever face au sol, relever sur le dos |
| Vehicules | ouvrir portiere, entrer et s'asseoir, sortir ; monter et descendre de moto ; sauter d'un vehicule en marche |
| Porter | sac a la main, sacs lourds, charge sur la tete (buste droit, main qui stabilise) |
| Idles de vie | telephone, s'eponger le front, s'etirer, se gratter la tete, mains sur la tete sous la pluie |
| Accroupi | idle, marche accroupie |

Sources libres possibles :

| Source | Licence | Contenu | Remarque |
|---|---|---|---|
| Quaternius, Universal Animation Library (1 et 2) | CC0 | ~120 a 200 clips mocap : locomotion, demarrages et arrets, sauts, roulades, vault, climb, idles, conduite | Recommande : CC0, squelette humanoide standard, deja prevu dans la roadmap ; telechargement gratuit (itch.io / quaternius.com) |
| Mixamo (Adobe) | gratuit, usage commercial autorise dans un jeu, pas de redistribution des fichiers bruts | tres grand choix de clips | Compte Adobe et telechargement manuel, clip par clip |
| CMU Motion Capture Database | libre (usage libre, credit apprecie) | mocap brute | Nettoyage lourd, pas de boucles pretes |

Reglages d'import Godot (glTF / FBX) : Skeleton > Bone Map avec `SkeletonProfileHumanoid` (retargeting vers le
squelette du projet), `Remove Tracks > Except Bone Transform`, `Root Motion > Root Bone = Hips` (piste extraite
pour le root motion), `Loop Mode = Linear` sur les cycles, `Rest Fixer > Overwrite Axis` et `Fix Silhouette`.

## Choix structurant (a valider par Olympe)

Pour atteindre le ressenti GTA V, il faut des clips captes sur de vrais acteurs (mocap) et donc un squelette
humanoide standard (hanches, 3 vertebres, cou, clavicules, doigts, orteils) a la place des 15 os maison.
Les personnages seraient regeneres par `build_character.py` sur ce squelette (noms du profil humanoide de Godot),
les clips importes et redirigees par le Bone Map, puis l'AnimationTree (machine a etats, root motion) remplacerait
`character_anim.gd` pour le joueur et les PNJ.
