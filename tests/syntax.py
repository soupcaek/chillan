import os as _os
HERE = _os.path.dirname(_os.path.abspath(__file__)) + "/"
REPO = _os.path.dirname(HERE.rstrip("/")) + "/"
import sys, glob, os
from lupa import lua51
L = lua51.LuaRuntime()
check = L.eval("function(src, name) local f, err = loadstring(src, name) if f then return 'ok' else return err end end")
bad = 0
for p in sorted(glob.glob(REPO + "**/*.lua", recursive=True)):
    r = check(open(p, encoding="utf-8").read(), os.path.basename(p))
    if r != "ok":
        bad += 1
        print("FEIL", r)
print("filer sjekket, feil:", bad)
