#!/usr/bin/env python3
"""Builds the library the app loads, `assets/exercises/catalogue.json`.

    python3 tool/merge_exercise_catalogue.py

It is `tool/exercise_data/core.json` (the exercises with pictures of their
own, from `tool/build_exercise_catalogue.py`) followed by
`tool/exercise_data/additions.json`: exercises written for this app, in
the file's own shape,

    id, zh, aliases, equipment, primary, secondary, pattern, laterality,
    tracking, family, demoFrom, cues

where `demoFrom` names an exercise of the core whose three poses stand in
for this one (the same movement with other equipment or grip) or is null.
The validation that matters is `test/backend/exercise_catalogue_test.dart`;
this only joins the two files and fails on what cannot be joined.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DATA = ROOT / 'tool' / 'exercise_data'
OUT = ROOT / 'assets' / 'exercises' / 'catalogue.json'


def main() -> None:
    core = json.loads((DATA / 'core.json').read_text())
    additions = json.loads((DATA / 'additions.json').read_text())['exercises']
    by_id = {e['id']: e for e in core['exercises']}

    exercises = list(core['exercises'])
    for entry in additions:
        if entry['id'] in by_id:
            sys.exit(f"{entry['id']}: already in the core")
        frames = []
        if entry['demoFrom']:
            owner = by_id.get(entry['demoFrom'])
            if owner is None:
                sys.exit(f"{entry['id']}: demoFrom {entry['demoFrom']} is not in the core")
            frames = owner['frames']
        row = {
            'id': entry['id'],
            'name': entry['zh'],
            'aliases': entry['aliases'],
            'equipment': entry['equipment'],
            'primaryMuscles': entry['primary'],
            'secondaryMuscles': entry['secondary'],
            'pattern': entry['pattern'],
            'laterality': entry['laterality'],
            'family': entry['family'],
            'trackingType': entry['tracking'],
            'frames': frames,
            'cues': entry['cues'],
        }
        by_id[entry['id']] = row
        exercises.append(row)

    OUT.write_text(json.dumps({
        'source': core['source'],
        'frameLicense': core['frameLicense'],
        'exercises': exercises,
    }, ensure_ascii=False, indent=1) + '\n')
    print(f'{len(exercises)} exercises ({len(core["exercises"])} core, {len(additions)} added)')


if __name__ == '__main__':
    main()
