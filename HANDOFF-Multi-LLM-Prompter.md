# HANDOFF - Multi-LLM Prompter

> Russian parallel version: [HANDOFF-Multi-LLM-Prompter.ru.md](HANDOFF-Multi-LLM-Prompter.ru.md).
> This English file is the source of truth; keep both in sync on changes.

Last updated: 2026-06-16
Current version: **v0.8.58** (delivered, daily driver).
File: `Multi-LLM-Prompter-v0_8_58.ps1` (~9,535 lines, ~416 KB).

Status: **daily driver.** The file is mechanically clean (0 parser errors, UTF-8 BOM,
ASCII-only body, CRLF, balanced here-strings). Phase 2 (the Detected/Editable Tasks
panel) is **DELIVERED** - it shipped incrementally across v0.8.9 - v0.8.40, not as the
single v0.8.3 drop the older handoff anticipated.

Session chain (high level): v0.7.x (GUI shell + headless child, cost/judge hardening)
-> v0.8.0 (Full-always-strong-judge) -> v0.8.1/0.8.2 (clarity + AD prompt rules)
-> v0.8.3 (script-relative config/secrets paths) -> v0.8.4 - v0.8.8 (header model panel,
GUI API-key entry, judge-verdict block, operator labels) -> v0.8.9 - v0.8.40 (Phase 2:
editable task list, tasks_input.json, per-task Type/WorkMode overrides, task-review grid,
estimates, sidebar + inspector rail, menus, personas, clarification gate, cost budget)
-> v0.8.41 - v0.8.51 (persona backend, polish, run-done signal, version badge, log toggle)
-> v0.8.52 (generated-code correctness fix: `$null -lt [DateTime]` semantics)
-> v0.8.53 (Stop kills the whole backend process tree) -> v0.8.54 (RunFinalVerifier, opt-in)
-> v0.8.55 (GUI toggle for the verifier) -> v0.8.56 (report/banner version strings use $ToolVersion) -> v0.8.57 (first-run wording + cost labels) -> v0.8.58 (How-it-works strip + cost on Run button).

## THIS SESSION (2026-06-16) - READ FIRST

