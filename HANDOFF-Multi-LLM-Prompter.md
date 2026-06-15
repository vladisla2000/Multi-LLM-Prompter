# HANDOFF - Multi-LLM Prompter

Last updated: 2026-06-14
Current version: **v0.8.2** (delivered).
Next: **v0.8.3** - Phase 2 (Detected Tasks panel) is now SCOPED with locked decisions;
**build pending, no code written yet** (full spec in section 8).
Status: **daily driver.** v0.8.0/v0.8.1 live-validated (single code task PASS, section 6).
v0.8.2 is a prompts-only change (AD rules + a prompt $-interpolation fix); it cannot
regress routing or cost and only improves what the models receive. One small verify
pending: confirm a regenerated AD script now includes DistinguishedName + New-Item -Force.

Session chain: v0.7.6 -> v0.7.7 -> v0.7.8 -> v0.7.9 -> v0.8.0 -> v0.8.1 -> v0.8.2
-> [2026-06-14 scoping session: Phase 2 locked for v0.8.3, no code yet].

---

## 1. WHAT THIS PROJECT IS

Single-file PowerShell 5.1 tool: sends one prompt to two LLM answer models in parallel,
a Judge model compares/synthesizes (Full) or validates/reviews (Light/ReviewOnly) the
answers, then writes a final answer plus a full audit trail to disk. WPF GUI front end;
the SAME .ps1 runs as a hidden headless child for the pipeline.

- GUI Run: writes gui_prompt.txt, creates Run_<timestamp>, starts the hidden child (env MULTILLM_HEADLESS=1 + contract below).
- Child: loads config, splits prompt into tasks, per task router -> 2 parallel answers (Start-Job) -> Judge -> final_answer.md + metrics/logs.
- GUI DispatcherTimer 1 s: tasks.json -> total; Task_NN/final -> progress; transcript tail -> Run Log; child exited -> load results.
- Detect Tasks (v0.8.1): previews the split GUI-side (no child, no API).
- Stop: kills the child process.

No param() blocks anywhere (user convention). All GUI->child parameters travel via environment variables.

### Environment variable contract (GUI -> headless child)

- MULTILLM_HEADLESS "1" = run pipeline, suppress interactive prompts/popups
- MULTILLM_PROMPT_FILE path to gui_prompt.txt (UTF-8 BOM)
- MULTILLM_RUNFOLDER run folder pre-created by the GUI
- MULTILLM_SPLITMODE Heuristic / None
- MULTILLM_WORKMODE Auto / Review / Script
- MULTILLM_UICODE_MODE Review / Script (used when WORKMODE=Auto)
- MULTILLM_MODEL_OPENAI answer model A id
- MULTILLM_MODEL_ANTHROPIC answer model B id
- MULTILLM_MODEL_JUDGE SELECTED judge id (Light/ReviewOnly-non-cheap + display only)
- MULTILLM_MODEL_JUDGE_CHEAP cheap judge id (Light/ReviewOnly when toggle on)
- MULTILLM_CHEAP_JUDGE "1"/"0" cheap-judge toggle

Precedence: env applied AFTER config load -> GUI choices win over config, which wins over top-of-script defaults.

No env var exists for the strong judge (by design, v0.8.0). $AnthropicModel_JudgeStrong (default claude-opus-4-8) comes only from the top-of-script default or config (Models.AnthropicJudgeStrong). The GUI cannot weaken it per run. Full mode always uses it.

---

## 2. CURRENT FILE & PROJECT FOLDER

