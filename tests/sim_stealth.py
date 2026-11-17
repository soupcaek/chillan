import sys, json
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__))), "discord", "companion"))
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
from decoder import find_strips
import numpy as np
from PIL import Image
L, G, ns = A
L.execute('''
local mt = getmetatable(UIParent)
local old = mt.__index
mt.__index = function(t, k)
  if k == "SetPoint" then return function(self, a, rel, b, x, y) self._pt = { x or 0, y or 0 } end end
  if k == "SetColorTexture" then return function(self, r, g, b) self._rgb = { r, g, b } end end
  return old(t, k)
end
''')
L.execute('ADDON_NS.Discord:Slash("on")'); run(3)
def snapshot():
    img = np.full((8, 1920, 3), 90, np.uint8)  # some game world behind it
    st = L.eval('ChillanDiscordStrip')
    n = L.eval('(function() local c = 0 for _, r in ipairs({}) do end return 0 end)()')
    i = 1
    while True:
        t = L.eval(f'(function() local s = ChillanDiscordStrip; return s and select({i}, s:GetRegions()) end)()') if False else None
        break
    return img
# walk the pool via debug: textures are created with strip as parent; collect from a registry
L.execute('''
REG = {}
local mt = getmetatable(UIParent)
local old = mt.__index
mt.__index = function(t, k)
  if k == "Show" then return function(self) self._shown = true if rawget(self, "_rgb") then REG[self] = true end end end
  if k == "Hide" then return function(self) self._shown = false end end
  return old(t, k)
end
''')
def snap():
    img = np.full((8, 1920, 3), 90, np.uint8)
    for t in L.eval('REG').keys():
        if not t._shown: continue
        x = int(t._pt[1]); y = -int(t._pt[2]); w = int(t._w); h = int(t._h)
        rgb = [int(round(t._rgb[k] * 255)) for k in (1, 2, 3)]
        img[y:y+h, x:x+w] = rgb
    return img
L.execute('ADDON_NS.Discord:Slash("test")')
img = snap()
got = find_strips(img)
print("clean:", [g.decode()[:70] for g in got])
w = max(int(t._pt[1]) + 2 for t in L.eval('REG').keys() if t._shown)
print("line size: %d x 3 px, max shade %d" % (w, img[:3, :w].max()))
def tryit(name, im): print(name, len(find_strips(im)))
tryit("gamma 0.8", (255 * (img / 255.0) ** 0.8).astype(np.uint8))
tryit("gamma 1.2", (255 * (img / 255.0) ** 1.2).astype(np.uint8))
tryit("bright +20", np.clip(img.astype(int) + 20, 0, 255).astype(np.uint8))
tryit("x1.25", np.array(Image.fromarray(img).resize((int(1920*1.25), 10), Image.BILINEAR)))
tryit("noise±4", np.clip(img.astype(int) + np.random.randint(-4, 5, img.shape), 0, 255).astype(np.uint8))
print("FEIL:", list(G.ERRORS.values())[:3])
