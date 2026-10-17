#!/usr/bin/env python3
"""Textes du jeu -> fichier de traduction (phase 13, base de la traduction de la phase 24).

Le francais du code sert de cle (methode standard de Godot) : les Label, Button et Label3D traduisent leur texte
tout seuls, les textes composes passent par tr(). Ce script releve les textes visibles par le joueur dans
godot/scripts/*.gd (menus, HUD, histoire, dialogues, commerces...) et ecrit godot/i18n/gtb.pot (format gettext,
avec le fichier et la ligne de chaque texte). Une traduction = copier gtb.pot en en.po, remplir les msgstr, puis
ajouter le .po dans Projet > Parametres > Localisation.

Lancement (depuis la racine du depot) : python3 godot/tools/extraire_textes.py
Ignore : commentaires, print / push_warning / assert, chemins res://, noms de noeuds et cles (un seul mot en
minuscules, snake_case), scripts techniques (debug, journal, tests).
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SCRIPTS = os.path.join(ROOT, "scripts")
OUT = os.path.join(ROOT, "i18n", "gtb.pot")
SKIP_FILES = {"debug.gd", "journal.gd", "free_camera.gd", "anim_ctrl.gd", "character_anim.gd", "ubc.gd"}
# scripts d'interface : les mots seuls y sont des textes (boutons, articles) ; ailleurs il faut une phrase
UI_FILES = {"menus.gd", "hud_jeu.gd", "hud_carte.gd", "commerce.gd", "taxi.gd", "partie.gd", "histoire.gd",
	"dialogues.gd", "police.gd", "lieux.gd", "mode_photo.gd"}
SKIP_LINE = re.compile(r"^\s*(#|##)|\bprint(_rich)?\(|push_(warning|error)\(|assert\(|get_node|find_child|has_meta|set_meta|get_meta|\.name\s*=|load\(|preload\(|is_action|action_press|Input\.|group")
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
LETTER = re.compile(r"[A-Za-zÀ-ÿ]")


def visible(s, ui):
    if " " not in s and ("_" in s or "/" in s or re.search(r"\d", s)):
        return False
    if " " not in s and not ui:
        return False
    if not LETTER.search(s) or s.startswith(("res://", "user://", "uid://", "mat_", "veh_", "prop_", "chr_", "bld_", "lieu_", "%")) and " " not in s:
        return False
    if s.startswith(("res://", "user://", "uid://")):
        return False
    if re.fullmatch(r"[a-z0-9_./:-]+", s):           # cle, nom de noeud, chemin
        return False
    if re.fullmatch(r"[A-Z0-9_]+", s) and len(s) < 4:  # sigles techniques courts
        return False
    if re.fullmatch(r"[A-Za-z]+[A-Z][A-Za-z]*\d*", s) and " " not in s and not re.search(r"[À-ÿ]", s):
        return False                                   # CamelCase (noeuds Godot, os)
    return True


def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"') if '\\"' not in s else s


def main():
    entries = {}
    order = []
    for name in sorted(os.listdir(SCRIPTS)):
        if not name.endswith(".gd") or name in SKIP_FILES:
            continue
        with open(os.path.join(SCRIPTS, name), encoding="utf-8") as f:
            in_doc = False
            for n, line in enumerate(f, 1):
                if line.strip().startswith('"""'):
                    in_doc = not in_doc if line.count('"""') == 1 else in_doc
                if in_doc or SKIP_LINE.search(line):
                    continue
                code = line.split(" # ")[0]
                for m in STRING.finditer(code):
                    s = m.group(1)
                    if not visible(s, name in UI_FILES):
                        continue
                    if s not in entries:
                        entries[s] = []
                        order.append(s)
                    entries[s].append("scripts/%s:%d" % (name, n))
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write('# GTB (Gbe Town Benin) : textes du jeu, genere par godot/tools/extraire_textes.py\n')
        f.write('msgid ""\nmsgstr ""\n"Content-Type: text/plain; charset=UTF-8\\n"\n"Language: fr\\n"\n\n')
        for s in order:
            refs = entries[s]
            f.write("#: %s\n" % " ".join(refs[:6]))
            f.write('msgid "%s"\nmsgstr ""\n\n' % s)
    print("%d textes dans %s" % (len(order), os.path.relpath(OUT, os.path.join(ROOT, ".."))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
