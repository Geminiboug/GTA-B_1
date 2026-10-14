# GTB : genere godot/assets/materials/<nom>.tres depuis materials.json.
# Lancement : python3 blender/tools/build_godot_materials.py
import json
import os

root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
data = json.load(open(os.path.join(root, "blender", "tools", "materials.json"), encoding="utf-8"))
out_dir = os.path.join(root, "godot", "assets", "materials")
os.makedirs(out_dir, exist_ok=True)

for name, p in data.items():
    if name.startswith("_"):
        continue
    r, g, b = p["color"]
    a = p.get("alpha", 1.0)
    lines = ['[gd_resource type="StandardMaterial3D" format=3]', "", "[resource]", f'resource_name = "{name}"']
    if a < 1.0:
        lines.append("transparency = 1")
    lines.append(f"albedo_color = Color({r}, {g}, {b}, {a})")
    if "metallic" in p:
        lines.append(f"metallic = {p['metallic']}")
    lines.append(f"roughness = {p.get('roughness', 0.8)}")
    open(os.path.join(out_dir, name + ".tres"), "w", encoding="utf-8", newline="\n").write("\n".join(lines) + "\n")
    print("ok", name)
