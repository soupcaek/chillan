"""Daily/weekly recaps, catch-up summaries, /whois and /stats, as embed dicts (no discord library)."""
import random
import time

from cards import CLASS, CLASS_NAME, GOLD, GREY, QUALITY, RED, WOWHEAD_ITEM, dur, who

AWARD_LINES = {
    "mvp": ["carried the gang on their back", "is built different", "grinded like rent was due", "touched grass? never heard of it"],
    "clown": ["kept the spirit healer in business", "speedran the graveyard", "is on a first-name basis with death", "should maybe try not dying"],
    "punching": ["is the Alliance's favourite chew toy", "got farmed for honor all day", "is basically an Alliance daily quest"],
    "goblin": ["has suspiciously good luck", "rolled need on everything, probably", "is swimming in purples"],
    "dungeon": ["lives in dungeons now", "forgot the outside world exists"],
}


def _n(n, word):
    return "%d %s%s" % (n, word, "" if n == 1 else "s")


def _rng(seed):
    return random.Random(str(seed))


def summarize(events):
    """Per-person tallies for a list of events."""
    people = {}

    def p(e):
        key = e.get("p") or who(e)
        d = people.setdefault(key, {"name": who(e), "cl": e.get("cl"), "levels": [], "deaths": [], "alli": 0,
                                    "loot": [], "ach": [], "dg": []})
        if e.get("cl"):
            d["cl"] = e["cl"]
        return d

    for e in sorted(events, key=lambda x: int(x.get("t") or 0)):
        k = e.get("k")
        if k == "DING":
            p(e)["levels"].append(int(e.get("l") or 0))
        elif k == "DEAD":
            d = p(e)
            d["deaths"].append(e)
            if e.get("cat") == "PLAYER":
                d["alli"] += 1
        elif k == "LOOT":
            p(e)["loot"].append(e)
        elif k == "ACH":
            p(e)["ach"].append(e)
        elif k == "DUNGEON":
            p(e)["dg"].append(e)
    return people


def _top(people, key, minimum=1):
    best = None
    for d in people.values():
        v = key(d)
        if v >= minimum and (best is None or v > best[1]):
            best = (d, v)
    return best


def _loot_link(e):
    name = e.get("nm") or "an item"
    return "[%s](%s)" % (name, WOWHEAD_ITEM.format(e["i"])) if e.get("i") else name


def _body(people, rng, max_loot=5):
    lines = []
    lv = [(d["name"], d["levels"]) for d in people.values() if d["levels"]]
    if lv:
        lv.sort(key=lambda x: -len(x[1]))
        lines.append("**Levels:** " + ", ".join("%s +%d (now %d)" % (n, len(l), max(l)) for n, l in lv))
    deaths = [e for d in people.values() for e in d["deaths"]]
    if deaths:
        per = sorted(((d["name"], len(d["deaths"])) for d in people.values() if d["deaths"]), key=lambda x: -x[1])
        lines.append("**Deaths:** %d · %s" % (len(deaths), ", ".join("%s %d" % x for x in per)))
        lines.append("> " + (rng.choice(deaths).get("tx") or "Someone died."))
    loot = sorted((e for d in people.values() for e in d["loot"]), key=lambda e: -int(e.get("q") or 0))
    if loot:
        lines.append("**Loot:** " + ", ".join("%s %s" % (who(e), _loot_link(e)) for e in loot[:max_loot])
                     + (" and %d more" % (len(loot) - max_loot) if len(loot) > max_loot else ""))
    ach = [e for d in people.values() for e in d["ach"]]
    if ach:
        lines.append("**Achievements:** " + ", ".join("%s «%s»" % (who(e), e.get("an") or "?") for e in ach[:6])
                     + (" and %d more" % (len(ach) - 6) if len(ach) > 6 else ""))
    dg = [e for d in people.values() for e in d["dg"]]
    if dg:
        lines.append("**Dungeons:** " + ", ".join("%s (%s)" % (e.get("dg") or "?", dur(e.get("dur"))) for e in dg[:5]))
    return lines


