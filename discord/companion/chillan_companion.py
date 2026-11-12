"""Chillan companion: relays Chillan? events from WoW to Discord.

Two sources:
  * live: the code strip Chillan flashes at the top of the WoW window (needs /chill discord on)
  * backup: the outbox in Chillan's saved data file, written by the game at /reload, logout and exit
Everything goes to the hidden raw channel's webhook; the Chillan bot turns it into cards and
removes duplicates.
"""
import ctypes
import json
import os
import queue
import sys
import threading
import time
import tkinter as tk
from collections import deque
from tkinter import filedialog, messagebox, ttk

import numpy as np

from decoder import find_strips
from relay import post
from savedvars import find_saved_files, read_discord

APP = "Chillan companion"
VERSION = "1.0.1"
HOME = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "ChillanCompanion")
CFG_PATH = os.path.join(HOME, "config.json")
STATE_PATH = os.path.join(HOME, "state.json")
LOG_PATH = os.path.join(HOME, "log.txt")
SCAN_ROWS = 110         # strip lives in the top rows of the WoW window
SCAN_EVERY = 0.12       # seconds between screen reads
FILE_EVERY = 3.0        # seconds between saved-file checks
STATUS_MIN_GAP = 30     # seconds between two status relays

os.makedirs(HOME, exist_ok=True)


def log(msg):
    line = time.strftime("%Y-%m-%d %H:%M:%S ") + msg
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as f:
            f.write(line + "\n")
        if os.path.getsize(LOG_PATH) > 2_000_000:
            os.replace(LOG_PATH, LOG_PATH + ".old")
    except OSError:
        pass


def load_json(path, default):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def save_json(path, data):
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    os.replace(tmp, path)


# ---------------------------------------------------------------------------
# Windows: find the WoW window and read the top of it
# ---------------------------------------------------------------------------
IS_WIN = sys.platform == "win32"
if IS_WIN:
    from ctypes import wintypes
    user32 = ctypes.windll.user32
    try:
        ctypes.windll.shcore.SetProcessDpiAwareness(2)  # real pixels, not scaled ones
    except Exception:
        try:
            user32.SetProcessDPIAware()
        except Exception:
            pass


def wow_client_rect():
    """(left, top, width, height) of the WoW window's client area in screen pixels, or None."""
    if not IS_WIN:
        return None
    found = []
    EnumProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def cb(hwnd, _):
        if not user32.IsWindowVisible(hwnd) or user32.IsIconic(hwnd):
            return True
        n = user32.GetWindowTextLengthW(hwnd)
        if n:
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, buf, n + 1)
            if buf.value.strip().startswith("World of Warcraft"):
                found.append(hwnd)
        return True

    user32.EnumWindows(EnumProc(cb), 0)
    if not found:
        return None
    fg = user32.GetForegroundWindow()
    hwnd = fg if fg in found else found[0]
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    w, h = r.right - r.left, r.bottom - r.top
    if w < 200 or h < 100:
        return None
    return pt.x, pt.y, w, h


def set_autostart(on):
    if not IS_WIN:
        return
    import winreg
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0,
                         winreg.KEY_SET_VALUE)
    try:
        if on:
            exe = sys.executable if getattr(sys, "frozen", False) else '"%s" "%s"' % (sys.executable, os.path.abspath(__file__))
            winreg.SetValueEx(key, "ChillanCompanion", 0, winreg.REG_SZ, exe if exe.startswith('"') else '"%s"' % exe)
        else:
            try:
                winreg.DeleteValue(key, "ChillanCompanion")
            except FileNotFoundError:
                pass
    finally:
        winreg.CloseKey(key)


