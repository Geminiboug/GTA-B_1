# GTB : pipeline Blender vers Godot

## Conventions
- Echelle : 1 unite = 1 metre. Blender : Z en haut. L'export glTF convertit en Y en haut.
- Origine des objets : au sol, au centre de la base (un batiment pose a Z = 0).
- Appliquer echelle et rotation avant export : Ctrl+A > All Transforms.
- Nommage des fichiers et objets : bld_ (batiments), prop_ (objets), veh_ (vehicules), chr_ (personnages), en minuscules, sans accents ni espaces. Ex : bld_terminal_aeroport, prop_poteau_sbee.
- Sources : blender/<categorie>/<nom>.blend. Exports : godot/assets/models/<nom>.glb (genere, ne pas modifier a la main).
- Pas de textures avant la Phase 6 : un materiau Principled BSDF avec une couleur unie.

## Collisions (suffixes reconnus par Godot a l'import)
- objet-col : mesh visible + collision exacte (trimesh). Pour le decor statique simple.
- objet-colonly : collision seule, invisible. Pour une forme simplifiee a cote du mesh detaille.
- objet-convcol : collision convexe, plus legere.
Regle : decor detaille = mesh visible sans suffixe + une boite simplifiee en -colonly.

## Test du cube (Phase 1)
1. Blender : nouveau fichier General. Garder le cube par defaut (2 m de cote).
2. Le renommer prop_cube_test-col (double-clic dans l'Outliner).
3. Le monter de 1 m (G, Z, 1, Entree) pour que sa base soit au sol, puis Ctrl+A > All Transforms.
4. Material : couleur unie au choix.
5. Enregistrer sous blender/test/prop_cube_test.blend.
6. Onglet Scripting > Open > blender/tools/export_glb.py > Run Script.
   Resultat : godot/assets/models/prop_cube_test.glb
7. Godot : Import > choisir godot/project.godot.
8. Ouvrir scenes/test_pipeline.tscn, glisser prop_cube_test.glb dans la scene, le placer en (0, 0, 0). Ctrl+S.
9. F5 : la boule tombe et doit rester posee sur le cube. Camera : ZQSD, clic droit maintenu pour tourner, Shift pour accelerer.
Si la boule traverse le cube : le suffixe -col manque ou est mal tape.
