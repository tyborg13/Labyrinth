#!/bin/sh
set -eu

launcher=$0
if [ -L "$launcher" ]; then
    target=$(readlink "$launcher")
    case "$target" in
        /*) launcher=$target ;;
        *) launcher=$(dirname "$launcher")/$target ;;
    esac
fi
cd "$(dirname "$launcher")/../.."
exec python3 tools/scn01/census.py --both "$@"
