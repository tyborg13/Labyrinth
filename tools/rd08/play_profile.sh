#!/bin/sh
set -eu
: "${RD08_PROFILE_HOME:?Set RD08_PROFILE_HOME to the original HOME before invoking the runner}"
RD08_PROFILE="$RD08_PROFILE_HOME/Library/Application Support/Escape the Umbra Playtest rd-08"
RD08_SOURCE="$RD08_PROFILE_HOME/Library/Application Support/Escape the Umbra/steam/76561198007239340"
if [ ! -d "$RD08_PROFILE" ]; then
    # Stage the whole new profile before publishing it; source files are read only.
    RD08_STAGING=$(mktemp -d "$RD08_PROFILE_HOME/Library/Application Support/.rd08-profile.XXXXXX")
    trap 'rm -rf "$RD08_STAGING"' EXIT HUP INT TERM
    for RD08_FILE in progression.json settings.json current_run.save; do
        cp "$RD08_SOURCE/$RD08_FILE" "$RD08_STAGING/$RD08_FILE"
    done
    mv "$RD08_STAGING" "$RD08_PROFILE"
    trap - EXIT HUP INT TERM
fi
exec env -u LABYRINTH_TASK_ID -u APPDATA -u LOCALAPPDATA -u XDG_DATA_HOME \
    -u XDG_CONFIG_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
    HOME="$RD08_PROFILE_HOME" LABYRINTH_USER_DIR_NAME='Escape the Umbra Playtest rd-08' \
    godot --log-file /private/tmp/labyrinth_codex/rd-08/play.log "$@"
