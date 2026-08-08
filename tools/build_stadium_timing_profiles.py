#!/usr/bin/env python3
"""Generate roster-wide timing profiles from Stadium's effect controllers.

Stadium schedules battle effects on a shared cursor.  ``func_8432EB2C``
advances that cursor and ``func_8432F8E8`` schedules the controller's explicit
completion signal.  This tool retains those signals for every move dispatch
sequence and uses the portable presentation timing only when a controller has
no static timing signal of its own.
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
from pathlib import Path


FUNCTION_RE = re.compile(
    r"\bvoid\s+(func_[0-9A-Fa-f]+)\s*\([^;]*?\)\s*\{", re.S
)
CALL_RE = re.compile(
    r"func_8432(EB14|EB20|EB2C|EB44|EC28|ECA0|ED0C|ED74|EDE8|EE5C|"
    r"EED0|EF40|EFB4|F028|F098|F104|F174|F1E0|F254|F2C8|F344|F3C4|"
    r"F440|F4BC|F538|F5B8|F638|F6B8|F728|F7A0|F818|F884|F8E8|F93C)"
    r"\s*\(([^;]*)\)"
)
REPEATED = {"ECA0", "EED0", "F028", "F174"}


def numeric(value: str) -> int | None:
    try:
        return int(value.strip(), 0)
    except ValueError:
        return None


def function_bodies(source: str) -> dict[str, str]:
    """Extract C function bodies without assuming decomp formatting."""
    bodies: dict[str, str] = {}
    for match in FUNCTION_RE.finditer(source):
        depth, cursor = 1, match.end()
        while depth and cursor < len(source):
            depth += (source[cursor] == "{") - (source[cursor] == "}")
            cursor += 1
        if depth:
            raise ValueError(f"unterminated function {match.group(1)}")
        bodies[match.group(1)] = source[match.end() : cursor - 1]
    return bodies


def initializer_table(source: str, name: str) -> list[str]:
    match = re.search(rf"{name}\[\]\s*=\s*\{{(.*?)\}};", source, re.S)
    if not match:
        raise ValueError(f"could not find {name}")
    return re.findall(r"func_[0-9A-Fa-f]+", match.group(1))


def parse_roster(path: Path) -> dict[int, tuple[list[int], list[int]]]:
    source = path.read_text(encoding="utf-8")
    roster: dict[int, tuple[list[int], list[int]]] = {}
    pattern = re.compile(
        r"\[(\d+)\].*?primary = \{(.*?)\}.*?impact = \{(.*?)\}", re.S
    )
    for match in pattern.finditer(source):
        values = lambda text: [
            int(token, 16) for token in re.findall(r"0x([0-9A-Fa-f]+)", text)
        ]
        roster[int(match.group(1))] = (values(match.group(2)), values(match.group(3)))
    if sorted(roster) != list(range(1, 166)):
        raise ValueError(f"expected 165 move dispatch rows, found {len(roster)}")
    return roster


def load_presentations(moves_path: Path, tool_path: Path) -> dict[int, dict[str, object]]:
    spec = importlib.util.spec_from_file_location("all_move_specs", tool_path)
    if not spec or not spec.loader:
        raise ValueError(f"could not load {tool_path}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return {
        row["id"]: module.presentation(row)
        for row in module.parse_moves(moves_path)
    }


def sequence_timing(
    opcodes: list[int], table: list[str], bodies: dict[str, str]
) -> dict[str, int]:
    cursor = marker = phase = last = 0
    for opcode in opcodes:
        if opcode >= len(table):
            raise ValueError(f"opcode 0x{opcode:02X} is outside initializer table")
        for match in CALL_RE.finditer(bodies.get(table[opcode], "")):
            kind = match.group(1)
            args = [part.strip() for part in match.group(2).split(",")]
            first = numeric(args[0]) if args else None
            if kind in {"EB14", "EB44"}:
                cursor = 0
            elif kind == "EB20" and first is not None:
                cursor = first
            elif kind == "EB2C" and first is not None:
                cursor += first
                phase = max(phase, cursor)
            elif first is not None:
                end = cursor + first
                if kind in REPEATED and len(args) >= 3:
                    interval, count = numeric(args[1]), numeric(args[2])
                    if interval is not None and count is not None and count > 0:
                        end += interval * (count - 1)
                last = max(last, end)
                if kind == "F8E8":
                    marker = max(marker, cursor + first)
    return {"marker": marker, "phase": phase, "last": last}


def calibrate(base: dict[str, object], primary: dict[str, int], impact: dict[str, int]) -> dict[str, object]:
    base_impact, base_duration = int(base["impactAt"]), int(base["duration"])
    marker, phase, envelope = primary["marker"], primary["phase"], primary["last"]

    if marker >= 40:
        duration, evidence = marker + 4, "controller-completion"
    elif envelope >= 40:
        # Particle callbacks own their individual lifetimes.  Sixteen ticks is
        # the bounded compositor tail used after the last static emission.
        duration, evidence = max(base_duration, envelope + 16), "controller-envelope"
    else:
        duration, evidence = base_duration, "dispatch-archetype"

    if phase >= 18:
        impact_at = phase + 8
    elif marker >= 40:
        impact_at = round(marker * (base_impact / base_duration))
    elif envelope >= 40:
        impact_at = round(envelope * (base_impact / base_duration))
    else:
        impact_at = base_impact
    impact_at = max(12, min(impact_at, duration - 18))
    if impact["last"] >= 8:
        duration = max(duration, impact_at + impact["last"] + 12)
        if evidence == "dispatch-archetype":
            evidence = "impact-envelope"

    return {
        "impactAt": impact_at,
        "duration": duration,
        "controllerMarker": marker,
        "controllerPhase": phase,
        "controllerEnvelope": envelope,
        "impactEnvelope": impact["last"],
        "timingEvidence": evidence,
    }


def build_profiles(
    roster: dict[int, tuple[list[int], list[int]]],
    presentations: dict[int, dict[str, object]],
    primary_table: list[str],
    impact_table: list[str],
    bodies: dict[str, str],
) -> dict[int, dict[str, object]]:
    profiles = {}
    for move_id in range(1, 166):
        primary, impact = roster[move_id]
        profiles[move_id] = calibrate(
            presentations[move_id],
            sequence_timing(primary, primary_table, bodies),
            sequence_timing(impact, impact_table, bodies),
        )
    return profiles


def write_lua(path: Path, profiles: dict[int, dict[str, object]]) -> None:
    lines = [
        "-- Generated by tools/build_stadium_timing_profiles.py. Do not edit by hand.",
        "-- Static Stadium controller cursor/completion evidence for all Gen 1 moves.",
        "return {",
    ]
    for move_id, row in profiles.items():
        lines.append(
            f"  [{move_id}] = {{ impactAt = {row['impactAt']}, duration = {row['duration']}, "
            f"controllerMarker = {row['controllerMarker']}, controllerPhase = {row['controllerPhase']}, "
            f"controllerEnvelope = {row['controllerEnvelope']}, impactEnvelope = {row['impactEnvelope']}, "
            f"timingEvidence = {json.dumps(row['timingEvidence'])} }},"
        )
    lines.extend(["}", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--stadium-source", type=Path, required=True)
    parser.add_argument("--moves", type=Path, required=True)
    parser.add_argument("--roster", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source_files = sorted(args.stadium_source.glob("*.c"))
    source = "\n".join(path.read_text(encoding="utf-8") for path in source_files)
    dispatch_source = (args.stadium_source / "fragment62_315D50.c").read_text(encoding="utf-8")
    profiles = build_profiles(
        parse_roster(args.roster),
        load_presentations(args.moves, Path(__file__).with_name("build_all_move_specs.py")),
        initializer_table(dispatch_source, "D_84386480"),
        initializer_table(dispatch_source, "D_843866C4"),
        function_bodies(source),
    )
    write_lua(args.output, profiles)
    print(f"generated {len(profiles)} Stadium timing profiles")


if __name__ == "__main__":
    main()
