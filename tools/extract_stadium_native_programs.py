#!/usr/bin/env python3
"""Extract Stadium's native move-controller programs without interpreting them.

The output is deliberately lossless: every move opcode, dispatch target, and
ordered scheduler call retains its original C expression and source location.
It is the input to the native-program interpreter; it is not a timing guess.
"""

from __future__ import annotations

import argparse
import ast
import json
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path


FUNCTION_RE = re.compile(
    r"\b(?:void|[suf](?:8|16|32|64)|unk_[A-Za-z0-9_]+\s*\*)\s+"
    r"(func_[0-9A-Fa-f]+)\s*\([^;]*?\)\s*\{",
    re.S,
)
SCHEDULER_RE = re.compile(
    r"\b(func_8432(?:EB14|EB20|EB2C|EB44|EC28|ECA0|ED0C|ED74|EDE8|"
    r"EE5C|EED0|EF40|EFB4|F028|F098|F104|F174|F1E0|F254|F2C8|F344|"
    r"F3C4|F440|F4BC|F538|F5B8|F638|F6B8|F728|F7A0|F818|F884|F8E8|"
    r"F93C))\s*\("
)
MOVE_RE = re.compile(
    r'^\s*\[(\d+)\]\s*=\s*\{\s*key\s*=\s*"([^"]+)".*?'
    r"primary\s*=\s*\{(.*?)\}.*?alternate\s*=\s*\{(.*?)\}.*?"
    r"impact\s*=\s*\{(.*?)\}.*?primaryResources\s*=\s*\{(.*?)\}.*?"
    r"impactResources\s*=\s*\{(.*?)\}",
    re.M | re.S,
)


@dataclass(frozen=True)
class Function:
    name: str
    file: Path
    line: int
    body: str
    body_offset: int


def _balanced_end(text: str, start: int, opening: str, closing: str) -> int:
    depth = 1
    quote: str | None = None
    escape = False
    i = start
    while i < len(text):
        char = text[i]
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == quote:
                quote = None
        elif char in {'"', "'"}:
            quote = char
        elif text.startswith("//", i):
            end = text.find("\n", i)
            i = len(text) if end < 0 else end
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = len(text) if end < 0 else end + 2
            continue
        elif char == opening:
            depth += 1
        elif char == closing:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise ValueError(f"unterminated {opening}{closing} expression")


def split_args(text: str) -> list[str]:
    args: list[str] = []
    start = 0
    depths = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    quote: str | None = None
    escape = False
    for i, char in enumerate(text):
        if quote:
            if escape:
                escape = False
            elif char == "\\":
                escape = True
            elif char == quote:
                quote = None
        elif char in {'"', "'"}:
            quote = char
        elif char in depths:
            depths[char] += 1
        elif char in pairs:
            depths[pairs[char]] -= 1
        elif char == "," and not any(depths.values()):
            args.append(text[start:i].strip())
            start = i + 1
    tail = text[start:].strip()
    if tail:
        args.append(tail)
    return args


def functions(source_dir: Path, recursive: bool = False) -> dict[str, Function]:
    result: dict[str, Function] = {}
    paths = source_dir.rglob("*.c") if recursive else source_dir.glob("*.c")
    for path in sorted(paths):
        source = path.read_text(encoding="utf-8")
        for match in FUNCTION_RE.finditer(source):
            end = _balanced_end(source, match.end(), "{", "}")
            body_start = match.end()
            result[match.group(1)] = Function(
                match.group(1), path, source.count("\n", 0, match.start()) + 1,
                source[body_start:end], body_start,
            )
    return result


def initializer_table(source: str, name: str) -> list[str]:
    match = re.search(rf"\b{re.escape(name)}\[\]\s*=\s*\{{(.*?)\}};", source, re.S)
    if not match:
        raise ValueError(f"could not find initializer table {name}")
    return re.findall(r"func_[0-9A-Fa-f]+", match.group(1))