# ---------------------------------------------------------------------------
# the relay engine
# ---------------------------------------------------------------------------
class Engine:
    def __init__(self):
        self.cfg = load_json(CFG_PATH, {"webhook": "", "saved_file": "", "live": True, "autostart": False})
        st = load_json(STATE_PATH, {})
        self.sent = deque(st.get("sent", []), maxlen=5000)
        self.sent_set = set(self.sent)
        self.q = queue.Queue()
        self.stop = threading.Event()
        self.last_status = None
        self.last_status_at = 0
        self.file_mtime = 0
        self.stats = {"strips": 0, "sent": 0, "failed": 0, "last": "nothing yet", "wow": False, "file": "not found"}
        self.lock = threading.Lock()
        self.last_frame = None
        if not self.cfg.get("saved_file"):
            files = find_saved_files()
            if files:
                self.cfg["saved_file"] = files[0]
                self.save_cfg()

    def save_cfg(self):
        save_json(CFG_PATH, self.cfg)

    def save_state(self):
        with self.lock:
            save_json(STATE_PATH, {"sent": list(self.sent)})

    def offer(self, payload_json, source):
        """Queue an event (as JSON text) unless it has already been relayed."""
        try:
            e = json.loads(payload_json)
        except ValueError:
            return
        if not isinstance(e, dict) or "k" not in e:
            return
        if e.get("k") == "STATUS":
            now = time.time()
            sig = json.dumps(e.get("g"), sort_keys=True)
            if sig == self.last_status and now - self.last_status_at < 600:
                return
            if now - self.last_status_at < STATUS_MIN_GAP and source != "file":
                return
            self.last_status, self.last_status_at = sig, now
            self.q.put(payload_json)
            return
        eid = str(e.get("id", ""))
        with self.lock:
            if not eid or eid in self.sent_set:
                return
            self.sent.append(eid)
            self.sent_set.add(eid)
            if len(self.sent_set) > len(self.sent) + 500:
                self.sent_set = set(self.sent)
        self.stats["last"] = "%s %s (%s)" % (e.get("k"), e.get("n", ""), source)
        log("queued %s from %s" % (eid, source))
        self.q.put(payload_json)

    # --- threads ---
    def sender(self):
        while not self.stop.is_set():
            try:
                item = self.q.get(timeout=0.5)
            except queue.Empty:
                continue
            url = self.cfg.get("webhook", "").strip()
            if not url:
                time.sleep(2)
                self.q.put(item)
                continue
            if post(url, item):
                self.stats["sent"] += 1
                self.save_state()
            else:
                self.stats["failed"] += 1
                log("send failed, retrying later")
                time.sleep(5)
                self.q.put(item)

    def screen(self):
        try:
            import mss
        except ImportError:
            log("mss missing: live reading off")
            return
        with mss.mss() as sct:
            while not self.stop.is_set():
                time.sleep(SCAN_EVERY)
                if not self.cfg.get("live", True):
                    continue
                rect = wow_client_rect()
                self.stats["wow"] = rect is not None
                if not rect:
                    time.sleep(1)
                    continue
                x, y, w, h = rect
                try:
                    shot = sct.grab({"left": x, "top": y, "width": w, "height": min(SCAN_ROWS, h)})
                except Exception:
                    time.sleep(1)
                    continue
                img = np.frombuffer(shot.bgra, np.uint8).reshape(shot.height, shot.width, 4)[:, :, :3]
                self.last_frame = img
                for data in find_strips(img):
                    self.stats["strips"] += 1
                    try:
                        self.offer(data.decode("utf-8"), "live")
                    except UnicodeDecodeError:
                        pass

    def files(self):
        while not self.stop.is_set():
            time.sleep(FILE_EVERY)
            path = self.cfg.get("saved_file", "")
            if not path or not os.path.isfile(path):
                self.stats["file"] = "not found"
                continue
            self.stats["file"] = "ok"
            try:
                mt = os.path.getmtime(path)
            except OSError:
                continue
            if mt == self.file_mtime:
                continue
            first = self.file_mtime == 0
            self.file_mtime = mt
            time.sleep(1.0)  # let the game finish writing
            try:
                d = read_discord(path)
            except Exception as ex:
                log("could not read saved file: %r" % ex)
                continue
            # on the very first read only take recent events (the bot ignores old ones anyway)
            for j in d["out"]:
                self.offer(j, "file")
            if d["status"] and not first:
                self.offer(d["status"], "file")

    def start(self):
        for fn in (self.sender, self.screen, self.files):
            threading.Thread(target=fn, daemon=True).start()


# ---------------------------------------------------------------------------
# tray icon + settings window
# ---------------------------------------------------------------------------
def make_icon_image():
    from PIL import Image, ImageDraw
    img = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse((2, 2, 62, 62), fill=(198, 155, 109, 255))
    d.ellipse((10, 10, 54, 54), fill=(30, 26, 22, 255))
    d.text((22, 18), "C?", fill=(240, 220, 170, 255))
    return img


