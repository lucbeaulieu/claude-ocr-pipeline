# LaunchAgents

These `.plist` files are **generated automatically** by `install_pipeline.sh` — they are
excluded from version control via `.gitignore` because they embed your system username.

The installer creates:

- `com.<USERNAME>.md2notes.plist` — watches `~/Documents/Claude-OCR-Notes/`
- `com.<USERNAME>.tasks2reminders.plist` — watches `~/Documents/Claude-OCR-Tasks/`

Both are recreated on every run of `install_pipeline.sh`.
