#!/bin/sh
# Owner-only windowed launch. The outer task runner keeps process supervision
# and logs; restore the caller's actual home and normal profile namespace.
set -eu
: "${RD05_NORMAL_HOME:?Set RD05_NORMAL_HOME to the caller's HOME before the task runner}"
exec env -u LABYRINTH_TASK_ID -u LABYRINTH_USER_DIR_NAME -u LABYRINTH_DISABLE_STEAM \
  -u APPDATA -u LOCALAPPDATA -u XDG_DATA_HOME -u XDG_CONFIG_HOME \
  -u XDG_CACHE_HOME -u XDG_STATE_HOME HOME="$RD05_NORMAL_HOME" \
  godot --log-file /private/tmp/labyrinth_codex/rd-05/play.log "$@"
