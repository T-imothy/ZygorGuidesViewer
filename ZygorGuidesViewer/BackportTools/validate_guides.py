#!/usr/bin/env python3
"""Compile and validate Zygor guide data for the WoW 1.12 backport.

The validator treats CMaNGOS Classic DB as the canonical content inventory,
checks every registered guide, and emits a Lua step manifest used at runtime.
Only missing quests automatically disable steps; missing NPC/item references
are reported for review because an otherwise-valid Vanilla quest may use an
alternate server-side entry.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable


REGISTER_RE = re.compile(
    r'(?m)^(?!\s*--)\s*ZygorGuidesViewer:RegisterGuide\("(?P<title>(?:\\.|[^"\\])*)",\[\[(?P<body>.*?)\]\]\)',
    re.DOTALL,
)
STEP_RE = re.compile(r"^\s*step(?:\s|$)")
QUEST_DIRECTIVE_RE = re.compile(r"(?:accept|turnin)\s+.*?##(\d+)", re.I)
QUEST_OBJECTIVE_RE = re.compile(r"\|q\s*(\d+)(?:/(\d+))?", re.I)
HASH_ID_RE = re.compile(r"##(\d+)")
GOTO_RE = re.compile(
    r"\bgoto\s+(?:(?P<map>[^,|]+),\s*)?(?P<x>\d+(?:\.\d+)?),\s*(?P<y>\d+(?:\.\d+)?)",
    re.I,
)
ZONE_GOTO_RE = re.compile(r"\bgoto\s+([^,|]+?)(?:\||$)", re.I)
LEVEL_RANGE_RE = re.compile(r"\((\d+)-(\d+)\)")
ONLY_RE = re.compile(r"^only\s+(.+)$", re.I)
GET_NOTE_RE = re.compile(r"\.get\s+(.+?)\|n(?:\||$)", re.I)
USE_ITEM_RE = re.compile(r"\|use\s+(.+?)##\d+", re.I)
FPATH_RE = re.compile(r"\.fpath\s+(.+)$", re.I)
HOME_RE = re.compile(r"(?:^|\.)home\s+(.+)$", re.I)
NEXT_GUIDE_RE = re.compile(r"^\s*next\s+(.+?)\s*$", re.I | re.M)

CLASSES = ("Warrior", "Paladin", "Hunter", "Rogue", "Priest", "Shaman", "Mage", "Warlock", "Druid")
RACES = ("Human", "Dwarf", "Night Elf", "Gnome", "Orc", "Tauren", "Troll", "Undead")

SQL_TABLES = {
    "quest_template": "quests",
    "creature_template": "creatures",
    "item_template": "items",
    "gameobject_template": "gameobjects",
}


@dataclass
class Step:
    number: int
    lines: list[str] = field(default_factory=list)
    quest_ids: set[int] = field(default_factory=set)
    npc_ids: set[int] = field(default_factory=set)
    item_ids: set[int] = field(default_factory=set)
    coordinates: list[tuple[str | None, float, float]] = field(default_factory=list)
    zone_targets: list[str] = field(default_factory=list)
    actions: set[str] = field(default_factory=set)
    only_condition: str | None = None


@dataclass
class Guide:
    title: str
    source: str
    steps: list[Step]
    target_112: bool
    next_guide: str | None = None


def decode_lua_string(value: str) -> str:
    return value.replace(r"\\", "\\").replace(r'\"', '"')


def parse_step(number: int, lines: list[str]) -> Step:
    step = Step(number=number, lines=lines)
    noted_gets: set[str] = set()
    used_items: set[str] = set()
    for line in lines:
        lower = line.lower()
        only = ONLY_RE.match(line)
        if only and step.only_condition is None:
            step.only_condition = only.group(1).strip()
        directive_ids = {int(value) for value in QUEST_DIRECTIVE_RE.findall(line)}
        objective_ids = {int(value) for value, _ in QUEST_OBJECTIVE_RE.findall(line)}
        step.quest_ids.update(directive_ids)
        step.quest_ids.update(objective_ids)

        hash_ids = {int(value) for value in HASH_ID_RE.findall(line)}
        if ".talk " in lower or ".from " in lower:
            step.npc_ids.update(hash_ids)
        if any(token in lower for token in (".get ", ".collect ", ".buy ", "|use ")):
            step.item_ids.update(hash_ids - directive_ids)

        for match in GOTO_RE.finditer(line):
            map_name = match.group("map")
            step.coordinates.append((map_name.strip() if map_name else None,
                                     float(match.group("x")), float(match.group("y"))))
        for match in ZONE_GOTO_RE.finditer(line):
            target = match.group(1).strip()
            if target and not re.fullmatch(r"\d+(?:\.\d+)?", target):
                step.zone_targets.append(target)

        if "accept " in lower:
            step.actions.add("accept")
        if "turnin " in lower:
            step.actions.add("turnin")
        if any(token in lower for token in (".get ", "goal ", "kill ")) and objective_ids:
            step.actions.add("objective")
        if "|use " in lower:
            step.actions.add("use")
        if "goto " in lower:
            step.actions.add("travel")
        if step.zone_targets:
            step.actions.add("zone_travel")
        if re.search(r"(?:^|\s)ding\s+\d+", lower):
            step.actions.add("level")
        if "|c" in lower:
            step.actions.add("complete_on_arrival")
        if FPATH_RE.search(line):
            step.actions.add("flight_path")
        if HOME_RE.search(line):
            step.actions.add("home")
        noted_gets.update(match.strip().lower() for match in GET_NOTE_RE.findall(line))
        used_items.update(match.strip().lower() for match in USE_ITEM_RE.findall(line))
    if "accept" in step.actions and noted_gets.intersection(used_items):
        step.actions.add("item_start_accept")
    return step


def step_applies(
    step: Step,
    race: str,
    class_name: str,
    unavailable_steps: set[int] | None = None,
) -> bool:
    """Mirror the runtime's generated-manifest and `only` applicability rules."""
    if unavailable_steps and step.number in unavailable_steps:
        return False
    condition = step.only_condition
    if not condition:
        return True
    mentioned_classes = {name for name in CLASSES if name in condition}
    mentioned_races = {name for name in RACES if name in condition}
    if mentioned_classes and class_name not in mentioned_classes:
        return False
    if mentioned_races and race not in mentioned_races:
        return False
    return True


