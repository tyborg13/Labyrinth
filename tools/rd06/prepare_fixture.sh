#!/bin/sh
set -eu
mkdir -p /private/tmp/labyrinth_codex/rd-06
python3 tools/inspection_fixture.py --task-id rd-06 --run-id rd-06-combat --manifest /private/tmp/labyrinth_codex/rd-06/combat.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,quick_stab,brace --player-position 2:4 --enemy-types crawler,warden,crawler,crawler,crawler --enemy-positions 3:5,5:6,6:2,7:3,1:1 --umbra-stage clear --summary 'rd-06 startup pillar occlusion'
python3 tools/inspection_fixture.py --task-id rd-06 --run-id rd-06-briefing --manifest /private/tmp/labyrinth_codex/rd-06/briefing.json --scenario pre_battle --seed 7262026 --room-coord 1,0 --hand dull_bolt,quick_stab,brace --summary 'rd-06 real briefing entry'
