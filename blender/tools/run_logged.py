# GTB : execute un script Blender et ecrit sa sortie (print, erreurs) dans un fichier journal.
# Le lanceur Blender du Microsoft Store n'affiche pas la console : sans ce journal, une erreur passe inapercue.
# Lancement : blender -b --python blender/tools/run_logged.py -- <journal.txt> <script.py> [arguments du script...]
import runpy
import sys
import traceback

args = sys.argv[sys.argv.index("--") + 1:]
log_path, script = args[0], args[1]
log = open(log_path, "w", encoding="utf-8")
sys.stdout = log
sys.stderr = log
sys.argv = [script, "--"] + args[2:]
try:
    runpy.run_path(script, run_name="__main__")
    print("FIN OK")
except SystemExit:
    print("FIN OK")
except Exception:
    traceback.print_exc()
    print("FIN ERREUR")
finally:
    log.flush()
    log.close()
