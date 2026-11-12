"""Turn Chillan events into Discord embed dicts (no discord library needed, easy to test)."""
import time
from datetime import datetime, timezone

CLASS = {
    "WARRIOR": 0xC69B6D, "PALADIN": 0xF48CBA, "HUNTER": 0xAAD372, "ROGUE": 0xFFF468, "PRIEST": 0xFFFFFF,
    "SHAMAN": 0x0070DD, "MAGE": 0x3FC7EB, "WARLOCK": 0x8788EE, "DRUID": 0xFF7C0A,
}
CLASS_NAME = {k: k.title() for k in CLASS}
QUALITY = {2: (0x1EFF00, "uncommon"), 3: (0x0070DD, "rare"), 4: (0xA335EE, "epic"), 5: (0xFF8000, "legendary")}
TIER = {"Bronze": 0xCD7F32, "Silver": 0xC0C0C0, "Gold": 0xE0C068, "Legendary": 0xF0A8D0}
RED, GOLD, GREY, BLUE = 0xE5484D, 0xE0C068, 0x6B7280, 0x8FB8E8
WOWHEAD_ITEM = "https://www.wowhead.com/classic/item={}"


def dur(sec):
    try:
        sec = int(sec)
    except (TypeError, ValueError):
        return "?"
    d, sec = divmod(sec, 86400)
    h, sec = divmod(sec, 3600)
    m = sec // 60
    if d:
        return "%dd %dh" % (d, h)
    if h:
        return "%dh %dm" % (h, m)
    return "%dm" % m


def money(c):
    try:
        c = int(c)
    except (TypeError, ValueError):
        return "?"
    g, c = divmod(c, 10000)
    s, c = divmod(c, 100)
    return " ".join(x for x in ("%dg" % g if g else "", "%ds" % s if s else "", "%dc" % c if c or not (g or s) else "") if x)


def iso(t):
    try:
        return datetime.fromtimestamp(int(t), timezone.utc).isoformat()
    except (TypeError, ValueError, OSError):
        return datetime.now(timezone.utc).isoformat()


def who(e):
    return e.get("n") or e.get("ch") or "Someone"


def footer(e):
    bits = []
    if e.get("ch") and e.get("ch") != e.get("n"):
        bits.append(e["ch"])
    if e.get("l"):
        bits.append("level %s" % e["l"])
    if e.get("cl") in CLASS_NAME:
        bits.append(CLASS_NAME[e["cl"]])
    return {"text": " · ".join(bits) or "Chillan?"}


def card(e):
    """Embed dict for one event, or None if this kind has no card."""
    k = e.get("k")
    c = CLASS.get(e.get("cl"), GREY)
    if k == "DEAD":
        fields = []
        if e.get("z"):
            fields.append({"name": "Where", "value": e["z"], "inline": True})
        if e.get("kc"):
            fields.append({"name": "Killed by", "value": e["kc"] + (" · " + e["kx"] if e.get("kx") else ""), "inline": True})
        return {"author": {"name": (e.get("kick") or "DEAD").upper()}, "description": "**%s**" % (e.get("tx") or (who(e) + " died.")),
                "color": RED, "fields": fields, "footer": footer(e), "timestamp": iso(e.get("t"))}
    if k == "KILL":
        revenge = e.get("cat") == "REVENGE"
        f = []
        if e.get("vi"):
            f.append({"name": "Victim", "value": e["vi"] + (" · " + e["vx"] if e.get("vx") else ""), "inline": True})
        if e.get("z"):
            f.append({"name": "Where", "value": e["z"], "inline": True})
        return {"author": {"name": (e.get("kick") or ("REVENGE!" if revenge else "ALLIANCE DOWN")).upper()},
                "description": "**%s**" % (e.get("tx") or (who(e) + " killed " + str(e.get("vi") or "an Alliance player"))),
                "color": 0xFF8A3D if revenge else GOLD, "fields": f, "footer": footer(e), "timestamp": iso(e.get("t"))}
    if k == "DING":
        lines = []
        if e.get("first"):
            lines.append("**First in the gang to reach %s!**" % e.get("l"))
        elif e.get("place") and int(e.get("l") or 0) % 10 == 0:
            lines.append("No. %s in the gang to get here" % e["place"])
        if e.get("pl"):
            lines.append("/played %s" % dur(e["pl"]))
        return {"author": {"name": "DING! LEVEL %s" % e.get("l")}, "title": "Gratz on the ding, %s!" % who(e),
                "description": "\n".join(lines) or None, "color": c, "footer": footer(e), "timestamp": iso(e.get("t"))}
    if k == "RECAP":
        f = []
        if e.get("time"):
            f.append({"name": "Time on the level", "value": dur(e["time"]), "inline": True})
        if e.get("xph"):
            f.append({"name": "XP per hour", "value": "{:,}".format(int(e["xph"])).replace(",", " "), "inline": True})
        f.append({"name": "Deaths", "value": "%s (%s to Alliance)" % (e.get("de") or 0, e.get("al") or 0), "inline": True})
        if e.get("ki") is not None:
            f.append({"name": "Mobs killed", "value": str(e["ki"]) + (" · most: %s (%s)" % (e["tm"], e.get("tmn")) if e.get("tm") else ""), "inline": True})
        if e.get("mo"):
            f.append({"name": "Money gained", "value": money(e["mo"]), "inline": True})
        if e.get("qu") is not None:
            f.append({"name": "Quests", "value": str(e["qu"]), "inline": True})
        if e.get("rk") and e.get("rof"):
            f.append({"name": "Gang ranking", "value": "%s of %s fastest" % (e["rk"], e["rof"]), "inline": True})
        if e.get("li"):
            f.append({"name": "Best loot", "value": "[item %s](%s)" % (e["li"], WOWHEAD_ITEM.format(e["li"])), "inline": True})
        return {"author": {"name": "LEVEL RECAP"}, "title": "%s: level %s → %s" % (who(e), e.get("fr"), e.get("l")),
                "color": c, "fields": f, "footer": footer(e), "timestamp": iso(e.get("t"))}
    if k == "LOOT":
        qc, qn = QUALITY.get(int(e.get("q") or 0), (GREY, "item"))
        name = e.get("nm") or "an item"
        out = {"author": {"name": "LOOT · %s" % qn.upper()}, "title": "%s looted [%s]" % (who(e), name),
               "color": qc, "footer": footer(e), "timestamp": iso(e.get("t"))}
        if e.get("i"):
            out["url"] = WOWHEAD_ITEM.format(e["i"])
        if e.get("first"):
            out["description"] = "**First epic in the gang!**"
        return out
    if k == "ACH":
        out = {"author": {"name": "ACHIEVEMENT" + (" · " + e["at"].upper() if e.get("at") else "")},
               "title": "%s unlocked «%s»" % (who(e), e.get("an") or "?"), "color": TIER.get(e.get("at"), GOLD),
               "footer": footer(e), "timestamp": iso(e.get("t"))}
        if e.get("ad"):
            out["description"] = e["ad"]
        return out
    if k == "DUNGEON":
        names = e.get("with") or [who(e)]
        f = [{"name": "Time", "value": dur(e.get("dur")), "inline": True}]
        if e.get("bo"):
            f.append({"name": "Bosses", "value": str(e["bo"]), "inline": True})
        f.append({"name": "Deaths", "value": str(e.get("dd") or 0), "inline": True})
        return {"author": {"name": "DUNGEON RUN"}, "title": "%s cleared %s" % (", ".join(names), e.get("dg") or "a dungeon"),
                "color": BLUE, "fields": f, "footer": footer(e), "timestamp": iso(e.get("t"))}
    if k == "TEST":
        return {"author": {"name": "TEST"}, "title": "It works!", "description": e.get("tx") or "Test from Chillan?",
                "color": GOLD, "footer": footer(e), "timestamp": iso(e.get("t"))}
    return None


