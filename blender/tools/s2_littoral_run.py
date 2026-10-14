# GTB : detection du trait de cote et de la limite de plage sur l'image Sentinel-2 (refs/sentinel2).
# Lancement (venv avec numpy, pillow) : python blender/tools/s2_littoral_run.py
# Sortie : refs/sentinel2/littoral_<date>.geojson + /tmp/s2_check.png (controle visuel)
exec(open('/home/olympe/GTA-B_1/blender/tools/s2_littoral.py').read().split('coast, inner = [], []')[0])
coast, inner = [], []
for x in range(0, W, 12):
    col_sea = water[:, x] | surf[:, x]
    y = H - 1
    while y > 0 and col_sea[y]: y -= 1          # remonter depuis la mer
    if y < H * 0.35: continue
    # premier sable franc
    while y > 0 and not sand[max(0, y - 4):y + 1, x].all() and col_sea[y] == False and y > H * 0.35: y -= 1
    yc = y
    y = yc - 12; miss, top = 0, yc
    while y > 0 and miss < 22:
        if sand[y, x]: top = y; miss = 0
        else: miss += 1
        y -= 1
    coast.append((x, yc)); inner.append((x, top))
exec('def smooth' + open('/home/olympe/GTA-B_1/blender/tools/s2_littoral.py').read().split('def smooth')[1])
