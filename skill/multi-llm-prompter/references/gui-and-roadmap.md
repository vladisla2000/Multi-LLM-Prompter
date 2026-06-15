# GUI And Roadmap

## GUI zones (vlad-wpf-design)

Header #0F3460 (title + models-in-use panel + run folder) / Input / TabControl /
Actions / dark log / StatusBar.

- Header models panel (v0.8.4): a labeled 2x2 grid of the models ACTUALLY in use -
  Answer A (`HdrModelA`), Answer B (`HdrModelB`), Judge Full-forced-strong
  (`HdrJudgeFull`, amber), Cheap Light/Rev (`HdrJudgeCheap`). Set in two places:
  startup + on Run; the selected-vs-strong `[WARN]` still fires on Run. Replaced the
  old single cramped `HdrModels` line.

- Input: Prompt (multiline Consolas) | Preset | Splitter (Heuristic/None) | Work mode |
  UI auto mode | Open-in-Notepad / Open-folder | Model A | Model B | Judge |
  Cheap-judge checkbox + combo.
- Tabs: Full Answer (renamed from "Final Answer" in v0.7.9; filename + marker + ids
  unchanged) | Tasks | Metrics | Run Log.
- Tasks grid columns: Id / Type / Work / OK / Ans / Judge / JudgeModel / Compl / Tokens
  / Cost / Title / Error. Row coloring via XAML DataTriggers (Completeness=WARN amber,
  Success=False red) - color is never the sole meaning carrier.
- Actions: Detect Tasks | Run #0B6A0B | Full Answer (separate window) | Copy | Improved
  Prompt | Run Folder | Config || Stop #A4262C | Exit.
- Config button (v0.8.5) is a small settings menu (ContextMenu built in CODE, not XAML,
  to dodge the named-MenuItem namescope gotcha): "Open config file" / "Set API keys...".
- UI naming (v0.8.7): NEVER show "Cheap" in the UI. Labels are "Quality judge" (the
  selected/Full-forced judge) and "Review judge" (Light/ReviewOnly), checkbox "Use review
  judge for light checks". The internal vars/config keys/env var (`AnthropicModel_JudgeCheap`,
  `CheapJudgeCombo`, `ChkCheapJudge`, `MULTILLM_CHEAP_JUDGE`, `AnthropicJudgeCheap`) keep the
  "Cheap" name - they are load-bearing; only the visible text changed.
