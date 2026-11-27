#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
exec python3 -B tools/tut03/record.py "$@"
