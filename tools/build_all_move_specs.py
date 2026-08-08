#!/usr/bin/env python3
"""Generate complete runtime presentation specs for all 165 Gen 1 moves."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


BLOCK_RE = re.compile(
    r"^  ([A-Z0-9_]+) = \{\n(.*?)(?=^  [A-Z0-9_]+ = \{|^\})",
    re.M | re.S,
)


def field(body: str, name: str):
    match = re.search(
        rf'^    {re.escape(name)} = (?:(\d+)|"([^"]*)"),', body, re.M
    )
    if not match:
        raise ValueError(f"missing {name}")
    return match.group(2) if match.group(2) is not None else int(match.group(1))


def parse_moves(path: Path) -> list[dict[str, object]]:
    rows = []
    for key, body in BLOCK_RE.findall(path.read_text(encoding="utf-8")):
        rows.append(
            {
                "id": field(body, "index"),
                "key": key,
                "name": field(body, "name").title(),
                "type": field(body, "type").replace("_TYPE", ""),
                "power": field(body, "power"),
                "effect": field(body, "effect"),
            }
        )
    rows.sort(key=lambda row: row["id"])
    if [row["id"] for row in rows] != list(range(1, 166)):
        raise ValueError("generated move data is not the complete Gen 1 roster")
    return rows


SELF_EFFECTS = (
    "_UP", "HEAL_EFFECT", "FOCUS_ENERGY", "BIDE", "RAGE", "MIST",
    "LIGHT_SCREEN", "REFLECT", "SUBSTITUTE", "CONVERSION", "TRANSFORM",
    "METRONOME", "MIMIC", "MIRROR_MOVE", "SPLASH",
)
SCREEN_EFFECTS = ("HAZE", "LIGHT_SCREEN", "REFLECT", "MIST", "EXPLODE")
SCREEN_MOVES = {"FLASH", "HAZE", "LIGHT_SCREEN", "MIST", "REFLECT"}
BEAMS = {
    "AURORA_BEAM", "BUBBLEBEAM", "HYPER_BEAM", "ICE_BEAM", "PSYBEAM",
    "SOLARBEAM", "THUNDERBOLT",
}
PROJECTILES = {
    "ACID", "BONE_CLUB", "BONEMERANG", "EGG_BOMB", "EMBER", "FIRE_BLAST",
    "LEECH_SEED", "PAY_DAY", "PIN_MISSILE", "POISON_STING", "PSYWAVE",
    "RAZOR_LEAF", "ROCK_SLIDE", "ROCK_THROW", "SEED_BOMB", "SLUDGE",
    "SONICBOOM", "SPIKE_CANNON", "SWIFT", "WATER_GUN",
}

# Portable visual programs.  These are deliberately move-shaped instead of
# type-shaped: Stadium composes a move from a body animation, a primary
# program, and one or more defender/impact programs.  Several moves therefore
# reuse the same program while attacks of the same elemental type need not
# look alike.
PUNCHES = {
    "COMET_PUNCH", "MEGA_PUNCH", "FIRE_PUNCH", "ICE_PUNCH",
    "THUNDERPUNCH", "DIZZY_PUNCH",
}
KICKS = {
    "STOMP", "DOUBLE_KICK", "MEGA_KICK", "JUMP_KICK", "ROLLING_KICK",
    "LOW_KICK", "HI_JUMP_KICK",
}
SLASHES = {
    "KARATE_CHOP", "SCRATCH", "GUILLOTINE", "CUT", "CRABHAMMER",
    "FURY_SWIPES", "SLASH",
}
BITES = {"BITE", "HYPER_FANG", "SUPER_FANG"}
GRAPPLES = {
    "VICEGRIP", "BIND", "WRAP", "SUBMISSION", "SEISMIC_TOSS", "CLAMP",
    "CONSTRICT",
}
RUSHES = {
    "POUND", "SLAM", "HEADBUTT", "TACKLE", "BODY_SLAM", "TAKE_DOWN",
    "THRASH", "DOUBLE_EDGE", "COUNTER", "STRENGTH", "QUICK_ATTACK",
    "RAGE", "SKULL_BASH", "STRUGGLE",
}
NEEDLES = {
    "PECK", "DRILL_PECK", "HORN_ATTACK", "FURY_ATTACK", "HORN_DRILL",
    "POISON_STING", "TWINEEDLE", "PIN_MISSILE", "SPIKE_CANNON",
}
WINDS = {
    "RAZOR_WIND", "GUST", "WING_ATTACK", "WHIRLWIND", "FLY",
    "SKY_ATTACK",
}
SOUNDS = {"GROWL", "ROAR", "SING", "SUPERSONIC", "SONICBOOM", "SCREECH"}
STREAMS = {
    "ACID", "EMBER", "FLAMETHROWER", "WATER_GUN", "HYDRO_PUMP",
    "BUBBLE", "FIRE_SPIN", "SMOG", "SLUDGE",
}
WAVES = {"SURF", "WATERFALL"}
STORMS = {"BLIZZARD", "THUNDER", "ROCK_SLIDE", "BARRAGE"}
ORBS = {
    "PAY_DAY", "FIRE_BLAST", "ROCK_THROW", "EGG_BOMB", "BONE_CLUB",
    "BONEMERANG", "SWIFT", "TRI_ATTACK", "DRAGON_RAGE",
}
LEAVES = {
    "VINE_WHIP", "LEECH_SEED", "RAZOR_LEAF", "PETAL_DANCE",
    "POISONPOWDER", "STUN_SPORE", "SLEEP_POWDER", "SPORE",
}
ELECTRIC = {"THUNDERSHOCK", "THUNDERBOLT", "THUNDER_WAVE", "THUNDERPUNCH", "THUNDER"}
PSYCHIC = {
    "PSYBEAM", "CONFUSION", "PSYCHIC_M", "HYPNOSIS", "TELEPORT",
    "NIGHT_SHADE", "CONFUSE_RAY", "KINESIS", "DREAM_EATER", "PSYWAVE",
}
DRAINS = {"ABSORB", "MEGA_DRAIN", "DREAM_EATER", "LEECH_LIFE"}
GROUND = {"SAND_ATTACK", "EARTHQUAKE", "FISSURE", "DIG", "BONE_CLUB", "BONEMERANG"}
BARRIERS = {"MIST", "BARRIER", "LIGHT_SCREEN", "HAZE", "REFLECT"}
HEALS = {"RECOVER", "SOFTBOILED", "REST"}
TRANSFORMS = {
    "DOUBLE_TEAM", "MINIMIZE", "TRANSFORM", "ACID_ARMOR", "SHARPEN",
    "CONVERSION", "SUBSTITUTE",
}
EXPLOSIONS = {"SELFDESTRUCT", "EXPLOSION"}

# Portable timings are calibrated by presentation family instead of giving
# almost every move the old 28/38/46-tick placeholder. They remain behavior-
# calibrated fallbacks; only StadiumFidelityProfiles may claim ROM/source
# calibration.
TIMING = {
    "impact": (30, 28), "rush": (32, 30), "slash": (34, 30),
    "punch": (32, 28), "kick": (35, 30), "bite": (36, 32),
    "grapple": (40, 38), "needle": (42, 34), "leaf": (48, 38),
    "orb": (46, 34), "wind": (50, 38), "sound": (34, 34),
    "stream": (52, 42), "wave": (58, 48), "beam": (56, 44),
    "storm": (58, 46), "electric": (50, 42), "psychic": (48, 42),
    "drain": (50, 48), "ground": (44, 46), "status": (28, 34),
    "barrier": (34, 44), "heal": (40, 48), "transform": (36, 46),
    "explosion": (50, 70), "flash": (18, 44), "mist": (32, 48),
    "haze": (28, 48),
}


def visual_program(row: dict[str, object]) -> str:
    """Choose a shared portable program for the move's complete staging."""
    key = row["key"]
    if key == "FLASH":
        return "flash"
    if key == "MIST":
        return "mist"
    if key == "HAZE":
        return "haze"
    if key in EXPLOSIONS:
        return "explosion"
    if key in GROUND:
        return "ground"
    if key in DRAINS:
        return "drain"
    if key in ELECTRIC:
        return "electric"
    if key in PSYCHIC:
        return "psychic"
    if key in BARRIERS:
        return "barrier"
    if key in HEALS:
        return "heal"
    if key in TRANSFORMS:
        return "transform"
    if key in SOUNDS:
        return "sound"
    if key in WINDS:
        return "wind"
    if key in SLASHES:
        return "slash"
    if key in PUNCHES:
        return "punch"
    if key in KICKS:
        return "kick"
    if key in BITES:
        return "bite"
    if key in GRAPPLES:
        return "grapple"
    if key in NEEDLES:
        return "needle"
    if key in RUSHES:
        return "rush"
    if key in STREAMS:
        return "stream"
    if key in WAVES:
        return "wave"
    if key in STORMS:
        return "storm"
    if key in ORBS:
        return "orb"
    if key in LEAVES:
        return "leaf"
    if key in BEAMS:
        return "beam"
    if row["power"] == 0:
        return "status"
    if key in PROJECTILES or row["type"] not in {"NORMAL", "FIGHTING", "FLYING"}:
        return "orb"
    return "impact"


