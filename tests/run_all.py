"""Runs the syntax check and every sim; fails (exit 1) if any reports a Lua error.
Used by the release workflow: a failing test stops the release.
  python3 tests/run_all.py            all sims
  python3 tests/run_all.py sim_qol2   only the ones named"""
import os, re, subprocess, sys, glob

HERE = os.path.dirname(os.path.abspath(__file__))
# sims that only build on others, or poke at old versions on purpose
SKIP = {"sim.py", "run_all.py", "syntax.py"}
# a Lua error caught by ns:On / ns:Fire prints "Chillan error <event> <message>"; a bare number is the
# sim's own Python listener, not the addon
BAD = re.compile(r"(FEIL\d?|ERRORS)[^:\n]*:\s*\[(?!\s*\])|Traceback \(most recent call last\)|ERRORS \w+ \[|Chillan error\|r\t\S+\t(?!\d+\s*$)", re.M)

def run(name):
    p = subprocess.run([sys.executable, name], cwd=HERE, capture_output=True, text=True, timeout=600)
    out = (p.stdout or "") + (p.stderr or "")
    bad = p.returncode != 0 or BAD.search(out)
    return (not bad), out

def main():
    ok, out = run("syntax.py")
    print(out.strip().splitlines()[-1] if out.strip() else "syntax: no output")
    if not ok or "feil: 0" not in out:
        print("SYNTAX FAILED"); print(out[-3000:]); return 1
    names = sys.argv[1:] or sorted(os.path.basename(f) for f in glob.glob(os.path.join(HERE, "sim_*.py")))
    failed = []
    for n in names:
        n = n if n.endswith(".py") else n + ".py"
        if n in SKIP: continue
        good, out = run(n)
        print(("ok   " if good else "FAIL ") + n)
        if not good:
            failed.append(n)
            print("\n".join(out.strip().splitlines()[-25:]))
    print(f"\n{len(names) - len(failed)} passed, {len(failed)} failed")
    return 1 if failed else 0

if __name__ == "__main__":
    sys.exit(main())
