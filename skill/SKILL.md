---
name: handwritten-notes-ocr
description: >
  Use this skill whenever the user uploads one or more handwritten page images or scanned PDFs
  and wants them transcribed, typed, or converted into clean markdown. Triggers include: any
  mention of "transcribe my notes", "OCR", "typed version of my handwriting", "convert my
  handwritten pages", "notes to markdown", "digitize my notes", "clean up my notes", or when
  the user uploads an image/PDF of handwritten content and asks Claude to read, convert, extract,
  or summarize it. Also triggers when the user says "weekly summary", "executive summary of my
  notes", or "Associate Dean summary". Always use this skill for multi-page note digitization
  workflows — do not attempt this without the skill.
---

# Handwritten Notes OCR & Executive Summary Skill

This skill enables Claude to act as an expert note-taker: transcribing handwritten pages
(JPEG, PNG, or PDF) into structured markdown files, with auto-tagging by domain and generation
of a structured executive weekly summary aligned with an Associate Dean academic workflow.

---

## Step 1 — Parse Filename Metadata

Each uploaded file encodes its metadata in the filename. Extract the following fields **before**
any transcription:

### Filename Format
```
YYYYMMDD_HHMMdescriptor.ext
```
- Characters 1–8   → Date: `YYYY`, `MM`, `DD`
- Characters 10–13 (after `_`) → Time: `HH` (24h), `MM`
- Characters 14+   → Free-text descriptor (may contain spaces, hyphens, underscores)

### Example
```
20240315_1430research-meeting-COMP.jpg
→ Date:       2024-03-15
→ Time:       14:30
→ Descriptor: research-meeting-COMP
→ Output file: 2024-03-15_research-meeting-COMP.md
```

If the filename does not conform to this pattern, fall back to:
1. EXIF/PDF metadata creation date (if accessible)
2. Insert placeholder `[DATE UNKNOWN]` and `[TIME UNKNOWN]` and flag for user review

---

## Step 2 — OCR Transcription

Claude performs vision-based transcription directly from the uploaded image or PDF page.

### Transcription Rules

- **Read every element**: headings, sub-headings, body text, bullet points, numbered lists,
  tables, arrows, underlines, circled words, margin annotations, starred items, and sketched
  diagrams (describe diagrams as `[DIAGRAM: brief description]`).
- **Preserve structure**: reproduce heading hierarchy using `#`, `##`, `###`; use `-` or `1.`
  for lists; use `**bold**` for underlined or double-underlined text; use `*italic*` for
  single-underlined or lightly emphasised text; use `~~strikethrough~~` for crossed-out text.
- **Preserve symbols**: mathematical notation, Greek letters, arrows (→, ↔, ↑, ↓), degree
  symbols, ± signs, subscripts/superscripts where markdown supports them (H₂O, x²).
- **Context-assisted correction**: when a word is ambiguous or illegible, use surrounding
  context (topic, sentence structure, domain vocabulary) to infer the most probable word.
  Flag uncertain words inline as `[word?]` so the Professor can review them.
- **Do not paraphrase**: reproduce the author's exact phrasing and abbreviations. If an
  abbreviation is unambiguous (e.g., "Bx" = brachytherapy), preserve it as written.
- **Multi-page ordering**: when multiple files share the same date, order sections
  chronologically by timestamp extracted from each filename.

### Page Section Header (insert before each transcribed page)

```markdown
---
## 📄 [Descriptor] — YYYY-MM-DD @ HH:MM
---
```

---

## Step 3 — Domain Auto-Tagging

After transcription of each page, scan the content and append a `tags:` metadata block using
the taxonomy below. Apply **all** tags that match; a note may carry multiple tags.

### Tag Taxonomy

| Tag | Trigger keywords / concepts |
|-----|----------------------------|
| `#research` | experiments, results, data, analysis, publication, manuscript, journal |
| `#grant` | NSERC, CIHR, budget, funding, application, deadline, proposal, FCI |
| `#student` | MSc, PhD, postdoc, HQP, mentoring, thesis, defence, supervision |
| `#clinical` | patient, treatment, dose, linac, brachytherapy, HDR, LDR, RT, TPS |
| `#dosimetry` | scintillator, detector, dosimeter, calibration, measurement, QA |
| `#admin` | committee, agenda, minutes, policy, budget, report, bylaws |
| `#governance` | senate, faculty council, board, dean, rector, accreditation, CACMS |
| `#teaching` | course, lecture, syllabus, exam, PHY, grading, curriculum |
| `#industry` | partner, contract, NDA, IP, license, company, startup, MOU |
| `#conference` | COMP, AAPM, ESTRO, abstract, invited talk, symposium, congress |
| `#action-required` | TODO, ⚠, !, action, follow-up, deadline, must, urgent |

Insert the tag block at the **end** of each page section:

```markdown
> **Tags:** #research #grant #action-required
```

---

## Step 4 — Assemble the Daily Markdown File