Multi-LLM-Prompter-v0_8_2.ps1 - ~5710 lines. PS 5.1, ASCII-only source (Unicode only as &#x...; entities in XAML here-strings), UTF-8 BOM, CRLF, cls first. $LaunchGui = $true default; $false runs the classic CLI pipeline.

Project folder: C:\_Combined\H_Productivity\Multi-LLM-Prompter\
- MultiLLM.config.json - correct since v0.7.5 (Opus 5/25, haiku entry, JudgeCheap, UseCheapJudgeForReview). v0.8.0 adds optional Models.AnthropicJudgeStrong.
- MultiLLM.secrets.xml - DPAPI Export-Clixml of SecureStrings, machine+user bound. Recreate via one $LaunchGui = $false run if keys change.
- Multi-LLM-Gate1-Benchmark-Prompts.csv - user-side benchmark set (v0.9 input).
- Multi-LLM-RunReviewHelper-v0.1.ps1 - user-side run analyzer (v0.9 seed).

Runtime outputs: C:\Temp\MultiLLMPrompter\
- gui_session.log - persistent GUI log, all sessions appended.
- Run_<timestamp>\: gui_prompt.txt, tasks.json, task_results_summary.{json,md}, final_answer.md, request_metrics.csv, stage_metrics.csv, timing_summary.json, cost_summary_by_role.json, cost_summary_by_model.json, cost_warnings.json, completeness_warnings.json, gui_run_report.json, console_transcript.txt, Task_NN\ subfolders.

Backup: GAMA-Work / Multi-LLM-Prompter on the user's Google Drive holds the HANDOFF; .ps1 files are copied there manually from the chat (connector cannot carry the BOM'd .ps1 losslessly).

---

## 3. BACKEND PIPELINE

### Models (defaults; answers + selected/cheap judge are GUI/config/env overridable)
- Answer A: OpenAI gpt-4.1-mini (chat/completions)
- Answer B: Anthropic claude-sonnet-4-6 (v1/messages, version 2023-06-01)
- Judge Strong: Anthropic claude-opus-4-8 (ALWAYS Full; config-only override)
- Judge select: Anthropic claude-opus-4-8 ($AnthropicModel_Judge; GUI Judge combo)
- Judge Cheap: Anthropic claude-sonnet-4-6 ($AnthropicModel_JudgeCheap; Light/Review)

Live runs commonly use cheaper answer models (e.g. haiku-4-5 for Answer B) selected in the GUI; the strong Full judge stays opus regardless.

### Task Splitter (Heuristic) - Split-UserPromptIntoTasks
Splits multi-line prompts only when >=2 lines look like separate tasks AND total non-empty lines <= 12. Mode None disables. Max tasks: $MaxTasksPerPrompt=10. Single-task prompts pass through untouched. TaskType assigned by Get-TaskType. Both are top-level functions, also called by the GUI (v0.8.1 Detect Tasks preview), so the preview is byte-identical to what the run splits.

### Router: task types and routing policy
Types: simple / technical / code / ui_code / documentation / creative.
- code, ui_code, technical: OpenAI + Sonnet + Judge
- documentation: MissingInput pre-check; source absent -> SKIPPED, 0 AI calls
- creative: Sonnet only, no Judge
- simple: OpenAI only

### WorkMode (Auto / Review / Script) - Get-TaskWorkMode  [LOGIC FROZEN since v0.7.5]
Review = notes + small snippets; Script = full runnable scripts. Auto order (matters):
1. ui_code: explicit complete/full/runnable/create/write script -> Script, else Review.
2. technical + correction wording -> Script (BEFORE the generic review rule).
3. generic review/analyze/audit/suggest/explain-the-bug -> Review.
4. code + script/code/function/wpf/xaml -> Script.
5. technical fallback / documentation / creative / simple -> Review.
Do NOT change this function except the version comment. The v0.8.x Routing Notes reporter is read-only and does not alter routing.

### Judge  [CRITICAL]
Marker contract (do not change casually; markdown inside JSON breaks ConvertFrom-Json):
- ---JUDGE_JSON--- (small clean JSON; no markdown/code inside)
- ---FINAL_ANSWER_MARKDOWN--- (markdown/code allowed)
- ---IMPROVED_PROMPT--- ("No improved prompt." if none)
Modes: Full (2 answers, compare+synthesize), Light (1 answer, validate), ReviewOnly (notes/verdict only).

JUDGE MODEL POLICY (v0.8.0; live-validated):
- Full -> ALWAYS $AnthropicModel_JudgeStrong (claude-opus-4-8). GUI Judge combo and cheap toggle IGNORED. If selected judge != strong, a [WARN] logs.
- Light -> cheap judge if $UseCheapJudgeForReview, else selected judge.
- ReviewOnly -> cheap judge if $UseCheapJudgeForReview, else selected judge.
Implemented in the per-task block: if ($JudgeMode -eq "Full") { $JudgeModelToUse = $AnthropicModel_JudgeStrong }. Invoke-LLMChat honors the passed -Model, so this block is authoritative.

JudgeModelUsed (v0.8.0): actual judge model per task surfaced as a "Judge Model" column in the Task Summary table and in Routing Notes.

