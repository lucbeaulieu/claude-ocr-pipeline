#!/bin/bash
set -euo pipefail
JSON_FILE="$1"
exec /usr/bin/python3 "$HOME/Library/Scripts/tasks2reminders_convert.py" "$JSON_FILE"