def status_card(st, updated=None):
    rows = st.get("g") or []
    rows = sorted(rows, key=lambda r: (-int(r[5] or 0), -int(r[3] or 0), str(r[0])))
    lines = []
    for r in rows:
        alias, char, cls, lvl, zone, online = r[0], r[1], r[2], r[3], r[4], r[5]
        dot = "🟢" if online else "⚫"
        cn = CLASS_NAME.get(cls, "")
        line = "%s **%s** · %s · %s %s" % (dot, alias, char, lvl, cn)
        if online and zone:
            line += " · " + zone
        lines.append(line.strip())
    online = sum(1 for r in rows if r[5])
    return {"title": "Gang status · %d of %d online" % (online, len(rows)), "description": "\n".join(lines) or "Nobody yet.",
            "color": 0x9BE08A if online else GREY,
            "footer": {"text": "Updated"}, "timestamp": iso(updated or st.get("t") or time.time())}


def deaths_card(deaths_all, deaths_week):
    count, week = {}, {}
    for e in deaths_all:
        count[who(e)] = count.get(who(e), 0) + 1
    for e in deaths_week:
        week[who(e)] = week.get(who(e), 0) + 1
    ranked = sorted(count.items(), key=lambda kv: -kv[1])
    lines = ["**%d.** %s · %d deaths%s" % (i + 1, n, c, " (%d this week)" % week[n] if week.get(n) else "")
             for i, (n, c) in enumerate(ranked[:10])]
    latest = ["> " + (e.get("tx") or who(e) + " died") for e in deaths_all[:3]]
    desc = "\n".join(lines) or "Nobody has died yet. Suspicious."
    if latest:
        desc += "\n\n**Latest:**\n" + "\n".join(latest)
    return {"title": "Wall of shame", "description": desc, "color": RED}


def levels_card(st):
    rows = sorted(st.get("g") or [], key=lambda r: -int(r[3] or 0))
    lines = []
    for i, r in enumerate(rows):
        lvl = int(r[3] or 0)
        filled = max(0, min(10, round(lvl / 6)))
        lines.append("**%d.** %s · %d %s\n`%s%s` %d%% to 60" % (i + 1, r[0], lvl, CLASS_NAME.get(r[2], ""),
                     "▰" * filled, "▱" * (10 - filled), round(lvl / 60 * 100)))
    return {"title": "Race to 60", "description": "\n".join(lines) or "No data yet.", "color": GOLD}


def loot_card(loot):
    lines = []
    now = time.time()
    for e in loot[:10]:
        qc, qn = QUALITY.get(int(e.get("q") or 0), (GREY, "item"))
        name = e.get("nm") or "item"
        link = "[%s](%s)" % (name, WOWHEAD_ITEM.format(e["i"])) if e.get("i") else name
        ago = dur(max(0, now - int(e.get("t") or now)))
        lines.append("**%s** · %s (%s) · %s ago" % (who(e), link, qn, ago))
    return {"title": "Recent loot", "description": "\n".join(lines) or "No loot posted yet.", "color": QUALITY[3][0]}