### PROMPT $-ESCAPING  [CRITICAL GOTCHA - found and fixed v0.8.2]
The answer and judge SYSTEM prompts are DOUBLE-QUOTED here-strings ($SystemPrompt = @"..."@), so PowerShell INTERPOLATES every $-token in the rule text at job runtime. Before v0.8.2 the rules used bare $, so:
- the example 'Enabled -eq $false' was sent to the model as 'Enabled -eq False' (the exact bug we were trying to prevent);
- $null and $_ collapsed to empty, blanking the null-comparison rules.
Output stayed mostly correct only because the models know PowerShell. v0.8.2 backtick-escapes every instruction $ in all four prompt blocks (`$true, `$false, `$null, `$_) so the model receives the literal text. RULE: any new instruction text in these prompts MUST escape $ with a backtick, or rephrase to avoid $.

### Embedded generation rules (answer + judge prompts; escaped since v0.8.2)
cls, vars-at-top, no param, if/else, Try/Catch, never Export-Csv after Format-Table, AD -Filter safety, @() before .Count, ASCII-only output. v0.7.8: behavioral claims (e.g. $null -lt $date) must be PROVEN by a runnable self-check in the generated script; null LastLogonDate via $null -eq; WhenCreated guard in-script; create export folder; return not Exit. v0.8.2 added: AD -Filter Booleans use $true/$false WITH the dollar sign (never bare True/False); AD inventory/report scripts include DistinguishedName and do NOT add an always-constant column (e.g. Enabled when already filtered on Enabled); create output folders with New-Item -Force.

### Parallelism / cost / metrics
Start-Job per answer model; per-model + total + judge timeouts (judge default 90 s); retry x1 on null/429/5xx, never on 400/401/403. Helper functions are intentionally DUPLICATED inside job scriptblocks (PS 5.1 jobs do not inherit session functions). Cost from config CostPer1MTokens by "Provider|Model" key. Get-EstimatedCostUsd is byte-frozen across v0.7.7-v0.8.2. Unknown-model cost is reported, not silent.

---

## 4. GUI

Zones (vlad-wpf-design): Header #0F3460 (title + model route + run folder) / Input / TabControl / Actions / dark log / StatusBar.

Input: Prompt (multiline Consolas) | Preset | Splitter (Heuristic/None) | Work mode | UI auto mode | Open-in-Notepad / Open-folder | Model A | Model B | Judge | Cheap-judge checkbox + combo. Model combos IsEditable=True (typed ids allowed; deliberate exception).

Tabs: Full Answer (renamed from "Final Answer", v0.7.9) | Tasks (columns Id/Type/Work/OK/Ans/Judge/JudgeModel/Compl/Tokens/Cost/Title/Error; row coloring via XAML DataTriggers: Completeness=WARN amber, Success=False red) | Metrics (timing + cost-by-role + cost-by-model + cost-warnings) | Run Log.

Actions: Detect Tasks | Run #0B6A0B | Full Answer #0078D7 (separate window) | Copy #0078D7 (one-click) | Improved Prompt | Run Folder | Config || Stop #A4262C | Exit.

GUI features added this session:
- Detect Tasks (v0.8.1): splits the current prompt with the same splitter + classifier the run uses and previews tasks (Id/Type/Title) into the Tasks tab before running. Read-only; switches to Tasks tab.
- Model clarity (v0.8.1): on Run, the Run Log prints each role->model (Answer A/B, "Judge (Full, forced)"=strong, "Judge (Light/ReviewOnly)"=cheap/selected) + a [WARN] if the selected judge != strong. Header: "A + B | Full judge: opus | Light/Rev: ...".
- Run button stays enabled-but-grayed ("Running...") with IsBusy guard (v0.7.6).
- Per-task Tokens/Cost columns + StatusBar tokens/cost on completion (v0.7.8).
- Report sections: Cost by Model (v0.7.6), Cost Warnings (v0.7.7), Routing Notes + numbered "## Prompt N of M" with --- separators (v0.7.8).

Safety/plumbing: STA guard before Add-Type; SelfPath check; API-key pre-check; UIReady; timer stopped + child killed on Closing.

---

## 5. VERSION HISTORY (delivered files)

