import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ok = True
for i in range(1, 5):
    t = (root / f"data/levels/level_0{i}.tres").read_text(encoding="utf-8")
    if any(x in t for x in ["path_02", "path_03", "path_04"]):
        print(f"FAIL L{i} extra paths")
        ok = False
    n = len(re.findall(r'id="Rule_', t))
    # id="Rule_p1" once in sub_resource; SubResource("Rule_p1") also matches — count sub_resource lines
    n = len(re.findall(r"^\[sub_resource .* id=\"Rule_", t, re.M))
    if n != 1:
        print(f"FAIL L{i} path rule sub_resources={n}")
        ok = False
    else:
        print(f"OK L{i}: path_01 only, single rule")

print("PASS" if ok else "FAIL")
raise SystemExit(0 if ok else 1)