def next_applicable_step(
    guide: Guide,
    current: int,
    race: str,
    class_name: str,
    unavailable_steps: set[int] | None = None,
) -> int:
    """Return the next 1-based step the runtime may select for a character."""
    for step in guide.steps[current:]:
        if step_applies(step, race, class_name, unavailable_steps):
            return step.number
    return current


def target_112_guide(title: str) -> bool:
    if " Leveling Guides\\" not in title:
        return False
    if any(part in title for part in ("Blood Elf", "Draenei", "Death Knight", "Outland", "Northrend")):
        return False
    match = LEVEL_RANGE_RE.search(title)
    return bool(match and int(match.group(2)) <= 60)


def parse_guides(paths: Iterable[Path]) -> list[Guide]:
    guides: list[Guide] = []
    for path in paths:
        text = path.read_text(encoding="utf-8", errors="replace")
        for match in REGISTER_RE.finditer(text):
            title = decode_lua_string(match.group("title"))
            steps: list[Step] = []
            current: list[str] | None = None
            for raw_line in match.group("body").splitlines():
                line = raw_line.strip()
                if STEP_RE.match(line):
                    if current is not None:
                        steps.append(parse_step(len(steps) + 1, current))
                    current = []
                elif current is not None and line:
                    current.append(line)
            if current is not None:
                steps.append(parse_step(len(steps) + 1, current))
            next_match = NEXT_GUIDE_RE.search(match.group("body"))
            next_guide = decode_lua_string(next_match.group(1)) if next_match else None
            guides.append(
                Guide(title, path.name, steps, target_112_guide(title), next_guide)
            )
    return guides


def load_classic_ids(sql_path: Path) -> dict[str, set[int]]:
    ids = {label: set() for label in SQL_TABLES.values()}
    active: str | None = None
    insert_re = re.compile(r"^INSERT INTO `([^`]+)`")
    row_re = re.compile(r"^\s*\((\d+),")
    with sql_path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            insert = insert_re.match(line)
            if insert:
                active = SQL_TABLES.get(insert.group(1))
                continue
            if active:
                row = row_re.match(line)
                if row:
                    ids[active].add(int(row.group(1)))
                if line.rstrip().endswith(";"):
                    active = None
    return ids


