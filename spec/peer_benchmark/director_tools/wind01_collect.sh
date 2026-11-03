#!/bin/zsh
# collect.sh <out-dir>: copy the newest wind01 probe captures and delete the probe home
S=/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad
H=$(ls -dt /private/tmp/labyrinth-godot-home/wind-01-*wind01_capture_probe-1 | head -1)
mkdir -p "$S/wind01/$1"
cp -r "$H/Library/Application Support/"*/wind01-captures/* "$S/wind01/$1/"
rm -rf "$H"