def cinematic_program(row: dict[str, object], visual: str, hits: int) -> str:
    """Choose a reusable attack-camera timeline, independent of VFX color."""
    effect = row["effect"]
    if visual == "explosion":
        return "explosion"
    if visual in {"ground", "wave", "storm", "barrier", "flash", "mist", "haze"}:
        return "field"
    if visual in {"transform", "heal"}:
        return "self"
    if row["power"] == 0 or visual in {"status", "sound"}:
        return "status"
    if row["key"] in {"FLY", "DIG", "SKY_ATTACK"} or "CHARGE" in effect:
        return "aerial"
    if hits > 1:
        return "combo"
    if visual in {"slash", "punch", "kick", "bite", "grapple", "rush", "impact"}:
        return "melee"
    if visual in {"beam", "stream", "electric", "drain"}:
        return "sustained"
    return "ranged"


def presentation(row: dict[str, object]) -> dict[str, object]:
    key, effect, power = row["key"], row["effect"], row["power"]
    visual = visual_program(row)
    status = power == 0
    if "EXPLODE" in effect:
        delivery, anchor = "screen", "attacker"
    elif status:
        delivery = "screen" if key in SCREEN_MOVES or any(
            x in effect for x in SCREEN_EFFECTS
        ) else "status"
        anchor = "attacker" if any(x in effect for x in SELF_EFFECTS) else "target"
    elif key in BEAMS or "HYPER_BEAM" in effect:
        delivery, anchor = "beam", "target"
    elif key in PROJECTILES or row["type"] not in {"NORMAL", "FIGHTING", "FLYING"}:
        delivery, anchor = "projectile", "target"
    else:
        delivery, anchor = "contact", "target"

    hits = 1
    if "ATTACK_TWICE" in effect or "TWINEEDLE" in effect:
        hits = 2
    elif "TWO_TO_FIVE" in effect:
        hits = 4
    elif "TRAPPING" in effect:
        hits = 3
    cinematic = cinematic_program(row, visual, hits)
    impact_at, tail = TIMING[visual]
    if power >= 100 and not status:
        impact_at += 4
    if power >= 140 and not status:
        impact_at += 4
    duration = impact_at + tail + (hits - 1) * 10
    if "CHARGE" in effect or "FLY_EFFECT" in effect or "HYPER_BEAM" in effect:
        duration += 24
    return {
        **row,
        "kind": "generic",
        "delivery": delivery,
        "anchor": anchor,
        "hits": hits,
        "visual": visual,
        "cinematic": cinematic,
        "impactAt": impact_at,
        "duration": duration,
        "calibration": "portable-behavior-v2",
    }


