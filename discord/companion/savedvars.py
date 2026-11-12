"""Read Chillan's Discord outbox from the game's saved data file (Chillan.lua).

The game writes it on /reload, logout and exit. Only the ["discord"] part of ChillanDB is parsed.
"""
import glob
import os
import re


class _Lua:
    """Minimal parser for WoW SavedVariables table literals."""

    def __init__(self, s, i=0):
        self.s, self.i = s, i

    def ws(self):
        s, n = self.s, len(self.s)
        while self.i < n:
            c = s[self.i]
            if c in " \t\r\n,;":
                self.i += 1
            elif s.startswith("--", self.i):
                j = s.find("\n", self.i)
                self.i = n if j < 0 else j + 1
            else:
                break

    def value(self):
        self.ws()
        s = self.s
        c = s[self.i]
        if c == "{":
            return self.table()
        if c == '"' or c == "'":
            return self.string()
        if s.startswith("true", self.i):
            self.i += 4
            return True
        if s.startswith("false", self.i):
            self.i += 5
            return False
        if s.startswith("nil", self.i):
            self.i += 3
            return None
        m = re.compile(r"-?(?:0x[0-9a-fA-F]+|\d+\.?\d*(?:[eE][-+]?\d+)?|\.\d+|inf|nan)").match(s, self.i)
        if m:
            self.i = m.end()
            t = m.group(0)
            try:
                if "x" in t:
                    return int(t, 16)
                f = float(t)
                return int(f) if f.is_integer() and "." not in t and "e" not in t.lower() else f
            except ValueError:
                return 0
        raise ValueError("unexpected %r at %d" % (s[self.i:self.i + 20], self.i))

    def string(self):
        s, q = self.s, self.s[self.i]
        self.i += 1
        out = bytearray()
        while True:
            c = s[self.i]
            if c == q:
                self.i += 1
                break
            if c == "\\":
                n = s[self.i + 1]
                if n.isdigit():
                    m = re.compile(r"\d{1,3}").match(s, self.i + 1)
                    out.append(int(m.group(0)) & 0xFF)
                    self.i = m.end()
                    continue
                out += {"n": b"\n", "t": b"\t", "r": b"\r", "\\": b"\\", '"': b'"', "'": b"'", "\n": b"\n"}.get(n, n.encode("utf-8"))
                self.i += 2
                continue
            out += c.encode("utf-8", "surrogateescape")
            self.i += 1
        return out.decode("utf-8", "replace")

    def table(self):
        self.i += 1
        arr, obj = [], {}
        while True:
            self.ws()
            if self.s[self.i] == "}":
                self.i += 1
                break
            if self.s[self.i] == "[":
                self.i += 1
                k = self.value()
                self.ws()
                assert self.s[self.i] == "]"
                self.i += 1
                self.ws()
                assert self.s[self.i] == "="
                self.i += 1
                obj[k] = self.value()
            else:
                m = re.compile(r"([A-Za-z_]\w*)\s*=(?!=)").match(self.s, self.i)
                if m:
                    self.i = m.end()
                    obj[m.group(1)] = self.value()
                else:
                    arr.append(self.value())
        if obj and arr:
            for n, v in enumerate(arr, 1):
                obj.setdefault(n, v)
            return obj
        if obj:
            # integer-keyed tables written as [1] = ..., [2] = ...
            if all(isinstance(k, int) for k in obj):
                return [obj[k] for k in sorted(obj)]
            return obj
        return arr


def read_discord(path):
    """Return {'out': [json strings], 'status': json string or None} from Chillan.lua."""
    with open(path, "rb") as f:
        text = f.read().decode("utf-8", "surrogateescape")
    m = re.search(r'\["discord"\]\s*=\s*\{', text)
    if not m:
        return {"out": [], "status": None}
    p = _Lua(text, m.end() - 1)
    d = p.table()
    out = []
    for e in d.get("out", []) if isinstance(d, dict) else []:
        if isinstance(e, dict) and isinstance(e.get("j"), str):
            out.append(e["j"])
    st = d.get("status") if isinstance(d, dict) else None
    return {"out": out, "status": st if isinstance(st, str) else None}


def find_saved_files(roots=None):
    """Look for WTF/Account/*/SavedVariables/Chillan.lua under the usual WoW folders."""
    found = []
    roots = roots or []
    if not roots:
        for drive in "CDEFGH":
            for base in (r"\Program Files (x86)\World of Warcraft", r"\Program Files\World of Warcraft",
                         r"\World of Warcraft", r"\Games\World of Warcraft", r"\Blizzard\World of Warcraft"):
                roots.append(drive + ":" + base)
    for root in roots:
        if not os.path.isdir(root):
            continue
        for pat in ("WTF/Account/*/SavedVariables/Chillan.lua", "*/WTF/Account/*/SavedVariables/Chillan.lua"):
            found += glob.glob(os.path.join(root, pat))
    return sorted(set(found))