### Output Filename
```
YYYY-MM-DD_descriptor.md
```
Where `descriptor` comes from the first (or only) file processed for that date. If multiple
files share a date but have different descriptors, use the earliest file's descriptor and
append `-et-al` (e.g., `2024-03-15_research-meeting-COMP-et-al.md`).

### File Structure

```markdown
# Notes — YYYY-MM-DD | [Descriptor]

<!-- Auto-generated by handwritten-notes-ocr skill -->
<!-- Source files: [list original filenames] -->

---
## 📄 [Descriptor 1] — YYYY-MM-DD @ HH:MM
[Transcribed content]

> **Tags:** #tag1 #tag2

---
## 📄 [Descriptor 2] — YYYY-MM-DD @ HH:MM
[Transcribed content]

> **Tags:** #tag1 #tag3
```

Sections are ordered **ascending by timestamp** within the file.

---

## Step 4b — Task Extraction for Apple Reminders

After assembling each daily `.md` file, scan **all transcribed content** for action items and
extract them into a structured JSON task file destined for the `tasks2reminders` pipeline.

### Task Detection Rules

Extract an item as a task if it matches **any** of the following signals:
- Explicitly tagged `#action-required` in the tags block
- Prefixed with `→`, `⇒`, `!`, `⚠`, or a checkbox `- [ ]`
- Contains deadline language: date, échéance, deadline, avant, d'ici, retour le, due
- Contains action verbs in imperative or future tense: transférer, confirmer, soumettre,
  vérifier, envoyer, préparer, compléter, contacter, valider, décider, relancer
- Circled or starred items in the original notes (transcribed with `⭐` or `[STARRED]`)
- Items attributed to a named person with a pending action ("Xavier → sortir les pass rate")

### Task Object Schema

Each extracted task must conform to this JSON schema:

```json
{
  "title":  "Concise action title (max 80 chars) — starts with an action verb",
  "due":    "YYYY-MM-DD or empty string if no date mentioned",
  "owner":  "Person responsible (first name or initials) or empty string",
  "note":   "Brief context (source section, meeting, rationale) — max 120 chars"
}
```