- v0.7.0-v0.7.5: GUI shell + headless child; logs/report; WorkMode combos; row coloring; cheap judge; editable model combos; Get-TaskWorkMode ordering fix. PASS.
- v0.7.6: Run busy-gray + IsBusy guard; Final Answer separate window; cost_summary_by_model + Cost-by-Model section. static PASS.
- v0.7.7: Unknown-model cost WARN; restored one-click Copy. PASS (3 prompts, $0.34477, prices correct).
- v0.7.8: Self-check judge+answer rules; numbered Prompt N of M + ---; per-task Tokens/Cost; Routing Notes. PASS (3-prompt run) - exposed the judge-policy bug.
- v0.7.9: Renamed "Final Answer" -> "Full Answer" (UI only). static PASS.
- v0.8.0: Full Judge safety: Full ALWAYS strong judge; [WARN] on mismatch; Strong/Cheap vars; JudgeModelUsed column. PASS (validated in v0.8.1 run).
- v0.8.1: Model-clarity Run Log + header; Detect Tasks preview. PASS (single code task, section 6).
- v0.8.2: AD prompt-quality rules + prompt $-interpolation fix (DistinguishedName, no constant Enabled column, New-Item -Force, $true/$false in filters; all instruction $ backtick-escaped). Prompts only. Static PASS; one live verify pending (section 6 #5).

---

## 6. LIVE VALIDATION & KNOWN ISSUES

### v0.8.1 live PASS - evidence (single code task, Run_20260613_121707)
- Routing: TaskType=code, WorkMode=Script, JudgeMode=Full, Completeness=OK.
- Judge: Judge Model = claude-opus-4-8 (Cost-by-Model: opus | Judge).
- Math: judge 3664 in + 2187 out @ Opus 5/25 = $0.072995 exactly -> confirms Opus (sonnet 3/15 would be $0.0438).
- Answers: haiku-4-5 + gpt-4.1-mini (cheap), $0.005583 total.
- Quality: generated AD filter = 'Enabled -eq $false' (correct $ sign) - the class of bug (Enabled -eq True) the cheap sonnet judge let through earlier. Strong Opus Full judge did NOT let it through -> v0.8.0 fix proven.
- Total: $0.078578 (judge ~93%; expected because Full = Opus).

### Known issues / actions
1. [CLOSED] Stale config / Opus 15/75 (v0.7.5+; confirmed live).
2. [CLOSED] Unknown-model cost = silent null (v0.7.7 cost WARN).
3. [CLOSED] Cheap judge leaked into Full (v0.8.0; live-validated).
4. [CLOSED - PASS] Live re-test of v0.8.0/v0.8.1.
5. [CLOSED - prompts] Prompt $-interpolation: double-quoted system here-strings blanked $null/$_ and turned the example 'Enabled -eq $false' into 'Enabled -eq False'. Fixed v0.8.2 by backtick-escaping all instruction $ in the 4 prompt blocks. PENDING small verify: re-run an AD inventory task and confirm the generated script now includes DistinguishedName and New-Item -Force (these rules now actually reach the model).
6. [watch-only] $null -lt $date narrative bug: did NOT reproduce in the v0.8.1 run; the v0.7.8 self-check rule covers it.
7. Judge cost dominance (~93% on a tiny script) is expected (Opus Full). Real workload is AD/security, which by policy stays Full Opus, so a complexity tier would save little. Not urgent.
8. Completeness-warning false positives (markdown endings w/o punctuation): intentionally unfixed; collecting stats.
9. Stop kills only the child; Start-Job grandchildren may finish in-flight calls (warning logged). Process-tree kill = backlog.

---

## 7. ROADMAP

- DONE v0.8.2: AD prompt rules + prompt $-escape fix (this release).
- NEXT (v0.8.3): Detect Tasks "Phase 2" - editable Detected Tasks panel. SCOPED + LOCKED 2026-06-14; full spec in section 8. Decisions: all features in one release; GUI may override Type/WorkMode per task; reuse the existing Tasks tab. Build pending (no code yet).
- LATER: Judge-tier-by-complexity option (Light for trivial code, Full Opus for security/AD/correction). Low ROI for this workload; parked.
- v0.9: Benchmark mode (Gate1 CSV); RunFinalVerifier real impl (verifier != judge).
- v1.0: config + adapters + CLI + GUI + benchmark + presets.
- Deferred: OpenRouter/LiteLLM backend, 4-5 answer models, separate Synthesizer, RAG, per-task model matrix.

---

## 8. PHASE 2 - DETECTED TASKS PANEL: LOCKED SCOPE (target v0.8.3, build pending)

Scoped 2026-06-14. Three decisions locked by the user (each chosen against the
recommend-and-proceed default; the defaults' rationale and the chosen-option risk +
mitigation are recorded below so the trade-off is not silently lost). NO code written
yet - this section is the spec to build v0.8.3 from.

### Decisions (locked)
1. SCOPE: everything in ONE release - edit + merge + reorder + delete + select-checkbox
   + Run Selected. (Not phased. Default rec was phased; user chose all-at-once.)
2. ROUTING OWNERSHIP: the GUI MAY override Type/WorkMode per task. The frozen functions
   stay the DEFAULT SEED and remain byte-frozen; the override is a thin gate AROUND the
   call site, never an edit to Get-TaskType / Get-TaskWorkMode themselves.
3. UI PLACEMENT: REUSE the existing Tasks tab in dual-mode (editable pre-run /
   read-only results), NOT a new tab.

### Architecture core: GUI owns the split
- New env var: `MULTILLM_TASKS_FILE` = path to `tasks_input.json` (UTF-8 BOM), written by
  the GUI into the run folder. (Added to the GUI -> child env contract in section 1.)
- On Run, the GUI ALWAYS materializes the panel's current task list into
  `tasks_input.json`; the child consumes it INSTEAD of splitting -> preview == run BY
  CONSTRUCTION (eliminates the "preview != run" bug class). `Splitter=None` is applied
  GUI-side when building the list.
- Child fallback UNCHANGED: if `MULTILLM_TASKS_FILE` is absent / the file is missing
  (CLI / `$LaunchGui=$false` / safety net), the child calls `Split-UserPromptIntoTasks`
  exactly as today. This is the backward-compat guarantee - a panel/editor bug must not
  break a normal run.

### tasks_input.json schema (array)
    { TaskId, TaskTitle, PromptText, TypeOverride, WorkModeOverride }
- TypeOverride: "" | simple | technical | code | ui_code | documentation | creative
- WorkModeOverride: "" | Review | Script
- "" => child uses the frozen function (default). Invalid value => [WARN], treated as "".

### Child-side edits (frozen functions NOT touched)
1. ~line 3606 (the single split point): if HeadlessMode AND `MULTILLM_TASKS_FILE` is set
   AND the file exists -> load the list from `tasks_input.json` (SplitMode="GuiOwned")
   INSTEAD of `Split-UserPromptIntoTasks`; else the old split. `tasks.json` is still
   written exactly as before.
2. ~line 2959 (`$TaskType = Get-TaskType ...`) AND the `Get-TaskWorkMode` call site: add a
   gate -> if the task carries a non-empty override, use it; else call the frozen
   function. The function bodies are not edited (proves out in the validation diff).

### GUI-side edits (Tasks tab dual-mode)
- Detect Tasks populates an editable `ObservableCollection[psobject]` bound to the Tasks
  grid (replaces the read-only preview-rows array for the pre-run state).
- Toolbar in the Tasks tab: `Add | Merge | Up | Down | Delete | Run Selected`. Columns
  gain Select (DataGridCheckBoxColumn) + Type (DataGridComboBoxColumn over the enum) +
  editable Title/Prompt. Results mode HIDES the toolbar and sets the grid `IsReadOnly`.
- PSCustomObject is NOT INotifyPropertyChanged: structural ops (merge / reorder / delete)
  mutate the ObservableCollection (re-bind), per-cell edits write into the psobject.
  Re-sequence TaskId 1..N after merge / delete / reorder.
- Merge: concatenate PromptText (with a separator) + combined title; re-seed Type/WorkMode
  from the frozen functions on the merged text (user may then override).
- On Run, the Run Log prints the EFFECTIVE route per task (after overrides) + cost
  implication, extending the v0.8.1 role->model + "Full judge forced" log.

### Risks introduced by the locked choices (+ mitigation)
- All-at-once (decision 1): bigger blast radius in one drop, landing together with the
  split-ownership change. -> internal build order = plumbing + fallback FIRST, editor UI
  on top; keep the child-splits fallback bulletproof; mandatory live-pass before v0.8.3
  becomes the daily driver.
- GUI overrides routing (decision 2): an override can SILENTLY change cost/judge
  (simple->code adds a 2nd answer model + a Full Opus judge). -> frozen functions stay the
  default seed; override is validated against the enums; effective route + cost surfaced
  in the Run Log so the change is visible.
- One grid, two states (decision 3): no change notification on PSCustomObject + the grid
  also serves the 11-column results schema with Success/Completeness DataTriggers.
  -> ObservableCollection + id re-sequence for structural ops; IsReadOnly/toolbar-visibility
  mode switch; the existing results-population path (Update-TasksGridFromSummary) is left
  intact.

### Version + validation
- Target v0.8.3 (v0.9 stays reserved for Benchmark per the roadmap). Full file, no dropped
  features, numbered changelog entry, never reuse a version.
- Validate before delivery: BOM, cls first, 0 non-ASCII, here-strings balanced
  (@" == "@), code-only paren balance == 0, Add_Click count, diff the FROZEN
  Get-TaskWorkMode / Get-EstimatedCostUsd / judge-selection to PROVE they are untouched,
  grep that prompt $-tokens stay backtick-escaped.

### Open during build (decide while building; not blockers)
- Merge separator + merged-title convention.
- Run Selected with an empty selection: run all, or warn (lean: warn).
- Tasks-tab toolbar placement (above grid) + mode-toggle triggers (Detect -> edit mode;
  run start -> results mode; Stop/new Detect -> back to edit mode).

---

## 9. BINDING CONVENTIONS (this project)

- PS 5.1 / ISE. UTF-8 BOM, CRLF. ASCII-only source; Unicode ONLY as &#x...; XAML entities. cls first. No top-level param() (env vars instead). No ternary/??. Full files only; never drop features; ALWAYS bump version everywhere + add a numbered changelog entry; never reuse a version number.
- PROMPT here-strings are double-quoted (@"..."@): escape EVERY instruction $ with a backtick (`$true, `$null), or the model receives interpolated garbage. (This was a real latent bug fixed in v0.8.2.)
- WPF: vlad-wpf-design palette/zones; Border-wrapper rounded buttons; no -f on XAML strings (.Replace only); inline styles in standalone here-string windows; UIReady guard; timers stopped on close; ComboBox IsEditable=False EXCEPT model combos. Add_Click handlers use $Script: globals (no GetNewClosure needed; matches file style).
- LOAD-BEARING, do not "clean up": judge marker contract; duplicated-functions-in-jobs pattern; Get-TaskWorkMode logic; Get-EstimatedCostUsd; the Full->strong judge enforcement.
- Distinguish layers: a flaw in a GENERATED script (missing -Force, missing DN, bad $false) is fixed by changing the answer/judge PROMPT RULES, not the tool's own code.
- Validation before delivery (no pwsh in assistant env; final syntax check is in ISE): BOM, cls first, 0 non-ASCII bytes, here-strings balanced (@" == "@), code-only paren balance == 0, Add_Click count, diff Get-EstimatedCostUsd/Get-TaskWorkMode to prove logic untouched, and grep that prompt $-tokens are backtick-escaped.
- Logs/outputs under C:\Temp. Color never the sole meaning carrier.

---

## 10. FIRST PROMPT FOR NEXT SESSION (suggested)

"Multi-LLM Prompter: here is the HANDOFF and v0.8.2 (daily driver). Phase 2 (Detected
Tasks panel) is scoped and LOCKED - see section 8 - build v0.8.3. Locked: all features in
one release (edit / merge / reorder / delete / select / Run Selected); the GUI owns the
split and writes tasks_input.json (new env MULTILLM_TASKS_FILE) which the child consumes
INSTEAD of re-splitting (fallback to Split-UserPromptIntoTasks when the file is absent);
the GUI may override Type/WorkMode per task via a gate around the FROZEN
Get-TaskType / Get-TaskWorkMode (function bodies stay byte-frozen); reuse the existing
Tasks tab in dual mode (editable pre-run / read-only results, ObservableCollection,
TaskId re-sequenced after structural ops). Build the full v0.8.3 file per section 8, then
run the section 8 validation checklist. (Still open from v0.8.2: re-run an AD inventory
task and confirm the generated script has DistinguishedName + New-Item -Force and that the
Full judge stayed claude-opus-4-8 - do this whenever the final_answer.md is handy.)"
