import sys, re, subprocess, os

md_file = sys.argv[1]
note_name = sys.argv[2]

with open(md_file, 'r', encoding='utf-8') as f:
    lines = f.readlines()

STYLE = 'font-family:Helvetica Neue,sans-serif;font-size:14px;line-height:1.7;'
html_lines = []
in_list = False
in_table = False
in_code = False

def close_open(il, it):
    out = []
    if il: out.append('</ul>')
    if it: out.append('</table>')
    return out, False, False

def esc(s):
    return s.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')

def inline(txt):
    txt = re.sub(r'[*][*](.+?)[*][*]', r'<strong>\1</strong>', txt)
    txt = re.sub(r'__(.+?)__', r'<strong>\1</strong>', txt)
    txt = re.sub(r'[*](.+?)[*]', r'<em>\1</em>', txt)
    txt = re.sub(r'~~(.+?)~~', r'<s>\1</s>', txt)
    return txt

for raw in lines:
    line = raw.rstrip('\n')
    if line.strip().startswith('<!--'): continue
    if line.startswith('```'):
        if in_code:
            html_lines.append('</pre>')
            in_code = False
        else:
            extra, in_list, in_table = close_open(in_list, in_table)
            html_lines.extend(extra)
            in_code = True
            html_lines.append('<pre style="background:#f4f4f4;padding:8px;font-family:monospace;font-size:12px;">')
        continue
    if in_code:
        html_lines.append(esc(line))
        continue
    if re.match(r'^---+$', line.strip()):
        extra, in_list, in_table = close_open(in_list, in_table)
        html_lines.extend(extra)
        html_lines.append('<hr style="border:none;border-top:1px solid #ddd;margin:10px 0;"/>')
        continue
    m = re.match(r'^(#{1,4})\s+(.*)', line)
    if m:
        extra, in_list, in_table = close_open(in_list, in_table)
        html_lines.extend(extra)
        lv = len(m.group(1))
        sz = {1:'20px',2:'17px',3:'15px',4:'14px'}[lv]
        wt = '700' if lv <= 2 else '600'
        txt = inline(re.sub(r'[\U0001F300-\U0001FAFF]\s*','',m.group(2)))
        html_lines.append(f'<h{lv} style="font-size:{sz};font-weight:{wt};margin:12px 0 3px;">{txt}</h{lv}>')
        continue
    if '|' in line and not line.strip().startswith('>'):
        if re.match(r'^[\|\s\-:]+$', line.strip()): continue
        if not in_table:
            extra, in_list, _ = close_open(in_list, False)
            html_lines.extend(extra); in_table = True
            html_lines.append('<table style="border-collapse:collapse;width:100%;font-size:13px;margin:6px 0;">')
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        row = '<tr>'+''.join(f'<td style="border:1px solid #ccc;padding:4px 8px;">{inline(c)}</td>' for c in cells if c)+'</tr>'
        html_lines.append(row); continue
    if in_table and '|' not in line:
        html_lines.append('</table>'); in_table = False
    m = re.match(r'^(\s*)[-*+]\s+(.*)', line)
    if m:
        if not in_list:
            in_list = True
            html_lines.append('<ul style="margin:4px 0;padding-left:20px;">')
        ml = f'margin-left:{len(m.group(1))*10}px;' if m.group(1) else ''
        html_lines.append(f'<li style="margin:2px 0;{ml}">{inline(m.group(2))}</li>'); continue
    if line.startswith('> '):
        extra, in_list, in_table = close_open(in_list, in_table)
        html_lines.extend(extra)
        html_lines.append(f'<blockquote style="border-left:3px solid #bbb;margin:4px 0 4px 10px;padding:3px 10px;color:#666;font-size:12px;">{inline(line[2:])}</blockquote>'); continue
    if line.strip() == '':
        extra, in_list, in_table = close_open(in_list, in_table)
        html_lines.extend(extra); html_lines.append('<br/>'); continue
    extra, in_list, in_table = close_open(in_list, in_table)
    html_lines.extend(extra)
    html_lines.append(f'<p style="margin:3px 0;">{inline(line)}</p>')

if in_list:  html_lines.append('</ul>')
if in_table: html_lines.append('</table>')
if in_code:  html_lines.append('</pre>')

body = '\n'.join(html_lines)
full_html = f'<html><body style="{STYLE}">{body}</body></html>'

as_script = f'''
tell application "Notes"
    set tF to missing value
    repeat with f in folders
        if name of f is "Handwritten Notes" then
            set tF to f
            exit repeat
        end if
    end repeat
    if tF is missing value then
        set tF to make new folder with properties {{name:"Handwritten Notes"}}
    end if
    set eN to missing value
    repeat with n in notes of tF
        if name of n is "{note_name.replace(chr(34), chr(92)+chr(34))}" then
            set eN to n
            exit repeat
        end if
    end repeat
    if eN is not missing value then
        set body of eN to "{full_html.replace(chr(34), chr(92)+chr(34))}"
    else
        make new note at tF with properties {{name:"{note_name.replace(chr(34), chr(92)+chr(34))}", body:"{full_html.replace(chr(34), chr(92)+chr(34))}"}}
    end if
    set validated to false
    repeat with n in notes of tF
        if name of n is "{note_name.replace(chr(34), chr(92)+chr(34))}" then
            set validated to true
            exit repeat
        end if
    end repeat
    return validated
end tell
'''

r = subprocess.run(['osascript', '-e', as_script], capture_output=True, text=True)
if r.returncode != 0:
    print(f'ERR:{r.stderr.strip()}', file=sys.stderr); sys.exit(1)

if r.stdout.strip().lower() == 'true':
    os.remove(md_file)
    print(f'OK:{note_name} — imported and source file removed')
else:
    print(f'WARN:{note_name} — note not validated, file kept', file=sys.stderr); sys.exit(1)