def simulate_transition(action: str, before: dict[str, bool], after: dict[str, bool]) -> bool:
    if action == "accept":
        return (not before.get("active", False)) and after.get("active", False)
    if action == "turnin":
        return before.get("active", False) and after.get("ledger", False)
    if action == "objective":
        return (not before.get("done", False)) and after.get("done", False)
    if action == "level":
        return (not before.get("level_met", False)) and after.get("level_met", False)
    if action == "use":
        return before.get("item", False) and after.get("consumed", False)
    if action == "complete_on_arrival":
        return (not before.get("arrived", False)) and after.get("arrived", False)
    if action == "zone_travel":
        return (not before.get("zone_arrived", False)) and after.get("zone_arrived", False)
    if action == "item_start_accept":
        return (not before.get("active", False)) and after.get("active", False)
    if action == "flight_path":
        return (not before.get("opened", False)) and after.get("opened", False)
    if action == "home":
        return (not before.get("bound", False)) and after.get("bound", False)
    raise ValueError(action)


def run_transition_tests() -> list[str]:
    failures: list[str] = []
    cases = {
        "accept": ({"active": False}, {"active": True}),
        "turnin": ({"active": True}, {"active": False, "ledger": True}),
        "objective": ({"done": False}, {"done": True}),
        "level": ({"level_met": False}, {"level_met": True}),
        "use": ({"item": True}, {"item": False, "consumed": True}),
        "complete_on_arrival": ({"arrived": False}, {"arrived": True}),
        "zone_travel": ({"zone_arrived": False}, {"zone_arrived": True}),
        "item_start_accept": ({"active": False}, {"active": True}),
        "flight_path": ({"opened": False}, {"opened": True}),
        "home": ({"bound": False}, {"bound": True}),
    }
    for action, (before, after) in cases.items():
        if not simulate_transition(action, before, after):
            failures.append(f"positive transition failed: {action}")
        if simulate_transition(action, before, before):
            failures.append(f"unchanged state resolved: {action}")
    return failures


def lua_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest().upper()


