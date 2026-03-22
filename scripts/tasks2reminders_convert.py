import sys, json, subprocess, os, time
from datetime import datetime

json_file = sys.argv[1]
task_file_name = os.path.basename(json_file)

with open(json_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

tasks = data.get('tasks', [])
source_note = data.get('source', task_file_name)

if not tasks:
    print(f'SKIP:{task_file_name} — no tasks found')
    os.remove(json_file)
    sys.exit(0)

# Ensure Reminders is open and ready
subprocess.run(['osascript', '-e', 'tell application "Reminders" to activate'], capture_output=True)
time.sleep(2)

TARGET_LIST = 'Inbox'
validated_count = 0
total_valid = len([t for t in tasks if t.get('title','').strip()])

for task in tasks:
    title  = task.get('title', '').strip()
    due    = task.get('due', '').strip()
    owner  = task.get('owner', '').strip()
    note   = task.get('note', '').strip()
    if not title: continue

    note_parts = []
    if owner:       note_parts.append(f'Owner: {owner}')
    if source_note: note_parts.append(f'Source: {source_note}')
    if note:        note_parts.append(note)
    reminder_note = ' | '.join(note_parts)

    title_esc = title.replace('\\', '\\\\').replace('"', '\\"')
    note_esc  = reminder_note.replace('\\', '\\\\').replace('"', '\\"')

    if due:
        try:
            d = datetime.strptime(due, '%Y-%m-%d')
            date_block = (f'set dueDate to (current date)\n'
                          f'set year of dueDate to {d.year}\n'
                          f'set month of dueDate to {d.month}\n'
                          f'set day of dueDate to {d.day}\n'
                          f'set hours of dueDate to 9\n'
                          f'set minutes of dueDate to 0\n'
                          f'set seconds of dueDate to 0')
            props_due = ', due date:dueDate'
        except ValueError:
            date_block = ''
            props_due  = ''
    else:
        date_block = ''
        props_due  = ''

    as_script = f'''tell application "Reminders"
    set tList to list "{TARGET_LIST}"
    {date_block}
    make new reminder at tList with properties {{name:"{title_esc}", body:"{note_esc}"{props_due}}}
    set validated to false
    repeat with r in reminders of tList
        if name of r is "{title_esc}" then
            set validated to true
            exit repeat
        end if
    end repeat
    return validated
end tell'''

    r = subprocess.run(['osascript', '-e', as_script], capture_output=True, text=True, timeout=30)
    if r.returncode != 0:
        print(f'ERR:{title} — {r.stderr.strip()}', file=sys.stderr); sys.exit(1)

    if r.stdout.strip().lower() == 'true':
        validated_count += 1
        print(f'OK:{title}')
    else:
        print(f'WARN:{title} — validation failed', file=sys.stderr); sys.exit(1)

if validated_count == total_valid:
    os.remove(json_file)
    print(f'DONE:{task_file_name} — {validated_count} reminder(s) created, file removed')
else:
    print(f'WARN:{validated_count}/{total_valid} validated, file kept', file=sys.stderr); sys.exit(1)
