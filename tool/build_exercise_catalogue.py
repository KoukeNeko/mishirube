#!/usr/bin/env python3
"""Builds the built-in exercise library from Workout Guide.

    python3 tool/build_exercise_catalogue.py <path to a workout-guide checkout>

Writes `assets/exercises/catalogue.json` and, for every exercise, its three
pose frames as WebP under `assets/exercises/frames/`. Workout Guide
(https://github.com/bryllim/workout-guide) supplies the exercise list and the
artwork; its metadata is MIT and its artwork CC BY-SA 4.0, derived in part
from Everkinetic. Everything else here — the Chinese names, the muscles in
the app's own groups, the movement pattern, laterality and family — is this
app's curation, written below. See `third_party/workout-guide/`.

Needs rsvg-convert and cwebp on the PATH.
"""

import json
import pathlib
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'assets' / 'exercises'

# Frame size and quality: sharp on a phone at the size the detail page
# shows them, about 12 KB a frame.
FRAME_PIXELS = 384
WEBP_QUALITY = 78

MUSCLES = {
    'ch': 'chest', 'fd': 'frontDelts', 'sd': 'sideDelts', 'rd': 'rearDelts',
    'bi': 'biceps', 'tr': 'triceps', 'fa': 'forearms', 'tp': 'traps',
    'la': 'lats', 'ub': 'upperBack', 'se': 'spinalErectors', 'ab': 'abs',
    'ob': 'obliques', 'gl': 'glutes', 'qu': 'quads', 'hm': 'hamstrings',
    'ad': 'adductors', 'abd': 'abductors', 'ca': 'calves',
}
PATTERNS = {
    'sq': 'squat', 'hg': 'hinge', 'hpu': 'horizontalPush',
    'hpl': 'horizontalPull', 'vpu': 'verticalPush', 'vpl': 'verticalPull',
    'lu': 'lunge', 'iso': 'isolation', 'cy': 'carry', 'co': 'core',
    'cd': 'conditioning',
}
LATERALITY = {'b': 'bilateral', 'u': 'unilateral', 'a': 'alternating'}
EQUIPMENT = {
    'Barbell': 'barbell', 'Dumbbell': 'dumbbell', 'Cable': 'cable',
    'Machine': 'machine', 'Kettlebell': 'kettlebell', 'Bodyweight': 'bodyweight',
    'Resistance Band': 'band', 'Cardio': 'cardio', 'Plate': 'plate',
    'Pull-up Bar': 'bodyweight', 'Wall': 'bodyweight', 'Towel': 'bodyweight',
    'Doorway': 'bodyweight', 'Box': 'bodyweight', 'Bench': 'bodyweight',
    'Chair': 'bodyweight', 'Stability Ball': 'other',
}
TRACKING = {
    'weight_reps': 'weightReps', 'bodyweight_reps': 'reps',
    'assisted_bodyweight': 'reps', 'duration': 'duration',
    'distance_duration': 'distance',
}

# The ids the app shipped with before this library, kept so the workouts
# already logged against them stay attached.
KEPT_IDS = {
    'squat': 'back-squat', 'smith-machine-squat': 'smith-squat',
    'romanian-deadlift': 'rdl', 'dumbbell-bench-press': 'db-bench',
    'overhead-press': 'ohp', 'kettlebell-swing': 'kb-swing',
}

# Equipment the source files under a broader heading.
EQUIPMENT_OVERRIDE = {
    'smith-machine-bench-press': 'smithMachine', 'smith-machine-squat': 'smithMachine',
    'smith-machine-hip-thrust': 'smithMachine',
    'smith-machine-romanian-deadlift': 'smithMachine',
    'smith-machine-bulgarian-split-squat': 'smithMachine',
    'smith-machine-reverse-lunge': 'smithMachine',
    'smith-machine-split-squat': 'smithMachine',
    'ez-bar-curl': 'ezBar', 'trap-bar-deadlift': 'trapBar',
    'landmine-press': 'landmine', 'landmine-squat': 'landmine',
    'landmine-romanian-deadlift': 'landmine', 'meadows-row': 'landmine',
    't-bar-row': 'landmine', 'skull-crusher': 'ezBar',
}