def initializer_entries(source: str, name: str) -> list[list[str]]:
    match = re.search(rf"\b{re.escape(name)}\[\]\s*=\s*\{{", source)
    if not match:
        raise ValueError(f"could not find initializer {name}")
    end = _balanced_end(source, match.end(), "{", "}")
    body = source[match.end():end]
    entries: list[list[str]] = []
    cursor = 0
    while True:
        opening = body.find("{", cursor)
        if opening < 0:
            break
        closing = _balanced_end(body, opening + 1, "{", "}")
        entries.append(split_args(body[opening + 1:closing]))
        cursor = closing + 1
    return entries


def scheduler_calls(fn: Function) -> list[dict[str, object]]:
    calls: list[dict[str, object]] = []
    for match in SCHEDULER_RE.finditer(fn.body):
        close = _balanced_end(fn.body, match.end(), "(", ")")
        absolute = fn.body_offset + match.start()
        calls.append({
            "helper": match.group(1),
            "args": split_args(fn.body[match.end():close]),
            "source": {
                "file": fn.file.name,
                "line": fn.file.read_text(encoding="utf-8").count("\n", 0, absolute) + 1,
            },
        })
    return calls


# Every public scheduler helper is a thin argument-ordering wrapper around
# func_8432EB64.  Preserve the original call above, but also expose the common
# event record consumed by the portable runtime.  Integer entries are source
# constants; expressions which depend on battle state remain strings.
EB64_FIELDS = (
    "start", "interval", "repeats", "callback", "render", "owner",
    "particleCount", "batchSize", "anchorMode", "attachment",
    "aux", "aux2",
)


def _wrapper(*values: object) -> tuple[object, ...]:
    if len(values) != len(EB64_FIELDS):
        raise ValueError("invalid native scheduler wrapper description")
    return values