All work below is on git branch **`chore/docs-helper-harness`** - **10 commits ahead of `main`,
pushed to origin, NOT merged.** No PR is open (`gh` is not installed on this machine - open it from
the GitHub UI: https://github.com/vladisla2000/Multi-LLM-Prompter/pull/new/chore/docs-helper-harness).

What shipped this session:
- Re-synced all docs from the stale v0.8.2 handoff to the live code (this file, DEVELOPER.md, the
  multi-llm-prompter skill references + repackaged .skill/.zip).
- Fixed + rewrote the run-review helper for the current run-folder layout -> `Multi-LLM-RunReviewHelper-v0.3.ps1`.
- Added **`Validate-MultiLLM.ps1`** (repo root) - the pre-delivery gate (static checks for app + helper
  + benchmark; invariants; AST-extracted behavioral tests of the frozen cost/routing functions). Run
  it before every delivery; it must be PASS.
- v0.8.53: Stop now kills the whole backend process tree (no orphaned API calls after Stop).
- v0.8.54: RunFinalVerifier - a verifier DISTINCT from the judge (opt-in, OFF by default).
- v0.8.55: GUI "Run final verifier" checkbox + `MULTILLM_RUNVERIFIER` env var.
- Added the Gate-1 benchmark runner `add\Multi-LLM-Benchmark-v0.2.ps1`; both it and the helper surface
  the verifier's `final_verification.json`.
- Adopted backup-then-rename versioning (section 7) and recorded the read-only MCP permission allowlist
  in `.claude\settings.json`.

LIVE VALIDATION (2026-06-16): the user's machine now HAS API keys and a live v0.8.55 run succeeded.
CONFIRMED live: the v0.8.55 GUI (the "Run final verifier" checkbox renders), Full->strong judge
(claude-opus-4-8 in Full), the cost math, Phase 2 selective run (1 of 6 selected), and the v0.8.52
AD-prompt fix - the generated script's self-check prints "[Self-check PASS] $null -lt date is TRUE
in WPS 5.1 (expected)" and the script includes DistinguishedName + New-Item -Force and omits a
constant Enabled column. (This closes the old v0.8.52 watch-item.) That live run also exposed the
v0.8.56 fix (report header said v0.8.52).

STILL PENDING for next session:
- Live-test the VERIFIER: run with "Run final verifier" CHECKED (or MULTILLM_RUNVERIFIER=1) and
  confirm Task_NN/final_verification.json + the verdict; this is the one verifier path not yet exercised.
- Run a LIVE benchmark: add\Multi-LLM-Benchmark-v0.2.ps1 with $DryRun=$false (spends real money).
- Open the PR for `chore/docs-helper-harness` (or merge it to main).
- v1.0 (config/adapters/CLI consolidation) is the next big milestone - needs scoping, not blind building.
- NOTE: the AGENT/build env (where the assistant runs) still has no keys - it validates
  statically/unit only; live runs happen on the user's machine.

---

## 1. WHAT THIS PROJECT IS

Single-file PowerShell 5.1 tool: sends one prompt to two LLM answer models in parallel,
a Judge model compares/synthesizes (Full) or validates/reviews (Light/ReviewOnly) the
answers, then writes a final answer plus a full audit trail to disk. WPF GUI front end;
the SAME .ps1 runs as a hidden headless child for the pipeline.

- GUI Run: writes gui_prompt.txt, creates Run_<timestamp>, optionally writes tasks_input.json,
  starts the hidden child (env MULTILLM_HEADLESS=1 + contract below).
- Child: loads config, builds the task list (from tasks_input.json when supplied, else the
  splitter), per task router -> answers (Start-Job, parallel) -> Judge -> per-task
  final_answer.md + a merged run-level final_answer.md + metrics/logs.
- GUI DispatcherTimer 1 s: tasks.json -> total; Task_NN/final -> progress (per-task row
  colors as tasks finish); transcript tail -> Run Log; child exited -> load results +
  run-done color/sound.
- Detect Tasks: previews the split GUI-side (no child, no API), fills the editable task grid.
- Stop: kills the child process.

No param() blocks anywhere (user convention). All GUI->child parameters travel via
environment variables.

### Environment variable contract (GUI -> headless child)

Original set:
- MULTILLM_HEADLESS "1" = run pipeline, suppress interactive prompts/popups
- MULTILLM_PROMPT_FILE path to gui_prompt.txt (UTF-8 BOM)
- MULTILLM_RUNFOLDER run folder pre-created by the GUI
- MULTILLM_SPLITMODE Heuristic / None
- MULTILLM_WORKMODE Auto / Review / Script
- MULTILLM_UICODE_MODE Review / Script (used when WORKMODE=Auto)
- MULTILLM_MODEL_OPENAI answer model A id
- MULTILLM_MODEL_ANTHROPIC answer model B id
- MULTILLM_MODEL_JUDGE selected judge id (Light/ReviewOnly-non-cheap + display only)
- MULTILLM_MODEL_JUDGE_CHEAP cheap/"review" judge id (Light/ReviewOnly when toggle on)
- MULTILLM_CHEAP_JUDGE "1"/"0" cheap-judge toggle

Added since v0.8.2:
- MULTILLM_TASKS_FILE (v0.8.9) path to tasks_input.json. When set AND the file exists, the
  child loads that explicit task list (array of {TaskId, TaskTitle, PromptText, TypeOverride,
  WorkModeOverride}) INSTEAD of running the splitter. Absent/empty -> Split-UserPromptIntoTasks
  as before (the backward-compat / CLI safety net).
- MULTILLM_PERSONA_MODE (v0.8.41) Off / Fixed
- MULTILLM_PERSONA_A (v0.8.41) persona key for Answer A (architect / ui_ux / devils_advocate
  / qa / senior_dev / none)
- MULTILLM_PERSONA_B (v0.8.41) persona key for Answer B
- MULTILLM_RUNVERIFIER (v0.8.55) "1"/"0" - enable the final verifier for this run (GUI "Run final verifier" checkbox). Absent -> config/default $RunFinalVerifier (CLI unchanged).

Precedence: env applied AFTER config load -> GUI choices win over config, which wins over
top-of-script defaults.

There is NO env var for the strong judge (by design, v0.8.0). $AnthropicModel_JudgeStrong
(default claude-opus-4-8) comes only from the top-of-script default or config
(Models.AnthropicJudgeStrong). The GUI cannot weaken it per run. Full mode always uses it.

---

## 2. CURRENT FILE & PROJECT FOLDER

`Multi-LLM-Prompter-v0_8_58.ps1` - ~9,535 lines. PS 5.1, ASCII-only source (Unicode only as
`&#x...;` entities in XAML here-strings), UTF-8 BOM, CRLF, `cls` first. $LaunchGui = $true
default; $false runs the classic CLI pipeline.

Project folder: `C:\_Combined\Multi-LLM-Prompter\` (this is the live working copy).
- MultiLLM.config.json - models, endpoints, timeouts, output budgets, behavior, CostPer1MTokens.
  Its own "Version" field may lag the script (currently v0.8.47 vs script v0.8.52) - that is
  expected and harmless; config load guards every key with IsNullOrWhiteSpace.
- MultiLLM.secrets.xml - DPAPI Export-Clixml of SecureStrings (OpenAIKey, AnthropicKey),
  machine+user bound. Can be (re)created from the GUI (Config -> Set API keys) or one
  $LaunchGui = $false run.
- $ConfigPath / $SecretsPath (v0.8.3+): resolved relative to the SCRIPT folder, with a
  fallback to the legacy fixed path `C:\_Combined\H_Productivity\Multi-LLM-Prompter` (which
  does NOT exist on disk - it is only a fallback). Prefer a file next to the .ps1, then legacy,
  else create next to the .ps1.
- add\ - dev helpers: Multi-LLM-Gate1-Benchmark-Prompts.csv (benchmark input),
  Multi-LLM-Benchmark-v0.2.ps1 (Gate-1 benchmark runner; drives the headless pipeline over the
  CSV and reports routing/cost/judge), Multi-LLM-RunReviewHelper-v0.3.ps1 (single-run analyzer;
  v0.1 was broken + flat-layout-only and is superseded), My Ideas.txt.
- Validate-MultiLLM.ps1 (repo root) - pre-delivery validation harness for the app + helpers.

Runtime outputs: `C:\Temp\MultiLLMPrompter\`
- gui_session.log - persistent GUI log, all sessions appended.
- Run_<timestamp>\ - one folder per run (see section 3 for the exact layout).

---

## 3. BACKEND PIPELINE

### Models (defaults; answers + selected/cheap judge are GUI/config/env overridable)
- Answer A: OpenAI gpt-4.1-mini (chat/completions)
- Answer B: Anthropic claude-sonnet-4-6 (v1/messages, version 2023-06-01)
- Judge Strong: Anthropic claude-opus-4-8 (ALWAYS Full; config-only override, never from GUI)
- Judge select: $AnthropicModel_Judge (GUI Judge combo; Light/ReviewOnly display)
- Judge Cheap/Review: $AnthropicModel_JudgeCheap (Light/ReviewOnly when the toggle is on)

Live runs commonly use cheaper answer models (e.g. haiku-4-5 for Answer B); the strong Full
judge stays opus regardless.

### Task list
Either the explicit GUI list (tasks_input.json via MULTILLM_TASKS_FILE) OR the heuristic
splitter. Split-UserPromptIntoTasks splits multi-line prompts only when >=2 lines look like
separate tasks AND total non-empty lines <= 12 (Mode None disables; MaxTasksPerPrompt=10);
single-task prompts pass through. Get-TaskType assigns the type. Both are top-level functions
and the GUI Detect Tasks preview calls the SAME ones, so preview == run split. Do not fork a
second splitter.

### Router: task types and routing policy
Types: simple / technical / code / ui_code / documentation / creative.
- code, ui_code, technical: OpenAI + Sonnet + Judge
- documentation: MissingInput pre-check; source absent -> SKIPPED, 0 AI calls
- creative: Sonnet only, no Judge
- simple: OpenAI only

Get-RouterDecision returns a PSCustomObject: TaskType, UseOpenAI, UseAnthropicAnswer,
UseJudge, WorkMode, WorkModeOverrideApplied, JudgeModePolicy (Auto/ReviewOnly/Skipped),
Reason, timeouts, token budgets. Per-task TypeOverride / WorkModeOverride (v0.8.39/0.8.40)
are applied as GATES around the call sites - the frozen function BODIES are not touched.

### WorkMode (Auto / Review / Script) - Get-TaskWorkMode  [LOGIC FROZEN]
Review = notes + small snippets; Script = full runnable scripts. Auto order (matters):
1. ui_code: explicit complete/full/runnable/create/write script -> Script, else Review.
2. technical + correction wording -> Script (BEFORE the generic review rule).
3. generic review/analyze/audit/suggest/explain-the-bug -> Review.
4. code + script/code/function/wpf/xaml -> Script.
5. technical fallback / documentation / creative / simple -> Review.
Do NOT change this function except the version comment.

### Judge  [CRITICAL]
Marker contract (do not change casually; markdown inside JSON breaks ConvertFrom-Json):
- ---JUDGE_JSON--- (small clean JSON; no markdown/code inside)
- ---FINAL_ANSWER_MARKDOWN--- (markdown/code allowed)
- ---IMPROVED_PROMPT--- ("No improved prompt." if none)
Modes: Full (2 answers, compare+synthesize), Light (1 answer, validate), ReviewOnly (notes/verdict).
Judge JSON: best_answer_id, confidence, scores.{A,B}.{6 criteria}, problems_found[],
best_parts_reused[], final_answer_source (v0.8.6; A/B composition summing to 100). Read via
Get-JudgeVerdict (defensive). Surfaced as a "=== Judge verdict ===" block prepended to the
merged final answer (Format-JudgeVerdictBlock).

JUDGE MODEL POLICY (v0.8.0; live-validated):
- Full -> ALWAYS $AnthropicModel_JudgeStrong (claude-opus-4-8). GUI Judge combo and cheap
  toggle IGNORED. If selected judge != strong, a [WARN] logs.
- Light / ReviewOnly -> cheap judge if $UseCheapJudgeForReview, else selected judge.
Implemented per-task: `if ($JudgeMode -eq "Full") { $JudgeModelToUse = $AnthropicModel_JudgeStrong }`.
JudgeModelUsed is carried per TaskResult and shown as the Judge Model column.

### Personas (v0.8.41) - static, backend
Config-overridable persona table (architect / ui_ux / devils_advocate / qa / senior_dev /
none). PersonaMode Off (default, byte-identical to before) or Fixed; in Fixed, Answer A/B get
PersonaA/PersonaB PREPENDED to a per-model COPY of the effective prompt. The Judge and
effective_prompt.txt stay persona-free; the shared EffectivePromptText is never mutated. Each
persona ends with a rule-lock tail so it cannot override formatting / PS 5.1 / AD-safety /
ASCII / self-check rules.

### Clarification gate (v0.8.25/0.8.26) - GUI option
"Ask questions if prompt is vague" with Local/AI mode. Local = free heuristic; AI = uses the
configured Anthropic review judge to decide if clarification is needed and to generate
questions BEFORE the real run starts.

### Embedded generation rules (answer + judge prompts)
The answer and judge SYSTEM prompts are DOUBLE-QUOTED here-strings, so PowerShell interpolates
every $-token at job runtime. RULE: any instruction $ in these prompts MUST be backtick-escaped
(`$true, `$false, `$null, `$_) or it is sent to the model as interpolated garbage. This was a
real latent bug (v0.8.2) and the root of the v0.8.52 fix too.
Rules embedded: cls, vars-at-top, no param, if/else, Try/Catch, never Export-Csv after
Format-Table, @() before .Count, ASCII-only output, return-not-Exit, create export folders with
New-Item -Force, AD -Filter Booleans use `$true/`$false WITH the dollar sign, AD inventory
includes DistinguishedName and omits constant columns, behavioral claims proven by a runnable
self-check. v0.8.52: the null-comparison rule now states the REAL PS 5.1 semantics ($null sorts
LESS THAN any value, so -lt/-le INCLUDE nulls) and forbids the old inverted claim; the self-check
must PASS on a clean host.

### Parallelism / cost / metrics
Start-Job per answer model; per-model + total + judge timeouts (judge default 90 s); retry x1
on null/429/5xx, never on 400/401/403. Helper functions are intentionally DUPLICATED inside job
scriptblocks (PS 5.1 jobs do not inherit session functions) - do NOT refactor away. Cost from
config CostPer1MTokens by "Provider|Model" key. Get-EstimatedCostUsd is byte-frozen. Unknown-model
cost is reported (cost_warnings.json), never silent.

### Run-folder layout (v0.8.x; KeepTaskSubfolders = $true)
Run_<timestamp>\ (root - aggregates):
- input_prompt.txt, tasks.json, tasks_input.json (GUI explicit list), gui_prompt.txt
- task_results_summary.json / .md (per-task fields: TaskId, TaskType, WorkMode, Success,
  AnswerCount, JudgeMode, JudgeModelUsed, CompletenessWarning/Reason, Input/Output/TotalTokens,
  EstimatedCostUsd, TaskFolder, Error)
- final_answer.md (merged, all tasks), timing_summary.json
- cost_summary_by_role.json, cost_summary_by_model.json, cost_warnings.json,
  completeness_warnings.json, errors.json
- stage_metrics.csv, request_metrics.csv, run_metrics.csv (conditional)
- console_transcript.txt, gui_run_report.json
- Task_NN\ subfolders (one per task, NN = TaskId zero-padded)

Task_NN\ (per task):
- input_prompt.txt, effective_prompt.txt, router_decision.json, missing_input_check.json
- answers_raw.json (the answers; there are NO answer_A/answer_B .md files anymore), errors.json
- run_metrics.csv, request_metrics.csv, stage_metrics.csv
- judge_raw.json, judge_text.txt, judge_scores_text.json, judge_parsed.json (only when a judge
  ran), selected_answer.md (Light/ReviewOnly), final_answer.md (per-task)

The run-review helper (add\Multi-LLM-RunReviewHelper-v0.3.ps1) understands this layout and treats
judge files as conditional on router_decision.json UseJudge.

---

## 4. GUI

Zones (vlad-wpf-design): top menu bar (Settings / Help) + left sidebar nav + Header
(title + version badge + model route panel + API-keys status + Set API Keys) / Input /
TabControl / Actions / dark collapsible Log / right inspector rail / StatusBar.

Input: Prompt (multiline Consolas) | Preset | Splitter (Heuristic/None) | Work mode |
UI auto mode | clarification gate (Local/AI) | Model A | Model B | Judge | review-judge toggle.
Model combos IsEditable=True (typed ids allowed; deliberate exception). Preset/Work mode/UI
mode carry accent labels.

Tabs:
- Full Answer (the merged answer for all prompts).
- Tasks - dual mode: editable pre-run task-review grid (Detect Tasks fills it; Select/Run
  checkbox per row, header master checkbox, Type + Work mode overrides in the details pane,
  per-row route/cost/tokens/judge estimates) and read-only results after a run (live per-task
  Status colors as tasks finish). Columns: Id/Type/Work/OK/Ans/Judge/JudgeModel/Compl/
  Tokens/Cost(USD,ILS)/Title/Error.
- Metrics (timing + cost-by-role + cost-by-model + cost-warnings).
- Run Log.

Right inspector rail: Run Details / Cost (configurable budget Output.CostBudgetUsd, predicted
vs actual delta, USD + approx ILS at 3.7) / Token Usage / Latency / Run Health.

Actions: Detect Tasks | Run (label reflects API-key state; auto-Detects if no tasks) |
Full Answer (separate window) | Copy | Improved Prompt | Run Folder | Config (menu:
open config / set API keys) || Stop | Exit. Run-done plays a sound and recolors the status bar.

Safety/plumbing: STA guard before Add-Type; SelfPath check; API-key pre-check + GUI key entry;
UIReady; timer stopped + child killed on Closing.

---

## 5. VERSION HISTORY (condensed; full numbered changelog is in the .ps1 header)

- v0.7.0 - v0.7.9: WPF GUI + headless child; logs/report; WorkMode combos; row coloring;
  cheap judge; editable model combos; busy-gray Run; separate Full Answer window; cost-by-model;
  unknown-model cost WARN; self-check answer/judge rules; per-task tokens/cost; Routing Notes;
  "Final"->"Full Answer" rename.
- v0.8.0 - v0.8.2: Full-always-strong-judge (+WARN on mismatch, JudgeModelUsed); model-clarity
  log/header + Detect Tasks preview; durable AD-inventory prompt rules + prompt $-escape fix.
- v0.8.3 - v0.8.8: script-relative config/secrets paths; header model panel; GUI API-key entry
  (masked, DPAPI); judge-verdict block in the final answer; operator labels + state-based Run +
  header API-keys status.
- v0.8.9 - v0.8.40 (Phase 2): editable Edit/Tasks list + tasks_input.json + MULTILLM_TASKS_FILE;
  task-review grid with select/Run-selected, estimates, details pane; sidebar nav + right
  inspector rail + two-rail layout; top menu bar; configurable cost budget; predicted-vs-actual
  cost; shekels display; per-task routing overrides (backend v0.8.39, GUI v0.8.40).
- v0.8.41 - v0.8.51: persona backend; grid/rail polish; run-done sound+color; live judge/cost
  re-estimate on model/judge change; auto-Detect on Run; labeled task details; per-task progress
  colors; sidebar nav actions; version badge; log Collapse/Expand toggle.
- v0.8.52: generated-code correctness fix - corrected the `$null -lt [DateTime]` rule (PS 5.1:
  $null sorts LESS THAN any value, so -lt/-le INCLUDE nulls), re-confirmed backtick-escaping of
  all instruction $ in the four answer/judge prompt blocks, and required the self-check to PASS
  on a clean host. Prompt text only; frozen functions, judge markers, and pipeline unchanged.
- v0.8.53: Stop now kills the whole backend process tree (Stop-ChildProcessTree: taskkill /T, with
  a recursive Win32_Process fallback) from the Stop button and the window Closing handler, so a
  stopped run cannot leave its Start-Job answer/judge grandchildren making in-flight API calls.
  GUI/teardown only; frozen functions, judge policy, routing, and cost math unchanged.
- v0.8.54: RunFinalVerifier implemented (opt-in, OFF by default). A gated post-pass after the per-task
  loop independently checks each task's final answer (Invoke-AnthropicVerifier - HTTP cloned from the
  judge; Get-VerifierVerdict parser; writes Task_NN/final_verification.json + a run summary). Verifier
  is NOT the judge; defaults to the strong judge model. Default behavior byte-identical; frozen
  functions + judge contract unchanged. Live LLM path not yet tested (no keys in build env); the
  parser (14/14) + the off-by-default gating are.
- v0.8.55: GUI toggle for the verifier. New "Run final verifier" checkbox (ChkRunVerifier) passes a
  new MULTILLM_RUNVERIFIER env var to the child, which sets $RunFinalVerifier for that run (CLI
  unchanged when the var is absent). Off by default. XAML-load smoke-tested + harness PASS 48/0;
  runtime still needs a keyed GUI run to confirm.
- v0.8.56: report/banner version strings now use $ToolVersion instead of a hardcoded "v0.8.52" (a
  live v0.8.55 run showed final_answer.md headers mislabelled as v0.8.52). Output text only; frozen
  functions, judge contract, routing, and cost math unchanged.
- v0.8.57: first-run clarity polish (part 1) from the design-system onboarding handoff. Run button
  reads "Run N selected"; unchecked pre-run tasks show "Not selected" (was "Skipped" - row .Status
  value only; JudgeMode="Skipped" + row-color triggers untouched); right-rail Cost card labels
  "Estimated cost" before the run and "Actual cost" after. GUI text/labels only; frozen functions,
  judge contract, routing, cost math unchanged. PARTS TO FOLLOW (need a live GUI pass): a 3-step rail
  (Prompt -> Detect -> Run), a dismissable quick-start card (persisted), an Advanced-settings expander
  for the model/judge/splitter/work-mode controls, and tab/queue empty states. Spec + React mock are
  in the user's "Multi-LLM Prompter Design System.zip" (design_handoff_first_run); behavioral changes
  apply within the flat WPF chrome (no reskin).
- v0.8.58: first-run clarity polish (part 2). Added a "How it works" strip under the header (Prompt
  -> two models answer -> Opus judge writes one final answer) and put the pre-run cost on the Run
  button ("Run (N task)" / "Run (N tasks) - est. $X.XX"). GUI text + one layout band; frozen
  functions, judge contract, routing, cost math unchanged. STILL TO FOLLOW (need a live GUI pass):
  Advanced-settings expander, dismissable quick-start card, tab/queue empty states.

---

## 6. KNOWN ISSUES / WATCH LIST

1. [FIXED v0.8.53] Stop now terminates the whole backend process tree (Stop-ChildProcessTree:
   taskkill /PID <id> /T /F, with a recursive Win32_Process fallback), wired into the Stop button
   and the window Closing handler, so a stopped run no longer leaves Start-Job grandchildren making
   in-flight API calls. Verified against a synthetic parent->children process tree.
2. [watch] Completeness-warning false positives (markdown endings without punctuation) -
   intentionally unfixed; collecting stats.
3. [info] Config "Version" lags the script version - harmless by design.
4. [closed] Cheap judge leaking into Full (v0.8.0). Unknown-model silent cost (v0.7.7).
   Stale config / wrong Opus pricing (v0.7.5+). Prompt $-interpolation (v0.8.2 + v0.8.52).
5. [done] RunReviewHelper rewritten to v0.2 (parse fix + current Run_*/Task_NN layout).

---

## 7. ROADMAP

- v0.9 Benchmark mode (DELIVERED - v0.2 runner): add\Multi-LLM-Benchmark-v0.2.ps1 drives the
  headless pipeline over the Gate1 CSV and reports routing accuracy (actual vs ExpectedTaskType),
  judge best-answer, and cost/tokens/time (benchmark_results.csv + benchmark_summary.md). DryRun
  (default) and report-only modes; a live run spends real money. The subjective Gate-1 verdict
  (does the final beat both singles) stays a manual read - auto-scoring it is RunFinalVerifier.
- v0.9 RunFinalVerifier (DELIVERED v0.8.54, opt-in / OFF by default): a verifier distinct from the
  judge. Gated post-pass; enable via the GUI "Run final verifier" checkbox (v0.8.55, MULTILLM_RUNVERIFIER)
  or config Behavior.RunFinalVerifier = true (or $RunFinalVerifier).
  Writes Task_NN/final_verification.json + final_verification_summary.json; verifier model defaults to
  the strong judge ($VerifierModel/$VerifierMaxTokens override). Needs a live run with keys to confirm
  the LLM path end-to-end (build env had no keys).
- Validation harness (DELIVERED): Validate-MultiLLM.ps1 parser-checks the app + helper + benchmark,
  verifies BOM/CRLF/ASCII/here-string balance + no top-level param(), proves the frozen functions
  are present and behaviorally unchanged (golden cost/routing cases), and checks the judge markers
  + Full->strong-judge enforcement. Run it before every delivery.
- Versioning (DECIDED 2026-06-15, refined 2026-06-16): per main-script change the order is
  "backup, then rename the new version":
  1. copy the current Multi-LLM-Prompter-vX.ps1 into backups\ (gitignored local safety net),
  2. make the change,
  3. git mv to vX+1 + bump the in-file $ToolVersion/header + add a numbered changelog entry,
  4. run Validate-MultiLLM.ps1,
  5. one git commit per version.
  backups\ never bloats the repo (gitignored); git history is the canonical version record.
  The single live Multi-LLM-Prompter-v*.ps1 is the working file.
- LATER / parked: judge-tier-by-complexity (low ROI for the AD/security workload, which stays
  Full Opus by policy). Deferred: OpenRouter/LiteLLM backend, 4-5 answer models, separate
  Synthesizer, RAG, per-task model matrix.

---

## 8. BINDING CONVENTIONS (this project)

- PS 5.1 / ISE. UTF-8 BOM, CRLF. ASCII-only source; Unicode ONLY as `&#x...;` XAML entities.
  `cls` first. No top-level param() (env vars instead). No ternary / `??`. Full files only;
  never drop features; ALWAYS bump the version everywhere + add a numbered changelog entry;
  never reuse a version number.
- PROMPT here-strings are double-quoted: escape EVERY instruction $ with a backtick, or the
  model receives interpolated garbage.
- WPF: vlad-wpf-design palette/zones; Border-wrapper rounded buttons; no -f on XAML strings
  (.Replace only); inline styles in standalone here-string windows; UIReady guard; timers
  stopped on close; ComboBox IsEditable=False EXCEPT model combos. Add_Click handlers use
  $Script: globals.
- LOAD-BEARING, do not "clean up": judge marker contract; duplicated-functions-in-jobs pattern;
  Get-TaskType / Get-TaskWorkMode logic; Get-EstimatedCostUsd; the Full->strong judge enforcement.
- Distinguish layers: a flaw in a GENERATED script is fixed by changing the answer/judge PROMPT
  RULES, not the tool's own code.
- Validate before delivery (real syntax check is available, no execution / no API calls):
  `[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$errs)` (0 errors),
  BOM present, `cls` first, 0 non-ASCII body bytes, here-strings balanced (@" == "@), code-only
  paren balance == 0, Add_Click count as expected, diff the FROZEN functions to prove untouched,
  grep that prompt $-tokens stay backtick-escaped.
- Logs/outputs under C:\Temp. Color is never the sole meaning carrier.

---

## 9. FIRST PROMPT FOR NEXT SESSION (suggested)

"Multi-LLM Prompter: here is the HANDOFF and v0.8.55 (daily driver, mechanically clean). NOTE: the
last session's work is on branch chore/docs-helper-harness (10 commits ahead of main, pushed,
UNMERGED) - check it out / merge / open the PR first. Phase 2 + RunFinalVerifier (opt-in) are
DELIVERED. Load the multi-llm-prompter skill with ps-wpf-core (+ vlad-wpf-design for GUI). Respect
the frozen functions (Get-TaskType / Get-TaskWorkMode / Get-EstimatedCostUsd), the judge marker
contract, and the Full->strong-judge policy. FIRST: if API keys are set, live-validate the verifier
(enable 'Run final verifier' / MULTILLM_RUNVERIFIER) end-to-end and run the benchmark
(add\Multi-LLM-Benchmark-v0.2.ps1, flip $DryRun=$false) - these are built but were never live-tested
(no keys last session). Versioning per change: copy the current Multi-LLM-Prompter-v*.ps1 into
backups\, edit, git mv to the next version, bump $ToolVersion + header + changelog, keep prompt
$-tokens backtick-escaped, then run Validate-MultiLLM.ps1 (must be PASS) before delivery."