# slug: (中文名, 別名, 主要肌群, 次要肌群, 動作模式, 單雙側, 動作家族)
C = {
    # 胸
    'bench-press': ('槓鈴臥推', '平板臥推 臥推', 'ch', 'tr fd', 'hpu', 'b', 'bench-press'),
    'incline-bench-press': ('上斜槓鈴臥推', '上斜臥推 上胸', 'ch', 'fd tr', 'hpu', 'b', 'incline-press'),
    'incline-dumbbell-press': ('上斜啞鈴臥推', '上斜啞鈴推胸 上胸', 'ch', 'fd tr', 'hpu', 'b', 'incline-press'),
    'dumbbell-bench-press': ('啞鈴臥推', '啞鈴推胸', 'ch', 'tr fd', 'hpu', 'b', 'bench-press'),
    'decline-bench-press': ('下斜槓鈴臥推', '下斜臥推 下胸', 'ch', 'tr fd', 'hpu', 'b', 'decline-press'),
    'decline-dumbbell-press': ('下斜啞鈴臥推', '下胸', 'ch', 'tr fd', 'hpu', 'b', 'decline-press'),
    'machine-chest-press': ('坐姿推胸機', '機械推胸', 'ch', 'tr fd', 'hpu', 'b', 'bench-press'),
    'smith-machine-bench-press': ('史密斯臥推', '', 'ch', 'tr fd', 'hpu', 'b', 'bench-press'),
    'pec-deck': ('蝴蝶機夾胸', '夾胸機 蝴蝶機', 'ch', 'fd', 'iso', 'b', 'chest-fly'),
    'cable-fly': ('滑輪夾胸', '繩索飛鳥 纜繩夾胸', 'ch', 'fd', 'iso', 'b', 'chest-fly'),
    'incline-cable-fly': ('上斜滑輪夾胸', '上胸', 'ch', 'fd', 'iso', 'b', 'chest-fly'),
    'dumbbell-fly': ('啞鈴飛鳥', '啞鈴夾胸', 'ch', 'fd', 'iso', 'b', 'chest-fly'),
    'push-up': ('伏地挺身', '俯地挺身', 'ch', 'tr fd ab', 'hpu', 'b', 'push-up'),
    'weighted-push-up': ('負重伏地挺身', '', 'ch', 'tr fd ab', 'hpu', 'b', 'push-up'),
    'incline-push-up': ('上斜伏地挺身', '扶高伏地挺身', 'ch', 'tr fd ab', 'hpu', 'b', 'push-up'),
    'knee-push-up': ('跪姿伏地挺身', '', 'ch', 'tr fd ab', 'hpu', 'b', 'push-up'),
    'wide-push-up': ('寬距伏地挺身', '', 'ch', 'fd tr ab', 'hpu', 'b', 'push-up'),
    'decline-push-up': ('下斜伏地挺身', '腳抬高伏地挺身', 'ch', 'fd tr ab', 'hpu', 'b', 'push-up'),
    'archer-push-up': ('弓箭手伏地挺身', '', 'ch', 'tr fd ab', 'hpu', 'a', 'push-up'),
    'typewriter-push-up': ('打字機伏地挺身', '', 'ch', 'tr fd ab', 'hpu', 'a', 'push-up'),
    'explosive-push-up': ('爆發式伏地挺身', '擊掌伏地挺身', 'ch', 'tr fd ab', 'hpu', 'b', 'push-up'),
    'hindu-push-up': ('印度伏地挺身', '', 'ch', 'fd tr ab', 'hpu', 'b', 'push-up'),
    'wall-push-up': ('扶牆伏地挺身', '', 'ch', 'tr fd', 'hpu', 'b', 'push-up'),
    'chest-dip': ('胸部雙槓撐體', '雙槓撐體 胸', 'ch', 'tr fd', 'vpu', 'b', 'dip'),
    'seal-jack': ('海豹開合跳', '', 'ch', 'sd ca', 'cd', 'b', 'jumping-jack'),
    # 肩
    'overhead-press': ('槓鈴肩推', '站姿肩推 軍式推舉', 'fd', 'sd tr', 'vpu', 'b', 'overhead-press'),
    'seated-dumbbell-press': ('坐姿啞鈴肩推', '', 'fd', 'sd tr', 'vpu', 'b', 'overhead-press'),
    'standing-dumbbell-press': ('站姿啞鈴肩推', '', 'fd', 'sd tr ab', 'vpu', 'b', 'overhead-press'),
    'arnold-press': ('阿諾推舉', '', 'fd', 'sd tr', 'vpu', 'b', 'overhead-press'),
    'machine-shoulder-press': ('坐姿推肩機', '機械肩推', 'fd', 'sd tr', 'vpu', 'b', 'overhead-press'),
    'push-press': ('借力推', '推舉', 'fd', 'sd tr qu', 'vpu', 'b', 'overhead-press'),
    'landmine-press': ('地雷管推舉', '', 'fd', 'ch tr', 'vpu', 'u', 'landmine-press'),
    'pike-push-up': ('屈體伏地挺身', '派克伏地挺身', 'fd', 'tr sd', 'vpu', 'b', 'handstand-push-up'),
    'feet-elevated-pike-push-up': ('腳抬高屈體伏地挺身', '', 'fd', 'tr sd', 'vpu', 'b', 'handstand-push-up'),
    'wall-handstand-push-up': ('靠牆倒立推', '', 'fd', 'tr sd ab', 'vpu', 'b', 'handstand-push-up'),
    'handstand-push-up': ('倒立推', '倒立伏地挺身', 'fd', 'tr sd ab', 'vpu', 'b', 'handstand-push-up'),
    'wall-walk': ('靠牆倒立行走', '', 'fd', 'ab tr', 'co', 'b', 'handstand-push-up'),
    'lateral-raise': ('啞鈴側平舉', '側平舉', 'sd', 'tp', 'iso', 'b', 'lateral-raise'),
    'cable-lateral-raise': ('滑輪側平舉', '繩索側平舉', 'sd', 'tp', 'iso', 'u', 'lateral-raise'),
    'machine-lateral-raise': ('側平舉機', '機械側平舉', 'sd', 'tp', 'iso', 'b', 'lateral-raise'),
    'front-raise': ('啞鈴前平舉', '前平舉', 'fd', 'ch', 'iso', 'b', 'front-raise'),
    'cable-front-raise': ('滑輪前平舉', '', 'fd', 'ch', 'iso', 'b', 'front-raise'),
    'plate-front-raise': ('槓片前平舉', '', 'fd', 'ch', 'iso', 'b', 'front-raise'),
    'rear-delt-fly': ('啞鈴反向飛鳥', '後三角飛鳥', 'rd', 'ub', 'iso', 'b', 'rear-delt-fly'),
    'bent-over-rear-delt-raise': ('俯身後三角平舉', '', 'rd', 'ub', 'iso', 'b', 'rear-delt-fly'),
    'reverse-pec-deck': ('反向蝴蝶機', '反向夾胸 後三角機', 'rd', 'ub', 'iso', 'b', 'rear-delt-fly'),
    'cable-rear-delt-fly': ('滑輪反向飛鳥', '', 'rd', 'ub', 'iso', 'b', 'rear-delt-fly'),
    'face-pull': ('滑輪面拉', '臉拉 面拉', 'rd', 'ub tp', 'hpl', 'b', 'face-pull'),
    'banded-face-pull': ('彈力帶面拉', '', 'rd', 'ub tp', 'hpl', 'b', 'face-pull'),
    'band-pull-apart': ('彈力帶拉開', '', 'rd', 'ub', 'hpl', 'b', 'face-pull'),
    'upright-row': ('槓鈴直立划船', '直立划船', 'sd', 'tp bi', 'vpl', 'b', 'upright-row'),
    'battle-ropes': ('戰繩', '', 'fd', 'ab', 'cd', 'a', 'battle-ropes'),
    # 背
    'deadlift': ('傳統硬舉', '硬舉', 'hm', 'gl se ub fa', 'hg', 'b', 'deadlift'),
    'sumo-deadlift': ('相撲硬舉', '', 'gl', 'qu ad hm se', 'hg', 'b', 'deadlift'),
    'trap-bar-deadlift': ('六角槓硬舉', '六角槓', 'qu', 'gl hm se fa', 'hg', 'b', 'deadlift'),
    'dumbbell-sumo-deadlift': ('啞鈴相撲硬舉', '', 'gl', 'qu ad hm', 'hg', 'b', 'deadlift'),
    'rack-pull': ('架上拉', '局部硬舉', 'se', 'gl hm tp', 'hg', 'b', 'deadlift'),
    'barbell-row': ('槓鈴划船', '俯身槓鈴划船', 'la', 'ub rd bi', 'hpl', 'b', 'row'),
    'pendlay-row': ('潘德雷划船', '', 'la', 'ub rd bi', 'hpl', 'b', 'row'),
    't-bar-row': ('T 槓划船', 'T槓划船', 'la', 'ub rd bi', 'hpl', 'b', 'row'),
    'meadows-row': ('梅多斯划船', '', 'la', 'ub rd bi', 'hpl', 'u', 'row'),
    'dumbbell-bent-over-row': ('俯身啞鈴划船', '', 'la', 'ub rd bi', 'hpl', 'b', 'row'),
    'one-arm-dumbbell-row': ('單臂啞鈴划船', '啞鈴單手划船', 'la', 'ub bi', 'hpl', 'u', 'row'),
    'chest-supported-row': ('胸靠划船', '趴姿划船', 'ub', 'la rd bi', 'hpl', 'b', 'row'),
    'seated-row': ('坐姿滑輪划船', '坐姿划船', 'la', 'ub rd bi', 'hpl', 'b', 'row'),
    'single-arm-cable-row': ('單臂滑輪划船', '', 'la', 'ub rd bi', 'hpl', 'u', 'row'),
    'machine-row': ('坐姿划船機', '機械划船', 'la', 'ub bi', 'hpl', 'b', 'row'),
    'inverted-row': ('反向划船', '澳洲式引體向上', 'ub', 'la bi ab', 'hpl', 'b', 'row'),
    'doorway-row': ('門框划船', '', 'ub', 'la bi', 'hpl', 'b', 'row'),
    'towel-row': ('毛巾划船', '', 'ub', 'la bi fa', 'hpl', 'b', 'row'),
    'banded-row': ('彈力帶划船', '', 'la', 'ub bi', 'hpl', 'b', 'row'),
    'lat-pulldown': ('滑輪下拉', '高位下拉 背闊下拉', 'la', 'bi ub', 'vpl', 'b', 'pulldown'),
    'close-grip-lat-pulldown': ('窄握滑輪下拉', '', 'la', 'bi ub', 'vpl', 'b', 'pulldown'),
    'wide-grip-lat-pulldown': ('寬握滑輪下拉', '', 'la', 'bi ub', 'vpl', 'b', 'pulldown'),
    'banded-lat-pulldown': ('彈力帶下拉', '', 'la', 'bi', 'vpl', 'b', 'pulldown'),
    'straight-arm-pulldown': ('直臂下拉', '滑輪直臂下壓', 'la', 'tr', 'iso', 'b', 'pullover'),
    'pull-up': ('引體向上', '正手引體向上', 'la', 'bi ub', 'vpl', 'b', 'pull-up'),
    'weighted-pull-up': ('負重引體向上', '', 'la', 'bi ub', 'vpl', 'b', 'pull-up'),
    'assisted-pull-up': ('輔助引體向上', '輔助機', 'la', 'bi', 'vpl', 'b', 'pull-up'),
    'neutral-grip-pull-up': ('對握引體向上', '', 'la', 'bi ub', 'vpl', 'b', 'pull-up'),
    'negative-pull-up': ('離心引體向上', '負向引體向上', 'la', 'bi ub', 'vpl', 'b', 'pull-up'),
    'commando-pull-up': ('突擊隊引體向上', '', 'la', 'bi ab', 'vpl', 'a', 'pull-up'),
    'l-sit-pull-up': ('L 坐引體向上', '', 'la', 'bi ab', 'vpl', 'b', 'pull-up'),
    'towel-pull-up': ('毛巾引體向上', '', 'la', 'bi fa', 'vpl', 'b', 'pull-up'),
    'scapular-pull-up': ('肩胛引體向上', '', 'la', 'ub', 'vpl', 'b', 'pull-up'),
    'chin-up': ('反手引體向上', '反握引體向上', 'la', 'bi', 'vpl', 'b', 'chin-up'),
    'weighted-chin-up': ('負重反手引體向上', '', 'la', 'bi', 'vpl', 'b', 'chin-up'),
    'assisted-chin-up': ('輔助反手引體向上', '', 'la', 'bi', 'vpl', 'b', 'chin-up'),
    'dead-hang': ('懸吊', '被動懸吊', 'fa', 'la', 'co', 'b', 'hang'),
    'active-hang': ('主動懸吊', '', 'la', 'ub fa', 'co', 'b', 'hang'),
    'shrug': ('槓鈴聳肩', '聳肩', 'tp', 'fa', 'iso', 'b', 'shrug'),
    'dumbbell-shrug': ('啞鈴聳肩', '', 'tp', 'fa', 'iso', 'b', 'shrug'),
    'back-extension': ('背伸展', '羅馬椅挺身 山羊挺身', 'se', 'gl hm', 'hg', 'b', 'back-extension'),
    'glute-focused-back-extension': ('臀部主導背伸展', '', 'gl', 'hm se', 'hg', 'b', 'back-extension'),
    'reverse-hyperextension': ('反向背伸展', '', 'gl', 'hm se', 'hg', 'b', 'back-extension'),
    'superman': ('超人式', '', 'se', 'gl ub', 'co', 'b', 'superman'),
    'superman-hold': ('超人式靜止', '', 'se', 'gl ub', 'co', 'b', 'superman'),
    'prone-y-raise': ('俯臥 Y 字上舉', 'Y字舉', 'ub', 'rd tp', 'iso', 'b', 'prone-raise'),
    'prone-t-raise': ('俯臥 T 字上舉', 'T字舉', 'ub', 'rd', 'iso', 'b', 'prone-raise'),
    'reverse-snow-angel': ('反向雪天使', '', 'ub', 'rd se', 'iso', 'b', 'prone-raise'),
    'scapular-push-up': ('肩胛伏地挺身', '', 'ub', 'ch', 'hpu', 'b', 'push-up'),
    # 腿：蹲
    'squat': ('槓鈴深蹲', '深蹲 背蹲', 'qu gl', 'ad se ab', 'sq', 'b', 'squat'),
    'front-squat': ('前蹲', '槓鈴前蹲舉', 'qu', 'gl ab', 'sq', 'b', 'squat'),
    'hack-squat': ('哈克深蹲', '', 'qu', 'gl', 'sq', 'b', 'squat'),
    'smith-machine-squat': ('史密斯深蹲', '', 'qu gl', 'ab', 'sq', 'b', 'squat'),
    'goblet-squat': ('高腳杯深蹲', '', 'qu gl', 'ab', 'sq', 'b', 'squat'),
    'heel-elevated-goblet-squat': ('墊腳跟高腳杯深蹲', '', 'qu', 'gl', 'sq', 'b', 'squat'),
    'belt-squat': ('腰帶深蹲', '', 'qu', 'gl', 'sq', 'b', 'squat'),
    'landmine-squat': ('地雷管深蹲', '', 'qu', 'gl ab', 'sq', 'b', 'squat'),
    'dumbbell-sumo-squat': ('啞鈴相撲深蹲', '', 'gl ad', 'qu hm', 'sq', 'b', 'squat'),
    'bodyweight-squat': ('徒手深蹲', '空蹲', 'qu', 'gl hm', 'sq', 'b', 'squat'),
    'banded-squat': ('彈力帶深蹲', '', 'qu', 'gl abd', 'sq', 'b', 'squat'),
    'jump-squat': ('深蹲跳', '跳躍深蹲', 'qu', 'gl ca', 'cd', 'b', 'squat'),
    'wall-sit': ('靠牆蹲', '', 'qu', 'gl', 'sq', 'b', 'squat'),
    'leg-press': ('腿推', '腿部推蹬 倒蹬', 'qu', 'gl hm', 'sq', 'b', 'leg-press'),
    'leg-extension': ('腿伸展', '坐姿腿伸展', 'qu', '', 'iso', 'b', 'leg-extension'),
    'sissy-squat': ('西斯深蹲', '', 'qu', 'ab', 'iso', 'b', 'leg-extension'),
    'pistol-squat': ('單腳深蹲', '手槍蹲', 'qu', 'gl hm', 'lu', 'u', 'single-leg-squat'),
    'assisted-pistol-squat': ('輔助單腳深蹲', '', 'qu', 'gl', 'lu', 'u', 'single-leg-squat'),
    'shrimp-squat': ('蝦式深蹲', '', 'qu', 'gl', 'lu', 'u', 'single-leg-squat'),
    'skater-squat': ('溜冰者深蹲', '', 'qu', 'gl', 'lu', 'u', 'single-leg-squat'),
    'single-leg-box-squat': ('單腳箱上蹲', '', 'qu', 'gl', 'lu', 'u', 'single-leg-squat'),
    'step-down': ('下台階', '', 'qu', 'gl', 'lu', 'u', 'single-leg-squat'),
    'cossack-squat': ('哥薩克深蹲', '側蹲', 'qu ad', 'gl', 'lu', 'a', 'lateral-lunge'),
    # 腿：弓步
    'bulgarian-split-squat': ('保加利亞分腿蹲', '後腳抬高分腿蹲', 'qu gl', 'ad', 'lu', 'u', 'split-squat'),
    'smith-machine-bulgarian-split-squat': ('史密斯保加利亞分腿蹲', '', 'qu gl', 'ad', 'lu', 'u', 'split-squat'),
    'split-squat': ('分腿蹲', '', 'qu gl', 'ad', 'lu', 'u', 'split-squat'),
    'smith-machine-split-squat': ('史密斯分腿蹲', '', 'qu gl', '', 'lu', 'u', 'split-squat'),
    'front-foot-elevated-split-squat': ('前腳抬高分腿蹲', '', 'qu gl', 'ad', 'lu', 'u', 'split-squat'),
    'walking-lunge': ('行走弓步', '弓箭步走', 'qu gl', 'hm ad', 'lu', 'a', 'lunge'),
    'forward-lunge': ('前弓步', '弓箭步', 'qu gl', 'hm', 'lu', 'a', 'lunge'),
    'reverse-lunge': ('後弓步', '後跨步蹲', 'qu gl', 'hm', 'lu', 'a', 'lunge'),
    'smith-machine-reverse-lunge': ('史密斯後弓步', '', 'qu gl', 'hm', 'lu', 'u', 'lunge'),
    'deficit-reverse-lunge': ('墊高後弓步', '', 'gl', 'qu hm', 'lu', 'u', 'lunge'),
    'lateral-lunge': ('側弓步', '', 'qu ad', 'gl', 'lu', 'a', 'lateral-lunge'),
    'dumbbell-lateral-lunge': ('啞鈴側弓步', '', 'qu ad', 'gl', 'lu', 'a', 'lateral-lunge'),
    'curtsy-lunge': ('交叉後弓步', '屈膝禮弓步', 'gl', 'qu abd', 'lu', 'a', 'lunge'),
    'dumbbell-curtsy-lunge': ('啞鈴交叉後弓步', '', 'gl', 'qu abd', 'lu', 'a', 'lunge'),
    'step-up': ('登階', '上台階', 'qu gl', '', 'lu', 'u', 'step-up'),
    # 腿：髖伸與腿後
    'romanian-deadlift': ('羅馬尼亞硬舉', 'RDL 直腿硬舉', 'hm gl', 'se', 'hg', 'b', 'romanian-deadlift'),
    'dumbbell-romanian-deadlift': ('啞鈴羅馬尼亞硬舉', '', 'hm gl', 'se', 'hg', 'b', 'romanian-deadlift'),
    'kettlebell-romanian-deadlift': ('壺鈴羅馬尼亞硬舉', '', 'hm gl', 'se', 'hg', 'b', 'romanian-deadlift'),
    'smith-machine-romanian-deadlift': ('史密斯羅馬尼亞硬舉', '', 'hm gl', 'se', 'hg', 'b', 'romanian-deadlift'),
    'landmine-romanian-deadlift': ('地雷管羅馬尼亞硬舉', '', 'hm gl', 'se', 'hg', 'b', 'romanian-deadlift'),
    'single-leg-romanian-deadlift': ('單腳羅馬尼亞硬舉', '', 'hm gl', 'abd', 'hg', 'u', 'romanian-deadlift'),
    'good-morning': ('早安體前屈', '早安式', 'hm', 'gl se', 'hg', 'b', 'romanian-deadlift'),
    'cable-pull-through': ('滑輪髖伸', '繩索後拉 Pull Through', 'gl', 'hm se', 'hg', 'b', 'hip-hinge'),
    'kettlebell-swing': ('壺鈴擺盪', '', 'gl hm', 'se ab', 'hg', 'b', 'hip-hinge'),
    'hip-airplane': ('髖關節飛機', '', 'gl', 'abd hm', 'co', 'u', 'hip-hinge'),
    'leg-curl': ('腿彎舉', '俯臥腿彎舉', 'hm', 'ca', 'iso', 'b', 'leg-curl'),
    'lying-leg-curl': ('俯臥腿彎舉機', '', 'hm', 'ca', 'iso', 'b', 'leg-curl'),
    'seated-leg-curl': ('坐姿腿彎舉', '', 'hm', 'ca', 'iso', 'b', 'leg-curl'),
    'nordic-hamstring-curl': ('北歐腿彎舉', '北歐式', 'hm', 'gl', 'iso', 'b', 'leg-curl'),
    'towel-hamstring-curl': ('毛巾腿彎舉', '', 'hm', 'gl', 'iso', 'b', 'leg-curl'),
    'stability-ball-hamstring-curl': ('瑜伽球腿彎舉', '抗力球腿彎舉', 'hm', 'gl', 'iso', 'b', 'leg-curl'),
    'lying-hamstring-walkout': ('臀橋腳跟走出', '', 'hm', 'gl', 'iso', 'b', 'leg-curl'),
    'hip-thrust': ('槓鈴臀推', '臀推', 'gl', 'hm', 'hg', 'b', 'hip-thrust'),
    'dumbbell-hip-thrust': ('啞鈴臀推', '', 'gl', 'hm', 'hg', 'b', 'hip-thrust'),
    'smith-machine-hip-thrust': ('史密斯臀推', '', 'gl', 'hm', 'hg', 'b', 'hip-thrust'),
    'banded-hip-thrust': ('彈力帶臀推', '', 'gl', 'hm abd', 'hg', 'b', 'hip-thrust'),
    'glute-bridge': ('臀橋', '', 'gl', 'hm', 'hg', 'b', 'glute-bridge'),
    'barbell-glute-bridge': ('槓鈴臀橋', '', 'gl', 'hm', 'hg', 'b', 'glute-bridge'),
    'dumbbell-glute-bridge': ('啞鈴臀橋', '', 'gl', 'hm', 'hg', 'b', 'glute-bridge'),
    'single-leg-glute-bridge': ('單腳臀橋', '', 'gl', 'hm', 'hg', 'u', 'glute-bridge'),
    'glute-bridge-march': ('臀橋踏步', '', 'gl', 'hm ab', 'hg', 'a', 'glute-bridge'),
    'banded-glute-bridge': ('彈力帶臀橋', '', 'gl', 'hm abd', 'hg', 'b', 'glute-bridge'),
    'frog-pump': ('青蛙臀橋', '', 'gl', 'ad', 'hg', 'b', 'glute-bridge'),
    'banded-frog-pump': ('彈力帶青蛙臀橋', '', 'gl', 'abd', 'hg', 'b', 'glute-bridge'),
    'cable-kickback': ('滑輪後踢', '繩索後踢腿', 'gl', 'hm', 'iso', 'u', 'kickback'),
    'machine-glute-kickback': ('後踢腿機', '臀部後踢機', 'gl', 'hm', 'iso', 'u', 'kickback'),
    'donkey-kick': ('驢踢', '跪姿後踢腿', 'gl', 'hm', 'iso', 'u', 'kickback'),
    'banded-donkey-kick': ('彈力帶驢踢', '', 'gl', 'hm', 'iso', 'u', 'kickback'),
    'banded-kickback': ('彈力帶後踢', '', 'gl', 'hm', 'iso', 'u', 'kickback'),
    # 髖外展與內收
    'hip-abduction-machine': ('髖外展機', '坐姿外展機 臀中', 'abd', 'gl', 'iso', 'b', 'hip-abduction'),
    'cable-standing-hip-abduction': ('滑輪站姿髖外展', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'banded-standing-hip-abduction': ('彈力帶站姿髖外展', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'banded-seated-hip-abduction': ('彈力帶坐姿髖外展', '', 'abd', 'gl', 'iso', 'b', 'hip-abduction'),
    'side-lying-hip-abduction': ('側躺抬腿', '側臥髖外展', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'side-lying-leg-raise': ('側臥抬腿', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'clamshell': ('蚌殼式', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'banded-clamshell': ('彈力帶蚌殼式', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'fire-hydrant': ('消防栓', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'banded-fire-hydrant': ('彈力帶消防栓', '', 'abd', 'gl', 'iso', 'u', 'hip-abduction'),
    'banded-lateral-walk': ('彈力帶側走', '怪獸走', 'abd', 'gl qu', 'iso', 'a', 'hip-abduction'),
    'banded-monster-walk': ('彈力帶怪獸走', '', 'abd', 'gl qu', 'iso', 'a', 'hip-abduction'),
    'hip-adduction-machine': ('髖內收機', '坐姿內收機 大腿內側', 'ad', '', 'iso', 'b', 'hip-adduction'),
    'cable-standing-hip-adduction': ('滑輪站姿髖內收', '', 'ad', 'ab', 'iso', 'u', 'hip-adduction'),
    'copenhagen-plank': ('哥本哈根棒式', '', 'ad', 'ob ab', 'co', 'u', 'hip-adduction'),
    # 小腿
    'standing-calf-raise': ('站姿提踵', '站姿小腿上提', 'ca', '', 'iso', 'b', 'calf-raise'),
    'seated-calf-raise': ('坐姿提踵', '坐姿小腿上提', 'ca', '', 'iso', 'b', 'calf-raise'),
    'donkey-calf-raise': ('驢式提踵', '', 'ca', '', 'iso', 'b', 'calf-raise'),
    'leg-press-calf-raise': ('腿推機提踵', '', 'ca', '', 'iso', 'b', 'calf-raise'),
    'calf-raise': ('徒手提踵', '墊腳尖', 'ca', '', 'iso', 'b', 'calf-raise'),
    'single-leg-calf-raise': ('單腳提踵', '', 'ca', '', 'iso', 'u', 'calf-raise'),
    # 二頭與前臂
    'bicep-curl': ('啞鈴彎舉', '二頭彎舉', 'bi', 'fa', 'iso', 'b', 'curl'),
    'hammer-curl': ('錘式彎舉', '', 'bi', 'fa', 'iso', 'b', 'hammer-curl'),
    'rope-hammer-curl': ('繩索錘式彎舉', '', 'bi', 'fa', 'iso', 'b', 'hammer-curl'),
    'preacher-curl': ('牧師椅彎舉', '斜板彎舉', 'bi', 'fa', 'iso', 'b', 'curl'),
    'cable-curl': ('滑輪彎舉', '繩索彎舉', 'bi', 'fa', 'iso', 'b', 'curl'),
    'incline-dumbbell-curl': ('上斜啞鈴彎舉', '', 'bi', 'fa', 'iso', 'b', 'curl'),
    'concentration-curl': ('集中彎舉', '', 'bi', 'fa', 'iso', 'u', 'curl'),
    'ez-bar-curl': ('EZ 槓彎舉', '曲槓彎舉', 'bi', 'fa', 'iso', 'b', 'curl'),
    'spider-curl': ('蜘蛛彎舉', '', 'bi', 'fa', 'iso', 'b', 'curl'),
    'drag-curl': ('拖曳彎舉', '', 'bi', 'fa', 'iso', 'b', 'curl'),
    'reverse-curl': ('反握彎舉', '', 'fa', 'bi', 'iso', 'b', 'reverse-curl'),
    'wrist-curl': ('腕屈', '手腕彎舉', 'fa', '', 'iso', 'b', 'wrist-curl'),
    'wrist-extension': ('腕伸', '反握手腕彎舉', 'fa', '', 'iso', 'b', 'wrist-curl'),
    'farmer-carry': ('農夫走路', '農夫行走', 'fa', 'tp ab ob', 'cy', 'b', 'carry'),
    # 三頭
    'tricep-pushdown': ('滑輪三頭下壓', '三頭下壓', 'tr', '', 'iso', 'b', 'triceps-pushdown'),
    'rope-tricep-pushdown': ('繩索三頭下壓', '', 'tr', '', 'iso', 'b', 'triceps-pushdown'),
    'overhead-tricep-extension': ('滑輪過頭三頭伸展', '', 'tr', '', 'iso', 'b', 'overhead-triceps'),
    'dumbbell-overhead-tricep-extension': ('啞鈴過頭三頭伸展', '', 'tr', '', 'iso', 'b', 'overhead-triceps'),
    'single-arm-dumbbell-tricep-extension': ('單臂啞鈴過頭三頭伸展', '', 'tr', '', 'iso', 'u', 'overhead-triceps'),
    'skull-crusher': ('仰臥三頭伸展', '碎顱者', 'tr', '', 'iso', 'b', 'skull-crusher'),
    'dumbbell-skull-crusher': ('啞鈴仰臥三頭伸展', '', 'tr', '', 'iso', 'b', 'skull-crusher'),
    'single-dumbbell-skullcrusher': ('單啞鈴仰臥三頭伸展', '', 'tr', '', 'iso', 'b', 'skull-crusher'),
    'tricep-kickback': ('啞鈴三頭後伸', '三頭後踢', 'tr', '', 'iso', 'b', 'triceps-kickback'),
    'close-grip-bench-press': ('窄握臥推', '', 'tr', 'ch fd', 'hpu', 'b', 'bench-press'),
    'diamond-push-up': ('鑽石伏地挺身', '窄距伏地挺身', 'tr', 'ch fd', 'hpu', 'b', 'push-up'),
    'dip': ('雙槓撐體', '撐體', 'tr', 'ch fd', 'vpu', 'b', 'dip'),
    'weighted-dip': ('負重雙槓撐體', '', 'tr', 'ch fd', 'vpu', 'b', 'dip'),
    'assisted-dip': ('輔助雙槓撐體', '', 'tr', 'ch', 'vpu', 'b', 'dip'),
    'bench-dip': ('板凳撐體', '椅子撐體', 'tr', 'fd', 'vpu', 'b', 'dip'),
    'chair-dip': ('椅子撐體', '', 'tr', 'fd', 'vpu', 'b', 'dip'),
    'crab-walk': ('螃蟹走', '', 'tr', 'gl ab', 'cd', 'a', 'crawl'),
    # 核心
    'plank': ('棒式', '平板支撐', 'ab', 'ob fd', 'co', 'b', 'plank'),
    'side-plank': ('側棒式', '側平板支撐', 'ob', 'ab abd', 'co', 'u', 'side-plank'),
    'side-plank-hip-dip': ('側棒式髖下沉', '', 'ob', 'ab', 'co', 'u', 'side-plank'),
    'plank-shoulder-tap': ('棒式拍肩', '', 'ab', 'ob fd', 'co', 'a', 'plank'),
    'push-up-shoulder-tap': ('伏地挺身拍肩', '', 'ab', 'ch fd tr', 'co', 'a', 'plank'),
    'plank-jack': ('棒式開合跳', '', 'ab', 'fd', 'cd', 'b', 'plank'),
    'bear-plank': ('熊式棒式', '', 'ab', 'qu fd', 'co', 'b', 'plank'),
    'bear-crawl': ('熊爬', '', 'ab', 'fd qu', 'cd', 'a', 'crawl'),
    'hollow-body-hold': ('空心支撐', '', 'ab', '', 'co', 'b', 'hollow-body'),
    'hollow-rock': ('空心搖擺', '', 'ab', '', 'co', 'b', 'hollow-body'),
    'l-sit-hold': ('L 坐', '', 'ab', 'tr', 'co', 'b', 'hollow-body'),
    'dead-bug': ('死蟲式', '', 'ab', 'ob', 'co', 'a', 'dead-bug'),
    'banded-dead-bug': ('彈力帶死蟲式', '', 'ab', 'ob', 'co', 'a', 'dead-bug'),
    'bird-dog': ('鳥狗式', '', 'ab', 'gl se', 'co', 'a', 'bird-dog'),
    'crunch': ('捲腹', '仰臥捲腹', 'ab', '', 'co', 'b', 'crunch'),
    'weighted-crunch': ('負重捲腹', '', 'ab', '', 'co', 'b', 'crunch'),
    'cable-crunch': ('滑輪捲腹', '跪姿繩索捲腹', 'ab', '', 'co', 'b', 'crunch'),
    'reverse-crunch': ('反向捲腹', '', 'ab', '', 'co', 'b', 'crunch'),
    'bicycle-crunch': ('腳踏車捲腹', '', 'ab', 'ob', 'co', 'a', 'crunch'),
    'decline-sit-up': ('下斜仰臥起坐', '仰臥起坐', 'ab', '', 'co', 'b', 'crunch'),
    'toe-touch': ('仰臥觸腳尖', '', 'ab', '', 'co', 'b', 'crunch'),
    'heel-tap': ('仰臥觸腳跟', '', 'ob', 'ab', 'co', 'a', 'crunch'),
    'v-up': ('V 字起身', 'V字捲腹', 'ab', '', 'co', 'b', 'crunch'),
    'seated-knee-tuck': ('坐姿收腿', '', 'ab', '', 'co', 'b', 'leg-raise'),
    'hanging-leg-raise': ('懸垂舉腿', '懸吊抬腿', 'ab', 'fa', 'co', 'b', 'leg-raise'),
    'hanging-knee-raise': ('懸垂屈膝舉腿', '', 'ab', 'fa', 'co', 'b', 'leg-raise'),
    'captains-chair-knee-raise': ('艦長椅抬膝', '羅馬椅抬膝', 'ab', '', 'co', 'b', 'leg-raise'),
    'lying-leg-raise': ('仰臥抬腿', '', 'ab', '', 'co', 'b', 'leg-raise'),
    'flutter-kick': ('交替踢腿', '仰臥剪刀腳', 'ab', '', 'co', 'a', 'leg-raise'),
    'dragon-flag': ('龍旗', '', 'ab', 'la', 'co', 'b', 'leg-raise'),
    'ab-wheel': ('健腹輪', '滾輪', 'ab', 'la', 'co', 'b', 'rollout'),
    'russian-twist': ('俄羅斯轉體', '', 'ob', 'ab', 'co', 'a', 'rotation'),
    'weighted-russian-twist': ('負重俄羅斯轉體', '', 'ob', 'ab', 'co', 'a', 'rotation'),
    'cable-woodchop': ('滑輪伐木', '繩索伐木', 'ob', 'ab', 'co', 'u', 'rotation'),
    'banded-woodchop': ('彈力帶伐木', '', 'ob', 'ab', 'co', 'u', 'rotation'),
    'pallof-press': ('Pallof 抗旋轉推', '抗旋轉推', 'ob', 'ab', 'co', 'u', 'anti-rotation'),
    'half-kneeling-pallof-press': ('半跪姿 Pallof 推', '', 'ob', 'ab gl', 'co', 'u', 'anti-rotation'),
    'cable-pallof-hold': ('Pallof 靜止', '', 'ob', 'ab', 'co', 'u', 'anti-rotation'),
    'banded-pallof-press': ('彈力帶 Pallof 推', '', 'ob', 'ab', 'co', 'u', 'anti-rotation'),
    'dumbbell-side-bend': ('啞鈴側彎', '', 'ob', '', 'co', 'u', 'side-bend'),
    'inchworm': ('尺蠖爬', '', 'ab', 'fd hm', 'co', 'b', 'crawl'),
    'mountain-climber': ('登山者', '', 'ab', 'fd qu', 'cd', 'a', 'mountain-climber'),
    # 體能與有氧
    'burpee': ('波比跳', '波比', 'qu', 'ch fd ab', 'cd', 'b', 'burpee'),
    'half-burpee': ('半波比', '', 'ab', 'qu fd', 'cd', 'b', 'burpee'),
    'squat-thrust': ('深蹲推', '', 'ab', 'qu fd', 'cd', 'b', 'burpee'),
    'sprawl': ('防摔撲地', '', 'qu', 'ab fd', 'cd', 'b', 'burpee'),
    'high-knees': ('高抬腿', '', 'qu', 'ab', 'cd', 'a', 'high-knees'),
    'jumping-jack': ('開合跳', '', 'qu', 'sd ca', 'cd', 'b', 'jumping-jack'),
    'skater-hop': ('溜冰者跳', '', 'gl', 'qu ca', 'cd', 'a', 'skater-hop'),
    'lateral-shuffle': ('側向滑步', '', 'qu', 'gl ca', 'cd', 'a', 'shuffle'),
    'fast-feet': ('快速小碎步', '', 'ca', 'qu', 'cd', 'a', 'shuffle'),
    'jump-rope': ('跳繩', '', 'ca', 'fd', 'cd', 'b', 'jump-rope'),
    'running': ('跑步', '', 'qu', 'hm ca gl', 'cd', 'a', 'running'),
    'treadmill-incline-walk': ('跑步機爬坡走', '坡度走', 'gl', 'ca hm', 'cd', 'a', 'walking'),
    'walking': ('健走', '走路', 'qu', 'ca gl', 'cd', 'a', 'walking'),
    'hiking': ('健行', '登山', 'qu', 'gl ca', 'cd', 'a', 'walking'),
    'cycling': ('飛輪', '腳踏車 騎車', 'qu', 'gl ca', 'cd', 'a', 'cycling'),
    'assault-bike': ('風扇車', '風阻單車', 'qu', 'fd', 'cd', 'a', 'cycling'),
    'elliptical': ('滑步機', '橢圓機', 'qu', 'gl', 'cd', 'a', 'elliptical'),
    'stair-climber': ('爬梯機', '', 'qu', 'gl ca', 'cd', 'a', 'stair-climber'),
    'rowing': ('划船機', '', 'la', 'qu ub', 'cd', 'b', 'rowing'),
    'skierg': ('滑雪機', 'SkiErg', 'la', 'tr ab', 'cd', 'b', 'skierg'),
    'swimming': ('游泳', '', 'la', 'fd', 'cd', 'a', 'swimming'),
}


def build(source: pathlib.Path) -> None:
    manifest = json.loads((source / 'packages/workout-guide/manifest.json').read_text())
    by_slug = {entry['slug']: entry for entry in manifest}
    missing = sorted(set(C) - set(by_slug))
    if missing:
        sys.exit(f'Not in Workout Guide: {missing}')
    frames_dir = OUT / 'frames'
    frames_dir.mkdir(parents=True, exist_ok=True)
    for old in frames_dir.glob('*.webp'):
        old.unlink()

    exercises = []
    with tempfile.TemporaryDirectory() as tmp:
        for slug, (name, aliases, primary, secondary, pattern, side, family) in C.items():
            entry = by_slug[slug]
            exercise_id = KEPT_IDS.get(slug, slug)
            frames = []
            for frame in entry['frames']:
                svg = source / 'packages/workout-guide' / frame['path']
                png = pathlib.Path(tmp) / 'frame.png'
                webp = frames_dir / f"{exercise_id}-{frame['index']}.webp"
                subprocess.run(
                    ['rsvg-convert', '-w', str(FRAME_PIXELS), '-h', str(FRAME_PIXELS),
                     str(svg), '-o', str(png)], check=True)
                subprocess.run(
                    ['cwebp', '-quiet', '-q', str(WEBP_QUALITY), '-alpha_q', str(WEBP_QUALITY),
                     str(png), '-o', str(webp)], check=True)
                frames.append(f'assets/exercises/frames/{webp.name}')
            exercises.append({
                'id': exercise_id,
                'name': name,
                'aliases': [a for a in [entry['name'], *aliases.split()] if a],
                'equipment': EQUIPMENT_OVERRIDE.get(slug, EQUIPMENT[entry['equipment']]),
                'primaryMuscles': [MUSCLES[m] for m in primary.split()],
                'secondaryMuscles': [MUSCLES[m] for m in secondary.split()],
                'pattern': PATTERNS[pattern],
                'laterality': LATERALITY[side],
                'family': family,
                'trackingType': TRACKING[entry['exerciseType']],
                'frames': frames,
            })

    (OUT / 'catalogue.json').write_text(
        json.dumps({
            'source': 'https://github.com/bryllim/workout-guide',
            'frameLicense': 'CC BY-SA 4.0',
            'exercises': exercises,
        }, ensure_ascii=False, indent=1) + '\n')
    print(f'{len(exercises)} exercises')


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build(pathlib.Path(sys.argv[1]))