def lua_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def write_lua(path: Path, rows: list[dict[str, object]]) -> None:
    lines = [
        "-- Generated by tools/build_all_move_specs.py. Do not edit by hand.",
        "-- Complete Gen 1 presentation fallback; exact traced specs override it.",
        "return {",
    ]
    for source in rows:
        row = presentation(source)
        lines.extend(
            [
                "  { "
                f"id = {row['id']}, key = {lua_string(row['key'])}, "
                f"name = {lua_string(row['name'])}, type = {lua_string(row['type'])},",
                "    "
                f"power = {row['power']}, effect = {lua_string(row['effect'])}, "
                f"kind = {lua_string(row['kind'])},",
                "    "
                f"delivery = {lua_string(row['delivery'])}, anchor = {lua_string(row['anchor'])}, "
                f"hits = {row['hits']},",
                "    "
                f"visual = {lua_string(row['visual'])}, cinematic = {lua_string(row['cinematic'])},",
                "    "
                f"impactAt = {row['impactAt']}, duration = {row['duration']}, "
                f"calibration = {lua_string(row['calibration'])},",
                "    resources = {}, assets = {} },",
            ]
        )
    lines.extend(["}", ""])
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--moves", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = parse_moves(args.moves)
    write_lua(args.output, rows)
    print(f"generated {len(rows)} complete move specs")


if __name__ == "__main__":
    main()
