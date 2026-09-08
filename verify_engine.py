#!/usr/bin/env python3
"""
Port of the EA's order-block engine, run against the real probe capture.

The indicator writes its own "consumed %" into a TXT object for each block.
That is ground truth I did not produce, so reproducing it from the NU/U
rectangle geometry proves the pairing and the consumed maths are right.
"""
import re, sys

PROBE = "/var/lib/freelancer/projects/40181036/OB_Probe_XAUUSD.r_60.txt"

BULL = 65280      # clrLime
BEAR = 1993170    # clrChocolate
FRESH_SUFFIX = " NU"
USED_SUFFIX  = " U"

def ends_with(s, suf):
    return len(suf) > 0 and len(s) >= len(suf) and s[len(s)-len(suf):] == suf

# ---------- parse the probe ----------
rows, bid = [], None
for line in open(PROBE, encoding="utf-8", errors="replace"):
    if line.startswith("Bid       :"):
        bid = float(line.split(":")[1])
    p = [c.strip() for c in line.split("|")]
    if len(p) >= 12 and p[0].isdigit():
        rows.append(dict(name=p[1], typ=p[2],
                         p1=float(p[3]), p2=float(p[4]),
                         color=int(p[7]), text=p[11]))

rect = [r for r in rows if r["typ"].startswith("OBJ_RECTANGLE")]
print(f"Bid {bid}   objects {len(rows)}   rectangles {len(rect)}\n")

# ---------- collect_zones(), pass 1 ----------
Z = []
for r in rect:
    if not ends_with(r["name"], FRESH_SUFFIX):
        continue
    cls = 1 if r["color"] == BULL else (-1 if r["color"] == BEAR else 0)
    if cls == 0:
        continue
    Z.append(dict(key=r["name"][:len(r["name"])-len(FRESH_SUFFIX)],
                  nuhi=max(r["p1"], r["p2"]), nulo=min(r["p1"], r["p2"]),
                  hi=max(r["p1"], r["p2"]),  lo=min(r["p1"], r["p2"]),
                  bull=(cls == 1)))

# ---------- collect_zones(), pass 2 ----------
for r in rect:
    if ends_with(r["name"], FRESH_SUFFIX) or not ends_with(r["name"], USED_SUFFIX):
        continue
    key = r["name"][:len(r["name"])-len(USED_SUFFIX)]
    for z in Z:
        if z["key"] == key:
            z["hi"] = max(z["hi"], r["p1"], r["p2"])
            z["lo"] = min(z["lo"], r["p1"], r["p2"])

def consumed(z):
    full = z["hi"] - z["lo"]
    if full <= 0:
        return 1.0
    fresh = z["nuhi"] - z["nulo"]
    return 1.0 if fresh <= 0 else 1.0 - fresh / full

# ---------- ground truth: the indicator's own TXT labels ----------
truth = {}
for r in rows:
    m = re.match(r"^(.*) TXT$", r["name"])
    if m and r["text"].endswith("%"):
        truth[m.group(1)] = float(r["text"].rstrip(" %"))

print(f"{'block':22} {'dir':5} {'full block':>20} {'mine':>8} {'indicator':>10}  check")
print("-" * 82)
fails = checked = 0
for z in sorted(Z, key=lambda z: z["lo"]):
    mine = consumed(z) * 100.0
    base = re.sub(r" L\d+$", "", z["key"])          # "31 Structure OB L2" -> "31 Structure OB"
    exp  = truth.get(base)
    if exp is None:
        mark = "no label (fully eaten)" if mine >= 99.99 else "NO LABEL"
        if mine < 99.99:
            fails += 1
    else:
        checked += 1
        ok = abs(mine - exp) < 0.05
        mark = "OK" if ok else "*** MISMATCH ***"
        if not ok:
            fails += 1
    print(f"{z['key']:22} {'bull' if z['bull'] else 'bear':5} "
          f"{z['lo']:9.2f}-{z['hi']:9.2f} {mine:7.2f}% "
          f"{('%9.2f%%' % exp) if exp is not None else '        -'}  {mark}")

print("-" * 82)
print(f"{len(Z)} blocks, {checked} cross-checked against the indicator's labels, {fails} problems\n")

# ---------- side check: does colour agree with position vs price ----------
print("colour vs position relative to Bid:")
bad = 0
for z in Z:
    if consumed(z) >= 1.0:
        continue
    above, below = z["lo"] > bid, z["hi"] < bid
    if above and z["bull"]:
        print(f"  {z['key']}: bullish block ABOVE price"); bad += 1
    if below and not z["bull"]:
        print(f"  {z['key']}: bearish block BELOW price"); bad += 1
print(f"  {'no contradictions' if bad == 0 else str(bad) + ' contradictions'}\n")

sys.exit(1 if fails else 0)