def _awards(people, rng, weekly=False):
    out = []
    mvp = _top(people, lambda d: len(d["levels"]) * 10 + len(d["dg"]) * 3 + len(d["ach"]))
    if mvp:
        d = mvp[0]
        out.append({"name": "🏆 " + ("Grinder of the week" if weekly else "MVP"), "inline": True,
                    "value": "**%s** %s (+%d level%s)" % (d["name"], rng.choice(AWARD_LINES["mvp"]), len(d["levels"]), "" if len(d["levels"]) == 1 else "s")
                    if d["levels"] else "**%s** %s" % (d["name"], rng.choice(AWARD_LINES["mvp"]))})
    clown = _top(people, lambda d: len(d["deaths"]))
    if clown:
        out.append({"name": "🤡 Clown of the " + ("week" if weekly else "day"), "inline": True,
                    "value": "**%s** %s (%s)" % (clown[0]["name"], rng.choice(AWARD_LINES["clown"]), _n(clown[1], "death"))})
    bag = _top(people, lambda d: d["alli"])
    if bag:
        out.append({"name": "🎯 Alliance punching bag", "inline": True,
                    "value": "**%s** %s (%d)" % (bag[0]["name"], rng.choice(AWARD_LINES["punching"]), bag[1])})
    goblin = _top(people, lambda d: len(d["loot"]))
    if goblin:
        out.append({"name": "💰 Loot goblin", "inline": True,
                    "value": "**%s** %s (%s)" % (goblin[0]["name"], rng.choice(AWARD_LINES["goblin"]), _n(goblin[1], "drop"))})
    if weekly:
        crawler = _top(people, lambda d: len(d["dg"]))
        if crawler:
            out.append({"name": "🗝️ Dungeon crawler", "inline": True,
                        "value": "**%s** %s (%s)" % (crawler[0]["name"], rng.choice(AWARD_LINES["dungeon"]), _n(crawler[1], "run"))})
    return out


def daily_card(events, label, seed):
    people = summarize(events)
    if not any(d["levels"] or d["deaths"] or d["loot"] or d["ach"] or d["dg"] for d in people.values()):
        return None
    rng = _rng(seed)
    return {"author": {"name": "DAILY RECAP"}, "title": "Yesterday in the gang · %s" % label,
            "description": "\n".join(_body(people, rng)), "color": GOLD, "fields": _awards(people, rng)}


def weekly_card(events, label, seed, status=None):
    people = summarize(events)
    if not any(d["levels"] or d["deaths"] or d["loot"] or d["ach"] or d["dg"] for d in people.values()):
        return None
    rng = _rng(seed)
    lines = _body(people, rng, max_loot=8)
    rows = sorted((status or {}).get("g") or [], key=lambda r: -int(r[3] or 0))
    if rows:
        lines.append("**Race to 60:** " + " · ".join("%s %s" % (r[0], r[3]) for r in rows[:8]))
    return {"author": {"name": "WEEKLY SUMMARY"}, "title": "The week in the gang · %s" % label,
            "description": "\n".join(lines), "color": GOLD, "fields": _awards(people, rng, weekly=True)}


def catchup_card(events):
    people = summarize(events)
    if not events:
        return None
    ts = [int(e.get("t") or 0) for e in events]
    rng = _rng(min(ts))
    span = dur(max(ts) - min(ts)) if max(ts) - min(ts) >= 60 else "a few minutes"
    return {"author": {"name": "CATCH-UP"}, "title": "What happened while the relay was offline",
            "description": "%s over %s\n\n" % (_n(len(events), "event"), span) + "\n".join(_body(people, rng)), "color": GREY}


def _match(name, rows, events):
    q = (name or "").strip().lower()
    if not q:
        return None, None
    for r in rows:
        if q in (str(r[0]).lower(), str(r[1]).lower()):
            return r, r[6] if len(r) > 6 else None
    for r in rows:
        if str(r[0]).lower().startswith(q) or str(r[1]).lower().startswith(q):
            return r, r[6] if len(r) > 6 else None
    for e in events:
        if q in (str(e.get("n", "")).lower(), str(e.get("ch", "")).lower()):
            return None, e.get("p")
    return None, None


