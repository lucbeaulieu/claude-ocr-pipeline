#!/bin/bash
# ══════════════════════════════════════════════════════════════════
# install_pipeline.sh
# One-command installer for the Claude OCR → Notes & Reminders pipeline
# Run from Terminal: bash ~/Downloads/install_pipeline.sh
# ══════════════════════════════════════════════════════════════════
set -euo pipefail

USERNAME=$(whoami)
HOME_DIR="$HOME"
SCRIPTS="$HOME_DIR/Library/Scripts"
AGENTS="$HOME_DIR/Library/LaunchAgents"
LOGS="$HOME_DIR/Library/Logs"
NOTES_DIR="$HOME_DIR/Documents/Claude-OCR-Notes"
TASKS_DIR="$HOME_DIR/Documents/Claude-OCR-Tasks"
DOWNLOADS="$HOME_DIR/Downloads"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Claude OCR Pipeline — Installation                  ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# 1. Create directories
echo "▸ Creating watch folders..."
mkdir -p "$NOTES_DIR" "$TASKS_DIR" "$SCRIPTS" "$AGENTS" "$LOGS"
echo "  ✓ ~/Documents/Claude-OCR-Notes/"
echo "  ✓ ~/Documents/Claude-OCR-Tasks/"

# 2. Copy scripts
echo ""
echo "▸ Installing scripts..."
cp "$DOWNLOADS/md2notes_convert.py"           "$SCRIPTS/"
cp "$DOWNLOADS/md2notes_convert.sh"           "$SCRIPTS/"
cp "$DOWNLOADS/md2notes_watcher.swift"        "$SCRIPTS/"
cp "$DOWNLOADS/tasks2reminders_convert.py"    "$SCRIPTS/"
cp "$DOWNLOADS/tasks2reminders_convert.sh"    "$SCRIPTS/"
cp "$DOWNLOADS/tasks2reminders_watcher.swift" "$SCRIPTS/"
chmod +x "$SCRIPTS/md2notes_convert.sh"
chmod +x "$SCRIPTS/tasks2reminders_convert.sh"
echo "  ✓ All scripts copied to ~/Library/Scripts/"

# 3. Compile Swift watchers
echo ""
echo "▸ Compiling md2notes_watcher (this takes ~30-60 seconds)..."
swiftc -O \
    -o "$SCRIPTS/md2notes_watcher" \
    "$SCRIPTS/md2notes_watcher.swift" \
    -framework Foundation \
    -framework CoreServices 2>&1 | grep -v "^$" || true
echo "  ✓ md2notes_watcher compiled"

echo ""
echo "▸ Compiling tasks2reminders_watcher (this takes ~30-60 seconds)..."
swiftc -O \
    -o "$SCRIPTS/tasks2reminders_watcher" \
    "$SCRIPTS/tasks2reminders_watcher.swift" \
    -framework Foundation \
    -framework CoreServices 2>&1 | grep -v "^$" || true
echo "  ✓ tasks2reminders_watcher compiled"

# 4. Write personalized plist files
echo ""
echo "▸ Creating LaunchAgent plists..."

cat > "$AGENTS/com.${USERNAME}.md2notes.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.${USERNAME}.md2notes</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPTS}/md2notes_watcher</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOGS}/md2notes_watcher.log</string>
    <key>StandardErrorPath</key>
    <string>${LOGS}/md2notes_watcher_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME_DIR}</string>
    </dict>
</dict>
</plist>
PLIST

cat > "$AGENTS/com.${USERNAME}.tasks2reminders.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.${USERNAME}.tasks2reminders</string>
    <key>ProgramArguments</key>
    <array>
        <string>${SCRIPTS}/tasks2reminders_watcher</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${LOGS}/tasks2reminders_watcher.log</string>
    <key>StandardErrorPath</key>
    <string>${LOGS}/tasks2reminders_watcher_error.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        <key>HOME</key>
        <string>${HOME_DIR}</string>
    </dict>
</dict>
</plist>
PLIST
echo "  ✓ com.${USERNAME}.md2notes.plist"
echo "  ✓ com.${USERNAME}.tasks2reminders.plist"

# 5. Load LaunchAgents
echo ""
echo "▸ Loading LaunchAgents..."
launchctl unload "$AGENTS/com.${USERNAME}.md2notes.plist" 2>/dev/null || true
launchctl load   "$AGENTS/com.${USERNAME}.md2notes.plist"
launchctl unload "$AGENTS/com.${USERNAME}.tasks2reminders.plist" 2>/dev/null || true
launchctl load   "$AGENTS/com.${USERNAME}.tasks2reminders.plist"
sleep 2

# 6. Verify
echo ""
echo "▸ Verifying agents..."
MD_STATUS=$(launchctl list | grep "com.${USERNAME}.md2notes" | awk '{print $1}')
TR_STATUS=$(launchctl list | grep "com.${USERNAME}.tasks2reminders" | awk '{print $1}')

if [[ "$MD_STATUS" != "-" && -n "$MD_STATUS" ]]; then
    echo "  ✓ md2notes watcher running (PID $MD_STATUS)"
else
    echo "  ✗ md2notes watcher NOT running — check $LOGS/md2notes_watcher_error.log"
fi

if [[ "$TR_STATUS" != "-" && -n "$TR_STATUS" ]]; then
    echo "  ✓ tasks2reminders watcher running (PID $TR_STATUS)"
else
    echo "  ✗ tasks2reminders watcher NOT running — check $LOGS/tasks2reminders_watcher_error.log"
fi

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║  Installation complete!                              ║"
echo "╠══════════════════════════════════════════════════════╣"
echo "║  IMPORTANT — Run this once to grant Reminders access:║"
echo "║                                                      ║"
echo "║  osascript -e 'tell application \"Reminders\"          ║"
echo "║    to return name of every list'                     ║"
echo "║                                                      ║"
echo "║  Click OK when macOS asks for permission.            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
