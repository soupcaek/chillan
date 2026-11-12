"""Chillan companion: relays Chillan? events from WoW to Discord.

How it gets the events (WoW addons can't reach the internet):
  * file (everyone): Chillan's saved data, which the game writes at /reload, logout and exit
  * live (only where switched on): the thin code line Chillan draws in the top-left corner of the
    WoW window, read with Windows' window capture so it also works when WoW is behind other windows

Zero setup: the relay link (a Discord webhook) comes from Chillan's own saved data, shared in game
by the gang. Started from the Chillan addon folder it installs itself to %LOCALAPPDATA%, starts with
Windows, and updates itself when WoWUp brings a newer copy.
"""
import ctypes
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
import tkinter as tk
from collections import deque
from tkinter import filedialog, messagebox, ttk

import numpy as np

from decoder import find_strips
from relay import post
from savedvars import find_saved_files, game_root_from, read_discord

APP = "Chillan companion"
VERSION = "2.0.0"
HOME = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "ChillanCompanion")
INSTALL_DIR = os.path.join(os.environ.get("LOCALAPPDATA", HOME), "ChillanCompanion")
INSTALLED_EXE = os.path.join(INSTALL_DIR, "ChillanCompanion.exe")
CFG_PATH = os.path.join(HOME, "config.json")
STATE_PATH = os.path.join(HOME, "state.json")
LOG_PATH = os.path.join(HOME, "log.txt")
SCAN_ROWS = 8           # the code line lives in the top few rows of the WoW window
SCAN_EVERY = 0.12       # seconds between reads
FILE_EVERY = 3.0        # seconds between saved-file checks
UPDATE_EVERY = 600      # seconds between checks for a newer copy in the addon folder
STATUS_MIN_GAP = 30     # seconds between two status relays

os.makedirs(HOME, exist_ok=True)
FROZEN = getattr(sys, "frozen", False)
IS_WIN = sys.platform == "win32"


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


def version_tuple(v):
    try:
        return tuple(int(x) for x in str(v).strip().split("."))
    except ValueError:
        return (0,)


# ---------------------------------------------------------------------------
# Windows helpers
# ---------------------------------------------------------------------------
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


def wow_window():
    """(hwnd, title, (left, top, width, height) of the client area or None if minimised), or None."""
    if not IS_WIN:
        return None
    found = []
    EnumProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    def cb(hwnd, _):
        if not user32.IsWindowVisible(hwnd):
            return True
        n = user32.GetWindowTextLengthW(hwnd)
        if n:
            buf = ctypes.create_unicode_buffer(n + 1)
            user32.GetWindowTextW(hwnd, buf, n + 1)
            if buf.value.strip().startswith("World of Warcraft"):
                found.append((hwnd, buf.value))
        return True

    user32.EnumWindows(EnumProc(cb), 0)
    if not found:
        return None
    fg = user32.GetForegroundWindow()
    hwnd, title = next(((h, t) for h, t in found if h == fg), found[0])
    if user32.IsIconic(hwnd):
        return hwnd, title, None
    r = wintypes.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = wintypes.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    w, h = r.right - r.left, r.bottom - r.top
    if w < 200 or h < 100:
        return hwnd, title, None
    return hwnd, title, (pt.x, pt.y, w, h)


def wow_is_foreground(hwnd):
    return IS_WIN and user32.GetForegroundWindow() == hwnd


def set_autostart(on):
    if not IS_WIN:
        return
    import winreg
    key = winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Microsoft\Windows\CurrentVersion\Run", 0,
                         winreg.KEY_SET_VALUE)
    try:
        if on:
            if FROZEN:
                exe = INSTALLED_EXE if os.path.isfile(INSTALLED_EXE) else sys.executable
                cmd = '"%s" --tray' % exe
            else:
                cmd = '"%s" "%s" --tray' % (sys.executable, os.path.abspath(__file__))
            winreg.SetValueEx(key, "ChillanCompanion", 0, winreg.REG_SZ, cmd)
        else:
            try:
                winreg.DeleteValue(key, "ChillanCompanion")
            except FileNotFoundError:
                pass
    finally:
        winreg.CloseKey(key)


def single_instance():
    """True if no other companion is running (a named mutex on Windows)."""
    if not IS_WIN:
        return True
    ctypes.windll.kernel32.CreateMutexW(None, False, "ChillanCompanionSingleInstance")
    return ctypes.windll.kernel32.GetLastError() != 183  # ERROR_ALREADY_EXISTS