- State-based Run button (v0.8.7): `Update-RunButtonState` (called from Set-RunBusyState's
  not-busy branch, the Run handler, the keys-dialog save, and startup) makes the primary
  button read "Set API keys to run" (#0078D7, width 160) when `Get-ApiKeyReadiness` is not
  ready - clicking it opens `Show-ApiKeysWindow` - and "Run" (#0B6A0B) when ready.

## API keys (v0.8.5)

`Set API keys...` opens `Show-ApiKeysWindow` - a modal `PasswordBox` dialog. Save calls
`Save-MultiLLMApiKeysSecure` (non-interactive twin of `New-MultiLLMSecretsFile`, no
Read-Host / no exit) which writes the SAME PSCustomObject (`OpenAIKey`/`AnthropicKey`
SecureStrings + CreatedAt/ComputerName/UserName/`Format="DPAPI-CLIXML"`) via
`Export-Clixml`, then `Initialize-ApiKeys` reloads. Keys stay SecureString end-to-end
(`PasswordBox.SecurePassword`); never logged, never converted to plaintext on save. Blank
field = keep existing key. DPAPI is user+machine bound (not portable).

Three entry points to the SAME dialog: (1) Config menu "Set API keys..." (v0.8.5); (2) the
primary Run button when keys are missing reads "Set API keys to run" (v0.8.7); (3) a header
"Set API Keys" button + `HdrApiStatus` indicator ("API keys: OK/missing", green/red) on the
top-right (v0.8.8). `Update-ApiStatusHeader` + `Update-RunButtonState` refresh together on
startup, after any save, and on a run attempt - keep them in sync if you add a 4th entry.

## Model-combo exception

Model combos are `IsEditable=True` (typed ids allowed) - the deliberate exception to
the project's usual `ComboBox IsEditable=False` rule. Keep it.

## Detect Tasks (v0.8.1) and Phase 2

- v0.8.1 Detect Tasks is a READ-ONLY preview: it splits the current prompt with the SAME
  splitter + classifier the run uses and previews Id/Type/Title into the Tasks tab. No
  child, no API call. Logs "Detected N task(s) - preview only".
- Phase 2 FOUNDATION (v0.8.9, DONE): the architecture change shipped. Detect Tasks also
  fills a new "Edit Tasks" tab (`TasksEditBox`, one task per line) + checks
  `ChkUseEditedTasks`. On Run, if that box is in use, the GUI writes `tasks_input.json`
  (array of {TaskId, PromptText}) to the run folder and passes `MULTILLM_TASKS_FILE`; the
  child loads that list INSTEAD of `Split-UserPromptIntoTasks` (falls back to the splitter
  if absent/empty). Chosen text-line editor over a DataGrid/cards because live WPF binding
  can't be parser-verified blind - the editor is bullet-proof. The "Edit Tasks" tab is the
  LAST TabItem (index 4) on purpose: tab indices are hardcoded (`SelectedIndex=3` = Run Log),
  so never insert a tab before the end.
- Phase 2 NEXT (visual, needs ISE iteration): restyle the editor into the cards /
  checkbox-grid "Run Selected" panel (per-task badge, select checkbox, Merge, reorder
  buttons) on top of the proven `tasks_input.json` foundation.

## Known-issue watch-list

- Completeness-warning false positives (markdown endings without punctuation):
  intentionally unfixed, collecting stats.
- Stop kills only the child; Start-Job grandchildren may finish in-flight calls (warning
  logged). Process-tree kill would clear the backlog but is not implemented.
- Judge cost dominance (~93% on a tiny script) is EXPECTED because Full = Opus; not a bug.

## Roadmap

- v0.8.2 (DONE): AD-inventory answer/judge prompt rules (New-Item -Force,
  DistinguishedName, no constant Enabled column). Prompt-only; routing/cost untouched.
- v0.8.3 path-fix (DONE): `$ConfigPath`/`$SecretsPath` script-relative + legacy fallback.
  Remaining v0.8.3 items (open): add `AnthropicJudgeStrong` to the on-disk config + bump
  its Version; upgrade `add\Multi-LLM-RunReviewHelper` to the current Run_* output layout.
- v0.8.4 (DONE): GUI model clarity - header models-in-use panel (see GUI zones above).
- v0.8.5 (DONE): GUI API key entry - Config settings menu + DPAPI PasswordBox dialog
  (see API keys section above). No more headless run needed to set keys.
- v0.8.6 (DONE): Judge verdict block in the final answer (better answer + A/B contribution
  bar + scores), via new judge JSON field final_answer_source (see pipeline-and-judge.md).
  FOLLOW-UP (deferred): Tasks-grid columns Best / A% / B% - needs the child summary
  projection (task_results_summary.json) + GUI grid map + XAML columns.
- v0.8.7 (DONE): Operator polish round 1 - removed "Cheap" from the UI (Quality/Review
  judge), state-based Run button "Set API keys to run" -> opens keys dialog (see notes above).
- v0.8.8 (DONE): Header credentials affordance - "Set API Keys" button + API-status
  indicator top-right (best-from-mock), opens the same dialog (see API keys section).
- v0.8.9 (DONE): Choose/edit tasks before run - Detect Tasks Phase 2 FOUNDATION (Edit Tasks
  tab + tasks_input.json + MULTILLM_TASKS_FILE; see Detect Tasks section). Note: it also
  counts tokens + USD cost per call/task/role/model + run total (actual, post-run); a PRE-run
  estimate does NOT exist yet (that's the Task Queue cost-est column / pre-run estimator).
- NEXT GOAL (user-set 2026-06-13): PRE-RUN ESTIMATOR. Before a run, estimate input/output
  tokens, USD cost, and time PER TASK and TOTAL, shown in the GUI (per-task Est. Cost/Time
  columns + totals). Uses the frozen `Get-EstimatedCostUsd(Provider,Model,In,Out)` + per-type
  output budgets (`$MaxOutputTokens*` lines 214-226) + per-type timeouts (`$Timeout*Sec`
  236-241) + replicate the routing (which models run per type) in a GUI helper. Output is an
  estimate (clamp + label "~"); real cost still comes post-run. This feeds the per-task cost
  in the Task Review feature below.
- THEN: TASK REVIEW / SELECTIVE RUN (spec: OneDrive\...\WPF_Task_Review_Handoff.txt, 2026-06-13).
  Rich version of v0.8.9: DataGrid of tasks with checkbox (IsSelected, default all) + #/type-
  badge/title/excerpt/status-chip/route/est-cost, tri-state header check, dynamic Run button
  ("Run N Tasks" / "Run N Selected" / disabled @0), Task Details right pane. RUN-FILTERING IS
  ALREADY DONE (v0.8.9 tasks_input.json): unselected tasks just aren't written, so they're
  never sent/judged/billed. CAVEAT: the spec assumes MVVM/computed-property bindings; this app
  is NOT MVVM (single-file PS 5.1, manual control wiring), so SelectedCount/RunButtonText/etc.
  are computed in CODE on checkbox events, not auto-bound. Badge taxonomy (Script/Audit/Summary/
  Creative/GUI/General) must MAP to the real TaskType (simple/technical/code/ui_code/documentation/
  creative). Live DataGridTemplateColumn binding needs ISE iteration (parser-only verifiable).
- ALSO (operator-layout track): right-hand Run Status panel; collapsible+themed bottom log;
  status bar Tasks 0/N. BIGGER (new features): left nav + Runs/Prompts/Presets history, Model
  Comparison tab. Stay WPF/PS5.1; web mock-up is design spec, not a replatform.
- TAB INDICES: de-hardcode via a `Select-MainTab -Header` helper (replaces SelectedIndex=0/1/3)
  so tabs can be reordered/inserted safely - prereq for the Task Review tab work.
- v0.9: Benchmark mode (Gate1 CSV); real RunFinalVerifier (verifier != judge).
- v1.0: config + adapters + CLI + GUI + benchmark + presets.
- Deferred: OpenRouter/LiteLLM backend, 4-5 answer models, separate Synthesizer, RAG,
  per-task model matrix.