# An integer selects that argument from the public helper. Strings beginning
# with '=' are exact constants copied from fragment62_317E70.c.
SCHEDULER_WRAPPERS = {
    "func_8432EC28": _wrapper(0, "=0", "=1", 1, 2, "=D_843902E8", 3, 4, 5, 6, 7, 8),
    "func_8432ECA0": _wrapper(0, 1, 2, 3, 4, "=D_843902E8", 5, 6, 7, 8, 9, 10),
    "func_8432ED0C": _wrapper(0, "=0", "=1", "=func_84331DC8", "=&D_8140E460", "=NULL", "=0", 1, "=0x16", "=0", 2, "=0"),
    "func_8432ED74": _wrapper(0, "=0", "=1", "=func_84332CD0", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", 4, 3, "=0"),
    "func_8432EDE8": _wrapper(0, "=0", "=1", "=func_84332DB0", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", "=0xFF", 3, "=0"),
    "func_8432EE5C": _wrapper(0, "=0", "=1", "=func_84332DB0", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", 4, 3, "=0"),
    "func_8432EED0": _wrapper(0, 1, 2, "=func_84332DB0", "=&D_843861D0[37]", "=NULL", 3, 4, "=0x16", 6, 5, "=0"),
    "func_8432EF40": _wrapper(0, "=0", "=1", "=func_84332E6C", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", "=0xFF", 3, "=0"),
    "func_8432EFB4": _wrapper(0, "=0", "=1", "=func_84332E6C", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", 4, 3, "=0"),
    "func_8432F028": _wrapper(0, 1, 2, "=func_84332E6C", "=&D_843861D0[37]", "=NULL", 3, 4, "=0x16", 6, 5, "=0"),
    "func_8432F098": _wrapper(0, "=0", "=1", "=func_84332F30", "=&D_843861D0[37]", "=NULL", 1, "=0", "=0x16", "=0xFF", 2, "=0"),
    "func_8432F104": _wrapper(0, "=0", "=1", "=func_84332F30", "=&D_843861D0[37]", "=NULL", 1, "=0", "=0x16", 3, 2, "=0"),
    "func_8432F174": _wrapper(0, 1, 2, "=func_84332F30", "=&D_843861D0[37]", "=NULL", 3, "=0", "=0x16", 5, 4, "=0"),
    "func_8432F1E0": _wrapper(0, "=0", "=1", "=func_84332FD0", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", 4, 3, "=0"),
    "func_8432F254": _wrapper(0, "=0", "=1", "=func_843330A0", "=&D_843861D0[37]", "=NULL", 1, 2, "=0x16", 4, 3, "=0"),
    "func_8432F2C8": _wrapper(0, "=0", "=1", "=func_84331EAC", "=&D_8140E460", "=D_843902E8", 2, 4, "=0x1A", 3, 1, "=0"),
    "func_8432F344": _wrapper(0, "=0", "=1", "=func_84331FAC", "=&D_8140E460", "=D_843902E8", 1, 5, "=0x1A", 4, 2, 3),
    "func_8432F3C4": _wrapper(0, "=0", "=1", "=func_843320A4", "=&D_8140E460", "=D_843902E8", 1, 4, "=0x1A", "=0", 2, 3),
    "func_8432F440": _wrapper(0, "=0", "=1", "=func_843321BC", "=&D_8140E460", "=D_843902E8", 4, 3, "=0x1A", 2, 1, "=0"),
    "func_8432F4BC": _wrapper(0, "=0", "=1", "=func_843321BC", "=&D_8140E460", "=D_843902E8", 4, 3, "=0x1A", 2, 1, "=0"),
    "func_8432F538": _wrapper(0, "=0", "=1", "=func_843323BC", "=&D_8140E460", "=D_843902E8", 4, 3, "=0x1A", 2, 1, 5),
    "func_8432F5B8": _wrapper(0, "=0", "=1", "=func_843323BC", "=&D_8140E460", "=D_843902E8", 4, 3, "=0x1A", 2, 1, 5),
    "func_8432F638": _wrapper(0, "=0", "=1", "=func_84332604", "=&D_8140E460", "=D_843902E8", 4, 3, "=0x1A", 2, 1, 5),
    "func_8432F6B8": _wrapper(0, "=0", "=1", "=func_843327B8", "=&D_8140E460", "=D_843902E8", "=0", 1, "=0x1A", 2, "=0", "=0"),
    "func_8432F728": _wrapper(0, "=0", "=1", "=func_84332964", "=&D_8140E460", "=D_843902E8", 1, 2, "=0x1A", 3, "=0", "=0"),
    "func_8432F7A0": _wrapper(0, "=0", "=1", "=func_84332AFC", "=&D_8140E460", "=D_843902E8", 1, 3, "=0x1A", 2, "=0", "=0"),
    "func_8432F818": _wrapper(0, "=0", "=1", "=func_84332AFC", "=&D_8140E460", "=D_843902E8", "=0xFF", "=0xFF", "=0x1A", "=0xFF", "=0", "=0"),
    "func_8432F884": _wrapper(0, "=0", "=1", "=func_84332AFC", "=&D_8140E460", "=D_843902E8", "=0", "=0xFF", "=0x1A", "=0", "=0", "=0"),
    "func_8432F8E8": _wrapper(0, "=0", "=1", "=NULL", "=NULL", "=0", "=0", "=0", "=0x17", 1, "=0", "=0"),
    "func_8432F93C": _wrapper(0, "=0", "=1", "=NULL", "=NULL", "=D_843902E8", "=0", "=0", "=0x19", 1, "=0", "=0"),
}


def constant(expression: str) -> int | str:
    """Convert source integer literals without evaluating arbitrary code."""
    text = expression.strip()
    try:
        node = ast.parse(text, mode="eval").body
    except SyntaxError:
        return text
    if isinstance(node, ast.Constant) and isinstance(node.value, int):
        return node.value
    if (isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.USub, ast.UAdd))
            and isinstance(node.operand, ast.Constant)
            and isinstance(node.operand.value, int)):
        return -node.operand.value if isinstance(node.op, ast.USub) else node.operand.value
    return text


def native_events(calls: list[dict[str, object]]) -> list[dict[str, object]]:
    cursor: int | str = 0
    events: list[dict[str, object]] = []
    for order, call in enumerate(calls):
        helper = str(call["helper"])
        args = list(call["args"])
        if helper in {"func_8432EB14", "func_8432EB44"}:
            cursor = 0
            continue
        if helper in {"func_8432EB20", "func_8432EB2C"}:
            value = constant(str(args[0]))
            if helper == "func_8432EB20":
                cursor = value
            elif isinstance(cursor, int) and isinstance(value, int):
                cursor += value
            else:
                cursor = f"({cursor}) + ({value})"
            continue
        wrapper = SCHEDULER_WRAPPERS.get(helper)
        if not wrapper:
            continue
        values: dict[str, object] = {}
        for field, selector in zip(EB64_FIELDS, wrapper):
            expression = args[selector] if isinstance(selector, int) else selector[1:]
            values[field] = constant(str(expression))
        start = values["start"]
        values["at"] = (cursor + start if isinstance(cursor, int) and isinstance(start, int)
                        else f"({cursor}) + ({start})")
        values["helper"] = helper
        values["order"] = order
        values["source"] = call["source"]
        render = str(values["render"])
        match = re.search(r"D_843861D0\[(0x[0-9A-Fa-f]+|\d+)\]", render)
        values["renderPreset"] = int(match.group(1), 0) if match else None
        events.append(values)
    return events


def _opcodes(text: str) -> list[int]:
    return [int(value, 16) for value in re.findall(r"0x([0-9A-Fa-f]+)", text)]


def moves(path: Path) -> list[dict[str, object]]:
    rows = [
        {"id": int(move_id), "key": key, "primary": _opcodes(primary),
         "alternate": _opcodes(alternate), "impact": _opcodes(impact),
         "primaryResources": _opcodes(primary_resources),
         "impactResources": _opcodes(impact_resources)}
        for (move_id, key, primary, alternate, impact, primary_resources,
             impact_resources) in MOVE_RE.findall(
            path.read_text(encoding="utf-8")
        )
    ]
    if [row["id"] for row in rows] != list(range(1, 166)):
        raise ValueError(f"expected moves 1..165, found {len(rows)} rows")
    return rows


def build(source_dir: Path, roster: Path) -> dict[str, object]:
    dispatch_path = source_dir / "fragment62_315D50.c"
    dispatch = dispatch_path.read_text(encoding="utf-8")
    all_functions = functions(source_dir)
    project_src = source_dir.parents[1]
    callback_functions = functions(project_src, recursive=True)
    tables = {
        "primary": initializer_table(dispatch, "D_84386480"),
        "impact": initializer_table(dispatch, "D_843866C4"),
    }
    used: set[tuple[str, int]] = set()
    move_rows = moves(roster)
    for row in move_rows:
        for channel in ("primary", "alternate"):
            used.update(("primary", opcode) for opcode in row[channel])
        used.update(("impact", opcode) for opcode in row["impact"])

    programs: dict[str, object] = {}
    for kind, opcode in sorted(used):
        table = tables[kind]
        if opcode >= len(table):
            raise ValueError(f"{kind} opcode 0x{opcode:02X} is outside its dispatch table")
        target = table[opcode]
        fn = all_functions.get(target)
        if not fn:
            raise ValueError(f"missing source body for {target}")
        programs[f"{kind}:0x{opcode:02X}"] = {
            "channel": kind,
            "opcode": opcode,
            "initializer": target,
            "source": {"file": fn.file.name, "line": fn.line},
            "schedulerCalls": scheduler_calls(fn),
        }
        programs[f"{kind}:0x{opcode:02X}"]["nativeEvents"] = native_events(
            programs[f"{kind}:0x{opcode:02X}"]["schedulerCalls"]
        )

    particle_rows = initializer_entries(dispatch, "D_84385E40")
    render_rows = initializer_entries(dispatch, "D_843861D0")
    particle_presets = [
        {
            "index": index,
            "batchMode": row[0],
            "enabled": row[1],
            "flags": row[2],
            "initialize": row[3],
            "draw": row[4],
            "asset": row[5],
        }
        for index, row in enumerate(particle_rows)
    ]
    render_presets = [
        {"index": index, "kind": row[0], "target": row[1]}
        for index, row in enumerate(render_rows)
    ]

    def transitive_asset_slots(start_names: set[str]) -> list[int]:
        pending = list(start_names)
        visited: set[str] = set()
        slots: set[int] = set()
        while pending:
            name = pending.pop()
            if name in visited:
                continue
            visited.add(name)
            fn = callback_functions.get(name)
            if not fn:
                continue
            slots.update(
                int(value, 16) if value.lower().startswith("0x") else int(value)
                for value in re.findall(
                    r"D_843920C0\[((?:0x)?[0-9A-Fa-f]+)\]", fn.body
                )
            )
            pending.extend(
                called for called in re.findall(r"func_[0-9A-Fa-f]+", fn.body)
                if called not in visited
            )
        return sorted(slots)

    for program in programs.values():
        roots: set[str] = set()
        direct_slots: set[int] = set()
        for call in program["schedulerCalls"]:
            joined = " ".join(call["args"])
            roots.update(re.findall(r"func_[0-9A-Fa-f]+", joined))
            for preset_text in re.findall(r"D_843861D0\[([^]]+)\]", joined):
                try:
                    preset_index = int(preset_text, 0)
                except ValueError:
                    continue
                if preset_index >= len(render_presets):
                    continue
                preset = render_presets[preset_index]
                roots.update(re.findall(r"func_[0-9A-Fa-f]+", preset["target"]))
                particle_match = re.search(r"D_84385E40\[(\d+)\]", preset["target"])
                if particle_match:
                    particle = particle_presets[int(particle_match.group(1))]
                    roots.update((particle["initialize"], particle["draw"]))
                    slot_match = re.search(r"D_843920C0\[(\d+)\]", particle["asset"])
                    if slot_match:
                        direct_slots.add(int(slot_match.group(1)))
        program["assetSlots"] = sorted(
            direct_slots | set(transitive_asset_slots(roots))
        )
        for event in program["nativeEvents"]:
            preset_index = event.get("renderPreset")
            event["particlePreset"] = None
            if not isinstance(preset_index, int) or preset_index >= len(render_presets):
                continue
            target = render_presets[preset_index]["target"]
            particle_match = re.search(r"D_84385E40\[(\d+)\]", target)
            if particle_match:
                event["particlePreset"] = int(particle_match.group(1))

    callback_names: set[str] = set()
    for program in programs.values():
        for call in program["schedulerCalls"]:
            for argument in call["args"]:
                callback_names.update(re.findall(r"func_[0-9A-Fa-f]+", argument))
    for row in particle_presets:
        callback_names.update((row["initialize"], row["draw"]))
    for row in render_presets:
        callback_names.update(re.findall(r"func_[0-9A-Fa-f]+", row["target"]))
    callbacks = {}
    for name in sorted(callback_names):
        fn = callback_functions.get(name)
        callbacks[name] = None if not fn else {
            "source": {"file": fn.file.name, "line": fn.line},
            "body": fn.body.strip(),
        }

    try:
        revision = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=source_dir, text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        revision = None
    return {
        "schema": 2,
        "sourceRevision": revision,
        "dispatchSource": dispatch_path.name,
        "moves": move_rows,
        "programs": programs,
        "particlePresets": particle_presets,
        "renderPresets": render_presets,
        "callbacks": callbacks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stadium-source", required=True, type=Path)
    parser.add_argument("--roster", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    result = build(args.stadium_source, args.roster)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    print(
        f"extracted {len(result['programs'])} used native programs for "
        f"{len(result['moves'])} moves"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