# ---------------------------------------------------------------------------
# install from the addon folder, self-update
# ---------------------------------------------------------------------------
def read_version_file(folder):
    try:
        with open(os.path.join(folder, "version.txt"), "r", encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return None


def install_from(src_exe):
    """Copy src_exe to INSTALL_DIR (waiting for an older running copy to let go) and start it."""
    os.makedirs(INSTALL_DIR, exist_ok=True)
    for _ in range(40):
        try:
            shutil.copy2(src_exe, INSTALLED_EXE)
            with open(os.path.join(INSTALL_DIR, "version.txt"), "w", encoding="utf-8") as f:
                f.write(VERSION)
            break
        except OSError:
            time.sleep(0.5)
    else:
        log("install: could not copy to %s" % INSTALLED_EXE)
        return False
    cfg = load_json(CFG_PATH, {})
    cfg["source_exe"] = src_exe
    root = game_root_from(src_exe)
    if root:
        cfg["game_root"] = root
    save_json(CFG_PATH, cfg)
    try:
        set_autostart(True)
    except Exception as ex:
        log("autostart failed: %r" % ex)
    subprocess.Popen([INSTALLED_EXE, "--installed"], close_fds=True)
    return True


def maybe_install():
    """Started from the addon folder: install or update, hand over, and return True (= exit now)."""
    if not (IS_WIN and FROZEN):
        return False
    me = os.path.abspath(sys.executable)
    if os.path.normcase(me) == os.path.normcase(INSTALLED_EXE):
        return False
    if not game_root_from(me):
        return False  # a loose download: just run from where it is
    installed_v = read_version_file(INSTALL_DIR)
    if installed_v and version_tuple(installed_v) >= version_tuple(VERSION) and os.path.isfile(INSTALLED_EXE):
        cfg = load_json(CFG_PATH, {})
        cfg["source_exe"] = me
        cfg["game_root"] = game_root_from(me)
        save_json(CFG_PATH, cfg)
        subprocess.Popen([INSTALLED_EXE], close_fds=True)  # already installed: just open it
        return True
    log("installing %s from %s" % (VERSION, me))
    return install_from(me)


# ---------------------------------------------------------------------------
# reading the WoW window
# ---------------------------------------------------------------------------
class WindowReader:
    """Top rows of the WoW window. Windows Graphics Capture (works behind other windows) with a
    screen-grab fallback (needs WoW in front)."""

    def __init__(self):
        self.lock = threading.Lock()
        self.frame = None
        self.frame_at = 0
        self.wgc_ok = None
        self.wgc_title = None
        self.control = None
        self.sct = None

    def _start_wgc(self, title):
        try:
            from windows_capture import WindowsCapture
        except Exception as ex:
            log("window capture unavailable: %r" % ex)
            self.wgc_ok = False
            return
        kwargs = dict(cursor_capture=False, draw_border=False, window_name=title)
        try:
            cap = WindowsCapture(minimum_update_interval=100, **kwargs)
        except TypeError:
            cap = WindowsCapture(**kwargs)
        reader = self

        @cap.event
        def on_frame_arrived(frame, control):
            try:
                buf = getattr(frame, "frame_buffer", None)
                if buf is None and hasattr(frame, "to_numpy"):
                    buf = frame.to_numpy()
                if buf is None:
                    return
                top = np.array(buf[:SCAN_ROWS, :, :3][:, :, ::-1])  # BGRA -> RGB, copy only the top rows
                with reader.lock:
                    reader.frame, reader.frame_at = top, time.time()
            except Exception as ex:
                log("frame error: %r" % ex)

        @cap.event
        def on_closed():
            reader.wgc_title = None

        try:
            if hasattr(cap, "start_free_threaded"):
                self.control = cap.start_free_threaded()
            else:
                threading.Thread(target=cap.start, daemon=True).start()
            self.wgc_title = title
            self.wgc_ok = True
            log("window capture started")
        except Exception as ex:
            log("window capture failed: %r" % ex)
            self.wgc_ok = False

    def read(self, win):
        """win = wow_window(). Returns an (H, W, 3) RGB array of the top rows, or None."""
        hwnd, title, rect = win
        if self.wgc_ok is not False and self.wgc_title != title:
            self._start_wgc(title)
        if self.wgc_ok:
            with self.lock:
                if self.frame is not None and time.time() - self.frame_at < 2.0:
                    return self.frame
        # no fresh window frames (minimised, or capture stalled): use the screen if WoW is in front
        if rect and wow_is_foreground(hwnd):
            try:
                import mss
                self.sct = self.sct or mss.mss()
                x, y, w, h = rect
                shot = self.sct.grab({"left": x, "top": y, "width": w, "height": min(SCAN_ROWS, h)})
                return np.frombuffer(shot.bgra, np.uint8).reshape(shot.height, shot.width, 4)[:, :, 2::-1]
            except Exception:
                return None
        return None


# ---------------------------------------------------------------------------
# the relay engine
# ---------------------------------------------------------------------------
class Engine:
    def __init__(self):
        self.cfg = load_json(CFG_PATH, {})
        self.cfg.setdefault("webhook", "")
        self.cfg.setdefault("live", False)       # live reading only where switched on (the owner's PC)
        self.cfg.setdefault("autostart", True)
        st = load_json(STATE_PATH, {})
        self.sent = deque(st.get("sent", []), maxlen=5000)
        self.sent_set = set(self.sent)
        self.q = queue.Queue()
        self.stop = threading.Event()
        self.last_status = None
        self.last_status_at = 0
        self.mtimes = {}
        self.file_link = None
        self.reader = WindowReader()
        self.last_frame = None
        self.stats = {"strips": 0, "sent": 0, "failed": 0, "last": "nothing yet", "wow": "not running", "files": 0}
        self.lock = threading.Lock()

    def webhook(self):
        return (self.cfg.get("webhook") or self.file_link or "").strip()

    def saved_files(self):
        roots = [self.cfg["game_root"]] if self.cfg.get("game_root") else []
        files = find_saved_files(roots) if roots else []
        manual = self.cfg.get("saved_file")
        if manual and os.path.isfile(manual):
            files.append(manual)
        if not files:
            files = find_saved_files()
        return sorted(set(files))

    def save_cfg(self):
        save_json(CFG_PATH, self.cfg)

    def save_state(self):
        with self.lock:
            save_json(STATE_PATH, {"sent": list(self.sent)})

    def offer(self, payload_json, source):
        """Queue an event (JSON text) unless it has already been relayed from this PC."""
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
            url = self.webhook()
            if not url:
                time.sleep(5)
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

    def live(self):
        while not self.stop.is_set():
            time.sleep(SCAN_EVERY)
            if not self.cfg.get("live"):
                continue
            win = wow_window()
            if not win:
                self.stats["wow"] = "not running"
                time.sleep(1)
                continue
            img = self.reader.read(win)
            self.stats["wow"] = "minimised" if win[2] is None else ("reading" if img is not None else "found")
            if img is None:
                continue
            self.last_frame = img
            for data in find_strips(img):
                self.stats["strips"] += 1
                try:
                    self.offer(data.decode("utf-8"), "live")
                except UnicodeDecodeError:
                    pass

    def files(self):
        while not self.stop.is_set():
            files = self.saved_files()
            self.stats["files"] = len(files)
            for path in files:
                try:
                    mt = os.path.getmtime(path)
                except OSError:
                    continue
                first = path not in self.mtimes
                if self.mtimes.get(path) == mt:
                    continue
                self.mtimes[path] = mt
                time.sleep(1.0)  # let the game finish writing
                try:
                    d = read_discord(path)
                except Exception as ex:
                    log("could not read %s: %r" % (path, ex))
                    continue
                if d.get("link"):
                    self.file_link = d["link"]
                for j in d["out"]:
                    self.offer(j, "file")
                if d["status"] and not first:
                    self.offer(d["status"], "file")
            time.sleep(FILE_EVERY)

    def updater(self):
        """Pick up a newer copy that WoWUp put in the addon folder."""
        while not self.stop.is_set():
            time.sleep(UPDATE_EVERY)
            src = self.cfg.get("source_exe")
            if not (FROZEN and src and os.path.isfile(src)):
                continue
            v = read_version_file(os.path.dirname(src))
            if v and version_tuple(v) > version_tuple(VERSION):
                log("update %s -> %s" % (VERSION, v))
                self.save_state()
                subprocess.Popen([src, "--update"], close_fds=True)
                os._exit(0)

    def start(self):
        for fn in (self.sender, self.live, self.files, self.updater):
            threading.Thread(target=fn, daemon=True).start()


# ---------------------------------------------------------------------------
# tray icon + window
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
        info = tk.StringVar()
        ttk.Label(w, textvariable=info, justify="left").grid(row=0, column=0, columnspan=3, sticky="w", **pad)
        live = tk.BooleanVar(value=bool(cfg.get("live")))
        ttk.Checkbutton(w, text="Also read events live from the WoW window on this PC (needs /chill discord on in game)",
                        variable=live).grid(row=1, column=0, columnspan=3, sticky="w", **pad)
        auto = tk.BooleanVar(value=bool(cfg.get("autostart", True)))
        ttk.Checkbutton(w, text="Start with Windows", variable=auto).grid(row=2, column=0, columnspan=3, sticky="w", **pad)

        adv = ttk.LabelFrame(w, text="Advanced (normally not needed)")
        adv.grid(row=3, column=0, columnspan=3, sticky="we", **pad)
        ttk.Label(adv, text="Relay link override (leave empty to use the gang's link from Chillan)").grid(row=0, column=0, columnspan=3, sticky="w", **pad)
        hook = tk.StringVar(value=cfg.get("webhook", ""))
        ttk.Entry(adv, textvariable=hook, width=70, show="•").grid(row=1, column=0, columnspan=3, sticky="we", **pad)
        ttk.Label(adv, text="Extra Chillan.lua (only if it isn't found automatically)").grid(row=2, column=0, columnspan=3, sticky="w", **pad)
        sv = tk.StringVar(value=cfg.get("saved_file", ""))
        ttk.Entry(adv, textvariable=sv, width=58).grid(row=3, column=0, columnspan=2, sticky="we", **pad)

        def browse():
            p = filedialog.askopenfilename(title="Find Chillan.lua", filetypes=[("Chillan saved data", "Chillan.lua"), ("Lua", "*.lua")])
            if p:
                sv.set(p)

        ttk.Button(adv, text="Browse…", command=browse).grid(row=3, column=2, sticky="e", **pad)

        def refresh():
            if not w.winfo_exists():
                return
            s = self.eng.stats
            if cfg.get("webhook"):
                link = "from your own settings"
            elif self.eng.file_link:
                link = "from Chillan (ok)"
            else:
                link = "waiting: log in to WoW once after the gang has set it up"
            info.set("Relay link: %s\nChillan data files found: %d\nWoW: %s    Live lines read: %d\nSent to Discord: %d    Failed: %d\nLast event: %s" % (
                link, s["files"], s["wow"], s["strips"], s["sent"], s["failed"], s["last"]))
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
            self.eng.mtimes = {}
            messagebox.showinfo(APP, "Saved.")

        def test():
            url = self.eng.webhook()
            if not url:
                messagebox.showwarning(APP, "No relay link yet. Log in to WoW once (Chillan gets it from the gang), then try again.")
                return
            e = {"v": 1, "k": "TEST", "id": "C%d" % int(time.time()), "t": int(time.time()), "n": "Companion",
                 "tx": "Test from the Chillan companion on this PC."}
            ok = post(url, json.dumps(e, ensure_ascii=False))
            messagebox.showinfo(APP, "Sent! Check the Discord feed." if ok else "Discord said no. The relay link may be outdated.")

        def debug_pic():
            img = self.eng.last_frame
            if img is None:
                messagebox.showwarning(APP, "No picture of the WoW window yet. Turn on live reading and keep WoW running.")
                return
            from PIL import Image
            d = os.path.join(HOME, "debug")
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, time.strftime("strip-%Y%m%d-%H%M%S.png"))
            Image.fromarray(np.ascontiguousarray(img)).resize((img.shape[1], img.shape[0] * 8), Image.NEAREST).save(path)
            messagebox.showinfo(APP, "Saved %s\n\nLines readable in it: %d" % (path, len(find_strips(img))))
            if IS_WIN:
                os.startfile(d)

        bb = ttk.Frame(w)
        bb.grid(row=4, column=0, columnspan=3, sticky="e", **pad)
        ttk.Button(bb, text="Save debug picture", command=debug_pic).pack(side="left", padx=(0, 6))
        ttk.Button(bb, text="Send test to Discord", command=test).pack(side="left")
        ttk.Button(bb, text="Save", command=save).pack(side="left", padx=6)
        ttk.Button(bb, text="Hide", command=w.withdraw).pack(side="left")
        w.protocol("WM_DELETE_WINDOW", w.withdraw)
        refresh()

    def first_run_note(self):
        if self.eng.cfg.get("welcomed"):
            return
        self.eng.cfg["welcomed"] = True
        self.eng.save_cfg()
        messagebox.showinfo(APP, "The Chillan companion is now running.\n\nIt sits in the system tray (the ^ next to the clock), "
                                 "starts with Windows and updates itself with Chillan. There's nothing else to set up: "
                                 "it posts the gang's Chillan events to Discord when you reload or log out of WoW.")

    def run(self):
        self.eng.start()
        self.tray()
        if self.eng.cfg.get("autostart", True) and FROZEN:
            try:
                set_autostart(True)
            except Exception:
                pass
        if "--installed" in sys.argv:
            self.root.after(500, self.first_run_note)
        elif "--tray" not in sys.argv:
            self.show_settings()
        self.root.mainloop()


if __name__ == "__main__":
    log("start %s %s" % (VERSION, " ".join(sys.argv[1:])))
    if "--update" in sys.argv:
        time.sleep(2)  # let the old copy exit
        install_from(os.path.abspath(sys.executable))
        sys.exit(0)
    if maybe_install():
        sys.exit(0)
    if not single_instance():
        root = tk.Tk()
        root.withdraw()
        messagebox.showinfo(APP, "The Chillan companion is already running.\n\nLook for the round C? icon in the system tray (the ^ arrow next to the clock) and double-click it.")
        sys.exit(0)
    App().run()