def write_manifest(
    path: Path,
    unavailable: dict[str, dict[int, list[int]]],
    source_name: str,
    source_hash: str,
) -> None:
    lines = [
        "-- Generated by BackportTools/validate_guides.py; do not edit by hand.",
        f'ZygorClassicVanillaManifestSource233 = "{lua_quote(source_name)}"',
        f'ZygorClassicVanillaManifestHash233 = "{source_hash}"',
        "ZygorClassicVanillaUnavailableSteps233 = {",
    ]
    for title in sorted(unavailable):
        lines.append(f'    ["{lua_quote(title)}"] = {{')
        for step, quest_ids in sorted(unavailable[title].items()):
            ids = ",".join(str(value) for value in quest_ids)
            lines.append(f"        [{step}] = \"missing quest {ids}\",")
        lines.append("    },")
    lines.extend(("}", ""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def audit(guides: list[Guide], ids: dict[str, set[int]]) -> dict:
    issues: list[dict] = []
    unavailable: dict[str, dict[int, list[int]]] = defaultdict(dict)
    action_counts: Counter[str] = Counter()
    target_steps = 0

    for guide in guides:
        if not guide.target_112:
            continue
        target_steps += len(guide.steps)
        for step in guide.steps:
            action_counts.update(step.actions)
            missing_quests = sorted(step.quest_ids - ids["quests"])
            available_quests = sorted(step.quest_ids & ids["quests"])
            missing_npcs = sorted(step.npc_ids - ids["creatures"])
            missing_items = sorted(step.item_ids - ids["items"])
            bad_coords = [(x, y) for _, x, y in step.coordinates if not (0 <= x <= 100 and 0 <= y <= 100)]
            excluded_for_quest = bool(missing_quests and not available_quests)
            if excluded_for_quest:
                unavailable[guide.title][step.number] = missing_quests
                issues.append({"severity": "exclude", "guide": guide.title, "step": step.number,
                               "kind": "missing_quest", "ids": missing_quests})
            elif missing_quests:
                issues.append({"severity": "review", "guide": guide.title, "step": step.number,
                               "kind": "mixed_missing_quest", "ids": missing_quests,
                               "available_ids": available_quests})
            if missing_npcs and not excluded_for_quest:
                issues.append({"severity": "review", "guide": guide.title, "step": step.number,
                               "kind": "missing_npc", "ids": missing_npcs})
            if missing_items and not excluded_for_quest:
                issues.append({"severity": "review", "guide": guide.title, "step": step.number,
                               "kind": "missing_item", "ids": missing_items})
            if bad_coords:
                issues.append({"severity": "error", "guide": guide.title, "step": step.number,
                               "kind": "invalid_coordinates", "values": bad_coords})
            if "home" in step.actions and not step.coordinates:
                issues.append({"severity": "review", "guide": guide.title, "step": step.number,
                               "kind": "home_without_waypoint"})
            for zone_target in step.zone_targets:
                fallback = False
                for future in guide.steps[step.number:step.number + 8]:
                    for map_name, _, _ in future.coordinates:
                        if map_name is None or map_name.lower() == zone_target.lower():
                            fallback = True
                            break
                    if fallback:
                        break
                if not fallback:
                    issues.append({"severity": "review", "guide": guide.title, "step": step.number,
                                   "kind": "zone_without_waypoint_fallback", "zone": zone_target})

    transition_failures = run_transition_tests()
    return {
        "summary": {
            "registered_guides": len(guides),
            "target_112_guides": sum(1 for guide in guides if guide.target_112),
            "target_112_steps": target_steps,
            "excluded_steps": sum(len(steps) for steps in unavailable.values()),
            "review_issues": sum(1 for issue in issues if issue["severity"] == "review"),
            "errors": sum(1 for issue in issues if issue["severity"] == "error") + len(transition_failures),
            "transition_tests": 20,
            "transition_failures": len(transition_failures),
            "action_counts": dict(sorted(action_counts.items())),
            "classic_db_counts": {key: len(value) for key, value in ids.items()},
        },
        "unavailable": {title: dict(steps) for title, steps in unavailable.items()},
        "issues": issues,
        "transition_failures": transition_failures,
    }


def write_markdown(path: Path, report: dict) -> None:
    summary = report["summary"]
    lines = [
        "# Zygor 1.12 Backport Validation",
        "",
        f"- Registered guides parsed: {summary['registered_guides']}",
        f"- Vanilla leveling guides in scope: {summary['target_112_guides']}",
        f"- Vanilla leveling steps checked: {summary['target_112_steps']}",
        f"- Steps excluded for missing Vanilla quests: {summary['excluded_steps']}",
        f"- NPC/item references requiring review: {summary['review_issues']}",
        f"- Validation errors: {summary['errors']}",
        f"- Transition simulations: {summary['transition_tests']} ({summary['transition_failures']} failures)",
        "",
        "## Automatically excluded steps",
        "",
    ]
    excluded = [issue for issue in report["issues"] if issue["severity"] == "exclude"]
    if excluded:
        for issue in excluded:
            lines.append(f"- {issue['guide']} — step {issue['step']}: missing quest ID(s) {', '.join(map(str, issue['ids']))}")
    else:
        lines.append("- None")
    lines.extend(("", "## Review queue", ""))
    reviews = [issue for issue in report["issues"] if issue["severity"] == "review"]
    if reviews:
        for issue in reviews:
            if "ids" in issue:
                detail = ", ".join(map(str, issue["ids"]))
            elif "zone" in issue:
                detail = issue["zone"]
            else:
                detail = ""
            lines.append(f"- {issue['guide']} — step {issue['step']}: {issue['kind']} {detail}".rstrip())
    else:
        lines.append("- None")
    lines.append("")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--classic-db", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--json", type=Path, required=True)
    parser.add_argument("--markdown", type=Path, required=True)
    args = parser.parse_args()

    guide_dir = args.addon / "Guides"
    guide_paths = sorted(guide_dir.glob("Zygor*.lua"))
    guides = parse_guides(guide_paths)
    ids = load_classic_ids(args.classic_db)
    report = audit(guides, ids)
    database_hash = file_sha256(args.classic_db)
    report["summary"]["classic_db_file"] = args.classic_db.name
    report["summary"]["classic_db_sha256"] = database_hash

    write_manifest(args.manifest, report["unavailable"], args.classic_db.name, database_hash)
    args.json.parent.mkdir(parents=True, exist_ok=True)
    args.json.write_text(json.dumps(report, indent=2, sort_keys=True), encoding="utf-8", newline="\n")
    write_markdown(args.markdown, report)

    print(json.dumps(report["summary"], indent=2, sort_keys=True))
    return 1 if report["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
