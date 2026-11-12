"""SQLite history for the Chillan bot."""
import json
import sqlite3
import time


class Store:
    def __init__(self, path):
        self.db = sqlite3.connect(path)
        self.db.execute("""CREATE TABLE IF NOT EXISTS events (
            id TEXT PRIMARY KEY, kind TEXT, t INTEGER, pid TEXT, name TEXT, json TEXT, received INTEGER)""")
        self.db.execute("CREATE INDEX IF NOT EXISTS ev_kind_t ON events(kind, t)")
        self.db.execute("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT)")
        self.db.commit()

    def add(self, e):
        """Store an event. Returns False when it was already there (a duplicate)."""
        try:
            self.db.execute("INSERT INTO events VALUES (?,?,?,?,?,?,?)",
                            (str(e["id"]), e.get("k"), int(e.get("t") or 0), str(e.get("p") or ""),
                             str(e.get("n") or ""), json.dumps(e, ensure_ascii=False), int(time.time())))
            self.db.commit()
            return True
        except sqlite3.IntegrityError:
            return False

    def events(self, kind, since=0, limit=1000):
        rows = self.db.execute("SELECT json FROM events WHERE kind=? AND t>=? ORDER BY t DESC LIMIT ?",
                               (kind, since, limit)).fetchall()
        return [json.loads(r[0]) for r in rows]

    def range(self, since, until):
        rows = self.db.execute("SELECT json FROM events WHERE t>=? AND t<? AND kind NOT IN ('TEST','STATUS') ORDER BY t",
                               (int(since), int(until))).fetchall()
        return [json.loads(r[0]) for r in rows]

    def all(self, limit=20000):
        rows = self.db.execute("SELECT json FROM events WHERE kind NOT IN ('TEST','STATUS') ORDER BY t DESC LIMIT ?",
                               (limit,)).fetchall()
        return [json.loads(r[0]) for r in reversed(rows)]

    def get(self, k, default=None):
        r = self.db.execute("SELECT v FROM meta WHERE k=?", (k,)).fetchone()
        return r[0] if r else default

    def set(self, k, v):
        self.db.execute("INSERT OR REPLACE INTO meta VALUES (?,?)", (k, str(v)))
        self.db.commit()
