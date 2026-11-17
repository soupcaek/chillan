import sys, json
sys.path.insert(0, __import__("os").path.join(__import__("os").path.dirname(__import__("os").path.dirname(__import__("os").path.abspath(__file__))), "discord", "companion"))
exec(open("sim_v09.py").read().split("# reaksjon-linje")[0])
from decoder import find_strips
import numpy as np
L, G, ns = A
# record SetPoint/SetSize/Show on all mock objects
L.execute('''
local mt = getmetatable(UIParent)
local old = mt.__index
mt.__index = function(t, k)
  if k == "SetPoint" then return function(self, a, rel, b, x, y) self._pt = { x or 0, y or 0 } end end
  return old(t, k)
end
''')
L.execute('ADDON_NS.Discord:Slash("on")')
run(2)
def capture():
    # paint the strip as the screen would show it (1 unit = 1 px), 1920 wide, top 80 rows
    img = np.zeros((80, 1920), np.uint8)
    st = L.eval('ChillanDiscordStrip')
    if not st or not st._shown: return None
    sx = int(st._pt[1]); sy = 0
    pool = L.execute('''
      local out = {}
      for _, t in ipairs({ChillanDiscordStrip:GetRegions()}) do end
      return out''')
    return img
# grab textures directly through the pool by walking objects created with parent = strip
L.execute('''
CAPT = {}
local mt = getmetatable(UIParent)
local old = mt.__index
mt.__index = function(t, k)
  if k == "Show" then return function(self) self._shown = true if rawget(self, "_kind") == "Texture" and self._parent == ChillanDiscordStrip then CAPT[self] = true end end end
  return old(t, k)
end
''')
def snapshot():
    st = L.eval('ChillanDiscordStrip')
    img = np.zeros((80, 1920), np.uint8)
    x0 = int(st._pt[1])
    for t in L.eval('CAPT').keys():
        if not t._shown: continue
        x = x0 + int(t._pt[1]); y = -int(t._pt[2])
        img[y:y+int(t._h), x:x+int(t._w)] = 255
    return img

def send_item(kind, a, b, c="", d=""):
    L.execute(f'ADDON_NS.Data:ApplyEvent("ev{kind}"..math.random(1e6), ADDON_NS.pid, ADDON_NS:GetPerson(ADDON_NS.pid).main, "{kind}", time(), {a!r}, {b!r}, {c!r}, {d!r})'.replace("'", '"'))
results = []
for kind, a, b, c, d in [("DEAD", "Dustwallow Marsh", "CROC:2", "Drywallow Snapper", ""),
                         ("DING", "34", "123456", "", ""),
                         ("LOOT", "6504", "3", "", "")]:
    L.execute('for k in pairs(CAPT) do CAPT[k] = nil end')
    send_item(kind, a, b, c, d)
    img = snapshot()
    got = find_strips(img)
    results.append((kind, [json.loads(g.decode("utf-8")) for g in got]))
    run(2)
for k, r in results: print(k, json.dumps(r, ensure_ascii=False)[:400])
L.execute('for k in pairs(CAPT) do CAPT[k] = nil end')
L.execute('ADDON_NS.Discord:Slash("test")')
print("TEST", [g.decode() for g in find_strips(snapshot())])
print("outbox", L.eval('#ADDON_NS.db.discord.out'))
print("FEIL:", list(G.ERRORS.values())[:4])
# robustness: blur + rescale the last test strip
from PIL import Image, ImageFilter
run(10)
L.execute('for k in pairs(CAPT) do CAPT[k] = nil end')
L.execute('ADDON_NS.Discord:Slash("test")')
base = snapshot()
print("clean:", len(find_strips(base)))
for name, f in [("blur", lambda im: im.filter(ImageFilter.GaussianBlur(0.8))),
                ("x1.25", lambda im: im.resize((int(im.width*1.25), int(im.height*1.25)), Image.BILINEAR)),
                ("x1.5", lambda im: im.resize((int(im.width*1.5), int(im.height*1.5)), Image.BILINEAR)),
                ("x0.8+blur", lambda im: im.resize((int(im.width*0.8), int(im.height*0.8)), Image.BILINEAR).filter(ImageFilter.GaussianBlur(0.5)))]:
    im = f(Image.fromarray(base))
    print(name, len(find_strips(np.array(im))))
