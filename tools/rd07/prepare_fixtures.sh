#!/bin/sh
set -eu
mkdir -p /private/tmp/labyrinth_codex/rd-07
python3 tools/inspection_fixture.py --task-id rd-07 --run-id rd-07-combat --manifest /private/tmp/labyrinth_codex/rd-07/combat.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,ember_rain,sidestep_slash,brace --player-position 2:3 --enemy-types crawler,warden,crawler,crawler,crawler --enemy-positions 3:3,5:5,4:3,6:3,3:5 --terrain wooden_box@3:4 --umbra-stage clear --summary 'rd-07 board UI five foes and Health prop'
python3 tools/inspection_fixture.py --task-id rd-07 --run-id rd-07-dragon --manifest /private/tmp/labyrinth_codex/rd-07/dragon.json --scenario dragon --dragon-id zekarion --hand quick_stab,brace --player-position 3:4 --umbra-stage clear --summary 'rd-07 Zekarion real arena board UI'
