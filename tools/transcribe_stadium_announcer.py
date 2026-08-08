#!/usr/bin/env python3
"""Build a resumable machine transcript of decoded Stadium announcer WAVs.

This is a research helper, not a runtime dependency. Install ``faster-whisper``
in the active Python environment before running it. Automatic text and labels
must be reviewed before they are promoted into the curated event catalog.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

from faster_whisper import WhisperModel


WAV_RE = re.compile(r"^BANK_([0-9A-F]+)_INSTR_[0-9A-F]+_SND_[0-9A-F]+\.wav$")
INITIAL_PROMPT = "Pokémon Stadium battle announcer commentary."


def classify(index: int, text: str) -> list[str]:
    if index < 165:
        return ["pokemon_call_unreviewed"]
    if index == 165:
        return ["transition_fragment_unreviewed"]
    normalized = text.lower()
    rules = (
        ("reserve_status", ("reserve", "pokémon left", "pokemon left")),
        ("battle_open", ("battle begins", "battle is underway", "get ready")),
        ("battle_result", ("winner", "victory", "battle is over", "defeated")),
        ("faint", ("down", "knocked out", "taken out", "goes down")),
        ("switch", ("switch", "change pokémon", "change pokemon", "withdraw")),
        ("move_call", ("going to", "used", "attack", "move")),
        ("critical_hit", ("critical hit",)),
        ("miss_or_fail", ("miss", "failed", "no effect", "didn't work")),
        ("damage_reaction", ("hit", "damage", "effective", "weak")),
        ("status_condition", ("poison", "paraly", "sleep", "frozen", "burn")),
    )
    labels = [label for label, phrases in rules if any(p in normalized for p in phrases)]
    return labels or ["commentary_unreviewed"]


def wav_index(path: Path) -> int:
    match = WAV_RE.match(path.name)
    if not match:
        raise ValueError(f"unexpected batch WAV filename: {path.name}")
    return int(match.group(1), 16)


def save(path: Path, records: dict[int, dict[str, object]], model_name: str) -> None:
    payload = {
        "format": "Pokemon Stadium automatic announcer transcript v1",
        "model": model_name,
        "warning": "Automatic transcription and categories require human review.",
        "clips": [records[index] for index in sorted(records)],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("wav_dir", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--model", default="distil-small.en")
    parser.add_argument("--device", default="cpu", choices=("cpu", "cuda"))
    parser.add_argument("--compute-type", default="int8")
    parser.add_argument("--start", type=int, default=0)
    parser.add_argument("--end", type=int, default=822)
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    wavs = {wav_index(path): path for path in args.wav_dir.glob("*.wav")}
    inventory = json.loads(args.manifest.read_text(encoding="utf-8"))["clips"]
    metadata = {int(clip["index"]): clip for clip in inventory}
    requested = [
        index for index in sorted(wavs) if args.start <= index <= args.end
    ]
    if not requested:
        parser.error("no WAVs matched the requested index range")

    records: dict[int, dict[str, object]] = {}
    if args.output.exists() and not args.overwrite:
        previous = json.loads(args.output.read_text(encoding="utf-8"))
        records = {int(item["index"]): item for item in previous.get("clips", [])}

    pending = [index for index in requested if index not in records]
    print(f"loaded {len(records)} existing records; transcribing {len(pending)} clips")
    if not pending:
        return 0

    model = WhisperModel(
        args.model, device=args.device, compute_type=args.compute_type
    )
    for position, index in enumerate(pending, 1):
        segments, info = model.transcribe(
            str(wavs[index]),
            language="en",
            beam_size=5,
            vad_filter=False,
            condition_on_previous_text=False,
            initial_prompt=INITIAL_PROMPT,
        )
        completed = list(segments)
        text = " ".join(segment.text.strip() for segment in completed).strip()
        records[index] = {
            "index": index,
            "archive_path": metadata[index]["archive_path"],
            "duration_seconds": metadata[index]["expected_duration_seconds"],
            "wav": wavs[index].name,
            "text_auto": text,
            "categories_auto": classify(index, text),
            "average_log_probability": round(
                sum(segment.avg_logprob for segment in completed) / len(completed)
                if completed
                else -99.0,
                5,
            ),
            "no_speech_probability": round(
                sum(segment.no_speech_prob for segment in completed) / len(completed)
                if completed
                else 1.0,
                5,
            ),
            "reviewed": False,
        }
        if position % 25 == 0 or position == len(pending):
            save(args.output, records, args.model)
            print(f"{position}/{len(pending)} new clips; last={index}: {text}", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
