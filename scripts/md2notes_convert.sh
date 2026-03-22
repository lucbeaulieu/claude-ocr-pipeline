#!/bin/bash
set -euo pipefail
MD_FILE="$1"
NOTE_NAME=$(basename "$MD_FILE" .md)
exec /usr/bin/python3 "$HOME/Library/Scripts/md2notes_convert.py" "$MD_FILE" "$NOTE_NAME"
