#!/usr/bin/env python3
"""Says which ExerciseDB animation shows each exercise of the library.

    python3 tool/match_exercisedb.py path/to/exercisedb-exercises.json

The input is the free ExerciseDB list (1,500 exercises, each with a `gifUrl`
on static.exercisedb.dev), e.g. `src/data/exercises.json` of
https://github.com/bootstrapping-lab/exercisedb-api. The output is
`tool/exercise_data/exercisedb.json`: our exercise id -> the ExerciseDB id
and name it was matched with, kept so a match can be read and argued with.
`tool/merge_exercise_catalogue.py` turns it into the asset the app loads.

A wrong animation is worse than none, so an exercise is matched only when
ExerciseDB has the same movement with the same equipment:

1. The names, read as bags of words with the equipment named in them left
   out, are equal, and the equipment is the same one (`EQUIPMENT`). An
   exercise with more than one such candidate gets none.
2. `REJECT` removes a match found that way which on reading is another
   variant (a weighted dip is not ring dips), and `ACCEPT` adds one the
   words did not find, by ExerciseDB's name. Both were read one by one.
"""

import collections
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / 'assets' / 'exercises' / 'catalogue.json'
OUT = ROOT / 'tool' / 'exercise_data' / 'exercisedb.json'

# Our equipment -> the ExerciseDB equipment that is the same one.
EQUIPMENT = {
    'bodyweight': {'body weight'},
    'dumbbell': {'dumbbell'},
    'barbell': {'barbell', 'olympic barbell'},
    'cable': {'cable'},
    'band': {'band', 'resistance band'},
    'kettlebell': {'kettlebell'},
    'machine': {'leverage machine', 'sled machine', 'assisted'},
    'smithMachine': {'smith machine'},
    'ezBar': {'ez barbell'},
    'stabilityBall': {'stability ball'},
    'medicineBall': {'medicine ball'},
    'foamRoller': {'roller', 'wheel roller'},
    'pullUpBar': {'body weight', 'assisted'},
    'plate': {'weighted'},
    'trapBar': {'trap bar'},
    'sled': {'sled machine'},
    'rings': {'body weight'},
    'suspension': {'body weight'},
    'box': {'body weight'},
    'landmine': {'barbell', 'olympic barbell'},
}

# Words that name the equipment: they say what it is done with, which
# `EQUIPMENT` compares, not what the movement is.
EQUIPMENT_WORDS = {
    'barbell', 'dumbbell', 'cable', 'lever', 'leverage', 'machine', 'smith',
    'band', 'resistance', 'kettlebell', 'ez', 'bar', 'weighted', 'assisted',
    'sled', 'body', 'weight', 'bodyweight', 'stability', 'ball', 'swiss',
    'medicine', 'roller', 'foam', 'plate', 'trap', 'hex', 'landmine',
    'suspension', 'ring', 'trx', 'box', 'olympic', 'rope', 'bosu', 'wheel',
}
FILLER = {'the', 'a', 'of', 'with', 'on', 'to', 'and', 'v'}

# Taken by the words but another variant of the movement.
REJECT = {
    'weighted-push-up', 'weighted-pull-up', 'weighted-chin-up',
    'weighted-dip', 'weighted-sissy-squat', 'weighted-inverted-row',
    'dip', 'suspension-dip', 'band-assisted-dip', 'tricep-pushdown',
    'rope-tricep-pushdown', 'v-up', 'suspension-knee-tuck',
    'band-assisted-pull-up', 'band-assisted-chin-up',
    'one-arm-kettlebell-clean', 'landmine-squat-to-press',
    'stability-ball-dumbbell-pullover', 'stability-ball-dumbbell-bench-press',
    'wide-stance-box-squat', 'one-arm-wall-lat-stretch', 'segmental-bridge',
    'plank-body-saw', 'suspension-mountain-climber', 'ring-row',
    'ring-push-up', 'ring-pull-up', 'ring-muscle-up', 'machine-hammer-curl',
    'swiss-bar-bench-press', 'plate-back-extension',
    'bench-reverse-hyperextension', 'landmine-romanian-deadlift',
    'landmine-single-leg-romanian-deadlift', 'landmine-reverse-lunge',
    'single-arm-landmine-floor-press', 'kettlebell-gorilla-row',
    'smith-machine-box-squat', 'ez-bar-bent-over-row', 'forearm-plank-pike',
    'hanging-alternating-knee-raise', 'standing-dumbbell-twist',
    'dip-belt-squat', 'cable-russian-twist', 'body-up',
}

