#!/usr/bin/env python3
"""
Positive control for ob_signal(): walk a price path across the real blocks
from the probe capture and check the EA fires the trades it should.

A gate that rejects everything passes every negative test, so this asserts
what MUST fire, not only what must not.
"""
import re, sys

PROBE = "/var/lib/freelancer/projects/40181036/OB_Probe_XAUUSD.r_60.txt"
BULL, BEAR = 65280, 1993170
NEAR, MID, FAR = 0, 1, 2

def ends_with(s, suf): return len(s) >= len(suf) > 0 and s[len(s)-len(suf):] == suf

rows = []
for line in open(PROBE, encoding="utf-8", errors="replace"):
    p = [c.strip() for c in line.split("|")]
    if len(p) >= 12 and p[0].isdigit():
        rows.append(dict(name=p[1], typ=p[2], p1=float(p[3]), p2=float(p[4]), color=int(p[7])))
rect = [r for r in rows if r["typ"].startswith("OBJ_RECTANGLE")]

Z = []
for r in rect:
    if not ends_with(r["name"], " NU"): continue
    cls = 1 if r["color"] == BULL else (-1 if r["color"] == BEAR else 0)
    if cls == 0: continue
    Z.append(dict(key=r["name"][:-3], nuhi=max(r["p1"],r["p2"]), nulo=min(r["p1"],r["p2"]),
                  hi=max(r["p1"],r["p2"]), lo=min(r["p1"],r["p2"]), bull=(cls==1)))
for r in rect:
    if ends_with(r["name"], " NU") or not ends_with(r["name"], " U"): continue
    for z in Z:
        if z["key"] == r["name"][:-2]:
            z["hi"] = max(z["hi"], r["p1"], r["p2"]); z["lo"] = min(z["lo"], r["p1"], r["p2"])

def consumed(z):
    full = z["hi"] - z["lo"]
    if full <= 0: return 1.0
    fresh = z["nuhi"] - z["nulo"]
    return 1.0 if fresh <= 0 else 1.0 - fresh/full

def ob_signal(prevbid, bid, used, edge=MID, require_dir=True, require_fresh=True, wantdir=-1):
    """Mirror of the MQL4 function. Returns (0 buy, 1 sell, -1 none), block key."""
    for z in Z:
        if z["key"] in used: continue
        if require_fresh and consumed(z) >= 1.0: continue
        mid = (z["hi"] + z["lo"]) / 2.0
        lvlup = lvldn = mid
        if edge == NEAR: lvlup, lvldn = z["lo"], z["hi"]
        if edge == FAR:  lvlup, lvldn = z["hi"], z["lo"]
        if prevbid < lvlup <= bid:
            if wantdir >= 0 and wantdir != 1: continue
            if require_dir and z["bull"]: continue
            return 1, z["key"]
        if prevbid > lvldn >= bid:
            if wantdir >= 0 and wantdir != 0: continue
            if require_dir and not z["bull"]: continue
            return 0, z["key"]
    return -1, None

def walk(path, **kw):
    """Feed a price path tick by tick, collect the trades."""
    used, out, prev = set(), [], path[0]
    for bid in path[1:]:
        d, key = ob_signal(prev, bid, used, **kw)
        if d >= 0:
            used.add(key)
            out.append(("SELL" if d == 1 else "BUY", key, bid))
        prev = bid
    return out

def ramp(a, b, step=0.01):
    n = int(abs(b-a)/step); s = step if b > a else -step
    return [round(a + i*s, 2) for i in range(n+1)]

fails = []
def check(label, got, want):
    ok = got == want
    print(f"  {'PASS' if ok else 'FAIL'}  {label}")
    if not ok:
        print(f"        expected {want}\n        got      {got}")
        fails.append(label)

print("Rally 4400 -> 4460 (through bear block 66, full 4433.38-4449.03, mid 4441.205)")
t = walk(ramp(4400.00, 4460.00))
print(f"  trades: {[(d,k,p) for d,k,p in t]}")
check("one SELL, from block 66, at the mid line",
      [(d, k, p) for d, k, p in t], [("SELL", "66 Structure OB L2", 4441.21)])

print("\nSell-off 4400 -> 4360 (through bull blocks 67 mid 4388.72 and 65 mid 4373.375)")
t = walk(ramp(4400.00, 4360.00))
check("two BUYs, blocks 67 then 65, in that order",
      [(d, k) for d, k, p in t],
      [("BUY", "67 Structure OB L2"), ("BUY", "65 Structure OB L2")])

print("\nSame rally, near edge instead of mid (block 66 low = 4433.38)")
t = walk(ramp(4400.00, 4460.00), edge=NEAR)
check("SELL fires earlier, at the near edge",
      [(d, k, p) for d, k, p in t], [("SELL", "66 Structure OB L2", 4433.38)])

print("\nRally repeated over the same block twice")
t = walk(ramp(4400.00, 4460.00) + ramp(4460.00, 4400.00) + ramp(4400.00, 4460.00))
check("block 66 fires once only, never re-used in the same cycle",
      len([1 for d, k, p in t if k == "66 Structure OB L2"]), 1)

print("\nRecovery: basket is SELL, only same-direction signals wanted")
t = walk(ramp(4400.00, 4460.00), wantdir=1)
check("still the SELL from 66", [(d, k) for d, k, p in t], [("SELL", "66 Structure OB L2")])
t = walk(ramp(4400.00, 4360.00), wantdir=1)
check("BUY signals suppressed while the basket is SELL", t, [])

print("\nDirection filter off: position alone decides (his literal rule)")
t = walk(ramp(4400.00, 4460.00), require_dir=False)
check("still a SELL rising into a block above",
      [(d, k) for d, k, p in t][:1], [("SELL", "66 Structure OB L2")])

print("\nFully-eaten blocks must never fire (15, 27 and 58 are 100% consumed)")
t = walk(ramp(4590.00, 4630.00))
check("block 58 (4603.67-4618.05, fully eaten) stays silent",
      [k for d, k, p in t if k == "58 Structure OB L2"], [])

print("\n" + "="*70)
print("ALL PASS" if not fails else f"{len(fails)} FAILED: {fails}")
sys.exit(1 if fails else 0)
