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

## Detect Tasks and Phase 2 (DELIVERED, v0.8.9 - v0.8.40)

Phase 2 shipped incrementally - the editable Tasks panel, selective run, pre-run estimator,
and per-task routing overrides are all DONE. Current state:

- Detect Tasks splits the current prompt with the SAME splitter + classifier the run uses
  (no child, no API) and fills the Tasks tab. On Run with no detected tasks, the GUI
  auto-Detects first (v0.8.46 `Invoke-DetectTasks`).
- The Tasks tab is DUAL-MODE: an editable pre-run task-review grid and a read-only results
  grid after a run (`Select-MainTab` replaced the hardcoded SelectedIndex jumps, v0.8.10).
- Pre-run task-review grid: per-row Run checkbox (live CheckBox template, v0.8.13) + header
  master tri-state checkbox (v0.8.27), Type / Title / excerpt, route, and PRE-RUN estimates
  (Est. Cost / Tokens / Time) computed by `Get-GuiTaskEstimate` from the frozen
  `Get-EstimatedCostUsd` + per-type budgets/timeouts (v0.8.10/0.8.15). Selected/all totals
  in a summary + status bar. Estimates re-run live when the model/judge selection changes
  (v0.8.45) and on combo LostFocus for typed ids (v0.8.47).
- Selective run: on Run, only SELECTED tasks are written to `tasks_input.json` (array of
  {TaskId, TaskTitle, PromptText, TypeOverride, WorkModeOverride}); unselected tasks are
  never sent/judged/billed. Child loads that list INSTEAD of `Split-UserPromptIntoTasks`
  (falls back to the splitter if `MULTILLM_TASKS_FILE` is absent/empty - the CLI safety net).
- Per-task routing overrides: the Selected Task Details pane has Type + Work mode dropdowns
  (default Auto = use the router). A non-empty override sets TypeOverride / WorkModeOverride,
  re-runs the row estimate, and is written to tasks_input.json. Applied as GATES around the
  call sites; `Get-TaskType` / `Get-TaskWorkMode` BODIES stay byte-frozen (v0.8.39 backend,
  v0.8.40 GUI). Effective route + cost are logged so an override cannot silently change cost.
- Live per-task progress: during a run the grid colors rows as tasks finish - Done green,
  Running amber, pending neutral (v0.8.48), driven from the poll timer.

## Other GUI surface added since v0.8.8

- Left sidebar nav (v0.8.19) with working actions (v0.8.50): Runs -> Tasks tab, Prompts ->
  focus prompt, Presets/Models -> open dropdowns, Settings -> config menu.
- Right inspector rail (v0.8.20, widened through v0.8.42): Run Details / Cost / Token Usage /
  Latency / Run Health. Cost card has a configurable budget (`Output.CostBudgetUsd`, 0 = off,
  v0.8.29), predicted-vs-actual delta (v0.8.30), and approx ILS at rate 3.7 (v0.8.34/0.8.38).
- Top menu bar (v0.8.31): Settings (config / set keys / output folder) + Help (about /
  session log / developer notes), built in CODE to dodge the MenuItem namescope gotcha.
- Personas (v0.8.41): static persona preambles for Answer A/B (see pipeline-and-judge.md).
- Clarification gate (v0.8.25/0.8.26): "Ask questions if prompt is vague" with Local/AI mode.
- Run-done signal (v0.8.43): status bar recolors green/red + a sound plays.
- Version badge in the header (v0.8.44); single Collapse/Expand log toggle (v0.8.51).
- Flat Button style with a visible disabled state (v0.8.32); tooltips on controls (v0.8.36).

## Known-issue watch-list

- Completeness-warning false positives (markdown endings without punctuation):
  intentionally unfixed, collecting stats.
- Stop kills only the child; Start-Job grandchildren may finish in-flight calls (warning
  logged). Process-tree kill would clear the backlog but is not implemented (real money).
- Judge cost dominance (~93% on a tiny script) is EXPECTED because Full = Opus; not a bug.

## Roadmap

- v0.9: Benchmark mode (Gate1 CSV in `add\Multi-LLM-Gate1-Benchmark-Prompts.csv`); real
  RunFinalVerifier (a verifier distinct from the judge).
- Maintainability (proposed): a Validate-MultiLLM.ps1 harness (parser-check app + helper,
  BOM/CRLF/ASCII/here-string balance, prove frozen functions untouched; optional Pester for
  splitting/routing/cost/judge-markers/config fallback).
- Versioning (DECIDED 2026-06-15): release discipline moves into git commits per version
  (commit each version with the changelog entry as the message) instead of accumulating
  versioned .ps1 files. `backups\` stays gitignored as a local safety net. Still bump the
  in-file version + changelog every build.
- v1.0: config + adapters + CLI + GUI + benchmark + presets.
- Deferred / parked: judge-tier-by-complexity (low ROI; AD/security stays Full Opus by
  policy); OpenRouter/LiteLLM backend, 4-5 answer models, separate Synthesizer, RAG,
  per-task model matrix.

## Dev helper

- `add\Multi-LLM-RunReviewHelper-v0.2.ps1` (DONE): reviews one completed run folder. v0.1 was
  broken (a markdown backtick escaped a closing quote -> 21 parse errors) and assumed the old
  flat output. v0.2 parses clean and understands the Run_*/Task_NN layout, reading answers from
  answers_raw.json and validating judge files only when router_decision.json UseJudge = true.
