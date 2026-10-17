# Export Android (demo)

## Outils sur le PC d'Olympe
- Java : `C:/Program Files/Eclipse Adoptium/jdk-25.0.4.101-hotspot`
- SDK Android (installe par Android Studio) : `C:/Users/La Paix Technology/AppData/Local/Android/Sdk`
- Les deux chemins sont renseignes dans les parametres de l'editeur Godot (Export > Android).

## Fabriquer l'APK
```
godot --headless --path godot --export-debug Android ../builds/android/GTB.apk
```
Avant chaque nouvel APK : augmenter `version/code` (et `version/name`) du preset Android dans `godot/export_presets.cfg`.

## Installer et mettre a jour sur le telephone
- Copier `GTB.apk` sur le telephone, l'ouvrir, autoriser la source si Android le demande.
- Mise a jour : installer le nouvel APK par-dessus, sans desinstaller. Les sauvegardes sont gardees.
- Desinstaller efface les sauvegardes du telephone.

## Cle de signature : a ne pas perdre
- `C:/Users/La Paix Technology/AppData/Roaming/Godot/keystores/debug.keystore` (mot de passe `android`, alias `androiddebugkey`).
- Android n'accepte une mise a jour que signee avec la meme cle. En garder une copie (cle USB, Drive).
- Pour le Play Store, il faudra une cle de publication separee.
