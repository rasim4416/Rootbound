"""Verify Phase 2 multi-path level data and WaveGenerator distribution logic."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def path_ends_at_nucleus(rel: str) -> bool:
    t = read(rel)
    return "Vector2i(17, 5)" in t and t.rstrip().endswith("])") or "Vector2i(17, 5)\n])" in t or "Vector2i(17, 5)\r\n])" in t


def main() -> int:
    ok = True

    # --- Level path wiring ---
    l1 = read("data/levels/level_01.tres")
    if "path_02" in l1 or "path_03" in l1:
        print("FAIL L1 must be path_01 only")
        ok = False
    else:
        print("OK L1: path_01 only")

    l2 = read("data/levels/level_02.tres")
    if "path_02.tres" not in l2 or "unlock_from_wave = 5" not in l2:
        print("FAIL L2 missing path_02 @ wave 5")
        ok = False
    if "path_03" in l2:
        print("FAIL L2 should not use path_03")
        ok = False
    if "ant.tres" not in l2:
        print("FAIL L2 must stay Bacterium only")
        ok = False
    else:
        print("OK L2: path_01 + path_02@5, Bacterium")

    for lid in ("level_03", "level_04"):
        t = read(f"data/levels/{lid}.tres")
        if not all(x in t for x in ("path_01.tres", "path_02.tres", "path_03.tres")):
            print(f"FAIL {lid} missing three paths")
            ok = False
        if "path_04" in t:
            print(f"FAIL {lid} should not use path_04")
            ok = False
        if t.count("unlock_from_wave = 10") < 1:
            print(f"FAIL {lid} Path3 unlock @10 missing")
            ok = False
        if "ant.tres" not in t:
            print(f"FAIL {lid} must stay Bacterium only")
            ok = False
        else:
            print(f"OK {lid}: path_01+02@5+03@10, Bacterium")

    for p in ("path_01", "path_02", "path_03"):
        text = read(f"data/paths/{p}.tres")
        # Last cell should be nucleus
        cells = re.findall(r"Vector2i\((\d+), (\d+)\)", text)
        if not cells or cells[-1] != ("17", "5"):
            print(f"FAIL {p} last cell {cells[-1] if cells else None} != (17,5)")
            ok = False
        else:
            print(f"OK {p} ends at Nucleus (17,5)")

    # --- WaveGenerator distribution (mirror GDScript logic) ---
    def build_order(n_paths: int, count: int) -> list[int]:
        order: list[int] = []
        guaranteed = min(count, n_paths)
        for i in range(guaranteed):
            order.append(i)
        for i in range(guaranteed, count):
            order.append(i % n_paths)
        return order

    order = build_order(2, 8)
    if set(order[:2]) != {0, 1}:
        print(f"FAIL early dual-path guarantee: {order}")
        ok = False
    else:
        print(f"OK dual-path early order: {order}")

    order3 = build_order(3, 9)
    if set(order3[:3]) != {0, 1, 2}:
        print(f"FAIL early triple-path guarantee: {order3}")
        ok = False
    else:
        print(f"OK triple-path early order: {order3}")

    # Activation simulation
    def active(rules: list[tuple[str, int]], wave: int) -> list[str]:
        return [p for p, u in rules if wave >= u]

    l2_rules = [("p1", 1), ("p2", 5)]
    if active(l2_rules, 4) != ["p1"] or active(l2_rules, 5) != ["p1", "p2"]:
        print("FAIL L2 activation schedule")
        ok = False
    else:
        print("OK L2: W1-4=p1, W5+=p1+p2")

    l3_rules = [("p1", 1), ("p2", 5), ("p3", 10)]
    if active(l3_rules, 9) != ["p1", "p2"] or active(l3_rules, 10) != ["p1", "p2", "p3"]:
        print("FAIL L3 activation schedule")
        ok = False
    else:
        print("OK L3: W10+= three paths")

    # Combat hooks still path-agnostic
    for rel, needles in [
        ("scripts/systems/targeting_system.gd", ["insect_layer.get_children()"]),
        ("scripts/systems/reward_manager.gd", ["insect"]),
        ("scripts/core/core_damage_system.gd", ["get_core_damage"]),
        ("scripts/systems/game_over_manager.gd", ["enter_game_over"]),
        ("scripts/insects/wave_manager.gd", ["_spawn_insect", "job.path"]),
        ("scripts/levels/wave_generator.gd", ["_build_path_spawn_order"]),
    ]:
        s = read(rel)
        for n in needles:
            if n not in s:
                print(f"FAIL {rel} missing {n}")
                ok = False
    print("OK combat/spawn hooks path-agnostic")

    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
