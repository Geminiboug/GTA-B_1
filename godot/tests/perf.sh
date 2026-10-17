#!/bin/sh
# Test de fluidite (phase 11) : tests/perf_fps.gd dans les trois qualites (Bas, Moyen, Haut), budget d'Olympe
# (70 images/s dehors, 60 en interieur). Echec si une qualite passe sous le budget.
# Lancement (Git Bash, depuis godot/) : GODOT=<chemin du _console.exe> sh tests/perf.sh
# Fermer l'editeur Godot, Blender et les logiciels lourds avant de mesurer.
GODOT=${GODOT:-godot}
fails=0
for q in 0 1 2; do
	out=$("$GODOT" --path . --resolution 1600x900 --script res://tests/perf_fps.gd -- $q 2>&1 | grep -E "Qualite|FPS|ECHEC|RESULTAT")
	echo "$out"
	echo "$out" | grep -q "RESULTAT perf : OK" || fails=$((fails + 1))
done
echo "RESULTAT fluidite : $([ $fails -eq 0 ] && echo OK || echo "$fails qualite(s) en echec")"
exit $fails
