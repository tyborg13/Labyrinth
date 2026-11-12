#!/bin/sh
# Owner-only. Restore the caller's real HOME while keeping a separate profile.
set -eu
: "${RD07_PROFILE_HOME:?Set RD07_PROFILE_HOME before invoking the task runner}"
exec env -u LABYRINTH_TASK_ID -u APPDATA -u LOCALAPPDATA -u XDG_DATA_HOME \
  -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
  HOME="$RD07_PROFILE_HOME" LABYRINTH_USER_DIR_NAME='Escape the Umbra Playtest rd-07' \
  godot --log-file /private/tmp/labyrinth_codex/rd-07/play.log "$@"
