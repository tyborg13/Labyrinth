#!/bin/sh
set -eu
mkdir -p /private/tmp/labyrinth_codex/rd-03/feedback1
python3 tools/inspection_fixture.py --task-id rd-03 --run-id rd-03-feedback1-combat --manifest /private/tmp/labyrinth_codex/rd-03/feedback1/combat.json --scenario combat --seed 7262026 --room-coord 1,0 --hand dull_bolt,quick_stab,whirlwind_slash,bloody_lunge,brace,ember_rain --player-position 3:6 --enemy-types crawler,warden,crawler,crawler,crawler --enemy-positions 3:5,5:6,6:2,7:3,1:1 --trap-elements fire --trap-positions 4:6 --terrain wooden_box@1:7 --umbra-stage clear --summary 'rd-03 five-foe aim focus'
python3 tools/inspection_fixture.py --task-id rd-03 --run-id rd-03-feedback1-dragon --manifest /private/tmp/labyrinth_codex/rd-03/feedback1/dragon.json --scenario dragon --dragon-id zekarion --hand quick_stab --player-position 3:4 --umbra-stage clear --summary 'rd-03 Zekarion melee focus'