# Our id -> ExerciseDB's name, for what the words did not find.
ACCEPT = {
    'v-bar-tricep-pushdown': 'cable triceps pushdown (v-bar)',
    'straight-arm-pulldown': 'cable straight arm pulldown',
    'seated-row': 'cable seated row',
    'machine-chest-press': 'lever chest press',
    'incline-cable-triceps-extension': 'cable incline triceps extension',
    'single-leg-standing-dumbbell-calf-raise': 'dumbbell single leg calf raise',
    'reverse-grip-incline-bench-press': 'barbell reverse grip incline bench press',
    'one-arm-incline-dumbbell-press': 'dumbbell incline one arm press',
    'close-grip-dumbbell-press': 'dumbbell close-grip press',
    'alternating-kettlebell-press': 'kettlebell alternating press',
    'ez-bar-spider-curl': 'ez barbell spider curl',
    'barbell-seated-calf-raise': 'barbell seated calf raise',
    'barbell-overhead-triceps-extension': 'barbell standing overhead triceps extension',
    'single-arm-cable-curl': 'cable one arm curl',
    'single-arm-lat-pulldown': 'cable one arm pulldown',
    'reverse-grip-tricep-pushdown': 'cable reverse-grip pushdown',
    'triceps-stretch': 'triceps stretch',
    'stability-ball-push-up': 'push-up (on stability ball)',
    'banded-seated-hip-abduction': 'resistance band seated hip abduction',
    'cable-external-rotation': 'cable standing shoulder external rotation',
    'ez-bar-reverse-preacher-curl': 'ez barbell reverse grip preacher curl',
    'dynamic-chest-stretch': 'dynamic chest stretch (male)',
    'standing-calf-stretch': 'standing calves calf stretch',
    'seated-calf-stretch': 'seated calf stretch (male)',
    'incline-push-up': 'incline push-up (on box)',
    'side-lying-hip-adduction': 'side lying hip adduction (male)',
    'wide-push-up': 'wide hand push up',
    'single-leg-romanian-deadlift': 'dumbbell single leg deadlift',
    'side-lying-hip-abduction': 'side hip abduction',
    'overhead-tricep-extension': 'cable overhead triceps extension (rope attachment)',
    'neutral-grip-incline-dumbbell-press': 'dumbbell incline hammer press',
    'l-sit-pull-up': 'l-pull-up',
    'cable-skull-crusher': 'cable lying triceps extension v. 2',
    'barbell-behind-the-back-wrist-curl': 'barbell standing back wrist curl',
}


def words(text: str) -> frozenset:
    text = re.sub(r'[^a-z0-9 ]', ' ', text.lower().replace('-', ' '))
    out = set()
    for word in text.split():
        if len(word) > 3 and word.endswith('s') and not word.endswith('ss'):
            word = word[:-1]
        if word not in FILLER and word not in EQUIPMENT_WORDS:
            out.add(word)
    return frozenset(out)


def english_names(exercise: dict) -> list:
    names = [exercise['id'].replace('-', ' ')]
    names += [a for a in exercise['aliases'] if re.fullmatch(r"[A-Za-z0-9 \-'/().,&]+", a)]
    return names


def main() -> None:
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    theirs = json.loads(pathlib.Path(sys.argv[1]).read_text())
    catalogue = json.loads(CATALOGUE.read_text())
    ours = catalogue if isinstance(catalogue, list) else catalogue['exercises']
    by_name = {x['name']: x for x in theirs}
    by_words = collections.defaultdict(list)
    for x in theirs:
        by_words[words(x['name'])].append(x)

    matches = {}
    for exercise in ours:
        if exercise['id'] in REJECT:
            continue
        same = EQUIPMENT.get(exercise['equipment'])
        if not same:
            continue
        found = {
            x['exerciseId']: x
            for name in english_names(exercise)
            for x in by_words.get(words(name), [])
            if set(x['equipments']) & same
        }
        if len(found) == 1:
            matches[exercise['id']] = next(iter(found.values()))
    ids = {e['id'] for e in ours}
    for id_, name in ACCEPT.items():
        if id_ not in ids or name not in by_name:
            sys.exit(f'ACCEPT {id_}: not in the library or in ExerciseDB')
        matches[id_] = by_name[name]

    users = collections.defaultdict(list)
    for id_, x in matches.items():
        users[x['exerciseId']].append(id_)
    shared = {k: v for k, v in users.items() if len(v) > 1}
    if shared:
        sys.exit(f'one animation for several exercises, read them: {shared}')

    OUT.write_text(json.dumps(
        {
            'source': 'ExerciseDB free tier (AscendAPI), https://oss.exercisedb.dev',
            'matches': {
                id_: {'id': x['exerciseId'], 'name': x['name']}
                for id_, x in sorted(matches.items())
            },
        },
        indent=1, ensure_ascii=False,
    ) + '\n')
    print(f'{len(matches)} of {len(ours)} exercises matched')


if __name__ == '__main__':
    main()
