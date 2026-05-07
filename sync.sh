#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/scripts"
exec python3 -m bb_sync "$@"
