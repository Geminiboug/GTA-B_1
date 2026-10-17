#!/usr/bin/env python3
"""Traduction (phase 24) : godot/i18n/gtb.pot + liste alignee de traductions (une ligne par texte, "=" pour garder
le francais : noms propres, enseignes, expressions en fon) -> godot/i18n/<langue>.po.

Lancement : python3 godot/tools/faire_po.py en godot/i18n/_ids.txt godot/i18n/_en.txt
(_ids.txt : les msgid de gtb.pot dans l'ordre, un par ligne ; a regenerer apres extraire_textes.py)
"""
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
lang, f_ids, f_tr = sys.argv[1:4]
ids = open(f_ids, encoding="utf-8").read().split("\n")
trs = open(f_tr, encoding="utf-8").read().rstrip("\n").split("\n")
assert len(ids) == len(trs), (len(ids), len(trs))
table = dict(zip(ids, trs))
pot = open(os.path.join(ROOT, "i18n", "gtb.pot"), encoding="utf-8").read()


def remplace(m):
    mid = m.group(1)
    t = table.get(mid, "=")
    t = "" if t == "=" else t.replace('"', '\\"')
    return 'msgid "%s"\nmsgstr "%s"' % (mid, t)


out = re.sub(r'^msgid "(.+)"\nmsgstr ""', remplace, pot, flags=re.M)
# en-tete : langue et encodage
out = re.sub(r'"Language: [^"]*"', '"Language: %s\\\\n"' % lang, out, count=1) if '"Language:' in out else \
    out.replace('msgstr ""\n', 'msgstr ""\n"Language: %s\\n"\n"Content-Type: text/plain; charset=UTF-8\\n"\n' % lang, 1)
open(os.path.join(ROOT, "i18n", lang + ".po"), "w", encoding="utf-8").write(out)
print("%s.po : %d textes, %d traduits" % (lang, len(ids), sum(1 for t in trs if t != "=")))