def whois_card(name, status, events, last_seen=None, now=None):
    now = now or time.time()
    rows = (status or {}).get("g") or []
    row, pid = _match(name, rows, events)
    mine = [e for e in events if (pid and e.get("p") == pid) or (not pid and row and who(e) == row[0])]
    if not row and not mine:
        return {"title": "Never heard of %s" % name, "description": "Nobody in the gang by that name (alias or character).", "color": GREY}
    alias = row[0] if row else who(mine[-1])
    cl = row[2] if row else next((e.get("cl") for e in mine if e.get("cl")), "")
    desc = []
    if row:
        desc.append("%s · level %s %s" % (row[1], row[3], CLASS_NAME.get(row[2], "")))
        if row[5]:
            desc.append("🟢 Online" + (" in %s" % row[4] if row[4] else ""))
        elif last_seen:
            desc.append("⚫ Last seen %s ago" % dur(now - last_seen))
        else:
            desc.append("⚫ Offline")
    week = now - 7 * 86400
    deaths = [e for e in mine if e.get("k") == "DEAD"]
    dings = [e for e in mine if e.get("k") == "DING"]
    loot = [e for e in mine if e.get("k") == "LOOT"]
    ach = [e for e in mine if e.get("k") == "ACH"]
    dgs = [e for e in mine if e.get("k") == "DUNGEON"]
    f = [
        {"name": "Deaths", "value": "%d (%d this week, %d to Alliance)" % (len(deaths), sum(1 for e in deaths if int(e.get("t") or 0) >= week),
                                                                          sum(1 for e in deaths if e.get("cat") == "PLAYER")), "inline": True},
        {"name": "Levels this week", "value": str(sum(1 for e in dings if int(e.get("t") or 0) >= week)), "inline": True},
        {"name": "Achievements", "value": str(len(ach)), "inline": True},
        {"name": "Dungeon runs", "value": str(len(dgs)), "inline": True},
    ]
    if loot:
        f.append({"name": "Latest loot", "value": _loot_link(loot[-1]), "inline": True})
    if deaths:
        f.append({"name": "Latest death", "value": "> " + (deaths[-1].get("tx") or "died"), "inline": False})
    return {"title": alias, "description": "\n".join(desc) or None, "color": CLASS.get(cl, GREY), "fields": f}


def stats_card(name, status, events, now=None):
    now = now or time.time()
    week = now - 7 * 86400
    if name:
        rows = (status or {}).get("g") or []
        row, pid = _match(name, rows, events)
        mine = [e for e in events if (pid and e.get("p") == pid) or (not pid and row and who(e) == row[0])]
        if not row and not mine:
            return {"title": "Never heard of %s" % name, "description": "Nobody in the gang by that name.", "color": GREY}
        events = mine
        title = "Stats · %s" % (row[0] if row else who(mine[-1]))
    else:
        title = "Gang stats"
    kinds = [("DEAD", "Deaths"), ("DING", "Dings"), ("LOOT", "Loot (blue+)"), ("ACH", "Achievements"), ("DUNGEON", "Dungeon runs")]
    lines = ["`%-14s %6s %6s`" % ("", "all", "week")]
    for k, label in kinds:
        allk = [e for e in events if e.get("k") == k]
        lines.append("`%-14s %6d %6d`" % (label, len(allk), sum(1 for e in allk if int(e.get("t") or 0) >= week)))
    alli = sum(1 for e in events if e.get("k") == "DEAD" and e.get("cat") == "PLAYER")
    lines.append("`%-14s %6d %6s`" % ("By Alliance", alli, ""))
    out = {"title": title, "description": "\n".join(lines), "color": GOLD}
    if not name:
        people = summarize(events)
        leaders = []
        for label, key in (("Most deaths", lambda d: len(d["deaths"])), ("Most dings", lambda d: len(d["levels"])),
                           ("Most loot", lambda d: len(d["loot"])), ("Most runs", lambda d: len(d["dg"]))):
            t = _top(people, key)
            if t:
                leaders.append({"name": label, "value": "%s (%d)" % (t[0]["name"], t[1]), "inline": True})
        out["fields"] = leaders
    return out


COMMANDS = [
    ("/gang", "Who's online, levels and zones"),
    ("/whois <name>", "Profile of one gang member (alias or character)"),
    ("/stats [name]", "Numbers for the whole gang, or one person"),
    ("/deaths", "The wall of shame"),
    ("/levels", "The race to 60"),
    ("/loot", "Recent good drops"),
]


def commands_card():
    return {"title": "Chillan? bot commands", "color": GOLD,
            "description": "\n".join("**%s** · %s" % c for c in COMMANDS)
            + "\n\nEvery morning at 08:00: yesterday's recap. Mondays at 08:00: the weekly summary. Deaths, dings, loot, achievements and dungeon runs are posted here as they happen."
            + "\n\n**Help the feed:** double-click `ChillanCompanion.exe` once. It's in your WoW folder under "
            + "`_forever_\\Interface\\AddOns\\Chillan\\Companion`. It installs itself, starts with Windows and only reads Chillan's saved data, never your screen."}