**Title construction rules:**
- Begin with an **action verb** in infinitive form (FR or EN matching the note's language):
  ex. "Transférer dossiers FCI-FI vers canal VDR", "Confirmer avec Kaouther — Chaire Inter"
- Do **not** reproduce tags, symbols (`→`, `#`), or markdown formatting in the title
- If the item names a responsible person, append ` — [Owner]` at the end of the title
  only if it would otherwise be ambiguous; otherwise populate the `owner` field

**Date extraction rules:**
- "25 mars" → `2026-03-25` (infer year from document date context)
- "fin semaine" → Friday of the current document week
- "mi-juin" → `2026-06-15`
- "d'ici lundi" → next Monday relative to document date
- Vague deadlines ("bientôt", "éventuellement") → empty string

### JSON Output File

```
YYYY-MM-DD_descriptor_tasks.json
```

**Full file structure:**
```json
{
  "source":    "YYYY-MM-DD_descriptor",
  "generated": "YYYY-MM-DD",
  "tasks": [
    {
      "title":  "...",
      "due":    "YYYY-MM-DD",
      "owner":  "...",
      "note":   "..."
    }
  ]
}
```

- One JSON file per daily `.md` file (not per page)
- If **no tasks** are detected, write `"tasks": []` — the pipeline will skip gracefully
- Weekly summary tasks are **not** extracted separately (they duplicate daily file tasks)

---

## Step 5 — Executive Weekly Summary

Generate this only when:
- The user explicitly requests it ("weekly summary", "executive summary"), **or**
- Three or more daily notes files from the same ISO calendar week are provided simultaneously.

### Output Filename
```
week-summary_YYYY-Www.md
```
Where `Www` is the ISO 8601 week number (e.g., `W12`).

### Weekly Summary Structure

```markdown
# Executive Weekly Summary — Week Wxx (YYYY-MM-DD → YYYY-MM-DD)

> Generated from: [list source .md files]

---

## 1. Decisions & Action Items
<!-- All items tagged #action-required across the week, with source date -->
| # | Action Item | Date | Deadline | Owner |
|---|-------------|------|----------|-------|
| 1 | ... | YYYY-MM-DD | ... | ... |

---

## 2. Meetings & Commitments
<!-- Chronological list of all meetings, calls, visits noted across the week -->
- **YYYY-MM-DD @ HH:MM** — [Meeting description]

---

## 3. Research & Academic Updates
<!-- Synthesis of #research, #grant, #student, #conference, #dosimetry, #clinical items -->
### 3.1 Research Progress
### 3.2 Grant & Funding Activity
### 3.3 Student Supervision & HQP
### 3.4 Publications & Conferences

---

## 4. Administrative & Governance
<!-- Synthesis of #admin, #governance, #teaching, #industry items -->
### 4.1 Faculty / Program Administration
### 4.2 Governance & Committee Work
### 4.3 Teaching & Curriculum
### 4.4 Industrial Partnerships & IP

---

## 5. Flagged Items Requiring Attention
<!-- Items with [word?] uncertain transcriptions, or explicitly starred/circled content -->
- [ ] [Description of flagged item] — *source: YYYY-MM-DD_descriptor.md*
```

### Summary Writing Guidelines
- Write each section in **concise prose** (2–4 sentences) followed by the structured
  sub-elements. Do not pad with filler language.
- Preserve the Professor's original terminology (do not substitute domain-specific abbreviations).
- Cross-reference items across the week where relevant (e.g., a grant deadline mentioned
  Monday that connects to a meeting noted Thursday).
- If a section has no content for the week, write `*No items recorded this week.*`

---

## Step 6 — Output Delivery

Two parallel pipelines are triggered simultaneously for every daily `.md` file produced.

### 6a — Export to Claude-OCR-Notes (Apple Notes pipeline)

Write each `.md` file directly to `$HOME/Documents/Claude-OCR-Notes/` using `osascript`:

**Procedure:**
1. Use `bash_tool` to resolve `$HOME`: `echo $HOME`
2. Construct target path: `$HOME/Documents/Claude-OCR-Notes/`
3. Create directory if absent: `mkdir -p "$HOME/Documents/Claude-OCR-Notes"`
4. Write the `.md` file via `osascript` `open for access … write … close access`
   - Daily notes: `$HOME/Documents/Claude-OCR-Notes/YYYY-MM-DD_descriptor.md`
   - Weekly summary: `$HOME/Documents/Claude-OCR-Notes/week-summary_YYYY-Www.md`
5. Call `present_files` on each path for in-chat download

> ✅ The `md2notes_watcher` LaunchAgent detects each new `.md` file and imports it into
> Apple Notes (**Handwritten Notes** folder) with full HTML formatting automatically.
> No direct Apple Notes API call is needed.

**Fallback only** — if the Professor reports the watcher is not running, use
`Read and Write Apple Notes:add_note` with plain-text content as a backup.

---

### 6b — Export to Claude-OCR-Tasks (Apple Reminders pipeline)

Write each `_tasks.json` file (generated in Step 4b) to `$HOME/Documents/Claude-OCR-Tasks/`:

**Procedure:**
1. Construct target path: `$HOME/Documents/Claude-OCR-Tasks/`
2. Create directory if absent: `mkdir -p "$HOME/Documents/Claude-OCR-Tasks"`
3. Serialize the task list to valid JSON (ensure all strings are properly escaped)
4. Write the `.json` file via `osascript` `open for access … write … close access`:
   - Filename: `$HOME/Documents/Claude-OCR-Tasks/YYYY-MM-DD_descriptor_tasks.json`
5. Do **not** call `present_files` for task files — they are transient pipeline inputs

> ✅ The `tasks2reminders_watcher` LaunchAgent detects each new `.json` file, creates the
> corresponding reminders in Apple Reminders **Inbox** list with due dates and notes,
> validates each reminder exists, then deletes the `.json` automatically.

**Important — JSON writing via osascript:**
The JSON content must be written as a clean AppleScript string. Before writing, ensure:
- All double quotes inside JSON values are escaped as `"`
- No raw newlines inside string values (use `\n` if needed)
- The `tasks` array is never omitted — use `[]` if no tasks were found

**Write pattern:**
```applescript
set jsonPath to "/Users/beaulieu/Documents/Claude-OCR-Tasks/YYYY-MM-DD_descriptor_tasks.json"
set jsonContent to "{ … valid JSON string … }"
set fileRef to open for access POSIX file jsonPath with write permission
set eof of fileRef to 0
write jsonContent to fileRef as «class utf8»
close access fileRef
```

---

### 6c — Confirmation Summary (inline, after all deliveries)

Provide a brief inline confirmation listing:
- Number of pages transcribed
- Date range covered
- All domain tags applied
- Any words flagged as uncertain `[word?]`
- Whether a weekly summary was generated
- Full path of each `.md` file written to `Claude-OCR-Notes/`
- Full path of each `_tasks.json` file written to `Claude-OCR-Tasks/`
- Number of tasks extracted per daily file
- Reminder that both LaunchAgents handle import/creation automatically

---

## Edge Cases & Quality Controls

| Situation | Handling |
|-----------|----------|
| Completely illegible word | Insert `[ILLEGIBLE]` |
| Ambiguous word, context helps | Insert best guess + `[word?]` |
| Diagram / sketch | Insert `[DIAGRAM: description]` |
| Table in notes | Reproduce as markdown table |
| Date absent from filename | Use `[DATE UNKNOWN]`, flag in Step 6 summary |
| Multiple pages, same timestamp | Append `-p1`, `-p2` etc. to section headers |
| Mixed language (FR/EN) | Transcribe in the language written; do not translate |
| Equations / formulas | Use LaTeX inline notation: `$E = mc^2$` |

---

## Reference Files

- `references/domain-vocabulary.md` — Extended glossary of medical physics, brachytherapy,
  and academic administration terms to assist context-based correction. Read this file when
  encountering unfamiliar abbreviations or ambiguous technical terms.
- `references/associate-dean-workflow.md` — Canonical description of the Associate Dean
  weekly workflow cadence to guide executive summary prioritization.
