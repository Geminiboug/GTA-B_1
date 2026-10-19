import json, os, numpy as np
from PIL import Image
# GTB_S2=<suffixe> : refs/sentinel2/s2_<suffixe>.png -> littoral_<suffixe>.geojson ; GTB_BBOX=lon0,lat0,lon1,lat1 (celle de s2_crop.py)
SUF = os.environ.get('GTB_S2', '20260124')
im = np.asarray(Image.open('/home/olympe/GTA-B_1/refs/sentinel2/s2_%s.png' % SUF)).astype(int)
H, W, _ = im.shape
_bb = [float(v) for v in os.environ.get('GTB_BBOX', '2.365,6.338,2.397,6.361').split(',')]
LON0, LON1, LAT0, LAT1 = _bb[0], _bb[2], _bb[1], _bb[3]
R, G, B = im[..., 0], im[..., 1], im[..., 2]
water = (R < 40) & (G < 70)
surf = (R > 230) & (G > 230) & (B > 190)
sand = (R > 200) & (G > 150) & (B < 215) & (G > 0.64 * R) & ~water
def ll(x, y): return (LON0 + (LON1 - LON0) * x / W, LAT1 - (LAT1 - LAT0) * y / H)
def runfirst(mask_col, start, step, n):
    y = start
    while 0 <= y < H:
        if mask_col[y:y + n].all() if step > 0 else mask_col[max(0, y - n + 1):y + 1].all():
            return y
        y += step
    return None
coast, inner = [], []
for x in range(0, W, 12):
    yc = runfirst(water[:, x], int(H * 0.45), 1, 20)
    if yc is None: continue
    # remonter dans le sable jusqu'a 12 px consecutifs non-sable
    y = yc - 1; miss = 0; top = yc
    while y > 0 and miss < 12:
        if sand[y, x]: top = y; miss = 0
        else: miss += 1
        y -= 1
    coast.append((x, yc)); inner.append((x, top))
def smooth(pts, k=3):
    ys = np.array([p[1] for p in pts], float)
    ys = np.convolve(np.pad(ys, k, mode='edge'), np.ones(2 * k + 1) / (2 * k + 1), 'valid')
    return [(p[0], y) for p, y in zip(pts, ys)]
coast, inner = smooth(coast), smooth(inner, 4)
widths = [(c[1] - i[1]) * (LAT1 - LAT0) / H * 110540 for c, i in zip(coast, inner)]
print('points', len(coast), 'largeur plage m: min %.0f med %.0f max %.0f' % (min(widths), np.median(widths), max(widths)))
feat = lambda name, pts: {"type": "Feature", "properties": {"name": name, "source": "Copernicus Sentinel-2, 2026-01-24"}, "geometry": {"type": "LineString", "coordinates": [ll(*p) for p in pts]}}
json.dump({"type": "FeatureCollection", "features": [feat("trait_de_cote", coast), feat("limite_plage", inner)]}, open('/home/olympe/GTA-B_1/refs/sentinel2/littoral_%s.geojson' % SUF, 'w'))
# image de controle
ov = im.copy().astype(np.uint8)
for (x, y) in coast: ov[max(0, int(y) - 3):int(y) + 3, x:x + 12] = (255, 0, 0)
for (x, y) in inner: ov[max(0, int(y) - 3):int(y) + 3, x:x + 12] = (0, 255, 255)
Image.fromarray(ov).save('/tmp/s2_check.png')