class App:
    def __init__(self):
        self.eng = Engine()
        self.root = tk.Tk()
        self.root.withdraw()
        self.root.title(APP)
        self.win = None
        self.icon = None

    def tray(self):
        try:
            import pystray
        except ImportError:
            self.show_settings()
            return
        menu = pystray.Menu(
            pystray.MenuItem("Open Chillan companion", lambda: self.root.after(0, self.show_settings), default=True),
            pystray.MenuItem("Quit", lambda: self.root.after(0, self.quit)),
        )
        self.icon = pystray.Icon("chillan", make_icon_image(), APP, menu)
        self.icon.run_detached()

    def quit(self):
        self.eng.stop.set()
        self.eng.save_state()
        if self.icon:
            self.icon.stop()
        self.root.destroy()

    def show_settings(self):
        if self.win and self.win.winfo_exists():
            self.win.deiconify()
            self.win.lift()
            return
        cfg = self.eng.cfg
        w = tk.Toplevel(self.root)
        self.win = w
        w.title(APP + " " + VERSION)
        w.resizable(False, False)
        pad = {"padx": 10, "pady": 4}
        ttk.Label(w, text="Discord webhook for the hidden raw channel").grid(row=0, column=0, columnspan=3, sticky="w", **pad)
        hook = tk.StringVar(value=cfg.get("webhook", ""))
        ttk.Entry(w, textvariable=hook, width=70, show="•").grid(row=1, column=0, columnspan=3, sticky="we", **pad)
        ttk.Label(w, text="Chillan's saved data file (WTF\\Account\\…\\SavedVariables\\Chillan.lua)").grid(row=2, column=0, columnspan=3, sticky="w", **pad)
        sv = tk.StringVar(value=cfg.get("saved_file", ""))
        ttk.Entry(w, textvariable=sv, width=58).grid(row=3, column=0, columnspan=2, sticky="we", **pad)

        def browse():
            p = filedialog.askopenfilename(title="Find Chillan.lua", filetypes=[("Chillan saved data", "Chillan.lua"), ("Lua", "*.lua")])
            if p:
                sv.set(p)

        def autofind():
            files = find_saved_files()
            if files:
                sv.set(files[0])
                if len(files) > 1:
                    messagebox.showinfo(APP, "Found several, using the first:\n\n" + "\n".join(files))
            else:
                messagebox.showwarning(APP, "Couldn't find Chillan.lua. Use Browse… and pick it in your WoW folder under WTF\\Account\\<account>\\SavedVariables.")

        bf = ttk.Frame(w)
        bf.grid(row=3, column=2, sticky="e", **pad)
        ttk.Button(bf, text="Browse…", command=browse).pack(side="left")
        ttk.Button(bf, text="Find", command=autofind).pack(side="left", padx=(4, 0))
        live = tk.BooleanVar(value=cfg.get("live", True))
        ttk.Checkbutton(w, text="Read events live from the WoW window (needs /chill discord on in game)", variable=live).grid(row=4, column=0, columnspan=3, sticky="w", **pad)
        auto = tk.BooleanVar(value=cfg.get("autostart", False))
        ttk.Checkbutton(w, text="Start with Windows", variable=auto).grid(row=5, column=0, columnspan=3, sticky="w", **pad)
        status = tk.StringVar()
        ttk.Label(w, textvariable=status, justify="left", foreground="#555").grid(row=6, column=0, columnspan=3, sticky="w", **pad)

        def refresh():
            if not w.winfo_exists():
                return
            s = self.eng.stats
            status.set("WoW window: %s    Saved file: %s\nStrips read: %d    Sent to Discord: %d    Failed: %d\nLast event: %s" % (
                "found" if s["wow"] else "not found", s["file"], s["strips"], s["sent"], s["failed"], s["last"]))
            w.after(1000, refresh)

        def save():
            cfg["webhook"] = hook.get().strip()
            cfg["saved_file"] = sv.get().strip()
            cfg["live"] = bool(live.get())
            if bool(auto.get()) != bool(cfg.get("autostart")):
                try:
                    set_autostart(bool(auto.get()))
                    cfg["autostart"] = bool(auto.get())
                except Exception as ex:
                    messagebox.showerror(APP, "Couldn't change autostart: %r" % ex)
            self.eng.save_cfg()
            self.eng.file_mtime = 0
            messagebox.showinfo(APP, "Saved.")

        def test():
            save_hook = hook.get().strip()
            if not save_hook:
                messagebox.showwarning(APP, "Paste the webhook first.")
                return
            e = {"v": 1, "k": "TEST", "id": "C%d" % int(time.time()), "t": int(time.time()), "n": "Companion",
                 "tx": "Test from the Chillan companion on this PC."}
            ok = post(save_hook, json.dumps(e, ensure_ascii=False))
            messagebox.showinfo(APP, "Sent! Check #chillan-feed." if ok else "Discord said no. Check the webhook link.")

        def debug_pic():
            img = self.eng.last_frame
            if img is None:
                messagebox.showwarning(APP, "Haven't seen the WoW window yet. Start WoW (not minimised) and try again.")
                return
            from PIL import Image
            d = os.path.join(HOME, "debug")
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, time.strftime("strip-%Y%m%d-%H%M%S.png"))
            Image.fromarray(np.ascontiguousarray(img[:, :, ::-1])).save(path)
            found = find_strips(img)
            messagebox.showinfo(APP, "Saved %s\n\nStrips readable in it: %d\n\nSend this picture to Claude." % (path, len(found)))
            if IS_WIN:
                os.startfile(d)

        bb = ttk.Frame(w)
        bb.grid(row=7, column=0, columnspan=3, sticky="e", **pad)
        ttk.Button(bb, text="Save debug picture", command=debug_pic).pack(side="left", padx=(0, 6))
        ttk.Button(bb, text="Send test to Discord", command=test).pack(side="left")
        ttk.Button(bb, text="Save", command=save).pack(side="left", padx=6)
        ttk.Button(bb, text="Hide", command=w.withdraw).pack(side="left")
        w.protocol("WM_DELETE_WINDOW", w.withdraw)
        refresh()

    def run(self):
        self.eng.start()
        self.tray()
        if not self.eng.cfg.get("webhook"):
            self.show_settings()
        self.root.mainloop()


if __name__ == "__main__":
    log("start %s" % VERSION)
    App().run()
