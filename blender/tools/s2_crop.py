# GTB : decoupe la zone dans une image Sentinel-2 (COG public AWS earth-search).
# Lancement : python blender/tools/s2_crop.py <url TCI.tif> <sortie.png>
import sys, rasterio
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds
from rasterio.enums import Resampling
import numpy as np
from PIL import Image
url, out = sys.argv[1], sys.argv[2]
# emprise : GTB_BBOX=lon0,lat0,lon1,lat1 (extension de la carte), sinon la zone de l'aeroport
import os
BB = tuple(float(v) for v in os.environ.get("GTB_BBOX", "2.365,6.338,2.397,6.361").split(","))
with rasterio.open(url) as src:
    b = transform_bounds("EPSG:4326", src.crs, *BB)
    win = from_bounds(*b, transform=src.transform)
    arr = src.read(window=win, out_shape=(3, int(win.height) * 6, int(win.width) * 6), resampling=Resampling.bilinear)
    print("px", win.width, win.height, "crs", src.crs)
img = np.transpose(arr, (1, 2, 0)).astype(np.float32)
img = np.clip((img - np.percentile(img, 1)) / (np.percentile(img, 99.5) - np.percentile(img, 1)) * 255, 0, 255).astype(np.uint8)
Image.fromarray(img).save(out)
print("ok", out, img.shape)
