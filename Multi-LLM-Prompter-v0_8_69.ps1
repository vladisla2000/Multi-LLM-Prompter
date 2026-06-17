cls

# ============================================================
# Multi-LLM Prompter v0.8.69 - PowerShell 5.1 Backend
# ============================================================
# Changes through v0.8.69:
#   1. OpenAI uses Chat Completions endpoint and messages body.
#   2. Claude Judge output split into:
#      ---JUDGE_JSON---
#      ---FINAL_ANSWER_MARKDOWN---
#      ---IMPROVED_PROMPT---
#      This avoids putting Markdown/code blocks inside JSON.
#   3. Added separate Judge timeout.
#   4. Router code-trigger override is explicit.
#   5. Judge JSON template explicitly includes Answer A and Answer B in Full mode.
#   6. Final answer parser trims accidental Improved Prompt text if marker is missing.
#   7. Added optional console output for the final answer.
#   8. Router detects "create ... script" as code.
#   9. Added duration/tokens/cost placeholder metrics.
#   10. Better HTTP error body extraction.
#   11. Judge instruction prevents Export-Csv after Format-Table.
#   12. Added hardcoded API key detection / safety stop.
#   13. Added encrypted secrets file creation/loading via Export-Clixml.
#   14. Added Active Directory PowerShell filter safety instructions.
#   15. v0.5.8: Fixed Test-ScriptSecretExposure regex patterns for legacy key variable assignments.
#   16. v0.5.9: Replaced Out-File text/json writers with explicit UTF-8 BOM .NET writers and common smart-punctuation repair.
#   17. v0.5.10: Tightened Judge final-answer instructions to prevent candidate/Judge meta leakage in user-facing output.
#   18. v0.6.0: Added JSON config, adapter wrappers, cost estimates, and heuristic task splitting.
#   19. v0.6.1: Added built-in multi-task prompt presets, improved single-task final output, and longer task titles.
#   20. v0.6.2: Fixed multi-task final merge polish: full task headings, all improved prompts, stricter Count/GUI judge rules.
#   21. v0.6.3: Added stage_metrics.csv and request_metrics.csv for every pipeline stage and AI model request.
#   22. v0.6.4: Added cost-control routing, MissingInput skip, per-task timeouts, and ASCII-safe code-output rules.
#   23. v0.6.6: Syntax hotfix for MissingInput inline-content check (literal triple-backtick detection).
#   24. v0.6.6: Added output token budgets by task type, completeness warnings, and cost-by-role summary.
#   25. v0.6.6: Added TaskWorkMode Auto/Review/Script and ReviewOnly Judge mode for long UI/code reviews.
#   26. v0.7.0: Added WPF GUI front end. The GUI launches this same script as a hidden headless child
#       process (env vars MULTILLM_HEADLESS / MULTILLM_PROMPT_FILE / MULTILLM_RUNFOLDER / MULTILLM_SPLITMODE),
#       monitors the run folder with a DispatcherTimer, and shows Final / Tasks / Metrics / Run Log tabs.
#       Set LaunchGui = false for the classic CLI behavior. Backend pipeline logic is based on the
#       v0.6.7 behavior: technical correction tasks route to Script while ui_code concepts stay ReviewOnly.
#   27. v0.7.1: Added automatic GUI observability: persistent gui_session.log (all GUI events with
#       timestamps, progress changes, child PID/exit) and per-run gui_run_report.json written into the
#       run folder on every outcome (Completed / CompletedNoFinal / Failed / StoppedByUser / LaunchError).
#   28. v0.7.2: GUI exposes TaskWorkMode (Auto/Review/Script) and UI auto mode (Review/Script) and passes
#       them to the child via MULTILLM_WORKMODE / MULTILLM_UICODE_MODE. Added STA guard, Stop behavior
#       warning, preset initialization from PromptPreset, and a separate Improved Prompt window with
#       Copy and Use-as-Prompt actions.
#   29. v0.7.3: Tasks grid uses explicit columns with row coloring (amber = completeness WARN,
#       red = failed task), double-click on a task opens its final answer in a details window,
#       Stop button gets a visible disabled style, and the header shows the active model route.
#   30. v0.7.4: Added cheap Judge option (AnthropicModel_JudgeCheap is used for Light and ReviewOnly
#       judge modes when UseCheapJudgeForReview is on; Full comparison keeps the strong judge) and
#       GUI model selection: Model A / Model B / Judge / Cheap judge combos passed to the child via
#       MULTILLM_MODEL_OPENAI / MULTILLM_MODEL_ANTHROPIC / MULTILLM_MODEL_JUDGE /
#       MULTILLM_MODEL_JUDGE_CHEAP / MULTILLM_CHEAP_JUDGE. Haiku pricing added to the cost table.
#   31. v0.7.5: Routing fix: the technical correction rule now runs BEFORE the generic review rule, so
#       "explain the bug and propose a safe PowerShell 5.1 correction" routes to Script/Full again
#       (the generic review rule was short-circuiting it). GUI model combos are now editable, so any
#       custom model ID can be typed directly. History note: backend items 22-25 above were delivered
#       across v0.6.4 - v0.6.7 in user-side builds; this file's lineage starts from the uploaded v0.6.6.
#   32. v0.7.6: GUI hotfix. Run button uses explicit readable busy colors instead of becoming
#       pale/invisible when disabled; Final Answer opens in a separate window with Copy/Open/Close.
#       Adds cost_summary_by_model.json, Cost by Model in final_answer.md, and clearer total
#       estimated cost in the GUI Metrics tab.
#   33. v0.7.7: Cost visibility hardening (closes the silent-null cost gap). When a used model has
#       no usable price in CostPer1MTokens, a visible [WARN] is now written to final_answer.md
#       (Cost Warnings section), cost_warnings.json, the GUI Metrics tab, and the Run Log instead of
#       the cost silently dropping from totals. Get-EstimatedCostUsd and the cost math are unchanged.
#       Restored the one-click Copy button next to the Final Answer window button.
#   34. v0.7.8: Output/UX. Self-checking judge+answer rules (behavioral claims must be proven by a
#       runnable self-check, plus AD null-logon / WhenCreated-guard / create-export-folder / return-not-Exit).
#       Multi-prompt final answer is numbered (Prompt N of M) and separated with --- rules. Per-task
#       tokens and cost now appear in task_results_summary, the Tasks grid, and the markdown summary.
#       StatusBar shows tokens and estimated cost after a run. Final report adds a Routing Notes section
#       explaining each WorkMode decision. Routing logic and cost math are unchanged.
#   35. v0.7.9: Renamed the user-facing "Final Answer" label to "Full Answer" (tab, button,
#       window title, and the Full Answer section header) to better convey that it holds the
#       combined answer for all prompts. The final_answer.md filename, the FINAL_ANSWER_MARKDOWN
#       marker, and all code identifiers are unchanged.
#   36. v0.8.0: Full Judge safety. Full comparison mode now ALWAYS uses the strong judge
#       ($AnthropicModel_JudgeStrong, default claude-opus-4-8), regardless of the GUI judge
#       selection or the cheap-judge toggle; if a weaker judge is selected, Full ignores it and
#       logs a [WARN]. Light/ReviewOnly may still use the cheap judge when the toggle is on.
#       Added a separate Strong Judge variable (config-overridable, not weakenable per-run from
#       the GUI) and a per-task JudgeModelUsed value surfaced in the Task Summary table and
#       Routing Notes. Routing logic and cost math are unchanged.
#   37. v0.8.1: Model clarity + task preview. The Run Log and header now show exactly which model
#       runs in each role (Answer A/B, Judge Full forced to strong, Judge Light/ReviewOnly), with a
#       [WARN] when the selected judge differs from the strong judge. Added a Detect Tasks button
#       that splits the current prompt with the same splitter the run uses and previews the tasks
#       (number + type) in the Tasks tab before running. No routing or cost-math changes.
#   38. v0.8.2: Durable AD-inventory prompt rules. The answer and judge system prompts now also
#       tell generated scripts to create export and output folders with
#       New-Item -ItemType Directory -Force (so missing parent folders are made too), to include
#       DistinguishedName in Active Directory inventory and report objects (duplicate common names
#       are common), and to omit a constant Enabled column when the query already filters to a
#       single Enabled state. Prompt-rule text only; routing, work mode, judge policy, and cost
#       math are unchanged.
#   39. v0.8.3: Portability fix. Config and secrets paths are now resolved relative to this
#       script folder, with a fallback to the legacy fixed location, so the tool reads the
#       MultiLLM.config.json and MultiLLM.secrets.xml that sit next to the .ps1 instead of a
#       hardcoded absolute path. Existing setups at the old path keep working; if neither
#       file exists yet, a new one is created next to the script. No routing, cost, judge,
#       or GUI changes.
#   40. v0.8.4: GUI model clarity. The header now shows the models actually in use as a
#       labeled, high-contrast panel - Answer A, Answer B, Judge (Full, forced to the strong
#       judge, shown in amber), and Cheap (Light/ReviewOnly) - instead of one small line.
#       The selected-vs-strong [WARN] on Run is unchanged; no routing, judge-policy, or cost
#       changes.
#   41. v0.8.5: GUI API key entry. The Config button is now a small settings menu
#       (Open config file / Set API keys). Set API keys opens a dialog with masked
#       PasswordBox fields that writes the same DPAPI-encrypted secrets file (OpenAIKey
#       and AnthropicKey SecureStrings) and reloads the keys, so keys can be set from the
#       GUI instead of a headless run. Keys are never logged. No routing, judge, or cost
#       changes.
#   42. v0.8.6: Judge verdict in the final answer. The judge JSON now includes
#       final_answer_source (the judge estimate of how much of each candidate answer went
#       into the synthesized final, summing to 100). The merged final answer now starts
#       with a "Judge verdict" block: better answer + confidence, an A/B composition bar,
#       average A/B scores, and reused parts. Parser is defensive (missing fields degrade
#       gracefully). Judge markers and routing/cost are unchanged.
#   43. v0.8.7: Operator labels + state-based Run. Removed "Cheap" from the UI (Quality
#       judge / Review judge / "Use review judge for light checks"); internal names, config
#       keys, and the env contract are unchanged. The primary button now reflects API-key
#       state: "Set API keys to run" (opens the keys dialog) when keys are missing, "Run"
#       when ready; Stop stays disabled until a run starts. No routing, judge, or cost changes.
#   44. v0.8.8: Header credentials affordance. The header now shows an API-keys status
#       ("API keys: OK/missing", colored) plus a "Set API Keys" button that opens the keys
#       dialog - matching the operator-layout mock. Status + Run button refresh together on
#       startup, after saving keys (dialog or Config menu), and on a run attempt. No routing,
#       judge, or cost changes.
#   45. v0.8.9: Choose/edit tasks before running (Phase 2 foundation). New "Edit Tasks"
#       tab: Detect Tasks fills it (one task per line); edit/add/delete/reorder freely, and
#       with "Use this task list" on, Run sends exactly those tasks. The GUI writes
#       tasks_input.json and passes MULTILLM_TASKS_FILE; the headless child loads that
#       explicit list instead of re-splitting (falls back to the splitter when absent or
#       empty). New env var added to the GUI-to-child contract. Routing/cost/judge unchanged.
#   46. v0.8.10: Task Review and pre-run estimates. The Tasks tab is now a selectable
#       review grid: Detect Tasks selects all tasks by default, shows type/title/excerpt,
#       route, rough cost/time estimates, and a details pane. Run writes only selected
#       tasks to tasks_input.json, so unchecked tasks are skipped before any model calls.
#       Added Select-MainTab helper to replace hardcoded MainTabs.SelectedIndex jumps.
#   47. v0.8.11: Task Review preview-row polish. Double-clicking a pre-run task row no
#       longer logs "Task folder not found"; it now keeps focus on the details pane until
#       a completed run provides a TaskFolder. Detect Tasks also updates the status bar
#       task count to show the previewed task total.
#   48. v0.8.12: Judge-label clarity. The visible GUI now says "Full judge (real)" for
#       the strong judge used in Full comparisons and "Review judge (light)" for the
#       optional lighter judge used only in Light/ReviewOnly checks.
#   49. v0.8.13: Task Review checkbox commit fix. The Run checkbox column now uses a
#       live CheckBox template instead of DataGridCheckBoxColumn, and selection counting
#       commits pending grid edits before building tasks_input.json.
#   50. v0.8.14: Task Details de-dup polish. The details pane no longer repeats the
#       same one-line task in both the title area and the full prompt box; duplicate
#       prompt text is replaced with a compact "same as title" note.
#   51. v0.8.15: Pre-run cost summary polish. Task Review now shows selected/all
#       estimated cost, time, and tokens; the grid includes Est. Tokens; the status bar
#       has an estimate field; Detect/Run logs include the selected pre-run estimate.
#   52. v0.8.16: Task Review selection sync hardening. Before counting or running
#       selected tasks, the GUI now synchronizes IsSelected from the actual visible
#       checkbox controls in the DataGrid and logs selected task IDs written to
#       tasks_input.json.
#   53. v0.8.17: Task Review bulk selection labels. The header buttons now say
#       "Enable All" and "Disable All" instead of "Select All" / "Clear", and they
#       write explicit log/status feedback after bulk changes.
#   54. v0.8.18: Layout clipping fixes. Task Review Enable/Disable controls moved to
#       the left side of the header, and the bottom action bar now wraps/tightens buttons
#       so Config/Stop/Exit are not clipped at narrower window widths.
#   55. v0.8.19: Sidebar navigation. Added the dark navy left rail from the redesign:
#       New Run, icon nav items, recent run rows, and a pinned user card using flat
#       fills, hairlines, Segoe UI, and Unicode glyphs from the design-system handoff.
#   56. v0.8.20: Redesign rail alignment. Added the right-side run/cost/status inspector
#       shown in the redesign mockup and widened the default window so the two-rail WPF
#       layout has room for the prompt, task review, and model controls.
#   57. v0.8.21: Two-rail fit polish. Tightened the header, prompt editor, side rails,
#       action bar, and log height so the redesign remains usable around 1280px wide
#       without the task grid and right inspector feeling clipped.
#   58. v0.8.22: Single-task grid fix. Task Review rows are now normalized into an
#       ArrayList before binding to the WPF DataGrid, preventing SingleAD/one-task
#       prompts from unrolling to a scalar PSCustomObject and breaking ItemsSource.
#   59. v0.8.23: Task checkbox interaction fix. Disable All no longer gets overwritten
#       by stale visible checkboxes during summary refresh, and the Run checkbox column
#       now toggles selected tasks with one click on the checkbox/cell.
#   60. v0.8.24: Collapsible/expandable GUI log. The bottom session log now has a
#       compact header with Collapse and Expand controls; Expand grows the log in
#       useful steps so longer transcripts can be inspected without leaving the window.
#   61. v0.8.25: Optional clarification gate. Added "Ask questions if prompt is vague"
#       to the GUI. When enabled, Run performs a local ambiguity check before creating
#       the run folder and can prompt the user to add clarifying answers, run anyway,
#       or cancel.
#   62. v0.8.26: AI clarification mode. The clarification gate now has a Local/AI mode
#       selector. Local remains free and heuristic; AI uses the configured Anthropic
#       review judge model to decide whether clarification is needed and to generate
#       better questions before the real run starts.
#   63. v0.8.27: Task grid master checkbox. The Run column header now contains a
#       general checkbox that enables or disables all task row checkboxes directly
#       from the grid header, with checked/unchecked/partial state feedback.
#   64. v0.8.28: Task Review truth-state polish. Completed runs now replace estimate
#       placeholders with actual task cost/tokens/time, the Selected Task Details pane
#       uses a clean dot-separated summary and hides duplicate prompt text, and the
#       right rail merges pre-run estimate details into the main Cost panel.
#   65. v0.8.29: Configurable cost budget. The right-rail Cost card budget is no longer
#       hardcoded at 10 USD - it reads Output.CostBudgetUsd from config (default 10). Set it
#       to 0 to hide the budget bar/percent ("off"). When actual cost exceeds the budget the
#       bar and percent turn red and the percent reads "over budget". GUI-only
#       (Set-RightRailCost); no routing, judge, or cost-math changes.
#   66. v0.8.30: Header emphasis + predicted-vs-actual cost. Header model values and the
#       API-keys status are now bold (slightly larger) for at-a-glance reading. The right-rail
#       Cost card keeps the pre-run PREDICTION and, after the run, shows it next to the ACTUAL
#       cost with the percentage delta and direction (lower/higher than predicted, green/red),
#       plus a "Cost compare" log line. GUI-only; frozen functions and cost math unchanged.
#   67. v0.8.31: Top menu bar. Added a Settings menu (Open config file, Set API keys, Open
#       output folder) and a Help menu (About, Open session log, Open developer notes) docked
#       at the top of the window. Menu items are built in code and wired to existing handlers
#       to avoid the MenuItem namescope issue. GUI-only; frozen functions unchanged.
#   68. v0.8.32: Button visibility fix. Added a flat Button style/template to the main window:
#       every button now has a visible 1px border and a readable disabled state (gray fill +
#       gray text), so plain and disabled buttons (Copy, Improved Prompt, Run-when-no-tasks,
#       Config) are no longer white-on-white or frameless. Colored buttons keep their color.
#       GUI-only; frozen functions unchanged.
#   69. v0.8.33: Right rail readability. Bumped inspector-rail label/value font sizes from 10
#       to 12 (33 places) and widened the rail 228->242 to fit, so Run Details / Cost / Token
#       Usage / Latency / Run Health read more clearly. GUI-only; frozen functions unchanged.
#   70. v0.8.34: Cost to 2 decimals + shekels. Per-task and total cost displays are now
#       rounded to 2 decimals and show an approximate shekel amount next to USD (rate 3.7,
#       deliberately approximate). New Format-CostUsdIls helper; Format-RailCost rounds to 2dp.
#       GUI display only - the audit-trail/report values and Get-EstimatedCostUsd are unchanged.
#   71. v0.8.35: Preset/mode prominence. The Preset, Work mode, and UI auto mode controls now
#       have bold accent-colored labels and a colored border with a light tint, so the run-shaping
#       choices stand out from the rest of the input row. GUI-only; frozen functions unchanged.
#   72. v0.8.36: Tooltips. Added hover tooltips to the action buttons (Run, Stop, Exit,
#       Improved Prompt, Run Folder, Config) and the Preset / Task splitter combos, so every
#       interactive control in the input and action rows now explains itself. GUI-only.
#   73. v0.8.37: Task grid selection fix. Clicking a row in the Tasks grid (most visibly after a
#       run completes) used to highlight for a moment and then lose both the highlight and the
#       details pane, because Refresh-TaskReviewGrid called Items.Refresh() - which clears the
#       DataGrid selection - on every click via Update-TaskReviewSelectionSummary and
#       CurrentCellChanged. Refresh-TaskReviewGrid now captures SelectedItem, refreshes, then
#       restores it, guarded by a reentrancy flag so restoring the selection cannot recurse.
#       GUI-only; frozen functions unchanged.
#   74. v0.8.38: Cost card shows shekels. The right-rail Cost card now shows an approximate
#       shekel amount under the big USD value (new TxtRailCostIls line, rate $Script:UsdToIls
#       = 3.7), so the headline cost reads in ILS too - matching the per-task / summary cost
#       displays. GUI display only; cost math and Get-EstimatedCostUsd unchanged.
#   75. v0.8.39: Per-task routing overrides (backend). tasks_input.json now carries optional
#       TypeOverride and WorkModeOverride per task; the GUI writes them and the headless child
#       reads them. At the per-task router site a gate uses a valid TypeOverride instead of
#       Get-TaskType, and Get-RouterDecision applies a valid WorkModeOverride (Review/Script)
#       around the call to Get-TaskWorkMode. Both frozen function BODIES are untouched - the
#       overrides are gates around the calls; invalid values are ignored with a [WARN] and the
#       effective route is logged so an override cannot silently change cost. No GUI control to
#       set them yet (that arrives in the next version); empty override = use the router as before.
#   76. v0.8.40: Per-task routing overrides (GUI). The Selected Task Details panel now has two
#       dropdowns, Type and Work mode, each defaulting to Auto (use the router). Choosing a value
#       sets that task's TypeOverride / WorkModeOverride, re-runs the pre-run estimate for the row
#       so the grid Type / Cost / Tokens and the selected/all totals reflect the override, and the
#       value is written into tasks_input.json for the run. The dropdowns are enabled only for
#       pre-run (detected) tasks and disabled on completed rows. Get-GuiTaskEstimate gained
#       optional TypeOverride / WorkModeOverride gates mirroring the backend; frozen functions
#       (Get-TaskType / Get-TaskWorkMode / Get-EstimatedCostUsd) remain byte-frozen.
#   77. v0.8.41: Expert personas (static, backend). New built-in config-overridable persona table
#       (architect / ui_ux / devils_advocate / qa / senior_dev / none), each a plain-ASCII prose
#       preamble ending with a rule-lock tail so a persona never overrides the formatting /
#       PowerShell 5.1 / AD-safety / ASCII / self-check rules. PersonaMode Off (default, byte-
#       identical to before) or Fixed; in Fixed, Answer A and Answer B get PersonaA / PersonaB
#       PREPENDED to a per-model COPY of the effective prompt (the Judge and effective_prompt.txt
#       stay persona-free; the shared EffectivePromptText is never mutated). New Get-PersonaPreamble
#       helper; env vars MULTILLM_PERSONA_MODE / _A / _B and config Personas + Behavior.Persona* with
#       the usual env over config over default precedence; invalid keys log a [WARN] and apply no
#       persona. No GUI control yet and no supervisor mode yet (both planned next). Frozen functions
#       and the judge region unchanged.
#   78. v0.8.42: Shekels in the Tasks grid + wider inspector rail. The grid Cost column now shows the
#       approximate shekel amount next to USD for completed tasks too (Update-TasksGridFromSummary uses
#       Format-CostUsdIls, matching the pre-run estimate), the Cost column header reads "Cost (USD/ILS)"
#       and is widened to fit, and the right inspector rail is widened 242 -> 280 for more room. GUI
#       display only; cost math, Get-EstimatedCostUsd, frozen functions, and the judge unchanged.
#   79. v0.8.43: Run-done signal + judge clarity. When a run finishes the status bar changes color
#       (green Completed / red Failed) and a system sound plays, so the result is obvious when the
#       window is in the background; the color resets when the next run starts. The Selected Task
#       Details panel now shows the exact judge per task ("Judge: <model> (<mode>)"), pre-run rows
#       carry JudgeModel, and the startup log states the policy plainly (Full comparisons always use
#       the strong judge, reviews use the cheap one). GUI display only; frozen functions and the
#       judge selection logic unchanged.
#   80. v0.8.44: App version more visible. The header now shows the version as a prominent blue
#       badge (HdrVersion pill) next to the MULTI-LLM PROMPTER title instead of a small muted note
#       in the tagline; the OS title bar still shows it too. GUI display only; frozen functions and
#       the judge unchanged.
#   81. v0.8.45: Live judge/cost re-estimate on model and judge changes. Toggling "Use fast judge" or
#       changing the Fast / Quality / Model A / Model B dropdowns now re-runs the pre-run estimate for
#       the detected tasks (new Update-AllTaskReviewRowEstimates over Ready/Skipped rows only), so the
#       grid Cost and the per-task "Judge: <model> (<mode>)" in the detail panel update without
#       re-clicking Detect Tasks. Update-TaskReviewRowEstimate now also refreshes JudgeModel. Note:
#       Full comparison tasks keep the strong Opus judge by policy, so only Review/Light tasks change.
#       GUI display only; frozen functions and the judge selection logic unchanged.
#   82. v0.8.46: Auto-detect on run + clearer task details. (1) Clicking Run with no detected tasks now
#       auto-runs Detect first (new Invoke-DetectTasks helper, shared by the Detect button and Run), so
#       the task list + cost estimate appear and the run uses that explicit list - no separate click.
#       (2) The Selected Task Details pane is now a labeled grid (Type / Status / Cost / Tokens / Time /
#       Judge) instead of one cramped dash-joined line, with the Judge on its own row (bold) so the
#       judge that will run is unmissable, and creative/no-judge tasks read "Not used". GUI display and
#       flow only; frozen functions, the judge selection logic, and the run pipeline are unchanged.
#   83. v0.8.47: Label clarity + tooltips + typed-model refresh. Renamed "Quality model" / "Fast model"
#       to "Quality judge" / "Fast judge" (labels and run log); the Selected Task Details and the Run-as
#       override now read "Task Type" / "Work Mode" with tooltips explaining each option; the detail pane
#       now states whether the cost/tokens/time are estimates (before the run) or actual values; and the
#       editable model/judge combos also re-estimate on LostFocus so a hand-typed custom model id updates
#       the cost/judge without a re-Detect. GUI display only; frozen functions and the judge logic unchanged.
#   84. v0.8.48: Per-task progress colors in the Tasks grid. During a run the grid now marks tasks live
#       as they finish (tasks run sequentially): completed rows turn green (Status Done), the one in
#       progress turns amber (Running), the rest stay pending - driven from the poll timer when the
#       done-count changes. New RowStyle DataTriggers color Done green and Running amber (Failed red and
#       Completeness WARN amber already existed). The post-run summary rebuild then shows the final
#       per-task outcome. GUI display only; frozen functions, judge logic, and the run pipeline unchanged.
#   85. v0.8.49: Scrollable task details. The Selected Task Details pane is now wrapped in a ScrollViewer
#       (vertical, auto) so when the window is small its content - title, Task Type / Status / Cost /
#       Tokens / Time / Judge, the Run-as override combos, and the prompt - stays fully reachable by
#       scrolling instead of being clipped. The outer container changed from a DockPanel to a StackPanel
#       so it sizes to content. GUI layout only; frozen functions and the judge logic unchanged.
#   86. v0.8.50: Sidebar nav now does something visible. The left-nav buttons (Runs / Prompts / Presets /
#       Models / Settings) were wired but only highlighted + focused an already-visible control, so they
#       felt dead. Each click now performs a clearly visible action: Runs switches to the Tasks tab,
#       Prompts focuses the prompt box (caret at end), Presets and Models open their dropdowns, Settings
#       opens the config menu - each also writes an INFO line to the run log. The Settings handler now
#       guards a null config menu. GUI behavior only; frozen functions and the judge logic unchanged.
#   87. v0.8.51: Log Collapse/Expand merged into one toggle button. The two log-panel buttons (Collapse,
#       Expand) are now a single BtnToggleLog whose label flips: it reads "Collapse" while the log is
#       shown and "Expand" while hidden; clicking collapses to 0 (saving the height) or restores the last
#       height. Set-GuiLogPanelHeight updates the toggle label instead of enabling/disabling a button. The
#       old per-click +80 grow is dropped in favor of a clean show/hide toggle. GUI behavior only; frozen
#       functions and the judge logic unchanged.
#   88. v0.8.52: Generated-code correctness fix (prompt rules). A run review found the generated AD scripts
#       teaching an INVERTED fact: "$null -lt [DateTime] returns $false so never-logged-in accounts are
#       dropped". In PS 5.1 $null sorts as LESS THAN any value, so $null -lt/-le are $true and a -lt filter
#       INCLUDES nulls; the shipped self-check even printed "UNEXPECTED: investigate your environment" on
#       every run. Two root causes fixed in all four answer/judge system prompts: (a) these are double-quoted
#       here-strings and the rule text was NOT backtick-escaped, so the model literally received "Enabled -eq
#       False" and "( -eq .LastLogonDate)" (the $false/$null/$_ interpolated away) - now backtick-escaped;
#       (b) the null-comparison rule now states the REAL PS 5.1 semantics and forbids claiming -lt drops
#       nulls, and the self-check rule now requires the check to PASS on a clean host (no false "unexpected"
#       alarms). Prompt text only; frozen functions, the judge marker contract, and pipeline code unchanged.
#   89. v0.8.53: Stop now terminates the whole backend process tree. Previously Stop (and the window
#       Closing handler) called $Script:ChildProcess.Kill(), which killed ONLY the hidden child; the
#       per-answer and judge Start-Job grandchildren (each its own powershell.exe) survived and could
#       keep their in-flight API calls running until the per-model timeout - i.e. real money spent
#       AFTER a Stop. New Stop-ChildProcessTree uses taskkill /PID <id> /T /F to kill the child and all
#       descendants (PS 5.1 has no .Kill($true) tree overload), with a recursive Win32_Process fallback
#       if taskkill cannot run. Wired into the Stop button and the window Closing handler; the old
#       "answer jobs may keep their API calls running" warning is replaced with a clear message that the
#       backend and its model jobs were stopped. GUI/teardown only; frozen functions, judge policy,
#       routing, and cost math unchanged.
#   90. v0.8.54: RunFinalVerifier implemented (opt-in; OFF by default). Distinct from the judge:
#       the judge produces/selects the final answer, the verifier independently re-reads each task's
#       original prompt + final_answer.md and reports correctness / completeness / unsupported claims
#       (with the same PS 5.1 + AD pitfalls the prompts enforce). Runs as a gated POST-PASS after the
#       per-task loop only when $RunFinalVerifier is true (config Behavior.RunFinalVerifier), so default
#       behavior is byte-identical. New Invoke-AnthropicVerifier (HTTP/retry skeleton cloned from
#       Invoke-AnthropicJudge, ---VERIFIER_JSON--- marker) + Get-VerifierVerdict parser; writes
#       Task_NN\final_verification.json + final_verification_summary.json. Verifier model defaults to
#       the strong judge ($AnthropicModel_JudgeStrong); $VerifierModel/$VerifierMaxTokens override it.
#       Frozen functions, judge marker contract, routing, and cost math unchanged. NOTE: the verifier
#       LLM call path is not yet live-tested (no keys in the build env); the parser and the off-by-
#       default gating are validated.
#   91. v0.8.55: GUI toggle for the final verifier + per-run env control. New "Run final verifier"
#       checkbox (ChkRunVerifier) in the model row; on Run it passes MULTILLM_RUNVERIFIER=1/0 to the
#       headless child, which sets $RunFinalVerifier for that run (config/default still apply when the
#       env var is absent, so CLI behavior is unchanged). Off by default. Completes the env contract
#       for the v0.8.54 verifier so it can be enabled per-run from the GUI (and by the benchmark
#       runner). GUI + one env read only; frozen functions, judge contract, routing, and cost math
#       unchanged. The verifier's own LLM call still needs a keyed run to confirm end-to-end.
#   92. v0.8.56: Report/banner version strings now use $ToolVersion instead of a hardcoded
#       "v0.8.52". A live v0.8.55 run exposed final_answer.md (and per-task report headers + the CLI
#       banner) still printing a hardcoded old version string regardless of the running version. The 7
#       output headers now interpolate $ToolVersion, so reports always match the actual version.
#       Output text only; frozen functions, judge marker contract, routing, and cost math unchanged.
#   93. v0.8.57: First-run clarity polish, part 1 (wording + cost labels). The Run button now reads
#       "Run N selected" (was "Run N Tasks" / "Run N Selected"); unchecked pre-run tasks show the
#       status "Not selected" instead of "Skipped" (clearer, non-failure word - the task-review row
#       state value was renamed via .Status only; the unrelated JudgeMode="Skipped" and the row-color
#       DataTriggers are untouched); and the right-rail Cost card shows an "Estimated cost" label
#       before/with the pre-run estimate and "Actual cost" after the run. GUI text/labels only; frozen
#       functions, judge contract, routing, and cost math unchanged. Step rail / quick-start card /
#       Advanced expander / tab empty-states follow in later versions (need a live GUI pass).
#   94. v0.8.58: First-run clarity polish, part 2 (orientation). Added a "How it works" strip under
#       the header (Prompt -> two models answer -> Opus judge writes one final answer) and put the
#       pre-run cost on the Run button: "Run (N task)" / "Run (N tasks) - est. $X.XX" (singular/plural;
#       ASCII hyphen, not a middle-dot, to keep the source ASCII-only). GUI text + one layout band
#       only; frozen functions, judge marker contract, routing, and cost math unchanged. Advanced
#       expander, quick-start card, and tab empty-states still to follow (need a live GUI pass).
#
#   95. v0.8.59: Run button auto-sizes to its label. The dynamic label "Run (N tasks) - est. $X.XX"
#       was clipped by the fixed Width="124" (showed "est. $0.0"). Changed Width to MinWidth=124 so
#       the button keeps its minimum size but grows to fit the cost text. XAML attribute only; no
#       logic, frozen functions, judge marker contract, routing, or cost math changed.
#
#   96. v0.8.60: First-run clarity polish, part 3 (input restructure). The crowded two-row band of
#       expert controls under the prompt is now collapsed into an "Advanced settings" Expander
#       (AdvancedExpander), collapsed by default. First-run users see Prompt + Preset + Run only;
#       the expander holds Task splitter, Work mode, UI auto mode, Open-in-Notepad / Open-folder,
#       Ask-clarifying + Mode, Model A/B, Quality/Fast judge, and Run-final-verifier. Every control
#       keeps its Name/tooltip/behavior - they were only wrapped in an Expander + StackPanel (WPF
#       Expander does not virtualize, so FindName + startup population still resolve when collapsed).
#       Selected models remain visible in the header model panel, so collapsing hides no state.
#       Preset stays on the always-visible essentials line (widened to 220). Pure XAML layout move;
#       no logic, frozen functions, judge contract, routing, or cost math changed.
#
#   97. v0.8.61: Left panel reworked from a confusing jump-nav into a real ACTION RAIL. The cramped
#       bottom action bar (ZONE 4) was removed and its buttons moved into the left rail, keeping their
#       exact Names so every handler + state routine (Update-RunButtonState, Set-GuiBusy enabling Stop /
#       disabling Run, post-run enabling of Full Answer/Copy/Improved) works unchanged. Rail layout:
#       pinned top = Run / Stop / Detect Tasks; scroll = New Run, Results (Full Answer, Copy, Improved
#       Prompt, Run Folder), Recent runs; pinned footer = Settings / Exit / app version. Removed the
#       redundant jump-nav buttons (Runs/Prompts/Presets/Models), the dead Set-SidebarActiveItem, the
#       fake "Vlad / Pro Plan" account card, and the duplicate Config button (folded into the rail
#       Settings entry, which now owns the ContextMenu). Recent-run entries are now clickable Buttons
#       (BtnSideRecent1..4) that load a past run via the new Open-PastRun (reuses the same folder-
#       parameterized loaders Complete-GuiRun uses: Update-TasksGridFromSummary / Update-MetricsTabFromRun
#       / Update-RightRailFromRun + final_answer.md + transcript; guarded against loading mid-run).
#       GUI/layout + one new read-only loader; frozen functions, judge contract, routing, cost math
#       unchanged.
#
#   98. v0.8.62: Clarify Prompt dialog reworked from two stacked boxes (one read-only list of ALL
#       questions on top, one shared answer box below) into a scrolling list of per-question sections -
#       each section shows the question AND its own answer box together, so the operator reads and
#       answers each item in place. Section UI is built in CODE (Border > StackPanel > question TextBlock
#       + answer TextBox per question) with the question text set via the .Text property, never embedded
#       in XAML, so '<' '>' '&' in a question cannot break the parse. On "Add Answers and Run" the
#       per-question answers are recombined into "Qn:/An:" pairs (blank answers skipped) and returned as
#       the SAME single Clarification string the caller already appends under "Clarifications:" - so the
#       GUI->prompt contract is unchanged; only the dialog layout and the (now richer, Q-paired) text
#       differ. Pure GUI change; frozen functions, judge contract, routing, cost math untouched.
#
#   99. v0.8.63: Cost by Role, Cost by Model, and the per-task Task Summary are now shown directly in
#       the GUI's "Cost & Metrics" tab (renamed from "Metrics"), not only inside the Full Answer window.
#       The Metrics tab previously dumped Cost by Model / Cost by Role as a hard-to-read vertical
#       key:value list and had NO task summary at all. New Format-AlignedTable helper renders each as a
#       monospace, column-aligned table (Consolas + NoWrap + horizontal scroll in MetricsBox), and a new
#       TASK SUMMARY table (Id/Type/Work/OK/Ans/Judge/Judge Model/Compl/Tokens/Cost/Title, Title capped
#       at 48 chars) reads task_results_summary.json independently of the cost files so it shows even if
#       a cost summary is missing. Read-only rendering only: it consumes the SAME run-folder JSON the
#       child already writes (cost_summary_by_role.json / cost_summary_by_model.json /
#       task_results_summary.json); no new files, no pipeline/child/judge/routing/cost-math change.
#
#  100. v0.8.64: Cost recommendations in the "Cost & Metrics" tab. A new offline Get-CostRecommendations
#       runs pure heuristics (NO API call, no model) over this run's metric JSON plus the totals of up to
#       10 recent prior runs, and prints an actionable "COST RECOMMENDATIONS" block at the top of the tab:
#       this run vs the recent average (+/-25% flagged); judge share of cost when a Full/strong judge ran
#       (>=60% -> suggest the review judge); any light-typed task (simple/technical/documentation/creative)
#       that used the Full/strong judge (suggest Review work mode / review judge); a single task that is
#       >=50% of the run (suggest dropping it); and models with no configured price (costs understated).
#       Returns nothing for an empty/in-progress run folder so the section is hidden until there is data.
#       Read-only over files the child already wrote (timing_summary / cost_summary_by_role /
#       task_results_summary / cost_warnings + prior runs' timing_summary); no new output files, no
#       pipeline/child/judge/routing/cost-math change. A live-model recommender could be added later as an
#       off-by-default toggle, but the offline heuristics need no keys and are validated here.
#
#  101. v0.8.65: Left action rail polish. (a) Buttons reordered to the workflow order Detect Tasks ->
#       Run -> Stop (Detect is now first; Run stays the visually primary green). (b) "Run Folder" button
#       relabeled "Open Folder". (c) Every button now has a clear hover state and a hand cursor so it
#       reads as clickable: a new implicit Button template + a keyed "RailButton" style add an overlay
#       that lightens on hover and darkens on press (works on any base colour - green Run, red Stop,
#       dark nav chips). Previously the rail buttons shared the rail's own colour with a 0px border, so
#       they looked like plain text and the old hover only recoloured an invisible border. (d) Rail
#       buttons are now chips (distinct fill + rounded corners) grouped inside bordered frames
#       (Primary actions / Results / Recent runs). Pure XAML + Window.Resources styling; all button
#       Names/handlers unchanged (BtnRun/BtnStop/BtnDetect/BtnOpenFolder/BtnSideRecent1-4 etc.), so
#       Update-RunButtonState / Set-GuiBusy / Open-PastRun keep working. No logic/judge/routing/cost change.
#
#  102. v0.8.66: Cost by Role, Cost by Model, and the Task Summary now render as real DataGrids (normal
#       GUI view) in the "Cost & Metrics" tab instead of monospace text. The tab is now a scrolling panel:
#       a recommendations card (MetricsRecBox) on top, then the three sortable/aligned DataGrids
#       (CostRoleGrid / CostModelGrid / MetricsTaskGrid), then a small timing+warnings text box
#       (MetricsBox) at the bottom. Update-MetricsTabFromRun now sets each grid's ItemsSource from the
#       run-folder JSON (cost_summary_by_role/by_model, task_results_summary) and only the timing/warnings
#       stay as text; new Clear-MetricsTab resets all of them and is called from the two run-reset paths.
#       Shared GridHeader/GridNum styles added to Window.Resources. Read-only over the same files the
#       child already writes; no new output files, no pipeline/child/judge/routing/cost-math change.
#       (Format-AlignedTable is now unused but kept.)
#
#  103. v0.8.67: HTML report (instead of an embedded web view). A new "HTML Report" button in the rail
#       Results group builds a self-contained, modern-looking cost report (New-RunHtmlReport) for the
#       current/loaded run and opens it in the default browser. The report has inline CSS (no external
#       files, no JS, no API call) and contains the total cost, the offline cost recommendations,
#       Cost by role / Cost by model / Task summary tables, the timing summary, and any warnings - all
#       read from the run-folder JSON the child already wrote, written to cost_report.html in that folder.
#       All dynamic text is HTML-escaped (ConvertTo-HtmlText) so titles/model ids/warnings cannot break
#       the markup. Chosen over hosting WebView2 in-process, which would need the WebView2 runtime + three
#       shipped DLLs + a JS<->PowerShell bridge - against the single-file PS 5.1 design. Read-only;
#       no pipeline/child/judge/routing/cost-math change. Adds one Add_Click handler (40 total).
#
#  104. v0.8.68: Log auto-expands on ERROR. Add-GuiLog now detects an ERROR tag and, only when the
#       bottom log panel is currently collapsed, expands it (to the last expanded height, else 160px,
#       clamped 96..360 via Set-GuiLogPanelHeight) so a failure can never hide behind a collapsed log.
#       Fires only on ERROR and only when collapsed, so it never fights a user who deliberately
#       collapsed an already-visible log. GUI behavior only; frozen functions, judge contract, routing,
#       and cost math unchanged. (Also this session: verified the v0.8.54/55 RunFinalVerifier offline -
#       wiring + parser unit-tested - see notes; the live LLM call still needs a keyed run to confirm.)
#
#  105. v0.8.69: Verifier cost is now counted in the run totals. A keyed run confirmed the v0.8.54/55
#       final verifier works end-to-end, but exposed that its API call was missing from the headline
#       cost: timing_summary.EstimatedCostUsd / AiRequestCount / token totals and CostByRole/CostByModel
#       only summed Answer + Judge, so with the verifier ON the GUI cost card, the Cost & Metrics grids,
#       the HTML report total, and the cost recommendations all UNDERSTATED real spend by the verifier
#       amount. Fix: the verifier post-pass now appends its request to $AllRequestMetrics with a new
#       "Verifier" role (via New-RequestMetricObject), so every run-level total built after the post-pass
#       includes it; CostByRole adds a Verifier row only when the verifier actually ran (off-by-default
#       stays byte-identical - no $0 row). Per-task TaskSummary (built before the post-pass) keeps the
#       answer+judge production cost, so total = sum(per-task) + Verifier. Get-EstimatedCostUsd and the
#       cost math are unchanged; this only stops a real call from being dropped from the aggregates.
#
#   OPENAI_API_KEY
#   ANTHROPIC_API_KEY
#
# Optional:
#   Set $ProxyUrl if needed, for example:
#   http://fwproxyex.dgama:8080
# ============================================================

# -----------------------------
# USER PARAMETERS - EDIT HERE
# -----------------------------

# GUI mode: $true shows the WPF window. $false runs the pipeline directly (classic CLI mode).
$LaunchGui   = $true
$ToolVersion = "v0.8.69"

# Prompt preset selector
# Options: Custom / SingleAD / MultiTaskDemo
$PromptPreset = "MultiTaskDemo"

$CustomUserPrompt = @"
Create a short PowerShell script that lists disabled AD users modified in the last 30 days.
"@

$SingleADPrompt = @"
Create a short PowerShell script that lists disabled AD users modified in the last 30 days.
"@

$MultiTaskDemoPrompt = @"
Create a short PowerShell script that lists disabled AD users modified in the last 30 days.
Create a complete PowerShell 5.1 script for ISE that checks disabled Active Directory users modified in the last 30 days, exports to CSV, and avoids fragile AD -Filter date logic.
Review an AD audit finding: stale accounts check ignores users that never logged in. Explain the bug and propose a safe PowerShell 5.1 correction.
Summarize a technical email about OneDrive retention into a short management summary with Q/A.
Create a concise SUNO style prompt for a nostalgic instrumental piano piece with jazz harmony and more virtuosic improvisation.
Create a PowerShell 5.1 WPF GUI concept for reviewing CSV results with search, export, refresh, and details view.
"@

if ($PromptPreset -eq "SingleAD") {
    $UserPrompt = $SingleADPrompt
}
elseif ($PromptPreset -eq "MultiTaskDemo") {
    $UserPrompt = $MultiTaskDemoPrompt
}
else {
    $UserPrompt = $CustomUserPrompt
}

$OpenAIModel_Answer       = "gpt-4.1-mini"
$AnthropicModel_Answer    = "claude-sonnet-4-6"
$AnthropicModel_Judge     = "claude-opus-4-8"

# Strong Judge: ALWAYS used for Full comparison mode, regardless of the GUI judge selection
# or the cheap-judge toggle. This protects the empirically required quality bar for Full mode.
$AnthropicModel_JudgeStrong = "claude-opus-4-8"

# Cheap Judge: used for Light and ReviewOnly judge modes when enabled.
# Full comparison (two answers, Script work mode) always keeps the strong judge above.
$AnthropicModel_JudgeCheap = "claude-sonnet-4-6"
$UseCheapJudgeForReview    = $true

# Expert personas: a built-in, config-overridable table of perspective preambles. Each preamble is
# plain ASCII prose with NO literal $ (it is prepended to the USER prompt, never spliced into a
# system here-string) and ends with a rule-lock tail so a persona can never override the load-bearing
# formatting / PowerShell 5.1 / Active Directory safety / ASCII / self-check rules in the system prompt.
$Script:PersonaRuleLock = ' This lens never overrides the formatting, PowerShell 5.1, Active Directory safety, ASCII-only, or self-check rules in the system instructions; if this lens and those rules conflict, those rules win.'
$Script:PersonaTable = [ordered]@{
    none            = ''
    architect       = 'You are a senior software architect. Prioritize clear structure, separation of concerns, explicit failure modes, and long-term maintainability over raw speed. Surface coupling, hidden assumptions, and missing abstractions.' + $Script:PersonaRuleLock
    ui_ux           = 'You are a UI and UX expert. Prioritize clarity, discoverability, accessibility, and a low-friction operator experience. Call out confusing flows, unlabeled states, and anything that raises cognitive load.' + $Script:PersonaRuleLock
    devils_advocate = 'You are a constructive devil''s advocate. Stress-test the obvious solution: surface edge cases, failure modes, and incorrect assumptions, offer one credible alternative approach, then say which you would choose and why.' + $Script:PersonaRuleLock
    qa              = 'You are a meticulous QA engineer. Focus on correctness, edge cases, error handling, and how the solution can be verified. Identify untested paths and concrete checks that would prove it works.' + $Script:PersonaRuleLock
    senior_dev      = 'You are a pragmatic senior developer. Deliver a correct, idiomatic, maintainable solution that follows the stated rules exactly, and note any meaningful trade-offs you made.' + $Script:PersonaRuleLock
}
# Persona selection: Off = no personas (byte-identical to no-persona behavior); Fixed = Answer A and
# Answer B get the personas below. A cheap-LLM Supervisor that picks per task is planned for later.
$PersonaMode = "Off"
$PersonaA    = "architect"
$PersonaB    = "senior_dev"

$OpenAIBaseUrl            = "https://api.openai.com/v1/chat/completions"
$AnthropicBaseUrl         = "https://api.anthropic.com/v1/messages"
$AnthropicVersion         = "2023-06-01"

# Do not hardcode API keys here.
# API keys are loaded by Initialize-ApiKeys from an encrypted secrets file
# and optionally from environment variables as fallback.
$OpenAIApiKey             = ""
$AnthropicApiKey          = ""

$ProxyUrl                 = ""   # Example: "http://fwproxyex.dgama:8080"

$OutputRoot               = "C:\Temp\MultiLLMPrompter"
$RunName                  = "Run"
$MaxOutputTokens_Answer   = 2500
$MaxOutputTokens_Judge    = 5000

# v0.8.52 output budgets by task type
$MaxOutputTokensSimple        = 800
$MaxOutputTokensCreative      = 1000
$MaxOutputTokensDocumentation = 1400
$MaxOutputTokensTechnical     = 3000
$MaxOutputTokensCode          = 4500
$MaxOutputTokensUiCode        = 6500
$MaxJudgeTokensTechnical      = 4500
$MaxJudgeTokensCode           = 6000
$MaxJudgeTokensUiCode         = 8000
$EnableCompletenessCheck      = $true
$CompletenessWarningMinLength = 80

$PerModelTimeoutSec       = 30
$TotalRequestTimeoutSec   = 45
$JudgeTimeoutSec          = 90
$MaxRetries               = 1

# v0.8.52 per-task timeout defaults
$TimeoutSimpleSec         = 30
$TimeoutTechnicalSec      = 60
$TimeoutDocumentationSec  = 45
$TimeoutCreativeSec       = 45
$TimeoutCodeSec           = 75
$TimeoutUiCodeSec         = 90

$SkipMultiForSimple       = $true
$ShowFinalAnswerOnScreen  = $true
$OpenFinalMarkdown        = $true
$OpenOutputFolder         = $true
$ExportRunMetricsCsv     = $true

# Secret safety
$AllowHardcodedApiKeys         = $false
$UseEncryptedSecretsFile       = $true
$CreateSecretsFileIfMissing    = $true
$ForceRecreateSecretsFile      = $false
$UseEnvironmentVariablesFallback = $true
# v0.8.52: resolve the data folder relative to this script, with a fallback to the legacy
# fixed location so older setups keep working. Prefer a file that already exists next to
# the script, then the legacy path; otherwise default to next-to-script so a new file is
# created beside the .ps1 instead of in a hardcoded absolute folder.
$ScriptSelfFile = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($ScriptSelfFile)) { $ScriptSelfFile = $MyInvocation.MyCommand.Path }
if (-not [string]::IsNullOrWhiteSpace($ScriptSelfFile)) {
    $ScriptDataFolder = Split-Path -Path $ScriptSelfFile -Parent
}
else {
    $ScriptDataFolder = (Get-Location).Path
}
$LegacyDataFolder = "C:\_Combined\H_Productivity\Multi-LLM-Prompter"

$SecretsPathLocal  = Join-Path -Path $ScriptDataFolder -ChildPath "MultiLLM.secrets.xml"
$SecretsPathLegacy = Join-Path -Path $LegacyDataFolder -ChildPath "MultiLLM.secrets.xml"
if (Test-Path -LiteralPath $SecretsPathLocal) {
    $SecretsPath = $SecretsPathLocal
}
elseif (Test-Path -LiteralPath $SecretsPathLegacy) {
    $SecretsPath = $SecretsPathLegacy
}
else {
    $SecretsPath = $SecretsPathLocal
}

# Router thresholds / behavior
$SimplePromptMaxChars             = 300
$CodeTriggersOverrideDocumentation = $true


# v0.6 config / adapter / task splitter / prompt presets
$UseConfigFile                  = $true
$CreateConfigIfMissing          = $true
$ConfigPathLocal  = Join-Path -Path $ScriptDataFolder -ChildPath "MultiLLM.config.json"
$ConfigPathLegacy = Join-Path -Path $LegacyDataFolder -ChildPath "MultiLLM.config.json"
if (Test-Path -LiteralPath $ConfigPathLocal) {
    $ConfigPath = $ConfigPathLocal
}
elseif (Test-Path -LiteralPath $ConfigPathLegacy) {
    $ConfigPath = $ConfigPathLegacy
}
else {
    $ConfigPath = $ConfigPathLocal
}
$RunFinalVerifier               = $false
$VerifierModel                  = ""            # v0.8.54: empty -> use the strong judge model for the final verifier
$VerifierMaxTokens              = 1500          # v0.8.54: verifier returns a small JSON verdict only
$TaskSplitterMode               = "Heuristic"   # None / Heuristic / LLM (LLM falls back to Heuristic in v0.8.52)
$TaskWorkMode                   = "Auto"        # Auto / Review / Script
$UiCodeAutoWorkMode             = "Review"      # Review / Script. Used only when TaskWorkMode = Auto
$MaxTasksPerPrompt              = 10
$KeepTaskSubfolders             = $true
$WriteMergedFinalAnswer         = $true
$AnswerProvider_OpenAI          = "OpenAI"
$AnswerProvider_Anthropic       = "Anthropic"
$JudgeProvider                  = "Anthropic"

# v0.8.52 cost-control and hardening
$SkipMissingInputTasks          = $true
$CreativeTasksUseSingleModel    = $true
$CreativeTasksUseJudge          = $false
$DocumentationTasksUseSingleModel = $true
$DocumentationTasksUseJudge     = $false
$SimpleTasksUseJudge            = $false


# -----------------------------
# CONFIG FILE LOAD - v0.8.52
# -----------------------------

$Script:MultiLLMConfig = $null

if ($UseConfigFile -eq $true) {
    Try {
        $ConfigFolder = Split-Path -Path $ConfigPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($ConfigFolder)) {
            if (-not (Test-Path $ConfigFolder)) {
                New-Item -ItemType Directory -Path $ConfigFolder -Force | Out-Null
            }
        }

        if ((-not (Test-Path $ConfigPath)) -and $CreateConfigIfMissing -eq $true) {
            $DefaultConfig = [ordered]@{
                Version = "v0.8.52"
                Models = [ordered]@{
                    OpenAIAnswer        = $OpenAIModel_Answer
                    AnthropicAnswer     = $AnthropicModel_Answer
                    AnthropicJudge      = $AnthropicModel_Judge
                    AnthropicJudgeStrong = $AnthropicModel_JudgeStrong
                    AnthropicJudgeCheap = $AnthropicModel_JudgeCheap
                }
                Personas = [ordered]@{
                    architect       = $Script:PersonaTable['architect']
                    ui_ux           = $Script:PersonaTable['ui_ux']
                    devils_advocate = $Script:PersonaTable['devils_advocate']
                    qa              = $Script:PersonaTable['qa']
                    senior_dev      = $Script:PersonaTable['senior_dev']
                }
                Endpoints = [ordered]@{
                    OpenAIChatCompletions = $OpenAIBaseUrl
                    AnthropicMessages     = $AnthropicBaseUrl
                    AnthropicVersion      = $AnthropicVersion
                    ProxyUrl              = $ProxyUrl
                }
                Timeouts = [ordered]@{
                    PerModelTimeoutSec     = $PerModelTimeoutSec
                    TotalRequestTimeoutSec = $TotalRequestTimeoutSec
                    JudgeTimeoutSec        = $JudgeTimeoutSec
                    MaxRetries             = $MaxRetries
                    TimeoutsByTaskType     = [ordered]@{
                        simple        = $TimeoutSimpleSec
                        technical     = $TimeoutTechnicalSec
                        documentation = $TimeoutDocumentationSec
                        creative      = $TimeoutCreativeSec
                        code          = $TimeoutCodeSec
                        ui_code       = $TimeoutUiCodeSec
                    }
                }
                OutputBudgets = [ordered]@{
                    MaxOutputTokensByTaskType = [ordered]@{
                        simple        = $MaxOutputTokensSimple
                        creative      = $MaxOutputTokensCreative
                        documentation = $MaxOutputTokensDocumentation
                        technical     = $MaxOutputTokensTechnical
                        code          = $MaxOutputTokensCode
                        ui_code       = $MaxOutputTokensUiCode
                    }
                    MaxJudgeTokensByTaskType = [ordered]@{
                        technical = $MaxJudgeTokensTechnical
                        code      = $MaxJudgeTokensCode
                        ui_code   = $MaxJudgeTokensUiCode
                    }
                    EnableCompletenessCheck      = $EnableCompletenessCheck
                    CompletenessWarningMinLength = $CompletenessWarningMinLength
                }
                Output = [ordered]@{
                    OutputRoot              = $OutputRoot
                    RunName                 = $RunName
                    ShowFinalAnswerOnScreen = $ShowFinalAnswerOnScreen
                    OpenFinalMarkdown       = $OpenFinalMarkdown
                    OpenOutputFolder        = $OpenOutputFolder
                    ExportRunMetricsCsv     = $ExportRunMetricsCsv
                }
                Behavior = [ordered]@{
                    SkipMultiForSimple                = $SkipMultiForSimple
                    SimplePromptMaxChars              = $SimplePromptMaxChars
                    CodeTriggersOverrideDocumentation = $CodeTriggersOverrideDocumentation
                    RunFinalVerifier                  = $RunFinalVerifier
                    UseCheapJudgeForReview            = $UseCheapJudgeForReview
                    RunFinalVerifierStatus            = "Implemented as a post-pass in v0.8.54"
                    TaskSplitterMode                  = $TaskSplitterMode
                    TaskWorkMode                      = $TaskWorkMode
                    UiCodeAutoWorkMode                = $UiCodeAutoWorkMode
                    MaxTasksPerPrompt                 = $MaxTasksPerPrompt
                    PromptPreset                      = $PromptPreset
                    SkipMissingInputTasks             = $SkipMissingInputTasks
                    CreativeTasksUseSingleModel       = $CreativeTasksUseSingleModel
                    CreativeTasksUseJudge             = $CreativeTasksUseJudge
                    DocumentationTasksUseSingleModel  = $DocumentationTasksUseSingleModel
                    DocumentationTasksUseJudge        = $DocumentationTasksUseJudge
                    SimpleTasksUseJudge               = $SimpleTasksUseJudge
                    PersonaMode                       = $PersonaMode
                    PersonaA                          = $PersonaA
                    PersonaB                          = $PersonaB
                }
                CostPer1MTokens = [ordered]@{
                    "OpenAI|gpt-4.1-mini"            = [ordered]@{ InputUsd = 0.40; OutputUsd = 1.60 }
                    "Anthropic|claude-sonnet-4-6"    = [ordered]@{ InputUsd = 3.00; OutputUsd = 15.00 }
                    "Anthropic|claude-opus-4-8"      = [ordered]@{ InputUsd = 5.00; OutputUsd = 25.00 }
                    "Anthropic|claude-haiku-4-5"     = [ordered]@{ InputUsd = 1.00; OutputUsd = 5.00 }
                }
                Backends = [ordered]@{
                    DefaultAnswerProviders = @("OpenAI", "Anthropic")
                    JudgeProvider          = "Anthropic"
                    OpenRouterEnabled      = $false
                    LiteLLMEnabled         = $false
                }
            }

            $ConfigJson = $DefaultConfig | ConvertTo-Json -Depth 25
            $Utf8BomForConfig = New-Object System.Text.UTF8Encoding($true)
            [System.IO.File]::WriteAllText($ConfigPath, $ConfigJson, $Utf8BomForConfig)
        }

        if (Test-Path $ConfigPath) {
            $RawConfig = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop
            if (-not [string]::IsNullOrWhiteSpace($RawConfig)) {
                $Script:MultiLLMConfig = $RawConfig | ConvertFrom-Json -ErrorAction Stop

                if ($null -ne $Script:MultiLLMConfig.Models) {
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Models.OpenAIAnswer)) { $OpenAIModel_Answer = [string]$Script:MultiLLMConfig.Models.OpenAIAnswer }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Models.AnthropicAnswer)) { $AnthropicModel_Answer = [string]$Script:MultiLLMConfig.Models.AnthropicAnswer }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Models.AnthropicJudge)) { $AnthropicModel_Judge = [string]$Script:MultiLLMConfig.Models.AnthropicJudge }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Models.AnthropicJudgeStrong)) { $AnthropicModel_JudgeStrong = [string]$Script:MultiLLMConfig.Models.AnthropicJudgeStrong }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Models.AnthropicJudgeCheap)) { $AnthropicModel_JudgeCheap = [string]$Script:MultiLLMConfig.Models.AnthropicJudgeCheap }
                }

                if ($null -ne $Script:MultiLLMConfig.Personas) {
                    foreach ($PersonaProp in $Script:MultiLLMConfig.Personas.PSObject.Properties) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$PersonaProp.Value)) {
                            $Script:PersonaTable[[string]$PersonaProp.Name] = [string]$PersonaProp.Value
                        }
                    }
                }

                if ($null -ne $Script:MultiLLMConfig.Endpoints) {
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Endpoints.OpenAIChatCompletions)) { $OpenAIBaseUrl = [string]$Script:MultiLLMConfig.Endpoints.OpenAIChatCompletions }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Endpoints.AnthropicMessages)) { $AnthropicBaseUrl = [string]$Script:MultiLLMConfig.Endpoints.AnthropicMessages }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Endpoints.AnthropicVersion)) { $AnthropicVersion = [string]$Script:MultiLLMConfig.Endpoints.AnthropicVersion }
                    if ($null -ne $Script:MultiLLMConfig.Endpoints.ProxyUrl) { $ProxyUrl = [string]$Script:MultiLLMConfig.Endpoints.ProxyUrl }
                }

                if ($null -ne $Script:MultiLLMConfig.Timeouts) {
                    if ($null -ne $Script:MultiLLMConfig.Timeouts.PerModelTimeoutSec) { $PerModelTimeoutSec = [int]$Script:MultiLLMConfig.Timeouts.PerModelTimeoutSec }
                    if ($null -ne $Script:MultiLLMConfig.Timeouts.TotalRequestTimeoutSec) { $TotalRequestTimeoutSec = [int]$Script:MultiLLMConfig.Timeouts.TotalRequestTimeoutSec }
                    if ($null -ne $Script:MultiLLMConfig.Timeouts.JudgeTimeoutSec) { $JudgeTimeoutSec = [int]$Script:MultiLLMConfig.Timeouts.JudgeTimeoutSec }
                    if ($null -ne $Script:MultiLLMConfig.Timeouts.MaxRetries) { $MaxRetries = [int]$Script:MultiLLMConfig.Timeouts.MaxRetries }
                    if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType) {
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.simple) { $TimeoutSimpleSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.simple }
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.technical) { $TimeoutTechnicalSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.technical }
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.documentation) { $TimeoutDocumentationSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.documentation }
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.creative) { $TimeoutCreativeSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.creative }
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.code) { $TimeoutCodeSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.code }
                        if ($null -ne $Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.ui_code) { $TimeoutUiCodeSec = [int]$Script:MultiLLMConfig.Timeouts.TimeoutsByTaskType.ui_code }
                    }
                }

                if ($null -ne $Script:MultiLLMConfig.OutputBudgets) {
                    if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType) {
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.simple) { $MaxOutputTokensSimple = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.simple }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.creative) { $MaxOutputTokensCreative = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.creative }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.documentation) { $MaxOutputTokensDocumentation = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.documentation }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.technical) { $MaxOutputTokensTechnical = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.technical }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.code) { $MaxOutputTokensCode = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.code }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.ui_code) { $MaxOutputTokensUiCode = [int]$Script:MultiLLMConfig.OutputBudgets.MaxOutputTokensByTaskType.ui_code }
                    }
                    if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType) {
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.technical) { $MaxJudgeTokensTechnical = [int]$Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.technical }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.code) { $MaxJudgeTokensCode = [int]$Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.code }
                        if ($null -ne $Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.ui_code) { $MaxJudgeTokensUiCode = [int]$Script:MultiLLMConfig.OutputBudgets.MaxJudgeTokensByTaskType.ui_code }
                    }
                    if ($null -ne $Script:MultiLLMConfig.OutputBudgets.EnableCompletenessCheck) { $EnableCompletenessCheck = [bool]$Script:MultiLLMConfig.OutputBudgets.EnableCompletenessCheck }
                    if ($null -ne $Script:MultiLLMConfig.OutputBudgets.CompletenessWarningMinLength) { $CompletenessWarningMinLength = [int]$Script:MultiLLMConfig.OutputBudgets.CompletenessWarningMinLength }
                }

                if ($null -ne $Script:MultiLLMConfig.Output) {
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Output.OutputRoot)) { $OutputRoot = [string]$Script:MultiLLMConfig.Output.OutputRoot }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Output.RunName)) { $RunName = [string]$Script:MultiLLMConfig.Output.RunName }
                    if ($null -ne $Script:MultiLLMConfig.Output.ShowFinalAnswerOnScreen) { $ShowFinalAnswerOnScreen = [bool]$Script:MultiLLMConfig.Output.ShowFinalAnswerOnScreen }
                    if ($null -ne $Script:MultiLLMConfig.Output.OpenFinalMarkdown) { $OpenFinalMarkdown = [bool]$Script:MultiLLMConfig.Output.OpenFinalMarkdown }
                    if ($null -ne $Script:MultiLLMConfig.Output.OpenOutputFolder) { $OpenOutputFolder = [bool]$Script:MultiLLMConfig.Output.OpenOutputFolder }
                    if ($null -ne $Script:MultiLLMConfig.Output.ExportRunMetricsCsv) { $ExportRunMetricsCsv = [bool]$Script:MultiLLMConfig.Output.ExportRunMetricsCsv }
                }

                if ($null -ne $Script:MultiLLMConfig.Behavior) {
                    if ($null -ne $Script:MultiLLMConfig.Behavior.SkipMultiForSimple) { $SkipMultiForSimple = [bool]$Script:MultiLLMConfig.Behavior.SkipMultiForSimple }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.SimplePromptMaxChars) { $SimplePromptMaxChars = [int]$Script:MultiLLMConfig.Behavior.SimplePromptMaxChars }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.CodeTriggersOverrideDocumentation) { $CodeTriggersOverrideDocumentation = [bool]$Script:MultiLLMConfig.Behavior.CodeTriggersOverrideDocumentation }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.RunFinalVerifier) { $RunFinalVerifier = [bool]$Script:MultiLLMConfig.Behavior.RunFinalVerifier }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.UseCheapJudgeForReview) { $UseCheapJudgeForReview = [bool]$Script:MultiLLMConfig.Behavior.UseCheapJudgeForReview }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.TaskSplitterMode)) { $TaskSplitterMode = [string]$Script:MultiLLMConfig.Behavior.TaskSplitterMode }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.TaskWorkMode)) { $TaskWorkMode = [string]$Script:MultiLLMConfig.Behavior.TaskWorkMode }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.UiCodeAutoWorkMode)) { $UiCodeAutoWorkMode = [string]$Script:MultiLLMConfig.Behavior.UiCodeAutoWorkMode }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.MaxTasksPerPrompt) { $MaxTasksPerPrompt = [int]$Script:MultiLLMConfig.Behavior.MaxTasksPerPrompt }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.PromptPreset)) { $PromptPreset = [string]$Script:MultiLLMConfig.Behavior.PromptPreset }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.SkipMissingInputTasks) { $SkipMissingInputTasks = [bool]$Script:MultiLLMConfig.Behavior.SkipMissingInputTasks }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.CreativeTasksUseSingleModel) { $CreativeTasksUseSingleModel = [bool]$Script:MultiLLMConfig.Behavior.CreativeTasksUseSingleModel }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.CreativeTasksUseJudge) { $CreativeTasksUseJudge = [bool]$Script:MultiLLMConfig.Behavior.CreativeTasksUseJudge }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.DocumentationTasksUseSingleModel) { $DocumentationTasksUseSingleModel = [bool]$Script:MultiLLMConfig.Behavior.DocumentationTasksUseSingleModel }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.DocumentationTasksUseJudge) { $DocumentationTasksUseJudge = [bool]$Script:MultiLLMConfig.Behavior.DocumentationTasksUseJudge }
                    if ($null -ne $Script:MultiLLMConfig.Behavior.SimpleTasksUseJudge) { $SimpleTasksUseJudge = [bool]$Script:MultiLLMConfig.Behavior.SimpleTasksUseJudge }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.PersonaMode)) { $PersonaMode = [string]$Script:MultiLLMConfig.Behavior.PersonaMode }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.PersonaA)) { $PersonaA = [string]$Script:MultiLLMConfig.Behavior.PersonaA }
                    if (-not [string]::IsNullOrWhiteSpace($Script:MultiLLMConfig.Behavior.PersonaB)) { $PersonaB = [string]$Script:MultiLLMConfig.Behavior.PersonaB }
                }
            }
        }
    }
    Catch {
        Write-Host "Config file load failed: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Continuing with variables from the top of the script." -ForegroundColor Yellow
    }
}

# -----------------------------
# INITIAL SETUP
# -----------------------------

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Mode detection: GUI (default) or pipeline (headless child / LaunchGui disabled).
$Script:SelfPath = $PSCommandPath
if ([string]::IsNullOrWhiteSpace($Script:SelfPath)) {
    $Script:SelfPath = $MyInvocation.MyCommand.Path
}

$Script:HeadlessMode = $false
if ($env:MULTILLM_HEADLESS -eq "1") {
    $Script:HeadlessMode = $true
}

$Script:RunPipelineMode = $false
if ($Script:HeadlessMode -eq $true) {
    $Script:RunPipelineMode = $true
}
if ($LaunchGui -ne $true) {
    $Script:RunPipelineMode = $true
}

if ($Script:HeadlessMode -eq $true) {
    # Child process launched by the GUI: no interactive prompts, no shell popups.
    $CreateSecretsFileIfMissing = $false
    $ForceRecreateSecretsFile   = $false
    $OpenFinalMarkdown          = $false
    $OpenOutputFolder           = $false
    $ShowFinalAnswerOnScreen    = $false

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_SPLITMODE)) {
        $TaskSplitterMode = $env:MULTILLM_SPLITMODE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_WORKMODE)) {
        $TaskWorkMode = $env:MULTILLM_WORKMODE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_UICODE_MODE)) {
        $UiCodeAutoWorkMode = $env:MULTILLM_UICODE_MODE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_MODEL_OPENAI)) {
        $OpenAIModel_Answer = $env:MULTILLM_MODEL_OPENAI
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_MODEL_ANTHROPIC)) {
        $AnthropicModel_Answer = $env:MULTILLM_MODEL_ANTHROPIC
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_MODEL_JUDGE)) {
        $AnthropicModel_Judge = $env:MULTILLM_MODEL_JUDGE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_MODEL_JUDGE_CHEAP)) {
        $AnthropicModel_JudgeCheap = $env:MULTILLM_MODEL_JUDGE_CHEAP
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_CHEAP_JUDGE)) {
        $UseCheapJudgeForReview = ($env:MULTILLM_CHEAP_JUDGE -eq "1")
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_PERSONA_MODE)) {
        $PersonaMode = $env:MULTILLM_PERSONA_MODE
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_PERSONA_A)) {
        $PersonaA = $env:MULTILLM_PERSONA_A
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_PERSONA_B)) {
        $PersonaB = $env:MULTILLM_PERSONA_B
    }

    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_RUNVERIFIER)) {
        $RunFinalVerifier = ($env:MULTILLM_RUNVERIFIER -eq "1")
    }
}

if (-not (Test-Path $OutputRoot)) {
    New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null
}

$RunFolder = ""
$TranscriptPath = ""

if ($Script:RunPipelineMode -eq $true) {
    if ($Script:HeadlessMode -eq $true -and -not [string]::IsNullOrWhiteSpace($env:MULTILLM_RUNFOLDER)) {
        $RunFolder = $env:MULTILLM_RUNFOLDER
    }
    else {
        $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $RunFolder = Join-Path $OutputRoot ($RunName + "_" + $TimeStamp)
    }

    New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

    $TranscriptPath = Join-Path $RunFolder "console_transcript.txt"
    Start-Transcript -Path $TranscriptPath -Force | Out-Null
}

# Re-apply prompt preset after config load, because config can override PromptPreset.
if ($PromptPreset -eq "SingleAD") {
    $UserPrompt = $SingleADPrompt
}
elseif ($PromptPreset -eq "MultiTaskDemo") {
    $UserPrompt = $MultiTaskDemoPrompt
}
else {
    $UserPrompt = $CustomUserPrompt
}

# GUI headless child: prompt text comes from the file written by the GUI.
if ($Script:HeadlessMode -eq $true) {
    if (-not [string]::IsNullOrWhiteSpace($env:MULTILLM_PROMPT_FILE)) {
        if (Test-Path -LiteralPath $env:MULTILLM_PROMPT_FILE) {
            $UserPrompt = [System.IO.File]::ReadAllText($env:MULTILLM_PROMPT_FILE)
            $PromptPreset = "Gui"
        }
    }
}

# -----------------------------
# HELPER FUNCTIONS
# -----------------------------

function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    Write-Host $Text -ForegroundColor $Color
}

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host ">>> $Text" -ForegroundColor Yellow
}

function Get-PersonaPreamble {
    param([string]$PersonaKey)

    if ($PersonaMode -ne "Fixed") { return "" }
    if ([string]::IsNullOrWhiteSpace($PersonaKey)) { return "" }
    $Key = $PersonaKey.Trim().ToLower()
    if ($Key -eq "none") { return "" }
    if ($Script:PersonaTable.Contains($Key)) {
        return [string]$Script:PersonaTable[$Key]
    }
    Write-Color ("[WARN] Unknown persona key: " + $Key + " (using no persona)") "Yellow"
    return ""
}

function Repair-CommonTextEncoding {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $Clean = $Text

    $ReplacementList = @(
        @{ Old = ([string][char]0x2013); New = "-" },
        @{ Old = ([string][char]0x2014); New = "-" },
        @{ Old = ([string][char]0x2018); New = "'" },
        @{ Old = ([string][char]0x2019); New = "'" },
        @{ Old = ([string][char]0x201C); New = '"' },
        @{ Old = ([string][char]0x201D); New = '"' },
        @{ Old = ([string][char]0x2026); New = "..." },
        @{ Old = ([string][char]0x00A0); New = " " },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x0093)); New = "-" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x0094)); New = "-" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x0098)); New = "'" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x0099)); New = "'" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x009C)); New = '"' },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x009D)); New = '"' },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x0080) + ([string][char]0x00A6)); New = "..." },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x201C)); New = "-" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x009D)); New = "-" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x02DC)); New = "'" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x2122)); New = "'" },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x0153)); New = '"' },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x009D)); New = '"' },
        @{ Old = (([string][char]0x00E2) + ([string][char]0x20AC) + ([string][char]0x00A6)); New = "..." }
    )

    foreach ($Item in $ReplacementList) {
        if ($Clean.Contains($Item.Old)) {
            $Clean = $Clean.Replace($Item.Old, $Item.New)
        }
    }

    # v0.8.52: remove common Unicode box-drawing/decorative characters that often mojibake in Windows PowerShell output.
    $Clean = [System.Text.RegularExpressions.Regex]::Replace($Clean, '[\u2500-\u257F]', '-')
    $Clean = $Clean.Replace((([string][char]0x00E2) + ([string][char]0x0094) + ([string][char]0x0080)), '-')

    return $Clean
}

function Save-Text {
    param(
        [string]$Path,
        [string]$Text
    )

    $SafeText = Repair-CommonTextEncoding -Text $Text
    $Utf8Bom = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($Path, $SafeText, $Utf8Bom)
}

function Save-Json {
    param(
        [string]$Path,
        [object]$Object
    )

    if ($null -eq $Object) {
        Save-Text -Path $Path -Text ""
    }
    else {
        $JsonText = $Object | ConvertTo-Json -Depth 25
        Save-Text -Path $Path -Text $JsonText
    }
}

function Get-HttpErrorBody {
    param([object]$ErrorRecord)

    $Body = ""

    try {
        if ($null -ne $ErrorRecord.Exception.Response) {
            $Stream = $ErrorRecord.Exception.Response.GetResponseStream()
            if ($null -ne $Stream) {
                $Reader = New-Object System.IO.StreamReader($Stream)
                $Body = $Reader.ReadToEnd()
                $Reader.Close()
            }
        }
    }
    catch {
        $Body = ""
    }

    return $Body
}

function Get-RunMetricObject {
    param(
        [object]$Result,
        [string]$Role
    )

    $Metric = [PSCustomObject]@{
        Role             = $Role
        Provider         = $Result.Provider
        Model            = $Result.Model
        Success          = $Result.Success
        Attempt          = $Result.Attempt
        DurationSeconds  = $Result.DurationSeconds
        StatusCode       = $Result.StatusCode
        InputTokens      = $Result.InputTokens
        OutputTokens     = $Result.OutputTokens
        TotalTokens      = $Result.TotalTokens
        EstimatedCostUsd = $Result.EstimatedCostUsd
        Error            = $Result.Error
    }

    return $Metric
}

function Test-ScriptSecretExposure {
    $ScriptPath = $MyInvocation.ScriptName

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        $ScriptPath = $PSCommandPath
    }

    if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
        return
    }

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        return
    }

    try {
        $ScriptText = Get-Content -LiteralPath $ScriptPath -Raw -ErrorAction Stop
    }
    catch {
        return
    }

    $HardcodedSecretPatterns = @(
        '\$OpenAIApiKey\s*=\s*["'']sk-',
        '\$AnthropicApiKey\s*=\s*["'']sk-',
        'sk-proj-[A-Za-z0-9_\\-]+',
        'REDACTED_ANTHROPIC_API_KEY[0-9A-Za-z_\\-]+'
    )

    $FoundSecret = $false

    foreach ($Pattern in $HardcodedSecretPatterns) {
        if ($ScriptText -match $Pattern) {
            $FoundSecret = $true
        }
    }

    if ($FoundSecret -eq $true) {
        Write-Header "SECURITY STOP"
        Write-Color "Hardcoded API key pattern was found inside the script file." "Red"
        Write-Color "Remove the key from the script and use environment variables instead." "Yellow"
        Write-Host ""
        Write-Host '$env:OPENAI_API_KEY = "your-openai-key"' -ForegroundColor Gray
        Write-Host '$env:ANTHROPIC_API_KEY = "your-anthropic-key"' -ForegroundColor Gray
        Write-Host ""

        if ($AllowHardcodedApiKeys -ne $true) {
            Stop-Transcript | Out-Null
            exit 1
        }
    }
}


function Convert-SecureStringToPlainText {
    param([System.Security.SecureString]$SecureString)

    if ($null -eq $SecureString) {
        return ""
    }

    $Bstr = [IntPtr]::Zero

    try {
        $Bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        $PlainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
        return $PlainText
    }
    catch {
        return ""
    }
    finally {
        if ($Bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Bstr)
        }
    }
}

function New-MultiLLMSecretsFile {
    param([string]$Path)

    Write-Header "CREATE ENCRYPTED SECRETS FILE"

    $ParentPath = Split-Path -Path $Path -Parent

    if (-not (Test-Path -LiteralPath $ParentPath)) {
        New-Item -ItemType Directory -Path $ParentPath -Force | Out-Null
    }

    Write-Color "Secrets file will be encrypted for the current Windows user on this computer." "Yellow"
    Write-Color "Path: $Path" "Gray"
    Write-Host ""

    $OpenAISecureKey = Read-Host "Enter OpenAI API key" -AsSecureString
    $AnthropicSecureKey = Read-Host "Enter Anthropic API key" -AsSecureString

    $SecretsObject = [PSCustomObject]@{
        OpenAIKey    = $OpenAISecureKey
        AnthropicKey = $AnthropicSecureKey
        CreatedAt    = (Get-Date)
        ComputerName = $env:COMPUTERNAME
        UserName     = "$env:USERDOMAIN\$env:USERNAME"
        Format       = "DPAPI-CLIXML"
    }

    Try {
        $SecretsObject | Export-Clixml -Path $Path -Force
        Write-Color "Encrypted secrets file created successfully." "Green"
    }
    Catch {
        Write-Color "Failed to create encrypted secrets file: $($_.Exception.Message)" "Red"
        Stop-Transcript | Out-Null
        exit 1
    }
}

function Save-MultiLLMApiKeysSecure {
    param(
        [System.Security.SecureString]$OpenAISecure,
        [System.Security.SecureString]$AnthropicSecure
    )

    $ParentPath = Split-Path -Path $SecretsPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($ParentPath)) {
        if (-not (Test-Path -LiteralPath $ParentPath)) {
            New-Item -ItemType Directory -Path $ParentPath -Force | Out-Null
        }
    }

    $SecretsObject = [PSCustomObject]@{
        OpenAIKey    = $OpenAISecure
        AnthropicKey = $AnthropicSecure
        CreatedAt    = (Get-Date)
        ComputerName = $env:COMPUTERNAME
        UserName     = "$env:USERDOMAIN\$env:USERNAME"
        Format       = "DPAPI-CLIXML"
    }

    $SecretsObject | Export-Clixml -Path $SecretsPath -Force
}

function Initialize-ApiKeys {
    $script:OpenAIApiKey = ""
    $script:AnthropicApiKey = ""

    if ($UseEncryptedSecretsFile -eq $true) {
        if ($ForceRecreateSecretsFile -eq $true) {
            New-MultiLLMSecretsFile -Path $SecretsPath
        }
        else {
            if (-not (Test-Path -LiteralPath $SecretsPath)) {
                if ($CreateSecretsFileIfMissing -eq $true) {
                    New-MultiLLMSecretsFile -Path $SecretsPath
                }
            }
        }

        if (Test-Path -LiteralPath $SecretsPath) {
            Try {
                $Secrets = Import-Clixml -Path $SecretsPath -ErrorAction Stop

                if ($null -ne $Secrets.OpenAIKey) {
                    if ($Secrets.OpenAIKey -is [System.Security.SecureString]) {
                        $script:OpenAIApiKey = Convert-SecureStringToPlainText -SecureString $Secrets.OpenAIKey
                    }
                }

                if ($null -ne $Secrets.AnthropicKey) {
                    if ($Secrets.AnthropicKey -is [System.Security.SecureString]) {
                        $script:AnthropicApiKey = Convert-SecureStringToPlainText -SecureString $Secrets.AnthropicKey
                    }
                }

                Write-Color "Encrypted secrets file loaded." "Green"
            }
            Catch {
                Write-Color "Failed to load encrypted secrets file: $($_.Exception.Message)" "Red"
                Write-Color "Delete/recreate the secrets file if it was copied from another user or computer." "Yellow"
                Stop-Transcript | Out-Null
                exit 1
            }
        }
    }

    if ($UseEnvironmentVariablesFallback -eq $true) {
        if ([string]::IsNullOrWhiteSpace($script:OpenAIApiKey)) {
            if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
                $script:OpenAIApiKey = $env:OPENAI_API_KEY
                Write-Color "OpenAI key loaded from environment variable fallback." "Yellow"
            }
        }

        if ([string]::IsNullOrWhiteSpace($script:AnthropicApiKey)) {
            if (-not [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) {
                $script:AnthropicApiKey = $env:ANTHROPIC_API_KEY
                Write-Color "Anthropic key loaded from environment variable fallback." "Yellow"
            }
        }
    }
}

function Test-ApiKeys {
    $Problems = @()

    if ([string]::IsNullOrWhiteSpace($OpenAIApiKey)) {
        $Problems += "OPENAI_API_KEY is missing."
    }

    if ([string]::IsNullOrWhiteSpace($AnthropicApiKey)) {
        $Problems += "ANTHROPIC_API_KEY is missing."
    }

    if ($Problems.Count -gt 0) {
        Write-Header "CONFIGURATION ERROR"
        foreach ($Problem in $Problems) {
            Write-Color $Problem "Red"
        }

        Write-Host ""
        Write-Host "Set keys in PowerShell before running:" -ForegroundColor Yellow
        Write-Host '$env:OPENAI_API_KEY = "your-openai-key"' -ForegroundColor Gray
        Write-Host '$env:ANTHROPIC_API_KEY = "your-anthropic-key"' -ForegroundColor Gray
        Stop-Transcript | Out-Null
        exit 1
    }
}

function Get-TaskType {
    param([string]$PromptText)

    $Lower = $PromptText.ToLower()
    $TaskType = "simple"

    $TechnicalTriggers = @(
        "powershell",
        "script",
        "active directory",
        " ad ",
        "intune",
        "defender",
        "api",
        "json",
        "yaml",
        "csv",
        "xml",
        "gpo",
        "dns",
        "dhcp",
        "vmware",
        "vcenter",
        "powercli",
        "wpf",
        "xaml",
        "gui",
        "veeam",
        "security",
        "error",
        "exception",
        "logs",
        "http",
        "rest",
        "proxy"
    )

    $CodeTriggers = @(
        "fix",
        "debug",
        "rewrite",
        "create script",
        "write script",
        "complete script",
        "function",
        "class",
        "module",
        "try/catch",
        "invoke-restmethod",
        "winforms",
        "datagridview",
        "listview",
        "datagrid",
        "wpf",
        "xaml",
        "gui"
    )

    $DocumentationTriggers = @(
        "summary",
        "management",
        "email",
        "guide",
        "documentation",
        "explain",
        "architecture",
        "design",
        "review"
    )

    $CreativeTriggers = @(
        "suno",
        "song",
        "lyrics",
        "style",
        "music",
        "poem"
    )

    foreach ($Trigger in $TechnicalTriggers) {
        if ($Lower.Contains($Trigger)) {
            $TaskType = "technical"
        }
    }

    foreach ($Trigger in $DocumentationTriggers) {
        if ($Lower.Contains($Trigger)) {
            if ($TaskType -eq "simple") {
                $TaskType = "documentation"
            }
        }
    }

    foreach ($Trigger in $CodeTriggers) {
        if ($Lower.Contains($Trigger)) {
            if ($CodeTriggersOverrideDocumentation -eq $true) {
                $TaskType = "code"
            }
            else {
                if ($TaskType -ne "documentation") {
                    $TaskType = "code"
                }
            }
        }
    }

    if ($Lower.Contains("create") -and $Lower.Contains("script")) {
        if ($CodeTriggersOverrideDocumentation -eq $true) {
            $TaskType = "code"
        }
        else {
            if ($TaskType -ne "documentation") {
                $TaskType = "code"
            }
        }
    }

    if ($Lower.Contains("write") -and $Lower.Contains("script")) {
        if ($CodeTriggersOverrideDocumentation -eq $true) {
            $TaskType = "code"
        }
        else {
            if ($TaskType -ne "documentation") {
                $TaskType = "code"
            }
        }
    }

    foreach ($Trigger in $CreativeTriggers) {
        if ($Lower.Contains($Trigger)) {
            $TaskType = "creative"
        }
    }

    if ($TaskType -eq "code") {
        if ($Lower.Contains("wpf") -or $Lower.Contains("xaml") -or $Lower.Contains("gui") -or $Lower.Contains("winforms") -or $Lower.Contains("datagrid")) {
            $TaskType = "ui_code"
        }
    }

    if ($PromptText.Length -gt $SimplePromptMaxChars) {
        if ($TaskType -eq "simple") {
            $TaskType = "technical"
        }
    }

    return $TaskType
}

function Get-TaskTimeoutSettings {
    param([string]$TaskType)

    $AnswerTimeout = $PerModelTimeoutSec

    if ($TaskType -eq "simple") {
        $AnswerTimeout = $TimeoutSimpleSec
    }
    elseif ($TaskType -eq "technical") {
        $AnswerTimeout = $TimeoutTechnicalSec
    }
    elseif ($TaskType -eq "documentation") {
        $AnswerTimeout = $TimeoutDocumentationSec
    }
    elseif ($TaskType -eq "creative") {
        $AnswerTimeout = $TimeoutCreativeSec
    }
    elseif ($TaskType -eq "ui_code") {
        $AnswerTimeout = $TimeoutUiCodeSec
    }
    elseif ($TaskType -eq "code") {
        $AnswerTimeout = $TimeoutCodeSec
    }

    $TotalTimeout = $AnswerTimeout + 15
    if ($TotalTimeout -lt $TotalRequestTimeoutSec) {
        $TotalTimeout = $TotalRequestTimeoutSec
    }

    return [PSCustomObject]@{
        PerModelTimeoutSec     = [int]$AnswerTimeout
        TotalRequestTimeoutSec = [int]$TotalTimeout
    }
}

function Get-TaskOutputTokenSettings {
    param([string]$TaskType)

    $AnswerMaxTokens = $MaxOutputTokens_Answer
    $JudgeMaxTokens = $MaxOutputTokens_Judge

    if ($TaskType -eq "simple") {
        $AnswerMaxTokens = $MaxOutputTokensSimple
    }
    elseif ($TaskType -eq "creative") {
        $AnswerMaxTokens = $MaxOutputTokensCreative
    }
    elseif ($TaskType -eq "documentation") {
        $AnswerMaxTokens = $MaxOutputTokensDocumentation
    }
    elseif ($TaskType -eq "technical") {
        $AnswerMaxTokens = $MaxOutputTokensTechnical
        $JudgeMaxTokens = $MaxJudgeTokensTechnical
    }
    elseif ($TaskType -eq "ui_code") {
        $AnswerMaxTokens = $MaxOutputTokensUiCode
        $JudgeMaxTokens = $MaxJudgeTokensUiCode
    }
    elseif ($TaskType -eq "code") {
        $AnswerMaxTokens = $MaxOutputTokensCode
        $JudgeMaxTokens = $MaxJudgeTokensCode
    }

    return [PSCustomObject]@{
        AnswerMaxTokens = [int]$AnswerMaxTokens
        JudgeMaxTokens  = [int]$JudgeMaxTokens
    }
}


function Get-TaskWorkMode {
    param(
        [string]$PromptText,
        [string]$TaskType
    )

    $Mode = $TaskWorkMode
    if ([string]::IsNullOrWhiteSpace($Mode)) {
        $Mode = "Auto"
    }

    if ($Mode -eq "Review" -or $Mode -eq "Script") {
        return $Mode
    }

    $Lower = $PromptText.ToLower()

    if ($TaskType -eq "ui_code") {
        if ($Lower.Contains("complete script") -or $Lower.Contains("full script") -or $Lower.Contains("runnable script") -or $Lower.Contains("create script") -or $Lower.Contains("write script")) {
            return "Script"
        }
        if ($Lower.Contains("concept") -or $Lower.Contains("review") -or $Lower.Contains("suggest") -or $Lower.Contains("design") -or $Lower.Contains("plan")) {
            return $UiCodeAutoWorkMode
        }
        return $UiCodeAutoWorkMode
    }

    # v0.8.52: technical correction rule runs BEFORE the generic review rule.
    # "Review an audit finding ... propose a safe correction" must produce a full
    # correction script, so correction/fix wording wins over review/audit wording.
    if ($TaskType -eq "technical") {
        if ($Lower.Contains("safe powershell") -or
            $Lower.Contains("powershell 5.1 correction") -or
            $Lower.Contains("propose a safe") -or
            $Lower.Contains("correction") -or
            $Lower.Contains("provide a script") -or
            $Lower.Contains("complete script") -or
            $Lower.Contains("runnable script") -or
            $Lower.Contains("fix ") -or
            $Lower.Contains(" fix") -or
            $Lower.Contains("correct ")) {
            return "Script"
        }
    }

    if ($Lower.Contains("review") -or $Lower.Contains("analyze") -or $Lower.Contains("audit") -or $Lower.Contains("suggest") -or $Lower.Contains("explain the bug")) {
        if (-not ($Lower.Contains("complete script") -or $Lower.Contains("full script") -or $Lower.Contains("runnable script") -or $Lower.Contains("create script") -or $Lower.Contains("write script"))) {
            return "Review"
        }
    }

    if ($TaskType -eq "code") {
        if ($Lower.Contains("script") -or $Lower.Contains("code") -or $Lower.Contains("function") -or $Lower.Contains("wpf") -or $Lower.Contains("xaml")) {
            return "Script"
        }
    }

    if ($TaskType -eq "technical") {
        return "Review"
    }

    if ($TaskType -eq "documentation" -or $TaskType -eq "creative" -or $TaskType -eq "simple") {
        return "Review"
    }

    return "Review"
}

function Get-EffectivePromptForWorkMode {
    param(
        [string]$PromptText,
        [string]$TaskType,
        [string]$WorkMode
    )

    if ($WorkMode -eq "Review") {
        return @"
WORK MODE: REVIEW
Do not write a full script or a full application.
Do not generate long code blocks.
Provide analysis, review, design notes, risks, tradeoffs, recommended structure, and small targeted snippets only when useful.
If the user asks for a GUI or script concept, describe the structure and behavior instead of outputting the full script.
Use concise, practical output.

TASK TYPE: $TaskType

USER TASK:
$PromptText
"@
    }

    return @"
WORK MODE: SCRIPT
Provide a complete runnable answer when the task asks for a script or code.
For PowerShell, follow Windows PowerShell 5.1 rules, start complete scripts with cls, keep variables at the top, use if/else and Try/Catch, and avoid top-level param blocks.
Use ASCII-only code/comments.

TASK TYPE: $TaskType

USER TASK:
$PromptText
"@
}

function Get-AnswerById {
    param(
        [object[]]$AnswerResults,
        [string]$AnswerId
    )

    if ([string]::IsNullOrWhiteSpace($AnswerId)) {
        return $null
    }

    $CleanId = $AnswerId.Trim().ToUpper()
    if ($CleanId.Length -gt 1) {
        $CleanId = $CleanId.Substring(0, 1)
    }

    $Index = [int][char]$CleanId - [int][char]'A'
    if ($Index -ge 0 -and $Index -lt @($AnswerResults).Count) {
        return $AnswerResults[$Index]
    }

    return $null
}

function Test-FinalAnswerCompleteness {
    param([string]$Text)

    $Warning = $false
    $Reason = ""

    if ($EnableCompletenessCheck -ne $true) {
        return [PSCustomObject]@{ Warning = $false; Reason = "Completeness check disabled." }
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return [PSCustomObject]@{ Warning = $true; Reason = "Final answer is empty." }
    }

    $Trimmed = $Text.Trim()
    if ($Trimmed.Length -lt $CompletenessWarningMinLength) {
        return [PSCustomObject]@{ Warning = $false; Reason = "Text is short; no completeness warning." }
    }

    $FenceCount = ([regex]::Matches($Trimmed, '```')).Count
    if (($FenceCount % 2) -ne 0) {
        return [PSCustomObject]@{ Warning = $true; Reason = "Possible incomplete output: unclosed Markdown code fence." }
    }

    $CleanEndChars = @('.', '!', '?', ')', ']', '}', '"', "'", '`')
    $LastChar = $Trimmed.Substring($Trimmed.Length - 1, 1)
    $EndsClean = $false

    foreach ($Char in $CleanEndChars) {
        if ($LastChar -eq $Char) {
            $EndsClean = $true
        }
    }

    if ($EndsClean -eq $false) {
        $Lines = @($Trimmed -split "`r?`n")
        $LastNonEmptyLine = ""
        foreach ($Line in $Lines) {
            if (-not [string]::IsNullOrWhiteSpace($Line)) {
                $LastNonEmptyLine = $Line.Trim()
            }
        }

        if ($LastNonEmptyLine.Length -gt 20) {
            $Reason = "Possible incomplete output: final non-empty line does not end with normal punctuation."
            return [PSCustomObject]@{ Warning = $true; Reason = $Reason }
        }
    }

    return [PSCustomObject]@{ Warning = $false; Reason = "Looks complete." }
}

function Test-TaskMissingRequiredInput {
    param(
        [string]$PromptText,
        [string]$TaskType
    )

    $Lower = $PromptText.ToLower()
    $Missing = $false
    $Reason = ""

    # Conservative v0.8.52 heuristic: skip obvious summarization/review tasks that refer to absent source material.
    if ($TaskType -eq "documentation") {
        if ($Lower.Contains("summarize") -and ($Lower.Contains("email") -or $Lower.Contains("document") -or $Lower.Contains("text") -or $Lower.Contains("file"))) {
            $HasInlineContent = $false

            if ($PromptText.Length -gt 600) { $HasInlineContent = $true }
            if ($Lower.Contains("from:") -or $Lower.Contains("subject:") -or $Lower.Contains("email content:") -or $Lower.Contains("text:") -or $Lower.Contains('```')) { $HasInlineContent = $true }

            if ($HasInlineContent -eq $false) {
                $Missing = $true
                $Reason = "Task asks to summarize source material, but no email/document/text content was provided."
            }
        }
    }

    return [PSCustomObject]@{
        Missing = $Missing
        Reason  = $Reason
    }
}

function Get-RouterDecision {
    param(
        [string]$PromptText,
        [string]$TaskType,
        [string]$WorkModeOverride = ""
    )

    $UseOpenAI = $true
    $UseAnthropicAnswer = $true
    $UseJudge = $true
    $WorkModeOverrideApplied = $false
    $WorkMode = Get-TaskWorkMode -PromptText $PromptText -TaskType $TaskType
    if ($WorkModeOverride -eq "Review" -or $WorkModeOverride -eq "Script") {
        $WorkMode = $WorkModeOverride
        $WorkModeOverrideApplied = $true
    }
    $JudgeModePolicy = "Auto"
    $Reason = "Default multi-model route."

    if ($SkipMultiForSimple -eq $true) {
        if ($TaskType -eq "simple") {
            $UseAnthropicAnswer = $false
            $UseJudge = $SimpleTasksUseJudge
            $Reason = "Simple prompt: using one fast answer model only."
        }
    }

    if ($TaskType -eq "creative") {
        if ($CreativeTasksUseSingleModel -eq $true) {
            $UseOpenAI = $false
            $UseAnthropicAnswer = $true
            $UseJudge = $CreativeTasksUseJudge
            $Reason = "Creative task: using Anthropic answer only by default to reduce cost."
        }
    }
    elseif ($TaskType -eq "documentation") {
        if ($DocumentationTasksUseSingleModel -eq $true) {
            $UseOpenAI = $false
            $UseAnthropicAnswer = $true
            $UseJudge = $DocumentationTasksUseJudge
            $Reason = "Documentation task: using Anthropic answer only by default to reduce cost."
        }
    }
    elseif ($TaskType -eq "code" -or $TaskType -eq "ui_code" -or $TaskType -eq "technical") {
        $UseOpenAI = $true
        $UseAnthropicAnswer = $true
        $UseJudge = $true
        $Reason = "Technical/code task: using both answer models and Judge."
    }

    if ($UseJudge -eq $true) {
        if ($WorkMode -eq "Review") {
            $JudgeModePolicy = "ReviewOnly"
        }
        elseif ($TaskType -eq "ui_code") {
            $JudgeModePolicy = "ReviewOnly"
        }
        else {
            $JudgeModePolicy = "Auto"
        }
    }
    else {
        $JudgeModePolicy = "Skipped"
    }

    $Reason = $Reason + " WorkMode=" + $WorkMode + "; JudgeModePolicy=" + $JudgeModePolicy + "."

    $TimeoutSettings = Get-TaskTimeoutSettings -TaskType $TaskType
    $OutputTokenSettings = Get-TaskOutputTokenSettings -TaskType $TaskType

    $Decision = [PSCustomObject]@{
        TaskType                       = $TaskType
        UseOpenAI                      = $UseOpenAI
        UseAnthropicAnswer             = $UseAnthropicAnswer
        UseJudge                       = $UseJudge
        WorkMode                       = $WorkMode
        WorkModeOverrideApplied        = $WorkModeOverrideApplied
        JudgeModePolicy                = $JudgeModePolicy
        Reason                         = $Reason
        PerModelTimeoutSec             = $TimeoutSettings.PerModelTimeoutSec
        TotalRequestTimeoutSec         = $TimeoutSettings.TotalRequestTimeoutSec
        MaxAnswerTokens                = $OutputTokenSettings.AnswerMaxTokens
        MaxJudgeTokens                 = $OutputTokenSettings.JudgeMaxTokens
        CodeTriggersOverrideDocumentation = $CodeTriggersOverrideDocumentation
    }

    return $Decision
}

function Test-LineLooksLikeSeparateTask {
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) {
        return $false
    }

    $CleanLine = $Line.Trim()
    $CleanLine = $CleanLine.TrimStart("#".ToCharArray()).Trim()
    $CleanLine = $CleanLine -replace '^\s*[\-\*]\s+', ''
    $CleanLine = $CleanLine -replace '^\s*\d+[\.)]\s+', ''
    $LowerLine = $CleanLine.ToLower()

    $TaskVerbs = @(
        "create ",
        "write ",
        "review ",
        "summarize ",
        "explain ",
        "compare ",
        "fix ",
        "rewrite ",
        "analyze ",
        "translate ",
        "make ",
        "generate ",
        "list ",
        "check ",
        "find ",
        "show ",
        "build ",
        "design "
    )

    foreach ($Verb in $TaskVerbs) {
        if ($LowerLine.StartsWith($Verb)) {
            return $true
        }
    }

    if ($LowerLine.Contains(" powershell ") -or $LowerLine.StartsWith("powershell ")) {
        return $true
    }

    return $false
}

function Get-TaskTitleFromText {
    param([string]$Text)

    $Clean = $Text.Trim()
    $Clean = $Clean.TrimStart("#".ToCharArray()).Trim()
    $Clean = $Clean -replace '^\s*[\-\*]\s+', ''
    $Clean = $Clean -replace '^\s*\d+[\.)]\s+', ''
    $Clean = $Clean -replace '\s+', ' '

    if ([string]::IsNullOrWhiteSpace($Clean)) {
        return "Untitled task"
    }

    return $Clean
}

function Get-ShortText {
    param(
        [string]$Text,
        [int]$MaxLength = 120
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $Clean = $Text -replace '\s+', ' '
    $Clean = $Clean.Trim()

    if ($Clean.Length -gt $MaxLength) {
        return $Clean.Substring(0, $MaxLength).Trim() + "..."
    }

    return $Clean
}

function ConvertTo-MarkdownTableCell {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $Clean = [string]$Text
    $Clean = $Clean.Replace("`r", " ").Replace("`n", " ")
    $Clean = $Clean -replace '\|', '\|'
    $Clean = $Clean.Trim()
    return $Clean
}

function New-TaskSummaryMarkdown {
    param([object[]]$TaskSummary)

    $Lines = @()
    $Lines += "| TaskId | TaskTitle | TaskType | WorkMode | Success | AnswerCount | JudgeMode | Judge Model | Completeness | Tokens | Cost USD | TaskFolder | Error |"
    $Lines += "|---:|---|---|---|---:|---:|---|---|---|---:|---:|---|---|"

    foreach ($Item in $TaskSummary) {
        if ($Item.CompletenessWarning -eq $true) {
            $CompletenessText = "WARN"
        }
        else {
            $CompletenessText = "OK"
        }

        $Lines += ("| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} |" -f `
            (ConvertTo-MarkdownTableCell -Text $Item.TaskId), `
            (ConvertTo-MarkdownTableCell -Text $Item.TaskTitle), `
            (ConvertTo-MarkdownTableCell -Text $Item.TaskType), `
            (ConvertTo-MarkdownTableCell -Text $Item.WorkMode), `
            (ConvertTo-MarkdownTableCell -Text $Item.Success), `
            (ConvertTo-MarkdownTableCell -Text $Item.AnswerCount), `
            (ConvertTo-MarkdownTableCell -Text $Item.JudgeMode), `
            (ConvertTo-MarkdownTableCell -Text $Item.JudgeModelUsed), `
            (ConvertTo-MarkdownTableCell -Text $CompletenessText), `
            (ConvertTo-MarkdownTableCell -Text $Item.TotalTokens), `
            (ConvertTo-MarkdownTableCell -Text $Item.EstimatedCostUsd), `
            (ConvertTo-MarkdownTableCell -Text $Item.TaskFolder), `
            (ConvertTo-MarkdownTableCell -Text $Item.Error))
    }

    return ($Lines -join "`r`n")
}


function New-StageMetric {
    param(
        [int]$TaskId,
        [string]$TaskTitle,
        [string]$StageName,
        [datetime]$StartTime,
        [datetime]$EndTime,
        [bool]$Success,
        [string]$Details
    )

    if ($null -eq $EndTime) {
        $EndTime = Get-Date
    }

    $DurationSeconds = [Math]::Round(($EndTime - $StartTime).TotalSeconds, 3)

    return [PSCustomObject]@{
        TaskId          = $TaskId
        TaskTitle       = $TaskTitle
        StageName       = $StageName
        StartedAt       = $StartTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        EndedAt         = $EndTime.ToString("yyyy-MM-dd HH:mm:ss.fff")
        DurationSeconds = $DurationSeconds
        Success         = $Success
        Details         = $Details
    }
}

function New-RequestMetricObject {
    param(
        [object]$Result,
        [string]$Role,
        [int]$TaskId,
        [string]$TaskTitle,
        [string]$RequestName,
        [string]$StageName
    )

    if ($null -eq $Result) {
        return [PSCustomObject]@{
            TaskId           = $TaskId
            TaskTitle        = $TaskTitle
            RequestName      = $RequestName
            StageName        = $StageName
            Role             = $Role
            Provider         = ""
            Model            = ""
            Success          = $false
            Attempt          = $null
            DurationSeconds  = $null
            StatusCode       = $null
            InputTokens      = $null
            OutputTokens     = $null
            TotalTokens      = $null
            EstimatedCostUsd = $null
            Error            = "Null result object"
        }
    }

    return [PSCustomObject]@{
        TaskId           = $TaskId
        TaskTitle        = $TaskTitle
        RequestName      = $RequestName
        StageName        = $StageName
        Role             = $Role
        Provider         = $Result.Provider
        Model            = $Result.Model
        Success          = $Result.Success
        Attempt          = $Result.Attempt
        DurationSeconds  = $Result.DurationSeconds
        StatusCode       = $Result.StatusCode
        InputTokens      = $Result.InputTokens
        OutputTokens     = $Result.OutputTokens
        TotalTokens      = $Result.TotalTokens
        EstimatedCostUsd = $Result.EstimatedCostUsd
        Error            = $Result.Error
    }
}

function Export-MetricCollection {
    param(
        [object[]]$MetricCollection,
        [string]$Path
    )

    if ($null -eq $MetricCollection) {
        Save-Text -Path $Path -Text ""
        return
    }

    $Items = @($MetricCollection)
    if ($Items.Count -gt 0) {
        $Items | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8 -Force
    }
    else {
        Save-Text -Path $Path -Text ""
    }
}

function Get-MetricTotalSeconds {
    param(
        [object[]]$MetricCollection,
        [string]$StageName
    )

    $Total = 0.0
    foreach ($Metric in @($MetricCollection)) {
        if ($Metric.StageName -eq $StageName) {
            if ($null -ne $Metric.DurationSeconds) {
                $Total += [double]$Metric.DurationSeconds
            }
        }
    }

    return [Math]::Round($Total, 3)
}

function Split-UserPromptIntoTasks {
    param(
        [string]$PromptText,
        [string]$Mode,
        [int]$MaxTasks
    )

    $Tasks = @()

    if ([string]::IsNullOrWhiteSpace($PromptText)) {
        $Tasks += [PSCustomObject]@{
            TaskId     = 1
            TaskTitle  = "Empty prompt"
            PromptText = ""
            SplitMode  = $Mode
            WasSplit   = $false
        }
        return $Tasks
    }

    if ($Mode -eq "None") {
        $Tasks += [PSCustomObject]@{
            TaskId     = 1
            TaskTitle  = Get-TaskTitleFromText -Text $PromptText
            PromptText = $PromptText.Trim()
            SplitMode  = "None"
            WasSplit   = $false
        }
        return $Tasks
    }

    $EffectiveMode = $Mode
    if ($Mode -eq "LLM") {
        $EffectiveMode = "HeuristicFallback"
    }

    $RawLines = [System.Text.RegularExpressions.Regex]::Split($PromptText, '\r?\n')
    $CandidateLines = @()

    foreach ($Line in $RawLines) {
        $Trimmed = $Line.Trim()
        if (-not [string]::IsNullOrWhiteSpace($Trimmed)) {
            $CandidateLines += $Trimmed
        }
    }

    $TaskLikeLines = @()
    foreach ($Line in $CandidateLines) {
        if (Test-LineLooksLikeSeparateTask -Line $Line) {
            $TaskLikeLines += $Line
        }
    }

    $ShouldSplit = $false
    if ($TaskLikeLines.Count -ge 2) {
        if ($CandidateLines.Count -le 12) {
            $ShouldSplit = $true
        }
    }

    if ($ShouldSplit -eq $false) {
        $Tasks += [PSCustomObject]@{
            TaskId     = 1
            TaskTitle  = Get-TaskTitleFromText -Text $PromptText
            PromptText = $PromptText.Trim()
            SplitMode  = $EffectiveMode
            WasSplit   = $false
        }
        return $Tasks
    }

    $TaskId = 0
    foreach ($Line in $TaskLikeLines) {
        if ($TaskId -ge $MaxTasks) {
            break
        }

        $TaskId++
        $Tasks += [PSCustomObject]@{
            TaskId     = $TaskId
            TaskTitle  = Get-TaskTitleFromText -Text $Line
            PromptText = $Line.Trim()
            SplitMode  = $EffectiveMode
            WasSplit   = $true
        }
    }

    return $Tasks
}

function Get-EstimatedCostUsd {
    param(
        [string]$Provider,
        [string]$Model,
        [object]$InputTokens,
        [object]$OutputTokens
    )

    if ($null -eq $Script:MultiLLMConfig) {
        return $null
    }

    if ($null -eq $Script:MultiLLMConfig.CostPer1MTokens) {
        return $null
    }

    if ($null -eq $InputTokens -or $null -eq $OutputTokens) {
        return $null
    }

    $Key = $Provider + "|" + $Model
    $EntryProperty = $Script:MultiLLMConfig.CostPer1MTokens.PSObject.Properties[$Key]

    if ($null -eq $EntryProperty) {
        return $null
    }

    $Entry = $EntryProperty.Value
    if ($null -eq $Entry.InputUsd -or $null -eq $Entry.OutputUsd) {
        return $null
    }

    $InputCost = ([double]$InputTokens / 1000000) * [double]$Entry.InputUsd
    $OutputCost = ([double]$OutputTokens / 1000000) * [double]$Entry.OutputUsd
    $TotalCost = $InputCost + $OutputCost

    return [Math]::Round($TotalCost, 6)
}

function Update-ResultCostEstimate {
    param([object]$Result)

    if ($null -eq $Result) {
        return $Result
    }

    $Cost = Get-EstimatedCostUsd `
        -Provider $Result.Provider `
        -Model $Result.Model `
        -InputTokens $Result.InputTokens `
        -OutputTokens $Result.OutputTokens

    if ($null -ne $Cost) {
        try {
            $Result.EstimatedCostUsd = $Cost
        }
        catch {
        }
    }

    return $Result
}

function Start-LLMJob {
    param(
        [string]$Provider,
        [string]$Role,
        [string]$PromptText,
        [string]$Model,
        [int]$TimeoutSec = 0,
        [int]$MaxTokens = 0
    )

    if ($Role -ne "Answer") {
        $Job = Start-Job -Name ($Provider + "_" + $Role) -ScriptBlock {
            param([string]$ProviderName, [string]$ModelName, [string]$RoleName)
            return [PSCustomObject]@{
                Provider         = $ProviderName
                Model            = $ModelName
                Success          = $false
                Attempt          = 0
                DurationSeconds  = 0
                StatusCode       = $null
                InputTokens      = $null
                OutputTokens     = $null
                TotalTokens      = $null
                EstimatedCostUsd = $null
                Text             = ""
                Error            = "Start-LLMJob supports Answer role only in v0.8.52."
                Raw              = $null
            }
        } -ArgumentList $Provider, $Model, $Role
        return $Job
    }

    $EffectiveTimeoutSec = $TimeoutSec
    if ($EffectiveTimeoutSec -le 0) {
        $EffectiveTimeoutSec = $PerModelTimeoutSec
    }

    $EffectiveMaxTokens = $MaxTokens
    if ($EffectiveMaxTokens -le 0) {
        $EffectiveMaxTokens = $MaxOutputTokens_Answer
    }

    if ($Provider -eq "OpenAI") {
        return Start-OpenAIAnswerJob `
            -PromptText $PromptText `
            -Model $Model `
            -ApiKey $OpenAIApiKey `
            -Url $OpenAIBaseUrl `
            -Proxy $ProxyUrl `
            -MaxTokens $EffectiveMaxTokens `
            -TimeoutSec $EffectiveTimeoutSec `
            -Retries $MaxRetries
    }

    if ($Provider -eq "Anthropic") {
        return Start-AnthropicAnswerJob `
            -PromptText $PromptText `
            -Model $Model `
            -ApiKey $AnthropicApiKey `
            -Url $AnthropicBaseUrl `
            -Version $AnthropicVersion `
            -Proxy $ProxyUrl `
            -MaxTokens $EffectiveMaxTokens `
            -TimeoutSec $EffectiveTimeoutSec `
            -Retries $MaxRetries
    }

    $UnsupportedJob = Start-Job -Name ($Provider + "_Answer") -ScriptBlock {
        param([string]$ProviderName, [string]$ModelName)
        return [PSCustomObject]@{
            Provider         = $ProviderName
            Model            = $ModelName
            Success          = $false
            Attempt          = 0
            DurationSeconds  = 0
            StatusCode       = $null
            InputTokens      = $null
            OutputTokens     = $null
            TotalTokens      = $null
            EstimatedCostUsd = $null
            Text             = ""
            Error            = "Provider is configured but not implemented in v0.8.52."
            Raw              = $null
        }
    } -ArgumentList $Provider, $Model

    return $UnsupportedJob
}

function Invoke-LLMChat {
    param(
        [string]$Provider,
        [string]$Role,
        [string]$PromptText,
        [object[]]$AnswerResults,
        [string]$Mode,
        [int]$MaxTokens = 0,
        [string]$Model = ""
    )

    $EffectiveMaxTokens = $MaxTokens
    if ($EffectiveMaxTokens -le 0) {
        $EffectiveMaxTokens = $MaxOutputTokens_Judge
    }

    $EffectiveJudgeModel = $Model
    if ([string]::IsNullOrWhiteSpace($EffectiveJudgeModel)) {
        $EffectiveJudgeModel = $AnthropicModel_Judge
    }

    if ($Role -eq "Judge" -and $Provider -eq "Anthropic") {
        return Invoke-AnthropicJudge `
            -PromptText $PromptText `
            -AnswerResults $AnswerResults `
            -JudgeModel $EffectiveJudgeModel `
            -ApiKey $AnthropicApiKey `
            -Url $AnthropicBaseUrl `
            -Version $AnthropicVersion `
            -Proxy $ProxyUrl `
            -MaxTokens $EffectiveMaxTokens `
            -TimeoutSec $JudgeTimeoutSec `
            -Retries $MaxRetries `
            -Mode $Mode
    }

    return [PSCustomObject]@{
        Provider         = $Provider
        Model            = ""
        Success          = $false
        Attempt          = 0
        DurationSeconds  = 0
        StatusCode       = $null
        InputTokens      = $null
        OutputTokens     = $null
        TotalTokens      = $null
        EstimatedCostUsd = $null
        Mode             = $Mode
        Text             = ""
        Error            = "Provider or role is not implemented in Invoke-LLMChat v0.8.52."
        Raw              = $null
    }
}

function Get-OpenAIChatTextFromResponse {
    param([object]$ResponseObject)

    $Text = ""

    if ($null -ne $ResponseObject.choices) {
        foreach ($Choice in $ResponseObject.choices) {
            if ($null -ne $Choice.message) {
                if ($null -ne $Choice.message.content) {
                    $Text += [string]$Choice.message.content
                }
            }
        }
    }

    return $Text
}

function Get-AnthropicTextFromResponse {
    param([object]$ResponseObject)

    $Text = ""

    if ($null -ne $ResponseObject.content) {
        foreach ($Item in $ResponseObject.content) {
            if ($null -ne $Item.text) {
                $Text += [string]$Item.text
            }
        }
    }

    return $Text
}

function Get-SectionAfterMarker {
    param(
        [string]$Text,
        [string]$StartMarker
    )

    $StartIndex = $Text.IndexOf($StartMarker)

    if ($StartIndex -lt 0) {
        return ""
    }

    $ContentStart = $StartIndex + $StartMarker.Length
    return $Text.Substring($ContentStart).Trim()
}

function Get-SectionBetweenMarkers {
    param(
        [string]$Text,
        [string]$StartMarker,
        [string]$EndMarker
    )

    $StartIndex = $Text.IndexOf($StartMarker)

    if ($StartIndex -lt 0) {
        return ""
    }

    $ContentStart = $StartIndex + $StartMarker.Length
    $EndIndex = $Text.IndexOf($EndMarker, $ContentStart)

    if ($EndIndex -lt 0) {
        return $Text.Substring($ContentStart).Trim()
    }

    return $Text.Substring($ContentStart, $EndIndex - $ContentStart).Trim()
}

function Remove-AccidentalImprovedPromptTail {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return ""
    }

    $Markers = @(
        "`r`n---IMPROVED_PROMPT---",
        "`n---IMPROVED_PROMPT---",
        "`r`n## Improved Prompt",
        "`n## Improved Prompt",
        "`r`nImproved Prompt:",
        "`nImproved Prompt:",
        "`r`n### Improved Prompt",
        "`n### Improved Prompt"
    )

    $CutIndex = -1

    foreach ($Marker in $Markers) {
        $Index = $Text.IndexOf($Marker)
        if ($Index -ge 0) {
            if ($CutIndex -lt 0 -or $Index -lt $CutIndex) {
                $CutIndex = $Index
            }
        }
    }

    if ($CutIndex -ge 0) {
        return $Text.Substring(0, $CutIndex).Trim()
    }

    return $Text.Trim()
}

function Try-ParseJsonText {
    param([string]$JsonText)

    $Result = $null

    if ([string]::IsNullOrWhiteSpace($JsonText)) {
        return $null
    }

    try {
        $Result = $JsonText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $StartIndex = $JsonText.IndexOf("{")
        $EndIndex = $JsonText.LastIndexOf("}")

        if ($StartIndex -ge 0 -and $EndIndex -gt $StartIndex) {
            $CleanJsonText = $JsonText.Substring($StartIndex, $EndIndex - $StartIndex + 1)

            try {
                $Result = $CleanJsonText | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                $Result = $null
            }
        }
    }

    return $Result
}

function Start-OpenAIAnswerJob {
    param(
        [string]$PromptText,
        [string]$Model,
        [string]$ApiKey,
        [string]$Url,
        [string]$Proxy,
        [int]$MaxTokens,
        [int]$TimeoutSec,
        [int]$Retries
    )

    $Job = Start-Job -Name "OpenAI_Answer" -ScriptBlock {
        param(
            [string]$PromptText,
            [string]$Model,
            [string]$ApiKey,
            [string]$Url,
            [string]$Proxy,
            [int]$MaxTokens,
            [int]$TimeoutSec,
            [int]$Retries
        )

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        function Get-OpenAIChatTextLocal {
            param([object]$ResponseObject)

            $Text = ""

            if ($null -ne $ResponseObject.choices) {
                foreach ($Choice in $ResponseObject.choices) {
                    if ($null -ne $Choice.message) {
                        if ($null -ne $Choice.message.content) {
                            $Text += [string]$Choice.message.content
                        }
                    }
                }
            }

            return $Text
        }

        function Get-HttpErrorBodyLocal {
            param([object]$ErrorRecord)

            $Body = ""

            try {
                if ($null -ne $ErrorRecord.Exception.Response) {
                    $Stream = $ErrorRecord.Exception.Response.GetResponseStream()
                    if ($null -ne $Stream) {
                        $Reader = New-Object System.IO.StreamReader($Stream)
                        $Body = $Reader.ReadToEnd()
                        $Reader.Close()
                    }
                }
            }
            catch {
                $Body = ""
            }

            return $Body
        }

        $Headers = @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type"  = "application/json"
        }

        $SystemPrompt = @"
You are an expert technical assistant.
Answer the user directly and practically.
For PowerShell, prefer Windows PowerShell 5.1 compatibility.
Use variables at the top of scripts.
Do not use a top-level param block.
Use if/else instead of ternary operators.
Use Try/Catch blocks.
Include cls at the beginning of complete PowerShell scripts.
For CSV export, never append Export-Csv after Format-Table. Export selected objects before formatting.
For Active Directory PowerShell:
- Do not build fragile Get-ADUser/Get-ADObject -Filter strings with quoted Boolean/date variables.
- Prefer simple server-side AD filters, for example: Get-ADUser -Filter 'Enabled -eq `$false'
- Apply date checks and complex conditions with Where-Object when safer.
- Wrap pipeline results with @() before using .Count.
- Treat a null LastLogonDate as never-logged-in using (`$null -eq `$_.LastLogonDate). In Windows PowerShell 5.1 `$null sorts as less than any value, so `$null -lt X and `$null -le X return `$true, while `$null -gt X and `$null -ge X return `$false; therefore a plain -lt cutoff filter INCLUDES null (never-logged-in) values - it does NOT drop them. Do not claim a -lt comparison excludes nulls; branch on (`$null -eq `$_.LastLogonDate) explicitly when you must treat them specially.
When the answer's correctness depends on a specific PowerShell behavior (for example how `$null compares with -lt, -gt, or -eq, or how an empty pipeline counts), do not only assert it in prose. Add a small runnable self-check in the script that prints the actual result, and write the self-check so it PASSES (prints a confirming OK message) for the TRUE PowerShell 5.1 behavior - never make its expected branch the wrong result, and never print an alarming "unexpected" or "investigate your environment" message for normal correct behavior.
For stale-account or auto-disable logic, put the brand-new-account guard (for example a WhenCreated check) in the script itself, not only in notes.
Before Export-Csv, make sure the destination folder exists and create it with New-Item if it is missing.
When creating an export or output folder, use New-Item -ItemType Directory -Force so that any missing parent folders are also created.
For Active Directory inventory or report objects, include the DistinguishedName property, because duplicate common names are common and the DistinguishedName uniquely identifies each account.
When the Active Directory query already restricts accounts to a single Enabled state (for example a disabled-only inventory), do not add an Enabled column to the report, because a constant column adds only noise.
In scripts intended for the ISE, use return instead of Exit so the host window is not closed.
Use clear steps and complete code when code is requested.
Use ASCII-only inside code blocks and PowerShell comments. Do not use box-drawing characters, decorative Unicode separator lines, smart quotes, en dash, or em dash. Use plain hyphen and comments like # ----------------------------.
Do not invent facts.
"@

        $BodyObject = [ordered]@{
            model    = $Model
            messages = @(
                [ordered]@{
                    role    = "system"
                    content = $SystemPrompt
                },
                [ordered]@{
                    role    = "user"
                    content = $PromptText
                }
            )
            max_tokens = $MaxTokens
        }

        $BodyJson = $BodyObject | ConvertTo-Json -Depth 20

        $Attempt = 0
        $LastError = ""
        $LastStatusCode = $null
        $RequestStarted = Get-Date

        while ($Attempt -le $Retries) {
            $Attempt++

            try {
                $Params = @{
                    Uri         = $Url
                    Method      = "Post"
                    Headers     = $Headers
                    Body        = $BodyJson
                    TimeoutSec  = $TimeoutSec
                    ErrorAction = "Stop"
                }

                if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
                    $Params.Proxy = $Proxy
                }

                $Response = Invoke-RestMethod @Params
                $Text = Get-OpenAIChatTextLocal -ResponseObject $Response

                $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

                $InputTokens = $null
                $OutputTokens = $null
                $TotalTokens = $null

                if ($null -ne $Response.usage) {
                    if ($null -ne $Response.usage.prompt_tokens) {
                        $InputTokens = $Response.usage.prompt_tokens
                    }
                    if ($null -ne $Response.usage.completion_tokens) {
                        $OutputTokens = $Response.usage.completion_tokens
                    }
                    if ($null -ne $Response.usage.total_tokens) {
                        $TotalTokens = $Response.usage.total_tokens
                    }
                }

                return [PSCustomObject]@{
                    Provider         = "OpenAI"
                    Model            = $Model
                    Success          = $true
                    Attempt          = $Attempt
                    DurationSeconds  = $DurationSeconds
                    StatusCode       = 200
                    InputTokens      = $InputTokens
                    OutputTokens     = $OutputTokens
                    TotalTokens      = $TotalTokens
                    EstimatedCostUsd = $null
                    Text             = $Text
                    Error            = ""
                    Raw              = $Response
                }
            }
            catch {
                $LastError = $_.Exception.Message

                $ErrorBody = Get-HttpErrorBodyLocal -ErrorRecord $_
                if (-not [string]::IsNullOrWhiteSpace($ErrorBody)) {
                    $LastError = $LastError + " | ResponseBody: " + $ErrorBody
                }

                $StatusCode = $null
                if ($null -ne $_.Exception.Response) {
                    try {
                        $StatusCode = [int]$_.Exception.Response.StatusCode
                        $LastStatusCode = $StatusCode
                    }
                    catch {
                        $StatusCode = $null
                    }
                }

                $ShouldRetry = $false

                if ($null -eq $StatusCode) {
                    $ShouldRetry = $true
                }
                else {
                    if ($StatusCode -eq 429 -or $StatusCode -eq 500 -or $StatusCode -eq 502 -or $StatusCode -eq 503 -or $StatusCode -eq 504) {
                        $ShouldRetry = $true
                    }
                }

                if ($ShouldRetry -eq $false) {
                    break
                }

                if ($Attempt -le $Retries) {
                    Start-Sleep -Seconds 2
                }
            }
        }

        $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

        return [PSCustomObject]@{
            Provider         = "OpenAI"
            Model            = $Model
            Success          = $false
            Attempt          = $Attempt
            DurationSeconds  = $DurationSeconds
            StatusCode       = $LastStatusCode
            InputTokens      = $null
            OutputTokens     = $null
            TotalTokens      = $null
            EstimatedCostUsd = $null
            Text             = ""
            Error            = $LastError
            Raw              = $null
        }

    } -ArgumentList $PromptText, $Model, $ApiKey, $Url, $Proxy, $MaxTokens, $TimeoutSec, $Retries

    return $Job
}

function Start-AnthropicAnswerJob {
    param(
        [string]$PromptText,
        [string]$Model,
        [string]$ApiKey,
        [string]$Url,
        [string]$Version,
        [string]$Proxy,
        [int]$MaxTokens,
        [int]$TimeoutSec,
        [int]$Retries
    )

    $Job = Start-Job -Name "Anthropic_Answer" -ScriptBlock {
        param(
            [string]$PromptText,
            [string]$Model,
            [string]$ApiKey,
            [string]$Url,
            [string]$Version,
            [string]$Proxy,
            [int]$MaxTokens,
            [int]$TimeoutSec,
            [int]$Retries
        )

        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

        function Get-AnthropicTextLocal {
            param([object]$ResponseObject)

            $Text = ""

            if ($null -ne $ResponseObject.content) {
                foreach ($Item in $ResponseObject.content) {
                    if ($null -ne $Item.text) {
                        $Text += [string]$Item.text
                    }
                }
            }

            return $Text
        }

        function Get-HttpErrorBodyLocal {
            param([object]$ErrorRecord)

            $Body = ""

            try {
                if ($null -ne $ErrorRecord.Exception.Response) {
                    $Stream = $ErrorRecord.Exception.Response.GetResponseStream()
                    if ($null -ne $Stream) {
                        $Reader = New-Object System.IO.StreamReader($Stream)
                        $Body = $Reader.ReadToEnd()
                        $Reader.Close()
                    }
                }
            }
            catch {
                $Body = ""
            }

            return $Body
        }

        $Headers = @{
            "x-api-key"         = $ApiKey
            "anthropic-version" = $Version
            "Content-Type"      = "application/json"
        }

        $SystemPrompt = @"
You are an expert technical assistant.
Answer the user directly and practically.
For PowerShell, prefer Windows PowerShell 5.1 compatibility.
Use variables at the top of scripts.
Do not use a top-level param block.
Use if/else instead of ternary operators.
Use Try/Catch blocks.
Include cls at the beginning of complete PowerShell scripts.
For CSV export, never append Export-Csv after Format-Table. Export selected objects before formatting.
For Active Directory PowerShell:
- Do not build fragile Get-ADUser/Get-ADObject -Filter strings with quoted Boolean/date variables.
- Prefer simple server-side AD filters, for example: Get-ADUser -Filter 'Enabled -eq `$false'
- Apply date checks and complex conditions with Where-Object when safer.
- Wrap pipeline results with @() before using .Count.
- Treat a null LastLogonDate as never-logged-in using (`$null -eq `$_.LastLogonDate). In Windows PowerShell 5.1 `$null sorts as less than any value, so `$null -lt X and `$null -le X return `$true, while `$null -gt X and `$null -ge X return `$false; therefore a plain -lt cutoff filter INCLUDES null (never-logged-in) values - it does NOT drop them. Do not claim a -lt comparison excludes nulls; branch on (`$null -eq `$_.LastLogonDate) explicitly when you must treat them specially.
When the answer's correctness depends on a specific PowerShell behavior (for example how `$null compares with -lt, -gt, or -eq, or how an empty pipeline counts), do not only assert it in prose. Add a small runnable self-check in the script that prints the actual result, and write the self-check so it PASSES (prints a confirming OK message) for the TRUE PowerShell 5.1 behavior - never make its expected branch the wrong result, and never print an alarming "unexpected" or "investigate your environment" message for normal correct behavior.
For stale-account or auto-disable logic, put the brand-new-account guard (for example a WhenCreated check) in the script itself, not only in notes.
Before Export-Csv, make sure the destination folder exists and create it with New-Item if it is missing.
When creating an export or output folder, use New-Item -ItemType Directory -Force so that any missing parent folders are also created.
For Active Directory inventory or report objects, include the DistinguishedName property, because duplicate common names are common and the DistinguishedName uniquely identifies each account.
When the Active Directory query already restricts accounts to a single Enabled state (for example a disabled-only inventory), do not add an Enabled column to the report, because a constant column adds only noise.
In scripts intended for the ISE, use return instead of Exit so the host window is not closed.
Use clear steps and complete code when code is requested.
Use ASCII-only inside code blocks and PowerShell comments. Do not use box-drawing characters, decorative Unicode separator lines, smart quotes, en dash, or em dash. Use plain hyphen and comments like # ----------------------------.
Do not invent facts.
"@

        $BodyObject = [ordered]@{
            model      = $Model
            max_tokens = $MaxTokens
            system     = $SystemPrompt
            messages   = @(
                [ordered]@{
                    role    = "user"
                    content = $PromptText
                }
            )
        }

        $BodyJson = $BodyObject | ConvertTo-Json -Depth 20

        $Attempt = 0
        $LastError = ""
        $LastStatusCode = $null
        $RequestStarted = Get-Date

        while ($Attempt -le $Retries) {
            $Attempt++

            try {
                $Params = @{
                    Uri         = $Url
                    Method      = "Post"
                    Headers     = $Headers
                    Body        = $BodyJson
                    TimeoutSec  = $TimeoutSec
                    ErrorAction = "Stop"
                }

                if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
                    $Params.Proxy = $Proxy
                }

                $Response = Invoke-RestMethod @Params
                $Text = Get-AnthropicTextLocal -ResponseObject $Response

                $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

                $InputTokens = $null
                $OutputTokens = $null
                $TotalTokens = $null

                if ($null -ne $Response.usage) {
                    if ($null -ne $Response.usage.input_tokens) {
                        $InputTokens = $Response.usage.input_tokens
                    }
                    if ($null -ne $Response.usage.output_tokens) {
                        $OutputTokens = $Response.usage.output_tokens
                    }
                    if ($null -ne $InputTokens -and $null -ne $OutputTokens) {
                        $TotalTokens = $InputTokens + $OutputTokens
                    }
                }

                return [PSCustomObject]@{
                    Provider         = "Anthropic"
                    Model            = $Model
                    Success          = $true
                    Attempt          = $Attempt
                    DurationSeconds  = $DurationSeconds
                    StatusCode       = 200
                    InputTokens      = $InputTokens
                    OutputTokens     = $OutputTokens
                    TotalTokens      = $TotalTokens
                    EstimatedCostUsd = $null
                    Text             = $Text
                    Error            = ""
                    Raw              = $Response
                }
            }
            catch {
                $LastError = $_.Exception.Message

                $ErrorBody = Get-HttpErrorBodyLocal -ErrorRecord $_
                if (-not [string]::IsNullOrWhiteSpace($ErrorBody)) {
                    $LastError = $LastError + " | ResponseBody: " + $ErrorBody
                }

                $StatusCode = $null
                if ($null -ne $_.Exception.Response) {
                    try {
                        $StatusCode = [int]$_.Exception.Response.StatusCode
                        $LastStatusCode = $StatusCode
                    }
                    catch {
                        $StatusCode = $null
                    }
                }

                $ShouldRetry = $false

                if ($null -eq $StatusCode) {
                    $ShouldRetry = $true
                }
                else {
                    if ($StatusCode -eq 429 -or $StatusCode -eq 500 -or $StatusCode -eq 502 -or $StatusCode -eq 503 -or $StatusCode -eq 504) {
                        $ShouldRetry = $true
                    }
                }

                if ($ShouldRetry -eq $false) {
                    break
                }

                if ($Attempt -le $Retries) {
                    Start-Sleep -Seconds 2
                }
            }
        }

        $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

        return [PSCustomObject]@{
            Provider         = "Anthropic"
            Model            = $Model
            Success          = $false
            Attempt          = $Attempt
            DurationSeconds  = $DurationSeconds
            StatusCode       = $LastStatusCode
            InputTokens      = $null
            OutputTokens     = $null
            TotalTokens      = $null
            EstimatedCostUsd = $null
            Text             = ""
            Error            = $LastError
            Raw              = $null
        }

    } -ArgumentList $PromptText, $Model, $ApiKey, $Url, $Version, $Proxy, $MaxTokens, $TimeoutSec, $Retries

    return $Job
}

function Invoke-AnthropicJudge {
    param(
        [string]$PromptText,
        [object[]]$AnswerResults,
        [string]$JudgeModel,
        [string]$ApiKey,
        [string]$Url,
        [string]$Version,
        [string]$Proxy,
        [int]$MaxTokens,
        [int]$TimeoutSec,
        [int]$Retries,
        [string]$Mode
    )

    $Headers = @{
        "x-api-key"         = $ApiKey
        "anthropic-version" = $Version
        "Content-Type"      = "application/json"
    }

    $AnswerBlock = ""
    $AnswerIndex = 0

    foreach ($Answer in $AnswerResults) {
        $AnswerIndex++
        $AnswerId = [char](64 + $AnswerIndex)

        $AnswerBlock += "`r`n--- ANSWER $AnswerId ---`r`n"
        $AnswerBlock += "Provider: " + $Answer.Provider + "`r`n"
        $AnswerBlock += "Model: " + $Answer.Model + "`r`n"
        $AnswerBlock += "Text:`r`n" + $Answer.Text + "`r`n"
    }

    if ($Mode -eq "Full") {
        $SystemPrompt = @"
You are the Judge and Final Synthesizer in a Multi-LLM Prompter.

You must:
1. Compare the candidate answers.
2. Score them.
3. Reuse only the strongest correct parts.
4. Produce a final answer.
5. Keep JSON small and clean.
6. Do NOT put Markdown, code blocks, or long text inside JSON.

Evaluation criteria:
- technical_correctness
- completeness
- clarity
- practical_usefulness
- security_or_risk
- fit_to_user_preferences

For PowerShell:
- prefer Windows PowerShell 5.1
- avoid a top-level param block
- use variables at the top
- use if/else
- include cls at script start
- use Try/Catch blocks
- provide complete runnable scripts when asked
- never suggest piping Format-Table output into Export-Csv
- if CSV export is mentioned, export selected objects before any Format-Table or formatting cmdlet
- for Active Directory PowerShell, do not use fragile -Filter strings with quoted Boolean/date variables
- prefer simple server-side AD filters, then apply date checks with Where-Object when safer
- wrap pipeline results with @() before using .Count
- if a variable receives pipeline output and the script later uses .Count on that variable, assign it as @(...)
- treat a null LastLogonDate as never-logged-in with (`$null -eq `$_.LastLogonDate). In Windows PowerShell 5.1 `$null sorts as less than any value, so `$null -lt and `$null -le return `$true while `$null -gt and `$null -ge return `$false; a plain -lt cutoff filter therefore INCLUDES null values and does not drop never-logged-in accounts. Reject any answer that claims a -lt comparison excludes nulls.
- when correctness depends on a specific PowerShell behavior (for example how `$null compares with -lt, -gt, or -eq), require a small runnable self-check in the final script that prints the actual result and is written to PASS for the true PowerShell 5.1 behavior; reject any self-check whose expected branch is the wrong result or that prints an "unexpected" / "investigate your environment" message for normal correct behavior
- for stale-account or auto-disable AD logic, require the brand-new-account guard (for example WhenCreated) inside the script, not only in notes
- before Export-Csv, ensure the destination folder exists and is created with New-Item if missing
- when creating an export or output folder, use New-Item -ItemType Directory -Force so missing parent folders are created too
- for Active Directory inventory or report output, include the DistinguishedName property, since duplicate common names are common and the DistinguishedName uniquely identifies each account
- when the Active Directory query already restricts accounts to a single Enabled state (for example a disabled-only inventory), do not add an Enabled column, since a constant column is only noise
- in scripts meant for the ISE, prefer return over Exit so the host is not closed
- for WPF/WinForms GUI scripts, prefer Always On Top, colored header area, minimum size, aligned layout, search box, refresh/export/exit actions, and double-click or button-based details view when relevant
- use ASCII-only inside code blocks and PowerShell comments; do not use box-drawing characters, decorative Unicode separator lines, smart quotes, en dash, or em dash; use plain hyphen and comments like # ----------------------------
"@
    }
    elseif ($Mode -eq "ReviewOnly") {
        $SystemPrompt = @"
You are the ReviewOnly Judge in a Multi-LLM Prompter.

You must:
1. Compare or validate the candidate answers.
2. Select the best answer ID in JSON.
3. Identify technical risks, missing pieces, and corrections.
4. Produce a concise review only.
5. Do NOT rewrite or regenerate full scripts, full WPF/XAML, or long code blocks.
6. Keep JSON small and clean.
7. Do NOT put Markdown, code blocks, or long text inside JSON.

For ReviewOnly mode, the engine may save the selected full answer separately. Your FINAL_ANSWER_MARKDOWN should contain only review notes, verdict, and recommended next changes.
Use ASCII-only text.
"@
    }
    else {
        $SystemPrompt = @"
You are the Light Judge and Final Polisher in a Multi-LLM Prompter.

Only one candidate answer is available.
You must:
1. Validate it.
2. Fix obvious technical or formatting problems.
3. Remove unsupported assumptions.
4. Produce a final answer.
5. Keep JSON small and clean.
6. Do NOT put Markdown, code blocks, or long text inside JSON.

Do not claim comparison was performed.

For PowerShell:
- prefer Windows PowerShell 5.1
- avoid a top-level param block
- use variables at the top
- use if/else
- include cls at script start
- use Try/Catch blocks
- provide complete runnable scripts when asked
- never suggest piping Format-Table output into Export-Csv
- if CSV export is mentioned, export selected objects before any Format-Table or formatting cmdlet
- for Active Directory PowerShell, do not use fragile -Filter strings with quoted Boolean/date variables
- prefer simple server-side AD filters, then apply date checks with Where-Object when safer
- wrap pipeline results with @() before using .Count
- if a variable receives pipeline output and the script later uses .Count on that variable, assign it as @(...)
- treat a null LastLogonDate as never-logged-in with (`$null -eq `$_.LastLogonDate). In Windows PowerShell 5.1 `$null sorts as less than any value, so `$null -lt and `$null -le return `$true while `$null -gt and `$null -ge return `$false; a plain -lt cutoff filter therefore INCLUDES null values and does not drop never-logged-in accounts. Reject any answer that claims a -lt comparison excludes nulls.
- when correctness depends on a specific PowerShell behavior (for example how `$null compares with -lt, -gt, or -eq), require a small runnable self-check in the final script that prints the actual result and is written to PASS for the true PowerShell 5.1 behavior; reject any self-check whose expected branch is the wrong result or that prints an "unexpected" / "investigate your environment" message for normal correct behavior
- for stale-account or auto-disable AD logic, require the brand-new-account guard (for example WhenCreated) inside the script, not only in notes
- before Export-Csv, ensure the destination folder exists and is created with New-Item if missing
- when creating an export or output folder, use New-Item -ItemType Directory -Force so missing parent folders are created too
- for Active Directory inventory or report output, include the DistinguishedName property, since duplicate common names are common and the DistinguishedName uniquely identifies each account
- when the Active Directory query already restricts accounts to a single Enabled state (for example a disabled-only inventory), do not add an Enabled column, since a constant column is only noise
- in scripts meant for the ISE, prefer return over Exit so the host is not closed
- for WPF/WinForms GUI scripts, prefer Always On Top, colored header area, minimum size, aligned layout, search box, refresh/export/exit actions, and double-click or button-based details view when relevant
- use ASCII-only inside code blocks and PowerShell comments; do not use box-drawing characters, decorative Unicode separator lines, smart quotes, en dash, or em dash; use plain hyphen and comments like # ----------------------------
"@
    }

    if ($Mode -eq "Full" -or ($Mode -eq "ReviewOnly" -and @($AnswerResults).Count -ge 2)) {
        $ScoresTemplate = @"
  "scores": {
    "A": {
      "technical_correctness": 1,
      "completeness": 1,
      "clarity": 1,
      "practical_usefulness": 1,
      "security_or_risk": 1,
      "fit_to_user_preferences": 1
    },
    "B": {
      "technical_correctness": 1,
      "completeness": 1,
      "clarity": 1,
      "practical_usefulness": 1,
      "security_or_risk": 1,
      "fit_to_user_preferences": 1
    }
  }
"@
        $BestAnswerHint = "A or B"
    }
    else {
        $ScoresTemplate = @"
  "scores": {
    "A": {
      "technical_correctness": 1,
      "completeness": 1,
      "clarity": 1,
      "practical_usefulness": 1,
      "security_or_risk": 1,
      "fit_to_user_preferences": 1
    }
  }
"@
        $BestAnswerHint = "A"
    }

    $UserJudgePrompt = @"
ORIGINAL USER PROMPT:
$PromptText

CANDIDATE ANSWERS:
$AnswerBlock

Return exactly in this format.
Do not omit any marker.

For final_answer_source, report the percentage of the FINAL answer text that came from each candidate answer (A and B). The two values must sum to 100. If only one candidate answer exists, set its value to 100 and the other to 0.

If mode is ReviewOnly, FINAL_ANSWER_MARKDOWN must be review-only: no full script, no full application, no long code block. Select best_answer_id in JSON and explain briefly why.

---JUDGE_JSON---
{
  "mode": "$Mode",
  "best_answer_id": "$BestAnswerHint",
  "confidence": 1,
$ScoresTemplate,
  "final_answer_source": {
    "A": 60,
    "B": 40
  },
  "problems_found": [
    "short problem text"
  ],
  "best_parts_reused": [
    "short reusable part"
  ]
}
---FINAL_ANSWER_MARKDOWN---
Write the final user-facing answer here in Markdown.
Markdown and code blocks are allowed here.
Do not mention candidate answers, Answer A, Answer B, Judge, scoring, comparison, or synthesis in this section.
This section must be suitable to show directly to the user as the final answer.

Important PowerShell CSV rule:
Never tell the user to add Export-Csv after Format-Table. If CSV export is needed, export selected objects before formatting.

Important Active Directory PowerShell rule:
Do not build fragile AD -Filter strings with quoted Boolean/date variables.
Prefer a simple server-side AD filter, then apply date checks and complex checks with Where-Object when safer.
If the script uses .Count on pipeline output, wrap the result with @(...).
If a variable receives pipeline output and the script later uses .Count on that variable, assign it as @(...).
Include the DistinguishedName property in Active Directory inventory or report objects, because duplicate common names are common.
When the query already restricts accounts to a single Enabled state, do not add a constant Enabled column.
When creating the export folder, use New-Item -ItemType Directory -Force so that missing parent folders are also created.

Important GUI rule:
For WPF/WinForms GUI scripts, prefer Always On Top, colored header area, minimum size, aligned layout, search box, refresh/export/exit actions, and double-click or button-based details view when relevant.

---IMPROVED_PROMPT---
Write a better version of the original prompt here.
If there is no better prompt, write: No improved prompt.
"@

    $BodyObject = [ordered]@{
        model      = $JudgeModel
        max_tokens = $MaxTokens
        system     = $SystemPrompt
        messages   = @(
            [ordered]@{
                role    = "user"
                content = $UserJudgePrompt
            }
        )
    }

    $BodyJson = $BodyObject | ConvertTo-Json -Depth 25

    $Attempt = 0
    $LastError = ""
    $LastStatusCode = $null
    $RequestStarted = Get-Date

    while ($Attempt -le $Retries) {
        $Attempt++

        try {
            $Params = @{
                Uri         = $Url
                Method      = "Post"
                Headers     = $Headers
                Body        = $BodyJson
                TimeoutSec  = $TimeoutSec
                ErrorAction = "Stop"
            }

            if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
                $Params.Proxy = $Proxy
            }

            $Response = Invoke-RestMethod @Params
            $Text = Get-AnthropicTextFromResponse -ResponseObject $Response

            $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

            $InputTokens = $null
            $OutputTokens = $null
            $TotalTokens = $null

            if ($null -ne $Response.usage) {
                if ($null -ne $Response.usage.input_tokens) {
                    $InputTokens = $Response.usage.input_tokens
                }
                if ($null -ne $Response.usage.output_tokens) {
                    $OutputTokens = $Response.usage.output_tokens
                }
                if ($null -ne $InputTokens -and $null -ne $OutputTokens) {
                    $TotalTokens = $InputTokens + $OutputTokens
                }
            }

            return [PSCustomObject]@{
                Provider         = "Anthropic"
                Model            = $JudgeModel
                Success          = $true
                Attempt          = $Attempt
                DurationSeconds  = $DurationSeconds
                StatusCode       = 200
                InputTokens      = $InputTokens
                OutputTokens     = $OutputTokens
                TotalTokens      = $TotalTokens
                EstimatedCostUsd = $null
                Mode             = $Mode
                Text             = $Text
                Error            = ""
                Raw              = $Response
            }
        }
        catch {
            $LastError = $_.Exception.Message

            $ErrorBody = Get-HttpErrorBody -ErrorRecord $_
            if (-not [string]::IsNullOrWhiteSpace($ErrorBody)) {
                $LastError = $LastError + " | ResponseBody: " + $ErrorBody
            }

            $StatusCode = $null
            if ($null -ne $_.Exception.Response) {
                try {
                    $StatusCode = [int]$_.Exception.Response.StatusCode
                    $LastStatusCode = $StatusCode
                }
                catch {
                    $StatusCode = $null
                }
            }

            $ShouldRetry = $false

            if ($null -eq $StatusCode) {
                $ShouldRetry = $true
            }
            else {
                if ($StatusCode -eq 429 -or $StatusCode -eq 500 -or $StatusCode -eq 502 -or $StatusCode -eq 503 -or $StatusCode -eq 504) {
                    $ShouldRetry = $true
                }
            }

            if ($ShouldRetry -eq $false) {
                break
            }

            if ($Attempt -le $Retries) {
                Start-Sleep -Seconds 2
            }
        }
    }

    $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

    return [PSCustomObject]@{
        Provider         = "Anthropic"
        Model            = $JudgeModel
        Success          = $false
        Attempt          = $Attempt
        DurationSeconds  = $DurationSeconds
        StatusCode       = $LastStatusCode
        InputTokens      = $null
        OutputTokens     = $null
        TotalTokens      = $null
        EstimatedCostUsd = $null
        Mode             = $Mode
        Text             = ""
        Error            = $LastError
        Raw              = $null
    }
}


# -----------------------------
# FINAL VERIFIER - v0.8.54 (distinct from the judge; opt-in)
# -----------------------------

# Independently checks ONE final answer against the original task. The HTTP/retry skeleton
# mirrors Invoke-AnthropicJudge exactly; only the prompts + marker differ. The verdict JSON
# is returned in .Text (parse it with Get-VerifierVerdict).
function Invoke-AnthropicVerifier {
    param(
        [string]$PromptText,
        [string]$FinalAnswer,
        [string]$VerifierModel,
        [string]$ApiKey,
        [string]$Url,
        [string]$Version,
        [string]$Proxy,
        [int]$MaxTokens,
        [int]$TimeoutSec,
        [int]$Retries
    )

    $Headers = @{
        "x-api-key"         = $ApiKey
        "anthropic-version" = $Version
        "Content-Type"      = "application/json"
    }

    $SystemPrompt = @"
You are the Final Verifier in a Multi-LLM Prompter. You are NOT the judge and you do not
rewrite the answer. You independently check ONE final answer against the original task.

Check for:
1. technical correctness - does it actually do what the task asked, without errors
2. completeness - are all parts of the task covered
3. unsupported claims - statements asserted as fact that are not justified
4. PowerShell 5.1 / Active Directory pitfalls, including:
   - never piping Format-Table output into Export-Csv
   - wrapping pipeline output with @() before using .Count
   - treating a null LastLogonDate as never-logged-in with (`$null -eq `$_.LastLogonDate); in
     Windows PowerShell 5.1 `$null sorts as less than any value, so `$null -lt and `$null -le
     return `$true and a plain -lt cutoff filter INCLUDES nulls (it does NOT drop never-logged-in
     accounts) - flag any claim that -lt excludes nulls
   - including DistinguishedName in Active Directory inventory output
   - creating output folders with New-Item -ItemType Directory -Force
   - using return rather than Exit in ISE scripts
   - ASCII-only output

Return ONLY the marker and a single small clean JSON object. No Markdown, no code blocks,
no text outside the JSON. Use ASCII only.

---VERIFIER_JSON---
{
  "verified": true,
  "confidence": "high",
  "issues": ["short issue text"],
  "unsupported_claims": ["short claim text"],
  "missing_points": ["short missing item"],
  "summary": "one short sentence"
}
"@

    $UserPrompt = @"
ORIGINAL TASK:
$PromptText

FINAL ANSWER TO VERIFY:
$FinalAnswer

Return exactly the ---VERIFIER_JSON--- marker followed by the JSON object described above.
Set "verified" to false if there is any real correctness or completeness problem. Keep every
list short and use empty lists when there is nothing to report.
"@

    $BodyObject = [ordered]@{
        model      = $VerifierModel
        max_tokens = $MaxTokens
        system     = $SystemPrompt
        messages   = @(
            [ordered]@{
                role    = "user"
                content = $UserPrompt
            }
        )
    }

    $BodyJson = $BodyObject | ConvertTo-Json -Depth 25

    $Attempt = 0
    $LastError = ""
    $LastStatusCode = $null
    $RequestStarted = Get-Date

    while ($Attempt -le $Retries) {
        $Attempt++

        try {
            $Params = @{
                Uri         = $Url
                Method      = "Post"
                Headers     = $Headers
                Body        = $BodyJson
                TimeoutSec  = $TimeoutSec
                ErrorAction = "Stop"
            }

            if (-not [string]::IsNullOrWhiteSpace($Proxy)) {
                $Params.Proxy = $Proxy
            }

            $Response = Invoke-RestMethod @Params
            $Text = Get-AnthropicTextFromResponse -ResponseObject $Response

            $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

            $InputTokens = $null
            $OutputTokens = $null
            $TotalTokens = $null

            if ($null -ne $Response.usage) {
                if ($null -ne $Response.usage.input_tokens) { $InputTokens = $Response.usage.input_tokens }
                if ($null -ne $Response.usage.output_tokens) { $OutputTokens = $Response.usage.output_tokens }
                if ($null -ne $InputTokens -and $null -ne $OutputTokens) { $TotalTokens = $InputTokens + $OutputTokens }
            }

            return [PSCustomObject]@{
                Provider         = "Anthropic"
                Model            = $VerifierModel
                Success          = $true
                Attempt          = $Attempt
                DurationSeconds  = $DurationSeconds
                StatusCode       = 200
                InputTokens      = $InputTokens
                OutputTokens     = $OutputTokens
                TotalTokens      = $TotalTokens
                EstimatedCostUsd = $null
                Mode             = "Verifier"
                Text             = $Text
                Error            = ""
                Raw              = $Response
            }
        }
        catch {
            $LastError = $_.Exception.Message

            $ErrorBody = Get-HttpErrorBody -ErrorRecord $_
            if (-not [string]::IsNullOrWhiteSpace($ErrorBody)) {
                $LastError = $LastError + " | ResponseBody: " + $ErrorBody
            }

            $StatusCode = $null
            if ($null -ne $_.Exception.Response) {
                try {
                    $StatusCode = [int]$_.Exception.Response.StatusCode
                    $LastStatusCode = $StatusCode
                }
                catch {
                    $StatusCode = $null
                }
            }

            $ShouldRetry = $false
            if ($null -eq $StatusCode) {
                $ShouldRetry = $true
            }
            else {
                if ($StatusCode -eq 429 -or $StatusCode -eq 500 -or $StatusCode -eq 502 -or $StatusCode -eq 503 -or $StatusCode -eq 504) {
                    $ShouldRetry = $true
                }
            }

            if ($ShouldRetry -eq $false) { break }
            if ($Attempt -le $Retries) { Start-Sleep -Seconds 2 }
        }
    }

    $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)

    return [PSCustomObject]@{
        Provider         = "Anthropic"
        Model            = $VerifierModel
        Success          = $false
        Attempt          = $Attempt
        DurationSeconds  = $DurationSeconds
        StatusCode       = $LastStatusCode
        InputTokens      = $null
        OutputTokens     = $null
        TotalTokens      = $null
        EstimatedCostUsd = $null
        Mode             = "Verifier"
        Text             = ""
        Error            = $LastError
        Raw              = $null
    }
}

# Parse the verifier's ---VERIFIER_JSON--- block defensively into a normalized verdict.
function Get-VerifierVerdict {
    param([string]$Text)

    $Result = [PSCustomObject]@{
        verified           = $null
        confidence         = ""
        issues             = @()
        unsupported_claims = @()
        missing_points     = @()
        summary            = ""
        parsed             = $false
    }

    if ([string]::IsNullOrWhiteSpace($Text)) { return $Result }

    $Json = $Text
    $Marker = "---VERIFIER_JSON---"
    $Idx = $Text.IndexOf($Marker)
    if ($Idx -ge 0) { $Json = $Text.Substring($Idx + $Marker.Length) }
    $Json = $Json.Trim()

    # Trim to the outermost JSON object if there is any wrapping text.
    $Start = $Json.IndexOf("{")
    $End = $Json.LastIndexOf("}")
    if ($Start -ge 0 -and $End -gt $Start) { $Json = $Json.Substring($Start, $End - $Start + 1) }

    try {
        $Obj = $Json | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $Result
    }

    if ($null -ne $Obj) {
        $Result.parsed = $true
        if ($null -ne $Obj.verified) { $Result.verified = [bool]$Obj.verified }
        if ($null -ne $Obj.confidence) { $Result.confidence = [string]$Obj.confidence }
        if ($null -ne $Obj.issues) { $Result.issues = @($Obj.issues) }
        if ($null -ne $Obj.unsupported_claims) { $Result.unsupported_claims = @($Obj.unsupported_claims) }
        if ($null -ne $Obj.missing_points) { $Result.missing_points = @($Obj.missing_points) }
        if ($null -ne $Obj.summary) { $Result.summary = [string]$Obj.summary }
    }
    return $Result
}

# -----------------------------
# TASK PIPELINE FUNCTIONS - v0.8.52
# -----------------------------

function Invoke-TaskPipeline {
    param(
        [object]$Task,
        [string]$ParentRunFolder
    )

    $TaskStarted = Get-Date
    $StageMetrics = @()
    $RequestMetrics = @()

    $TaskFolderName = "Task_" + ("{0:00}" -f [int]$Task.TaskId)
    $TaskFolder = Join-Path $ParentRunFolder $TaskFolderName

    $StageStarted = Get-Date
    if ($KeepTaskSubfolders -eq $true) {
        New-Item -ItemType Directory -Path $TaskFolder -Force | Out-Null
    }
    else {
        $TaskFolder = $ParentRunFolder
    }
    Save-Text -Path (Join-Path $TaskFolder "input_prompt.txt") -Text $Task.PromptText
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_PrepareFolderAndInput" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details $TaskFolder

    Write-Step ("Task " + $Task.TaskId + ": Routing")
    $StageStarted = Get-Date
    $TaskType = Get-TaskType -PromptText $Task.PromptText
    $TypeOverrideApplied = $false
    $TypeOverrideRaw = ""
    if ($Task.PSObject.Properties.Name -contains "TypeOverride") { $TypeOverrideRaw = [string]$Task.TypeOverride }
    if (-not [string]::IsNullOrWhiteSpace($TypeOverrideRaw)) {
        $ValidTaskTypes = @("simple", "technical", "code", "ui_code", "documentation", "creative")
        if ($ValidTaskTypes -contains $TypeOverrideRaw) {
            $TaskType = $TypeOverrideRaw
            $TypeOverrideApplied = $true
        }
        else {
            Write-Color ("Ignoring invalid task type override '" + $TypeOverrideRaw + "' (allowed: " + ($ValidTaskTypes -join ", ") + ")") "Yellow"
        }
    }
    $WorkModeOverrideClean = ""
    $WorkModeOverrideRaw = ""
    if ($Task.PSObject.Properties.Name -contains "WorkModeOverride") { $WorkModeOverrideRaw = [string]$Task.WorkModeOverride }
    if (-not [string]::IsNullOrWhiteSpace($WorkModeOverrideRaw)) {
        if ($WorkModeOverrideRaw -eq "Review" -or $WorkModeOverrideRaw -eq "Script") {
            $WorkModeOverrideClean = $WorkModeOverrideRaw
        }
        else {
            Write-Color ("Ignoring invalid work mode override '" + $WorkModeOverrideRaw + "' (allowed: Review, Script)") "Yellow"
        }
    }
    $RouterDecision = Get-RouterDecision -PromptText $Task.PromptText -TaskType $TaskType -WorkModeOverride $WorkModeOverrideClean
    Save-Json -Path (Join-Path $TaskFolder "router_decision.json") -Object $RouterDecision
    $EffectivePromptText = Get-EffectivePromptForWorkMode -PromptText $Task.PromptText -TaskType $TaskType -WorkMode $RouterDecision.WorkMode
    Save-Text -Path (Join-Path $TaskFolder "effective_prompt.txt") -Text $EffectivePromptText
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Routing" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("TaskType=" + $RouterDecision.TaskType + "; WorkMode=" + $RouterDecision.WorkMode + "; JudgeModePolicy=" + $RouterDecision.JudgeModePolicy + "; Route=" + $RouterDecision.Reason)

    Write-Color ("Task type: " + $RouterDecision.TaskType) "Green"
    Write-Color ("Work mode: " + $RouterDecision.WorkMode) "Green"
    Write-Color ("Judge policy: " + $RouterDecision.JudgeModePolicy) "Green"
    Write-Color ("Route: " + $RouterDecision.Reason) "Green"
    Write-Color ("Per-model timeout: " + $RouterDecision.PerModelTimeoutSec + " sec") "Gray"
    Write-Color ("Answer max tokens: " + $RouterDecision.MaxAnswerTokens + "; Judge max tokens: " + $RouterDecision.MaxJudgeTokens) "Gray"
    if ($TypeOverrideApplied -eq $true) { Write-Color ("NOTE: task type set by GUI override -> " + $TaskType + " (changes which models/judge run; check cost)") "Yellow" }
    if ($RouterDecision.WorkModeOverrideApplied -eq $true) { Write-Color ("NOTE: work mode set by GUI override -> " + $RouterDecision.WorkMode) "Yellow" }

    $StageStarted = Get-Date
    $MissingInputCheck = Test-TaskMissingRequiredInput -PromptText $Task.PromptText -TaskType $TaskType
    Save-Json -Path (Join-Path $TaskFolder "missing_input_check.json") -Object $MissingInputCheck
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_MissingInputPreCheck" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("Missing=" + $MissingInputCheck.Missing + "; Reason=" + $MissingInputCheck.Reason)

    if ($SkipMissingInputTasks -eq $true -and $MissingInputCheck.Missing -eq $true) {
        Write-Color ("Missing input detected: " + $MissingInputCheck.Reason) "Yellow"

        $MissingFinalAnswer = @"
This task was skipped before calling AI models because required source content was not provided.

Reason: $($MissingInputCheck.Reason)

Provide the missing email/document/text content and run the task again.
"@

        $TaskFinalMarkdown = @"
# Multi-LLM Prompter $ToolVersion - Task $($Task.TaskId) Missing Input

## Task

$($Task.PromptText)

## Router

Task type: $($RouterDecision.TaskType)

Work mode: $($RouterDecision.WorkMode)

Judge policy: $($RouterDecision.JudgeModePolicy)

Route: Skipped before AI requests - missing input.

## Full Answer

$MissingFinalAnswer

## Improved Prompt

Paste the source content directly under this task, then ask for the summary/review again.
"@

        Save-Text -Path (Join-Path $TaskFolder "final_answer.md") -Text $TaskFinalMarkdown
        Save-Json -Path (Join-Path $TaskFolder "answers_raw.json") -Object @()
        Save-Json -Path (Join-Path $TaskFolder "errors.json") -Object @()

        $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Total" -StartTime $TaskStarted -EndTime (Get-Date) -Success $true -Details "MissingInput skipped before AI requests."
        if ($ExportRunMetricsCsv -eq $true) {
            Export-MetricCollection -MetricCollection @() -Path (Join-Path $TaskFolder "run_metrics.csv")
            Export-MetricCollection -MetricCollection $StageMetrics -Path (Join-Path $TaskFolder "stage_metrics.csv")
            Export-MetricCollection -MetricCollection @() -Path (Join-Path $TaskFolder "request_metrics.csv")
        }

        return [PSCustomObject]@{
            TaskId         = $Task.TaskId
            TaskTitle      = $Task.TaskTitle
            TaskType       = $TaskType
            WorkMode       = $RouterDecision.WorkMode
            RouterDecision = $RouterDecision
            TaskFolder     = $TaskFolder
            Success        = $true
            Error          = "MissingInput: " + $MissingInputCheck.Reason
            AnswerCount    = 0
            JudgeMode      = "Skipped"
            JudgeModelUsed = ""
            JudgeResult    = $null
            JudgeJson      = $null
            FinalAnswer    = $MissingFinalAnswer
            ImprovedPrompt = "Paste the missing source content and run the task again."
            RunMetrics     = @()
            RequestMetrics = @()
            StageMetrics   = $StageMetrics
            Errors         = @()
        }
    }

    Write-Step ("Task " + $Task.TaskId + ": Starting answer model jobs")

    $StageStarted = Get-Date
    $Jobs = @()

    # Personas: prepend the per-model persona preamble to a COPY of the effective prompt. The shared
    # $EffectivePromptText is never mutated, so the Judge (and effective_prompt.txt) stay persona-free.
    # Off mode -> both preambles are empty -> $PromptForA / $PromptForB equal $EffectivePromptText.
    $PreambleA = Get-PersonaPreamble -PersonaKey $PersonaA
    $PreambleB = Get-PersonaPreamble -PersonaKey $PersonaB
    $PromptForA = $EffectivePromptText
    $PromptForB = $EffectivePromptText
    if (-not [string]::IsNullOrWhiteSpace($PreambleA)) { $PromptForA = $PreambleA + "`r`n`r`n" + $EffectivePromptText }
    if (-not [string]::IsNullOrWhiteSpace($PreambleB)) { $PromptForB = $PreambleB + "`r`n`r`n" + $EffectivePromptText }
    if ($PersonaMode -eq "Fixed") {
        Write-Color ("Personas (Fixed): Answer A = " + $PersonaA + " | Answer B = " + $PersonaB) "Cyan"
    }

    if ($RouterDecision.UseOpenAI -eq $true) {
        $Jobs += Start-LLMJob `
            -Provider "OpenAI" `
            -Role "Answer" `
            -PromptText $PromptForA `
            -Model $OpenAIModel_Answer `
            -TimeoutSec $RouterDecision.PerModelTimeoutSec `
            -MaxTokens $RouterDecision.MaxAnswerTokens
    }

    if ($RouterDecision.UseAnthropicAnswer -eq $true) {
        $Jobs += Start-LLMJob `
            -Provider "Anthropic" `
            -Role "Answer" `
            -PromptText $PromptForB `
            -Model $AnthropicModel_Answer `
            -TimeoutSec $RouterDecision.PerModelTimeoutSec `
            -MaxTokens $RouterDecision.MaxAnswerTokens
    }

    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_StartAnswerJobs" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("JobsStarted=" + @($Jobs).Count)

    $StageStarted = Get-Date
    $WaitStarted = Get-Date

    while ($true) {
        $CompletedCount = 0

        foreach ($Job in $Jobs) {
            if ($Job.State -eq "Completed" -or $Job.State -eq "Failed" -or $Job.State -eq "Stopped") {
                $CompletedCount++
            }
        }

        $Elapsed = ((Get-Date) - $WaitStarted).TotalSeconds

        if ($CompletedCount -eq $Jobs.Count) {
            break
        }

        if ($Elapsed -ge $RouterDecision.TotalRequestTimeoutSec) {
            Write-Color ("Total answer timeout reached (" + $RouterDecision.TotalRequestTimeoutSec + " sec). Stopping unfinished answer jobs.") "Yellow"
            foreach ($Job in $Jobs) {
                if ($Job.State -eq "Running") {
                    Stop-Job -Job $Job -Force
                }
            }
            break
        }

        Start-Sleep -Milliseconds 500
    }

    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_WaitForAnswerJobs" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("Jobs=" + @($Jobs).Count)

    Write-Step ("Task " + $Task.TaskId + ": Collecting answer results")

    $StageStarted = Get-Date
    $AnswerResults = @()
    $ErrorResults = @()

    foreach ($Job in $Jobs) {
        try {
            $JobResult = Receive-Job -Job $Job -ErrorAction Stop
            Remove-Job -Job $Job -Force

            if ($null -ne $JobResult) {
                $JobResult = Update-ResultCostEstimate -Result $JobResult

                if ($JobResult.Success -eq $true -and -not [string]::IsNullOrWhiteSpace($JobResult.Text)) {
                    $AnswerResults += $JobResult
                    Write-Color ("$($JobResult.Provider) / $($JobResult.Model): OK") "Green"
                }
                else {
                    $ErrorResults += $JobResult
                    Write-Color ("$($JobResult.Provider) / $($JobResult.Model): FAILED - $($JobResult.Error)") "Red"
                }
            }
        }
        catch {
            $ErrorResults += [PSCustomObject]@{
                Provider         = $Job.Name
                Model            = ""
                Success          = $false
                Attempt          = 0
                DurationSeconds  = $null
                StatusCode       = $null
                InputTokens      = $null
                OutputTokens     = $null
                TotalTokens      = $null
                EstimatedCostUsd = $null
                Text             = ""
                Error            = $_.Exception.Message
                Raw              = $null
            }

            Write-Color ("$($Job.Name): FAILED - $($_.Exception.Message)") "Red"

            try {
                Remove-Job -Job $Job -Force
            }
            catch {
            }
        }
    }

    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_CollectAnswerResults" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("Answers=" + @($AnswerResults).Count + "; Errors=" + @($ErrorResults).Count)

    Save-Json -Path (Join-Path $TaskFolder "answers_raw.json") -Object $AnswerResults
    Save-Json -Path (Join-Path $TaskFolder "errors.json") -Object $ErrorResults

    $RunMetrics = @()

    foreach ($AnswerMetricSource in $AnswerResults) {
        $RunMetrics += Get-RunMetricObject -Result $AnswerMetricSource -Role "Answer"
        $RequestMetrics += New-RequestMetricObject -Result $AnswerMetricSource -Role "Answer" -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -RequestName ("Task_" + $Task.TaskId + "_Answer_" + $AnswerMetricSource.Provider) -StageName "AI_AnswerRequest"
    }

    foreach ($ErrorMetricSource in $ErrorResults) {
        $RunMetrics += Get-RunMetricObject -Result $ErrorMetricSource -Role "Answer"
        $RequestMetrics += New-RequestMetricObject -Result $ErrorMetricSource -Role "Answer" -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -RequestName ("Task_" + $Task.TaskId + "_Answer_" + $ErrorMetricSource.Provider) -StageName "AI_AnswerRequest"
    }

    if ($ExportRunMetricsCsv -eq $true) {
        $RunMetricsPath = Join-Path $TaskFolder "run_metrics.csv"
        $RunMetrics | Export-Csv -Path $RunMetricsPath -NoTypeInformation -Encoding UTF8 -Force
        Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
    }

    $StageStarted = Get-Date
    $AnswerIndex = 0
    foreach ($Answer in $AnswerResults) {
        $AnswerIndex++
        $AnswerId = [char](64 + $AnswerIndex)
        $AnswerPath = Join-Path $TaskFolder ("answer_" + $AnswerId + "_" + $Answer.Provider + ".md")
        Save-Text -Path $AnswerPath -Text $Answer.Text
    }
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_SaveAnswerFiles" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("AnswerFiles=" + $AnswerIndex)

    if ($AnswerResults.Count -eq 0) {
        $Summary = @"
# Multi-LLM Prompter $ToolVersion - Task Error Summary

Task $($Task.TaskId): $($Task.TaskTitle)

No answer model returned usable text.

See:
- errors.json
- console_transcript.txt

Task folder:
$TaskFolder
"@

        $ErrorSummaryPath = Join-Path $TaskFolder "final_answer.md"
        Save-Text -Path $ErrorSummaryPath -Text $Summary

        $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Total" -StartTime $TaskStarted -EndTime (Get-Date) -Success $false -Details "No answer model returned usable text."
        if ($ExportRunMetricsCsv -eq $true) {
            Export-MetricCollection -MetricCollection $StageMetrics -Path (Join-Path $TaskFolder "stage_metrics.csv")
            Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
        }

        return [PSCustomObject]@{
            TaskId         = $Task.TaskId
            TaskTitle      = $Task.TaskTitle
            TaskType       = $TaskType
            WorkMode       = $RouterDecision.WorkMode
            RouterDecision = $RouterDecision
            TaskFolder     = $TaskFolder
            Success        = $false
            Error          = "No answer model returned usable text."
            AnswerCount    = 0
            JudgeMode      = "None"
            JudgeResult    = $null
            JudgeJson      = $null
            FinalAnswer    = $Summary
            ImprovedPrompt = ""
            RunMetrics     = $RunMetrics
            RequestMetrics = $RequestMetrics
            StageMetrics   = $StageMetrics
            Errors         = $ErrorResults
        }
    }

    if ($RouterDecision.UseJudge -ne $true) {
        Write-Step ("Task " + $Task.TaskId + ": Skipping Judge by routing policy")

        $StageStarted = Get-Date
        $FinalAnswer = $AnswerResults[0].Text
        $ImprovedPrompt = "No improved prompt. Judge skipped by routing policy."

        $TaskFinalMarkdown = @"
# Multi-LLM Prompter $ToolVersion - Task $($Task.TaskId) Full Answer

## Task

$($Task.PromptText)

## Router

Task type: $($RouterDecision.TaskType)

Work mode: $($RouterDecision.WorkMode)

Judge policy: $($RouterDecision.JudgeModePolicy)

Route: $($RouterDecision.Reason)

## Models Used

Answer models returned: $($AnswerResults.Count)

Judge mode: Skipped

Judge model: Not used

## Full Answer

$FinalAnswer

## Improved Prompt

$ImprovedPrompt
"@

        $FinalPath = Join-Path $TaskFolder "final_answer.md"
        Save-Text -Path $FinalPath -Text $TaskFinalMarkdown
        $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_SkipJudgeByPolicy" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "Judge skipped by router policy."
        $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Total" -StartTime $TaskStarted -EndTime (Get-Date) -Success $true -Details ("Answers=" + $AnswerResults.Count + "; JudgeMode=Skipped")

        if ($ExportRunMetricsCsv -eq $true) {
            Export-MetricCollection -MetricCollection $StageMetrics -Path (Join-Path $TaskFolder "stage_metrics.csv")
            Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
        }

        return [PSCustomObject]@{
            TaskId         = $Task.TaskId
            TaskTitle      = $Task.TaskTitle
            TaskType       = $TaskType
            WorkMode       = $RouterDecision.WorkMode
            RouterDecision = $RouterDecision
            TaskFolder     = $TaskFolder
            Success        = $true
            Error          = ""
            AnswerCount    = $AnswerResults.Count
            JudgeMode      = "Skipped"
            JudgeModelUsed = ""
            JudgeResult    = $null
            JudgeJson      = $null
            FinalAnswer    = $FinalAnswer
            ImprovedPrompt = $ImprovedPrompt
            RunMetrics     = $RunMetrics
            RequestMetrics = $RequestMetrics
            StageMetrics   = $StageMetrics
            Errors         = $ErrorResults
        }
    }

    Write-Step ("Task " + $Task.TaskId + ": Running Judge + Final")

    $JudgeMode = "Light"
    if ($AnswerResults.Count -ge 2) {
        $JudgeMode = "Full"
    }
    if ($RouterDecision.JudgeModePolicy -eq "ReviewOnly") {
        $JudgeMode = "ReviewOnly"
    }

    # v0.8.52 judge policy: Full comparison ALWAYS uses the strong judge, regardless of the
    # GUI judge selection or the cheap-judge toggle. Light and ReviewOnly may use the cheap
    # judge when the toggle is on; otherwise they use the selected judge.
    if ($JudgeMode -eq "Full") {
        $JudgeModelToUse = $AnthropicModel_JudgeStrong
        if ($AnthropicModel_Judge -ne $AnthropicModel_JudgeStrong) {
            Write-Color ("[WARN] Full Judge requires the strong judge. Selected judge '" + $AnthropicModel_Judge + "' is ignored for Full mode; using '" + $AnthropicModel_JudgeStrong + "'.") "Yellow"
        }
    }
    else {
        $JudgeModelToUse = $AnthropicModel_Judge
        if ($UseCheapJudgeForReview -eq $true) {
            $JudgeModelToUse = $AnthropicModel_JudgeCheap
        }
    }

    $StageStarted = Get-Date
    $JudgeResult = Invoke-LLMChat `
        -Provider $JudgeProvider `
        -Role "Judge" `
        -PromptText $EffectivePromptText `
        -AnswerResults $AnswerResults `
        -Mode $JudgeMode `
        -MaxTokens $RouterDecision.MaxJudgeTokens `
        -Model $JudgeModelToUse

    $JudgeResult = Update-ResultCostEstimate -Result $JudgeResult
    $JudgeModelUsed = $JudgeModelToUse
    if (-not [string]::IsNullOrWhiteSpace($JudgeResult.Model)) {
        $JudgeModelUsed = $JudgeResult.Model
    }
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_JudgeRequest" -StartTime $StageStarted -EndTime (Get-Date) -Success $JudgeResult.Success -Details ("JudgeMode=" + $JudgeMode + "; Provider=" + $JudgeResult.Provider + "; Model=" + $JudgeResult.Model)

    Save-Json -Path (Join-Path $TaskFolder "judge_raw.json") -Object $JudgeResult

    $RunMetrics += Get-RunMetricObject -Result $JudgeResult -Role "Judge"
    $RequestMetrics += New-RequestMetricObject -Result $JudgeResult -Role "Judge" -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -RequestName ("Task_" + $Task.TaskId + "_Judge_" + $JudgeResult.Provider) -StageName "AI_JudgeRequest"

    if ($ExportRunMetricsCsv -eq $true) {
        $RunMetricsPath = Join-Path $TaskFolder "run_metrics.csv"
        $RunMetrics | Export-Csv -Path $RunMetricsPath -NoTypeInformation -Encoding UTF8 -Force
        Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
    }

    if ($JudgeResult.Success -eq $false) {
        Write-Color ("Judge failed: " + $JudgeResult.Error) "Red"

        $FallbackText = @"
# Multi-LLM Prompter $ToolVersion - Task Fallback Full Answer

Task $($Task.TaskId): $($Task.TaskTitle)

Judge failed, so the first successful model answer is returned as fallback.

## Provider

$($AnswerResults[0].Provider)

## Model

$($AnswerResults[0].Model)

## Answer

$($AnswerResults[0].Text)
"@

        $FinalPath = Join-Path $TaskFolder "final_answer.md"
        Save-Text -Path $FinalPath -Text $FallbackText

        $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Total" -StartTime $TaskStarted -EndTime (Get-Date) -Success $true -Details "Judge failed; fallback used."
        if ($ExportRunMetricsCsv -eq $true) {
            Export-MetricCollection -MetricCollection $StageMetrics -Path (Join-Path $TaskFolder "stage_metrics.csv")
            Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
        }

        return [PSCustomObject]@{
            TaskId         = $Task.TaskId
            TaskTitle      = $Task.TaskTitle
            TaskType       = $TaskType
            WorkMode       = $RouterDecision.WorkMode
            RouterDecision = $RouterDecision
            TaskFolder     = $TaskFolder
            Success        = $true
            Error          = "Judge failed; fallback used."
            AnswerCount    = $AnswerResults.Count
            JudgeMode      = $JudgeMode
            JudgeModelUsed = $JudgeModelUsed
            JudgeResult    = $JudgeResult
            JudgeJson      = $null
            FinalAnswer    = $AnswerResults[0].Text
            ImprovedPrompt = ""
            RunMetrics     = $RunMetrics
            RequestMetrics = $RequestMetrics
            StageMetrics   = $StageMetrics
            Errors         = $ErrorResults
        }
    }

    $StageStarted = Get-Date
    $JudgeTextPath = Join-Path $TaskFolder "judge_text.txt"
    Save-Text -Path $JudgeTextPath -Text $JudgeResult.Text

    $JudgeJsonText = Get-SectionBetweenMarkers `
        -Text $JudgeResult.Text `
        -StartMarker "---JUDGE_JSON---" `
        -EndMarker "---FINAL_ANSWER_MARKDOWN---"

    $FinalAnswer = Get-SectionBetweenMarkers `
        -Text $JudgeResult.Text `
        -StartMarker "---FINAL_ANSWER_MARKDOWN---" `
        -EndMarker "---IMPROVED_PROMPT---"

    $FinalAnswer = Remove-AccidentalImprovedPromptTail -Text $FinalAnswer

    $ImprovedPrompt = Get-SectionAfterMarker `
        -Text $JudgeResult.Text `
        -StartMarker "---IMPROVED_PROMPT---"

    Save-Text -Path (Join-Path $TaskFolder "judge_scores_text.json") -Text $JudgeJsonText

    $JudgeJson = Try-ParseJsonText -JsonText $JudgeJsonText
    Save-Json -Path (Join-Path $TaskFolder "judge_parsed.json") -Object $JudgeJson

    if ([string]::IsNullOrWhiteSpace($FinalAnswer)) {
        Write-Color "Final answer marker was not found. Saving raw Judge text as fallback." "Yellow"
        $FinalAnswer = $JudgeResult.Text
    }

    if ($JudgeMode -eq "ReviewOnly") {
        $BestAnswerId = "A"
        try {
            if ($null -ne $JudgeJson.best_answer_id) {
                $BestAnswerId = [string]$JudgeJson.best_answer_id
            }
        }
        catch {
            $BestAnswerId = "A"
        }

        $SelectedAnswer = Get-AnswerById -AnswerResults $AnswerResults -AnswerId $BestAnswerId
        if ($null -eq $SelectedAnswer) {
            $SelectedAnswer = $AnswerResults[0]
            $BestAnswerId = "A"
        }

        $SelectedAnswerPath = Join-Path $TaskFolder "selected_answer.md"
        Save-Text -Path $SelectedAnswerPath -Text $SelectedAnswer.Text

        if ($RouterDecision.WorkMode -eq "Script") {
            if ($TaskType -eq "ui_code") {
                $FinalAnswer = @"
Selected full script/code answer: $SelectedAnswerPath

Review notes:

$FinalAnswer

The full selected script is saved separately to avoid another expensive Judge rewrite and to prevent final-answer truncation.
"@
            }
            else {
                $FinalAnswer = @"
Selected answer ($BestAnswerId):

$($SelectedAnswer.Text)

Review notes:

$FinalAnswer
"@
            }
        }
    }

    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_ParseJudgeOutput" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "Parsed judge text and markers."

    $StageStarted = Get-Date
    $TaskFinalMarkdown = @"
# Multi-LLM Prompter $ToolVersion - Task $($Task.TaskId) Full Answer

## Task

$($Task.PromptText)

## Router

Task type: $($RouterDecision.TaskType)

Work mode: $($RouterDecision.WorkMode)

Judge policy: $($RouterDecision.JudgeModePolicy)

Route: $($RouterDecision.Reason)

## Models Used

Answer models returned: $($AnswerResults.Count)

Judge mode: $JudgeMode

Judge model: $JudgeModelToUse

## Full Answer

$FinalAnswer

## Improved Prompt

$ImprovedPrompt
"@

    $FinalPath = Join-Path $TaskFolder "final_answer.md"
    Save-Text -Path $FinalPath -Text $TaskFinalMarkdown
    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_WriteFinalFiles" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details $FinalPath

    $StageMetrics += New-StageMetric -TaskId $Task.TaskId -TaskTitle $Task.TaskTitle -StageName "Task_Total" -StartTime $TaskStarted -EndTime (Get-Date) -Success $true -Details ("Answers=" + $AnswerResults.Count + "; JudgeMode=" + $JudgeMode)

    if ($ExportRunMetricsCsv -eq $true) {
        Export-MetricCollection -MetricCollection $StageMetrics -Path (Join-Path $TaskFolder "stage_metrics.csv")
        Export-MetricCollection -MetricCollection $RequestMetrics -Path (Join-Path $TaskFolder "request_metrics.csv")
    }

    $Verdict = Get-JudgeVerdict -JudgeJson $JudgeJson

    return [PSCustomObject]@{
        TaskId         = $Task.TaskId
        TaskTitle      = $Task.TaskTitle
        TaskType       = $TaskType
        WorkMode       = $RouterDecision.WorkMode
        RouterDecision = $RouterDecision
        TaskFolder     = $TaskFolder
        Success        = $true
        Error          = ""
        AnswerCount    = $AnswerResults.Count
        JudgeMode      = $JudgeMode
        JudgeModelUsed = $JudgeModelUsed
        JudgeResult    = $JudgeResult
        JudgeJson      = $JudgeJson
        BestAnswerId   = $Verdict.BestAnswerId
        JudgeConfidence = $Verdict.Confidence
        ShareA         = $Verdict.ShareA
        ShareB         = $Verdict.ShareB
        ScoreA         = $Verdict.ScoreA
        ScoreB         = $Verdict.ScoreB
        ReusedParts    = $Verdict.ReusedParts
        FinalAnswer    = $FinalAnswer
        ImprovedPrompt = $ImprovedPrompt
        RunMetrics     = $RunMetrics
        RequestMetrics = $RequestMetrics
        StageMetrics   = $StageMetrics
        Errors         = $ErrorResults
    }
}

# -----------------------------
# Judge verdict helpers (v0.8.52) - read-only summary of the judge JSON for the report.
function Get-JudgeScoreAverage {
    param($ScoreObj)
    if ($null -eq $ScoreObj) { return "" }
    $Vals = @()
    foreach ($P in @("technical_correctness","completeness","clarity","practical_usefulness","security_or_risk","fit_to_user_preferences")) {
        try {
            $Cell = $ScoreObj.$P
            if ($null -ne $Cell) { $Vals += [double]$Cell }
        }
        catch {
        }
    }
    if (@($Vals).Count -eq 0) { return "" }
    $Avg = ($Vals | Measure-Object -Average).Average
    return ("{0:0.0}" -f $Avg)
}

function Get-JudgeVerdict {
    param($JudgeJson)
    $V = [PSCustomObject]@{
        BestAnswerId = ""
        Confidence   = ""
        ShareA       = ""
        ShareB       = ""
        ScoreA       = ""
        ScoreB       = ""
        ReusedParts  = ""
    }
    if ($null -eq $JudgeJson) { return $V }
    try { if ($null -ne $JudgeJson.best_answer_id) { $V.BestAnswerId = [string]$JudgeJson.best_answer_id } } catch { }
    try { if ($null -ne $JudgeJson.confidence) { $V.Confidence = [string]$JudgeJson.confidence } } catch { }
    $A = $null
    $B = $null
    try {
        if ($null -ne $JudgeJson.final_answer_source) {
            if ($null -ne $JudgeJson.final_answer_source.A) { $A = [double]$JudgeJson.final_answer_source.A }
            if ($null -ne $JudgeJson.final_answer_source.B) { $B = [double]$JudgeJson.final_answer_source.B }
        }
    }
    catch {
    }
    if (($null -ne $A) -or ($null -ne $B)) {
        if ($null -eq $A) { $A = 0 }
        if ($null -eq $B) { $B = 0 }
        $Sum = $A + $B
        if ($Sum -gt 0) {
            $PctA = [int][Math]::Round(($A / $Sum) * 100)
            if ($PctA -lt 0) { $PctA = 0 }
            if ($PctA -gt 100) { $PctA = 100 }
            $V.ShareA = $PctA
            $V.ShareB = 100 - $PctA
        }
    }
    try { $V.ScoreA = Get-JudgeScoreAverage -ScoreObj $JudgeJson.scores.A } catch { }
    try { $V.ScoreB = Get-JudgeScoreAverage -ScoreObj $JudgeJson.scores.B } catch { }
    try {
        if ($null -ne $JudgeJson.best_parts_reused) {
            $Parts = @()
            foreach ($Item in @($JudgeJson.best_parts_reused)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$Item)) { $Parts += [string]$Item }
            }
            if (@($Parts).Count -gt 0) { $V.ReusedParts = ($Parts -join "; ") }
        }
    }
    catch {
    }
    return $V
}

function Format-JudgeVerdictBlock {
    param($TaskResult)
    if ($null -eq $TaskResult) { return "" }
    $Best = ""
    try { $Best = [string]$TaskResult.BestAnswerId } catch { }
    $ShareA = ""
    try { $ShareA = [string]$TaskResult.ShareA } catch { }
    $ShareB = ""
    try { $ShareB = [string]$TaskResult.ShareB } catch { }
    $ScoreA = ""
    try { $ScoreA = [string]$TaskResult.ScoreA } catch { }
    $ScoreB = ""
    try { $ScoreB = [string]$TaskResult.ScoreB } catch { }
    $Conf = ""
    try { $Conf = [string]$TaskResult.JudgeConfidence } catch { }
    $Reused = ""
    try { $Reused = [string]$TaskResult.ReusedParts } catch { }
    $HasVerdict = $false
    if (-not [string]::IsNullOrWhiteSpace($Best)) { $HasVerdict = $true }
    if (-not [string]::IsNullOrWhiteSpace($ShareA)) { $HasVerdict = $true }
    if (-not $HasVerdict) { return "" }
    $Lines = @()
    $Lines += "=== Judge verdict ==="
    $BetterLine = "Better answer : " + $Best
    if (-not [string]::IsNullOrWhiteSpace($Conf)) { $BetterLine += "  (confidence " + $Conf + ")" }
    $Lines += $BetterLine
    if (-not [string]::IsNullOrWhiteSpace($ShareA)) {
        $PctA = 0
        $PctB = 0
        try { $PctA = [int]$ShareA } catch { }
        if (-not [string]::IsNullOrWhiteSpace($ShareB)) { try { $PctB = [int]$ShareB } catch { } }
        $FillA = [int][Math]::Round($PctA / 10)
        if ($FillA -lt 0) { $FillA = 0 }
        if ($FillA -gt 10) { $FillA = 10 }
        $FillB = [int][Math]::Round($PctB / 10)
        if ($FillB -lt 0) { $FillB = 0 }
        if ($FillB -gt 10) { $FillB = 10 }
        $BarA = ("#" * $FillA) + (" " * (10 - $FillA))
        $BarB = ("#" * $FillB) + (" " * (10 - $FillB))
        $Lines += "Composition   : A " + ("{0,3}" -f $PctA) + "%  [" + $BarA + "]"
        $Lines += "                B " + ("{0,3}" -f $PctB) + "%  [" + $BarB + "]"
    }
    if ((-not [string]::IsNullOrWhiteSpace($ScoreA)) -or (-not [string]::IsNullOrWhiteSpace($ScoreB))) {
        $Lines += "Scores (avg)  : A " + $ScoreA + "   B " + $ScoreB
    }
    if (-not [string]::IsNullOrWhiteSpace($Reused)) {
        $Lines += "Reused parts  : " + $Reused
    }
    return (($Lines -join [Environment]::NewLine) + [Environment]::NewLine + [Environment]::NewLine)
}

# MAIN - PIPELINE MODE
# -----------------------------

if ($Script:RunPipelineMode -eq $true) {

$PipelineStarted = Get-Date
$PipelineStageMetrics = @()
$AllRequestMetrics = @()

Write-Header "Multi-LLM Prompter $ToolVersion"

Write-Color "Run folder: $RunFolder" "Gray"
Write-Color "OpenAI answer model: $OpenAIModel_Answer" "Gray"
Write-Color "Claude answer model: $AnthropicModel_Answer" "Gray"
Write-Color "Claude judge model : $AnthropicModel_Judge" "Gray"
Write-Color "OpenAI endpoint   : $OpenAIBaseUrl" "Gray"
Write-Color "Config file       : $ConfigPath" "Gray"
Write-Color "Task splitter     : $TaskSplitterMode" "Gray"
Write-Color "Task work mode    : $TaskWorkMode" "Gray"
Write-Color "UI auto mode      : $UiCodeAutoWorkMode" "Gray"
Write-Color "Prompt preset     : $PromptPreset" "Gray"
if ($RunFinalVerifier -eq $true) { Write-Color "Final verifier    : ENABLED (independent post-pass check after the judge)" "Green" }

$StageStarted = Get-Date
Test-ScriptSecretExposure
Initialize-ApiKeys
Test-ApiKeys
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_InitializeAndValidate" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "Secrets and API key validation completed."

$StageStarted = Get-Date
Save-Text -Path (Join-Path $RunFolder "input_prompt.txt") -Text $UserPrompt
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_SaveInputPrompt" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "input_prompt.txt"

Write-Step "Splitting prompt into tasks"
$StageStarted = Get-Date
$TasksInputFile = $env:MULTILLM_TASKS_FILE
$Tasks = @()
if ((-not [string]::IsNullOrWhiteSpace($TasksInputFile)) -and (Test-Path -LiteralPath $TasksInputFile)) {
    Try {
        $RawTasksInput = Get-Content -LiteralPath $TasksInputFile -Raw -ErrorAction Stop
        $ParsedTasksInput = $RawTasksInput | ConvertFrom-Json -ErrorAction Stop
        $ExplicitId = 0
        foreach ($Ti in @($ParsedTasksInput)) {
            $TiText = ""
            if ($null -ne $Ti.PromptText) { $TiText = [string]$Ti.PromptText }
            if ([string]::IsNullOrWhiteSpace($TiText)) { continue }
            $ExplicitId++
            $TiTitle = Get-TaskTitleFromText -Text $TiText
            if ($null -ne $Ti.TaskTitle) {
                if (-not [string]::IsNullOrWhiteSpace([string]$Ti.TaskTitle)) { $TiTitle = [string]$Ti.TaskTitle }
            }
            $TiTypeOverride = ""
            if ($null -ne $Ti.TypeOverride) { $TiTypeOverride = [string]$Ti.TypeOverride }
            $TiWorkModeOverride = ""
            if ($null -ne $Ti.WorkModeOverride) { $TiWorkModeOverride = [string]$Ti.WorkModeOverride }
            $Tasks += [PSCustomObject]@{
                TaskId     = $ExplicitId
                TaskTitle  = $TiTitle
                PromptText = $TiText.Trim()
                SplitMode  = "Explicit"
                WasSplit   = $true
                TypeOverride = $TiTypeOverride
                WorkModeOverride = $TiWorkModeOverride
            }
        }
        Write-Color ("Loaded " + @($Tasks).Count + " task(s) from the GUI task list: " + $TasksInputFile) "Green"
    }
    Catch {
        Write-Color ("Failed to read GUI task list, using the splitter instead: " + $_.Exception.Message) "Yellow"
        $Tasks = @()
    }
}
if (@($Tasks).Count -eq 0) {
    $Tasks = @(Split-UserPromptIntoTasks -PromptText $UserPrompt -Mode $TaskSplitterMode -MaxTasks $MaxTasksPerPrompt)
}
Save-Json -Path (Join-Path $RunFolder "tasks.json") -Object $Tasks
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_SplitPromptIntoTasks" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("Tasks=" + $Tasks.Count + "; Mode=" + $TaskSplitterMode)

Write-Color ("Tasks detected: " + $Tasks.Count) "Green"
foreach ($Task in $Tasks) {
    Write-Color ("Task " + $Task.TaskId + ": " + (Get-ShortText -Text $Task.TaskTitle -MaxLength 120)) "Gray"
}

$TaskResults = @()
$AllRunMetrics = @()
$AllErrors = @()

$StageStarted = Get-Date
foreach ($Task in $Tasks) {
    $TaskResult = Invoke-TaskPipeline -Task $Task -ParentRunFolder $RunFolder

    $CompletenessCheck = Test-FinalAnswerCompleteness -Text $TaskResult.FinalAnswer
    $TaskResult | Add-Member -MemberType NoteProperty -Name CompletenessWarning -Value $CompletenessCheck.Warning -Force
    $TaskResult | Add-Member -MemberType NoteProperty -Name CompletenessReason -Value $CompletenessCheck.Reason -Force

    if ($CompletenessCheck.Warning -eq $true) {
        Write-Color ("Task " + $TaskResult.TaskId + " completeness warning: " + $CompletenessCheck.Reason) "Yellow"
    }

    $TaskResults += $TaskResult

    foreach ($Metric in @($TaskResult.RunMetrics)) {
        $Metric | Add-Member -MemberType NoteProperty -Name TaskId -Value $TaskResult.TaskId -Force
        $Metric | Add-Member -MemberType NoteProperty -Name TaskTitle -Value $TaskResult.TaskTitle -Force
        $AllRunMetrics += $Metric
    }

    foreach ($RequestMetric in @($TaskResult.RequestMetrics)) {
        $AllRequestMetrics += $RequestMetric
    }

    foreach ($TaskStageMetric in @($TaskResult.StageMetrics)) {
        $PipelineStageMetrics += $TaskStageMetric
    }

    foreach ($TaskError in @($TaskResult.Errors)) {
        $TaskError | Add-Member -MemberType NoteProperty -Name TaskId -Value $TaskResult.TaskId -Force
        $TaskError | Add-Member -MemberType NoteProperty -Name TaskTitle -Value $TaskResult.TaskTitle -Force
        $AllErrors += $TaskError
    }
}
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_RunAllTasks" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("TaskResults=" + $TaskResults.Count)

$StageStarted = Get-Date
if ($ExportRunMetricsCsv -eq $true) {
    $RunMetricsPath = Join-Path $RunFolder "run_metrics.csv"
    $AllRunMetrics | Export-Csv -Path $RunMetricsPath -NoTypeInformation -Encoding UTF8 -Force

    $RequestMetricsPath = Join-Path $RunFolder "request_metrics.csv"
    Export-MetricCollection -MetricCollection $AllRequestMetrics -Path $RequestMetricsPath
}

Save-Json -Path (Join-Path $RunFolder "errors.json") -Object $AllErrors
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_WriteRawMetricsAndErrors" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "run_metrics.csv, request_metrics.csv, errors.json"

$StageStarted = Get-Date
$TaskSummary = @()
foreach ($TaskResult in $TaskResults) {
    $TaskReqMetrics = @($AllRequestMetrics | Where-Object { $_.TaskId -eq $TaskResult.TaskId })
    $TaskInputTokens = 0
    $TaskOutputTokens = 0
    $TaskTotalTokens = 0
    $TaskCost = 0.0
    foreach ($Rm in $TaskReqMetrics) {
        if ($null -ne $Rm.InputTokens) { $TaskInputTokens += [int]$Rm.InputTokens }
        if ($null -ne $Rm.OutputTokens) { $TaskOutputTokens += [int]$Rm.OutputTokens }
        if ($null -ne $Rm.TotalTokens) { $TaskTotalTokens += [int]$Rm.TotalTokens }
        if ($null -ne $Rm.EstimatedCostUsd) { $TaskCost += [double]$Rm.EstimatedCostUsd }
    }

    $TaskSummary += [PSCustomObject]@{
        TaskId      = $TaskResult.TaskId
        TaskTitle   = $TaskResult.TaskTitle
        TaskType    = $TaskResult.TaskType
        WorkMode    = $TaskResult.WorkMode
        Success     = $TaskResult.Success
        AnswerCount = $TaskResult.AnswerCount
        JudgeMode   = $TaskResult.JudgeMode
        JudgeModelUsed = $TaskResult.JudgeModelUsed
        CompletenessWarning = $TaskResult.CompletenessWarning
        CompletenessReason  = $TaskResult.CompletenessReason
        InputTokens      = $TaskInputTokens
        OutputTokens     = $TaskOutputTokens
        TotalTokens      = $TaskTotalTokens
        EstimatedCostUsd = [Math]::Round($TaskCost, 6)
        TaskFolder  = $TaskResult.TaskFolder
        Error       = $TaskResult.Error
    }
}

Save-Json -Path (Join-Path $RunFolder "task_results_summary.json") -Object $TaskSummary
$TaskSummaryMarkdown = New-TaskSummaryMarkdown -TaskSummary $TaskSummary
Save-Text -Path (Join-Path $RunFolder "task_results_summary.md") -Text $TaskSummaryMarkdown
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_BuildTaskSummary" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "task_results_summary.json/md"

# v0.8.54: Final verifier post-pass (verifier != judge). OFF unless $RunFinalVerifier is true,
# so default behavior is byte-identical. Runs AFTER the judge has produced every per-task final
# answer; it independently checks each final answer and writes Task_NN\final_verification.json
# plus a run-level final_verification_summary.json.
if ($RunFinalVerifier -eq $true) {
    Write-Step "Running final verifier (independent check; verifier is not the judge)"
    $StageStarted = Get-Date
    $VerifierModelToUse = $VerifierModel
    if ([string]::IsNullOrWhiteSpace($VerifierModelToUse)) { $VerifierModelToUse = $AnthropicModel_JudgeStrong }
    $VerifierSummaryRows = @()
    foreach ($Tr in $TaskResults) {
        $Tf = [string]$Tr.TaskFolder
        if ([string]::IsNullOrWhiteSpace($Tf) -or -not (Test-Path -LiteralPath $Tf)) { continue }
        $TfFinal = Join-Path $Tf "final_answer.md"
        if (-not (Test-Path -LiteralPath $TfFinal)) { continue }
        $FinalText = [System.IO.File]::ReadAllText($TfFinal)
        $OrigPrompt = ""
        $TfPrompt = Join-Path $Tf "input_prompt.txt"
        if (Test-Path -LiteralPath $TfPrompt) { $OrigPrompt = [System.IO.File]::ReadAllText($TfPrompt) }

        $VerifierResult = Invoke-AnthropicVerifier `
            -PromptText $OrigPrompt `
            -FinalAnswer $FinalText `
            -VerifierModel $VerifierModelToUse `
            -ApiKey $AnthropicApiKey `
            -Url $AnthropicBaseUrl `
            -Version $AnthropicVersion `
            -Proxy $ProxyUrl `
            -MaxTokens $VerifierMaxTokens `
            -TimeoutSec $JudgeTimeoutSec `
            -Retries $MaxRetries

        $VerifierResult = Update-ResultCostEstimate -Result $VerifierResult

        # v0.8.69: count the verifier's API call in the run-level cost/token totals. It is appended to
        # $AllRequestMetrics with Role "Verifier" so CostByRole, CostByModel, AiRequestCount, the token
        # totals, and the timing EstimatedCostUsd (all built after this post-pass) include it instead of
        # the verifier cost silently dropping out of the headline total. Per-task TaskSummary (built
        # before this pass) keeps the answer+judge production cost; the new Verifier role accounts for
        # the rest, so total = sum(per-task) + Verifier. Cost math (Get-EstimatedCostUsd) is unchanged.
        $AllRequestMetrics += New-RequestMetricObject -Result $VerifierResult -Role "Verifier" -TaskId $Tr.TaskId -TaskTitle $Tr.TaskTitle -RequestName ("Task_" + $Tr.TaskId + "_Verifier_" + $VerifierResult.Provider) -StageName "AI_VerifierRequest"

        $Verdict = Get-VerifierVerdict -Text $VerifierResult.Text
        $IssueCount = @($Verdict.issues).Count

        Save-Json -Path (Join-Path $Tf "final_verification.json") -Object ([PSCustomObject]@{
            TaskId            = $Tr.TaskId
            Model             = $VerifierResult.Model
            Success           = $VerifierResult.Success
            Verified          = $Verdict.verified
            Confidence        = $Verdict.confidence
            Issues            = $Verdict.issues
            UnsupportedClaims = $Verdict.unsupported_claims
            MissingPoints     = $Verdict.missing_points
            Summary           = $Verdict.summary
            InputTokens       = $VerifierResult.InputTokens
            OutputTokens      = $VerifierResult.OutputTokens
            EstimatedCostUsd  = $VerifierResult.EstimatedCostUsd
            Error             = $VerifierResult.Error
        })

        $VerifierSummaryRows += [PSCustomObject]@{
            TaskId           = $Tr.TaskId
            Verified         = $Verdict.verified
            Confidence       = $Verdict.confidence
            IssueCount       = $IssueCount
            Model            = $VerifierResult.Model
            EstimatedCostUsd = $VerifierResult.EstimatedCostUsd
            Success          = $VerifierResult.Success
        }

        $VerColor = "Yellow"
        if ($VerifierResult.Success -eq $true -and $Verdict.verified -eq $true) { $VerColor = "Green" }
        elseif ($VerifierResult.Success -ne $true) { $VerColor = "Red" }
        Write-Color ("Task " + $Tr.TaskId + " verifier: verified=" + $Verdict.verified + "; confidence=" + $Verdict.confidence + "; issues=" + $IssueCount + "; model=" + $VerifierResult.Model) $VerColor
    }
    Save-Json -Path (Join-Path $RunFolder "final_verification_summary.json") -Object $VerifierSummaryRows
    $PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_FinalVerifier" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details ("Verified tasks=" + @($VerifierSummaryRows).Count)
}

$StageStarted = Get-Date
$MergedFinal = ""
if ($TaskResults.Count -eq 1) {
    $SingleVerdict = Format-JudgeVerdictBlock -TaskResult $TaskResults[0]
    $MergedFinal = $SingleVerdict + $TaskResults[0].FinalAnswer.Trim()
}
else {
    $PromptIndex = 0
    $PromptTotal = $TaskResults.Count
    foreach ($TaskResult in $TaskResults) {
        $PromptIndex += 1
        if ($PromptIndex -gt 1) {
            $MergedFinal += "`r`n`r`n---`r`n`r`n"
        }
        $MergedFinal += "## Prompt " + $PromptIndex + " of " + $PromptTotal + ": " + $TaskResult.TaskTitle + "`r`n`r`n"
        $MergedFinal += Format-JudgeVerdictBlock -TaskResult $TaskResult
        $MergedFinal += $TaskResult.FinalAnswer.Trim() + "`r`n"
    }
    $MergedFinal = $MergedFinal.Trim()
}

$ImprovedPromptCombined = ""
$ImpIndex = 0
foreach ($TaskResult in $TaskResults) {
    $ImpIndex += 1
    if ($ImpIndex -gt 1) {
        $ImprovedPromptCombined += "`r`n---`r`n"
    }
    $ImprovedPromptCombined += "`r`n### Prompt " + $ImpIndex + " - " + $TaskResult.TaskTitle + "`r`n"

    if (-not [string]::IsNullOrWhiteSpace($TaskResult.ImprovedPrompt)) {
        $ImprovedPromptCombined += $TaskResult.ImprovedPrompt.Trim() + "`r`n"
    }
    else {
        $ImprovedPromptCombined += "No improved prompt returned for this task. Original task prompt:" + "`r`n" + $TaskResult.TaskTitle + "`r`n"
    }
}
$ImprovedPromptCombined = $ImprovedPromptCombined.Trim()

if ([string]::IsNullOrWhiteSpace($ImprovedPromptCombined)) {
    $ImprovedPromptCombined = "No improved prompt."
}
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_MergeFinalAnswer" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details "Merged final answer and improved prompt."

# v0.8.52: read-only routing notes for the report. Does not change Get-TaskWorkMode routing;
# it only describes the resolved decision and which keywords were present in the task prompt.
$RoutingNotesLines = @()
foreach ($TaskResult in $TaskResults) {
    $RTType = $TaskResult.TaskType
    $RTWork = $TaskResult.WorkMode
    $RTJudge = $TaskResult.JudgeMode
    $RTJudgeModel = $TaskResult.JudgeModelUsed
    $RTReason = "WorkMode forced by Work mode = " + $TaskWorkMode
    if ($TaskWorkMode -eq "Auto") {
        if ($RTWork -eq "Script") {
            $RTLower = ([string]$TaskResult.TaskTitle).ToLower()
            $RTMatched = @()
            foreach ($Kw in @("correction","fix","safe powershell","powershell 5.1 correction","propose a safe","complete script","runnable script","create script","write script","function","wpf","xaml")) {
                if ($RTLower.Contains($Kw)) { $RTMatched += $Kw }
            }
            if ($RTMatched.Count -gt 0) {
                $RTReason = "Auto: promoted to Script (matched: " + ((@($RTMatched) | Select-Object -Unique) -join ", ") + ")"
            }
            else {
                $RTReason = "Auto: resolved to Script"
            }
        }
        else {
            $RTReason = "Auto: resolved to Review"
        }
    }
    $RoutingNotesLines += "- Task " + $TaskResult.TaskId + " (" + $RTType + "): WorkMode=" + $RTWork + ", Judge=" + $RTJudge + " (" + $RTJudgeModel + ")" + " -- " + $RTReason
}
$RoutingNotesMarkdown = ($RoutingNotesLines -join "`r`n")
if ([string]::IsNullOrWhiteSpace($RoutingNotesMarkdown)) {
    $RoutingNotesMarkdown = "No routing notes."
}

$TotalAiRequestSeconds = 0.0
$TotalEstimatedCostUsd = 0.0
$TotalInputTokens = 0
$TotalOutputTokens = 0
$TotalTokens = 0
foreach ($RequestMetric in @($AllRequestMetrics)) {
    if ($null -ne $RequestMetric.DurationSeconds) {
        $TotalAiRequestSeconds += [double]$RequestMetric.DurationSeconds
    }
    if ($null -ne $RequestMetric.EstimatedCostUsd) {
        $TotalEstimatedCostUsd += [double]$RequestMetric.EstimatedCostUsd
    }
    if ($null -ne $RequestMetric.InputTokens) {
        $TotalInputTokens += [int]$RequestMetric.InputTokens
    }
    if ($null -ne $RequestMetric.OutputTokens) {
        $TotalOutputTokens += [int]$RequestMetric.OutputTokens
    }
    if ($null -ne $RequestMetric.TotalTokens) {
        $TotalTokens += [int]$RequestMetric.TotalTokens
    }
}

$CostByRole = @()
$KnownRoles = @("Answer", "Judge")
# v0.8.69: show a Verifier role only when the final verifier actually ran, so an off-by-default
# verifier never adds a $0 row, but an enabled verifier's cost is visible alongside Answer/Judge.
if (@($AllRequestMetrics | Where-Object { $_.Role -eq "Verifier" }).Count -gt 0) { $KnownRoles += "Verifier" }
foreach ($RoleName in $KnownRoles) {
    $RoleMetrics = @($AllRequestMetrics | Where-Object { $_.Role -eq $RoleName })
    $RoleDuration = 0.0
    $RoleCost = 0.0
    $RoleInputTokens = 0
    $RoleOutputTokens = 0
    $RoleTotalTokens = 0

    foreach ($RoleMetric in $RoleMetrics) {
        if ($null -ne $RoleMetric.DurationSeconds) { $RoleDuration += [double]$RoleMetric.DurationSeconds }
        if ($null -ne $RoleMetric.EstimatedCostUsd) { $RoleCost += [double]$RoleMetric.EstimatedCostUsd }
        if ($null -ne $RoleMetric.InputTokens) { $RoleInputTokens += [int]$RoleMetric.InputTokens }
        if ($null -ne $RoleMetric.OutputTokens) { $RoleOutputTokens += [int]$RoleMetric.OutputTokens }
        if ($null -ne $RoleMetric.TotalTokens) { $RoleTotalTokens += [int]$RoleMetric.TotalTokens }
    }

    $CostByRole += [PSCustomObject]@{
        Role = $RoleName
        RequestCount = $RoleMetrics.Count
        DurationSeconds = [Math]::Round($RoleDuration, 3)
        InputTokens = $RoleInputTokens
        OutputTokens = $RoleOutputTokens
        TotalTokens = $RoleTotalTokens
        EstimatedCostUsd = [Math]::Round($RoleCost, 6)
    }
}

$CostByRoleMarkdown = "| Role | Requests | Seconds | Input tokens | Output tokens | Total tokens | Estimated cost USD |`r`n"
$CostByRoleMarkdown += "|---|---:|---:|---:|---:|---:|---:|`r`n"
foreach ($CostItem in $CostByRole) {
    $CostByRoleMarkdown += "| $($CostItem.Role) | $($CostItem.RequestCount) | $($CostItem.DurationSeconds) | $($CostItem.InputTokens) | $($CostItem.OutputTokens) | $($CostItem.TotalTokens) | $($CostItem.EstimatedCostUsd) |`r`n"
}
$CostByRoleMarkdown = $CostByRoleMarkdown.Trim()

$CostByModel = @()
$ModelKeys = @(
    @($AllRequestMetrics | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Model) } | ForEach-Object { $_.Provider + "|" + $_.Model }) |
    Sort-Object -Unique
)

foreach ($ModelKey in $ModelKeys) {
    $ModelParts = $ModelKey.Split("|", 2)
    $ModelProvider = $ModelParts[0]
    $ModelName = $ModelParts[1]
    $ModelMetrics = @(
        $AllRequestMetrics | Where-Object {
            $_.Provider -eq $ModelProvider -and $_.Model -eq $ModelName
        }
    )

    $ModelDuration = 0.0
    $ModelCost = 0.0
    $ModelInputTokens = 0
    $ModelOutputTokens = 0
    $ModelTotalTokens = 0
    $ModelRoles = @()

    foreach ($ModelMetric in $ModelMetrics) {
        if ($null -ne $ModelMetric.DurationSeconds) { $ModelDuration += [double]$ModelMetric.DurationSeconds }
        if ($null -ne $ModelMetric.EstimatedCostUsd) { $ModelCost += [double]$ModelMetric.EstimatedCostUsd }
        if ($null -ne $ModelMetric.InputTokens) { $ModelInputTokens += [int]$ModelMetric.InputTokens }
        if ($null -ne $ModelMetric.OutputTokens) { $ModelOutputTokens += [int]$ModelMetric.OutputTokens }
        if ($null -ne $ModelMetric.TotalTokens) { $ModelTotalTokens += [int]$ModelMetric.TotalTokens }
        if (-not [string]::IsNullOrWhiteSpace($ModelMetric.Role)) { $ModelRoles += [string]$ModelMetric.Role }
    }

    $CostByModel += [PSCustomObject]@{
        Provider = $ModelProvider
        Model = $ModelName
        Roles = ((@($ModelRoles) | Sort-Object -Unique) -join ",")
        RequestCount = $ModelMetrics.Count
        DurationSeconds = [Math]::Round($ModelDuration, 3)
        InputTokens = $ModelInputTokens
        OutputTokens = $ModelOutputTokens
        TotalTokens = $ModelTotalTokens
        EstimatedCostUsd = [Math]::Round($ModelCost, 6)
    }
}

$CostByModelMarkdown = "| Provider | Model | Roles | Requests | Seconds | Input tokens | Output tokens | Total tokens | Estimated cost USD |`r`n"
$CostByModelMarkdown += "|---|---|---|---:|---:|---:|---:|---:|---:|`r`n"
foreach ($CostItem in $CostByModel) {
    $CostByModelMarkdown += "| $($CostItem.Provider) | $(ConvertTo-MarkdownTableCell -Text $CostItem.Model) | $($CostItem.Roles) | $($CostItem.RequestCount) | $($CostItem.DurationSeconds) | $($CostItem.InputTokens) | $($CostItem.OutputTokens) | $($CostItem.TotalTokens) | $($CostItem.EstimatedCostUsd) |`r`n"
}
$CostByModelMarkdown = $CostByModelMarkdown.Trim()

if ([string]::IsNullOrWhiteSpace($CostByModelMarkdown)) {
    $CostByModelMarkdown = "No model cost data available."
}

# v0.8.52: detect models that were used but have no usable price entry in config CostPer1MTokens.
# Makes the previously silent-null cost case visible (Known Issue #2). Cost math itself is unchanged.
$CostKeyWarnings = @()
foreach ($CostItem in $CostByModel) {
    $CostKey = $CostItem.Provider + "|" + $CostItem.Model
    $PriceMissing = $false
    $PriceReason = ""

    if ($null -eq $Script:MultiLLMConfig) {
        $PriceMissing = $true
        $PriceReason = "No config loaded; price table unavailable."
    }
    elseif ($null -eq $Script:MultiLLMConfig.CostPer1MTokens) {
        $PriceMissing = $true
        $PriceReason = "Config has no CostPer1MTokens table."
    }
    else {
        $PriceProperty = $Script:MultiLLMConfig.CostPer1MTokens.PSObject.Properties[$CostKey]
        if ($null -eq $PriceProperty) {
            $PriceMissing = $true
            $PriceReason = "No price entry for this Provider|Model key."
        }
        else {
            $PriceEntry = $PriceProperty.Value
            if ($null -eq $PriceEntry.InputUsd -or $null -eq $PriceEntry.OutputUsd) {
                $PriceMissing = $true
                $PriceReason = "Price entry exists but InputUsd or OutputUsd is null."
            }
        }
    }

    if ($PriceMissing -eq $true) {
        $CostKeyWarnings += [PSCustomObject]@{
            Provider     = $CostItem.Provider
            Model        = $CostItem.Model
            Roles        = $CostItem.Roles
            RequestCount = $CostItem.RequestCount
            InputTokens  = $CostItem.InputTokens
            OutputTokens = $CostItem.OutputTokens
            CountedCost  = $CostItem.EstimatedCostUsd
            Reason       = $PriceReason
        }
    }
}

$CostKeyWarningsMarkdown = ""
if ($CostKeyWarnings.Count -gt 0) {
    $CostKeyWarningsMarkdown = "| Provider | Model | Roles | Requests | Input tokens | Output tokens | Reason |`r`n"
    $CostKeyWarningsMarkdown += "|---|---|---|---:|---:|---:|---|`r`n"
    foreach ($CostWarn in $CostKeyWarnings) {
        $CostKeyWarningsMarkdown += "| $($CostWarn.Provider) | $(ConvertTo-MarkdownTableCell -Text $CostWarn.Model) | $($CostWarn.Roles) | $($CostWarn.RequestCount) | $($CostWarn.InputTokens) | $($CostWarn.OutputTokens) | $(ConvertTo-MarkdownTableCell -Text $CostWarn.Reason) |`r`n"
        Write-Color ("[WARN] Cost not counted for " + $CostWarn.Provider + "|" + $CostWarn.Model + " (" + $CostWarn.Reason + ")") "Yellow"
    }
    $CostKeyWarningsMarkdown = $CostKeyWarningsMarkdown.Trim()
}
else {
    $CostKeyWarningsMarkdown = "No cost warnings. All used models have price entries."
}


$CompletenessWarnings = @($TaskResults | Where-Object { $_.CompletenessWarning -eq $true })
$CompletenessWarningsLite = @()
$CompletenessWarningsMarkdown = ""
if ($CompletenessWarnings.Count -gt 0) {
    $CompletenessWarningsMarkdown = "| TaskId | TaskTitle | Reason |`r`n"
    $CompletenessWarningsMarkdown += "|---:|---|---|`r`n"
    foreach ($WarnItem in $CompletenessWarnings) {
        $CompletenessWarningsLite += [PSCustomObject]@{
            TaskId = $WarnItem.TaskId
            TaskTitle = $WarnItem.TaskTitle
            Reason = $WarnItem.CompletenessReason
            TaskFolder = $WarnItem.TaskFolder
        }
        $CompletenessWarningsMarkdown += "| $($WarnItem.TaskId) | $(ConvertTo-MarkdownTableCell -Text $WarnItem.TaskTitle) | $(ConvertTo-MarkdownTableCell -Text $WarnItem.CompletenessReason) |`r`n"
    }
    $CompletenessWarningsMarkdown = $CompletenessWarningsMarkdown.Trim()
}
else {
    $CompletenessWarningsMarkdown = "No completeness warnings detected."
}

$PipelineTotalSeconds = [Math]::Round(((Get-Date) - $PipelineStarted).TotalSeconds, 3)
$AnswerWaitSeconds = Get-MetricTotalSeconds -MetricCollection $PipelineStageMetrics -StageName "Task_WaitForAnswerJobs"
$JudgeRequestSeconds = Get-MetricTotalSeconds -MetricCollection $PipelineStageMetrics -StageName "Task_JudgeRequest"

$TimingSummary = [PSCustomObject]@{
    Version                = "v0.8.52"
    RunFolder              = $RunFolder
    TaskCount              = $Tasks.Count
    AiRequestCount         = @($AllRequestMetrics).Count
    PipelineTotalSeconds   = $PipelineTotalSeconds
    TotalAiRequestSeconds  = [Math]::Round($TotalAiRequestSeconds, 3)
    AnswerWaitSeconds      = $AnswerWaitSeconds
    JudgeRequestSeconds    = $JudgeRequestSeconds
    TotalInputTokens       = $TotalInputTokens
    TotalOutputTokens      = $TotalOutputTokens
    TotalTokens            = $TotalTokens
    EstimatedCostUsd       = [Math]::Round($TotalEstimatedCostUsd, 6)
    CostByRole             = $CostByRole
    CostByModel            = $CostByModel
    CompletenessWarnings   = $CompletenessWarnings.Count
    CostKeyWarnings        = $CostKeyWarnings.Count
}
Save-Json -Path (Join-Path $RunFolder "timing_summary.json") -Object $TimingSummary
Save-Json -Path (Join-Path $RunFolder "cost_summary_by_role.json") -Object $CostByRole
Save-Json -Path (Join-Path $RunFolder "cost_summary_by_model.json") -Object $CostByModel
Save-Json -Path (Join-Path $RunFolder "cost_warnings.json") -Object $CostKeyWarnings
Save-Json -Path (Join-Path $RunFolder "completeness_warnings.json") -Object $CompletenessWarningsLite

$FinalMarkdown = @"
# Multi-LLM Prompter $ToolVersion - Full Answer

## Original Prompt

$UserPrompt

## Task Splitter

Mode: $TaskSplitterMode

Task work mode: $TaskWorkMode

UI auto mode: $UiCodeAutoWorkMode

Prompt preset: $PromptPreset

Tasks detected: $($Tasks.Count)

## Timing Summary

| Metric | Value |
|---|---:|
| Pipeline total seconds | $($TimingSummary.PipelineTotalSeconds) |
| AI request count | $($TimingSummary.AiRequestCount) |
| Total AI request seconds | $($TimingSummary.TotalAiRequestSeconds) |
| Answer wait seconds | $($TimingSummary.AnswerWaitSeconds) |
| Judge request seconds | $($TimingSummary.JudgeRequestSeconds) |
| Total input tokens | $($TimingSummary.TotalInputTokens) |
| Total output tokens | $($TimingSummary.TotalOutputTokens) |
| Total tokens | $($TimingSummary.TotalTokens) |
| Estimated cost USD | $($TimingSummary.EstimatedCostUsd) |

Detailed timing files:
- stage_metrics.csv
- request_metrics.csv
- timing_summary.json
- cost_summary_by_role.json
- cost_summary_by_model.json
- cost_warnings.json
- completeness_warnings.json

## Estimated Cost Total

Estimated cost USD: **$($TimingSummary.EstimatedCostUsd)**

## Cost by Role

$CostByRoleMarkdown

## Cost by Model

$CostByModelMarkdown

## Cost Warnings

$CostKeyWarningsMarkdown

## Completeness Warnings

$CompletenessWarningsMarkdown

## Task Summary

$TaskSummaryMarkdown

## Routing Notes

$RoutingNotesMarkdown

## Full Answer

$MergedFinal

## Improved Prompt

$ImprovedPromptCombined
"@

$StageStarted = Get-Date
$FinalPath = Join-Path $RunFolder "final_answer.md"
Save-Text -Path $FinalPath -Text $FinalMarkdown
$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_WriteFinalAnswer" -StartTime $StageStarted -EndTime (Get-Date) -Success $true -Details $FinalPath

$PipelineStageMetrics += New-StageMetric -TaskId 0 -TaskTitle "Pipeline" -StageName "Pipeline_Total" -StartTime $PipelineStarted -EndTime (Get-Date) -Success $true -Details ("Final=" + $FinalPath)

if ($ExportRunMetricsCsv -eq $true) {
    Export-MetricCollection -MetricCollection $PipelineStageMetrics -Path (Join-Path $RunFolder "stage_metrics.csv")
    Export-MetricCollection -MetricCollection $AllRequestMetrics -Path (Join-Path $RunFolder "request_metrics.csv")
}

if ($ShowFinalAnswerOnScreen -eq $true) {
    Write-Header "FINAL ANSWER"
    Write-Host $MergedFinal -ForegroundColor White
}

Write-Header "DONE"
Write-Color "Final answer     : $FinalPath" "Green"
Write-Color "Run folder       : $RunFolder" "Green"
Write-Color "Stage metrics    : $(Join-Path $RunFolder 'stage_metrics.csv')" "Green"
Write-Color "Request metrics  : $(Join-Path $RunFolder 'request_metrics.csv')" "Green"
Write-Color "Timing summary   : $(Join-Path $RunFolder 'timing_summary.json')" "Green"

if ($OpenFinalMarkdown -eq $true) {
    Start-Process notepad.exe $FinalPath
}

if ($OpenOutputFolder -eq $true) {
    Start-Process explorer.exe $RunFolder
}

Stop-Transcript | Out-Null

}

# -----------------------------
# MAIN - GUI MODE (v0.8.52)
# -----------------------------
# Zones per vlad-wpf-design: Header / Input / Content / Actions / Log / StatusBar.
# The GUI launches this same script as a hidden headless child process and
# monitors the run folder with a DispatcherTimer. Backend logic is unchanged.

if ($Script:RunPipelineMode -ne $true) {

# WPF requires STA. PowerShell.exe and ISE are STA by default; this guard catches
# unusual hosts (MTA runspaces, some schedulers).
$ApartmentState = [System.Threading.Thread]::CurrentThread.GetApartmentState()
if ($ApartmentState -ne [System.Threading.ApartmentState]::STA) {
    Write-Host "[ERROR] WPF GUI requires STA mode. Restart with: powershell.exe -STA -File <this script>" -ForegroundColor Red
    exit 1
}

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml

# ---- GUI state ----
$Script:UIReady          = $false
$Script:IsBusy           = $false
$Script:KeysReady        = $false
$Script:ChildProcess     = $null
$Script:CurrentRunFolder = ""
$Script:CurrentFinalAnswerPath = ""
$Script:RunStartTime     = $null
$Script:TotalTasks       = 0
$Script:PollTimer        = $null
$Script:LastTranscriptLen = 0
$Script:LastDoneCount    = -1
$Script:RunSplitMode     = ""
$Script:RunPromptChars   = 0
$Script:TaskReviewRows   = $null
$Script:LastTaskReviewEstimate = $null
$Script:PreRunPredictedCostUsd = $null
$Script:SkipTaskReviewVisualSync = $false
$Script:IsRefreshingTaskGrid = $false
$Script:SuppressOverrideCombo = $false
$Script:GuiLogExpandedHeight = 160

# GUI session log: every GUI log line is also appended to this file, so test
# results (progress, stop, errors, repeat runs) are captured automatically.
$EnableGuiSessionLog  = $true
$GuiSessionLogPath    = Join-Path $OutputRoot "gui_session.log"

$Script:CurrentImprovedPrompt = ""

# ---- GUI helper functions ----

function Get-FileTextSafe {
    param(
        [string]$Path,
        [int]$MaxChars = 0
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        return ""
    }

    $Text = ""
    $Stream = $null
    $Reader = $null

    try {
        $Stream = New-Object System.IO.FileStream($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
        $Reader = New-Object System.IO.StreamReader($Stream, [System.Text.Encoding]::UTF8, $true)
        $Text = $Reader.ReadToEnd()
    }
    catch {
        $Text = ""
    }
    finally {
        if ($null -ne $Reader) { $Reader.Close() }
        elseif ($null -ne $Stream) { $Stream.Close() }
    }

    if ($MaxChars -gt 0 -and $Text.Length -gt $MaxChars) {
        $Text = $Text.Substring($Text.Length - $MaxChars)
    }

    return $Text
}

function Add-GuiLog {
    param(
        [string]$Tag,
        [string]$Message
    )

    if ($null -eq $Script:Ctl_LogBox) {
        return
    }

    $Stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Line = "[" + $Stamp + "] [" + $Tag + "] " + $Message
    $Script:Ctl_LogBox.AppendText($Line + [Environment]::NewLine)
    $Script:Ctl_LogBox.ScrollToEnd()

    # v0.8.68: an ERROR must never hide behind a collapsed log. If the log panel is collapsed when an
    # error is logged, auto-expand it (to the last expanded height, else a sane default) so the failure
    # is visible immediately. Only fires on ERROR and only when collapsed, so it cannot fight the user.
    if ($Tag -eq "ERROR" -and $null -ne $Script:Ctl_LogBox) {
        $LogCollapsed = ($Script:Ctl_LogBox.Visibility -ne [System.Windows.Visibility]::Visible) -or ($Script:Ctl_LogBox.Height -le 0)
        if ($LogCollapsed -eq $true) {
            $ExpandTo = 160.0
            if ($null -ne $Script:GuiLogExpandedHeight -and $Script:GuiLogExpandedHeight -gt 0) { $ExpandTo = [double]$Script:GuiLogExpandedHeight }
            if ($ExpandTo -lt 96) { $ExpandTo = 160.0 }
            if ($ExpandTo -gt 360) { $ExpandTo = 360.0 }
            Set-GuiLogPanelHeight -Height $ExpandTo
        }
    }

    if ($EnableGuiSessionLog -eq $true) {
        try {
            [System.IO.File]::AppendAllText($GuiSessionLogPath, $Line + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
        }
        catch {
        }
    }
}

function Write-GuiRunReport {
    param(
        [string]$Outcome,
        [int]$ExitCode,
        [bool]$FinalAnswerFound,
        [bool]$SummaryLoaded
    )

    if ([string]::IsNullOrWhiteSpace($Script:CurrentRunFolder)) {
        return
    }
    if (-not (Test-Path -LiteralPath $Script:CurrentRunFolder)) {
        return
    }

    $EndTime = Get-Date
    $DurationSec = 0
    if ($null -ne $Script:RunStartTime) {
        $DurationSec = [Math]::Round(($EndTime - $Script:RunStartTime).TotalSeconds, 1)
    }

    $DoneCount = 0
    try {
        $TaskFolders = @(Get-ChildItem -Path $Script:CurrentRunFolder -Directory -Filter "Task_*" -ErrorAction SilentlyContinue)
        foreach ($Folder in $TaskFolders) {
            if (Test-Path -LiteralPath (Join-Path $Folder.FullName "final_answer.md")) {
                $DoneCount++
            }
        }
    }
    catch {
        $DoneCount = 0
    }

    $TranscriptSize = 0
    $TranscriptFile = Join-Path $Script:CurrentRunFolder "console_transcript.txt"
    if (Test-Path -LiteralPath $TranscriptFile) {
        try {
            $TranscriptSize = (Get-Item -LiteralPath $TranscriptFile).Length
        }
        catch {
            $TranscriptSize = 0
        }
    }

    $Report = [PSCustomObject]@{
        ToolVersion        = $ToolVersion
        Outcome            = $Outcome
        ExitCode           = $ExitCode
        RunFolder          = $Script:CurrentRunFolder
        StartedAt          = $Script:RunStartTime
        EndedAt            = $EndTime
        GuiDurationSeconds = $DurationSec
        PromptChars        = $Script:RunPromptChars
        SplitMode          = $Script:RunSplitMode
        TasksDetected      = $Script:TotalTasks
        TasksCompleted     = $DoneCount
        FinalAnswerFound   = $FinalAnswerFound
        SummaryLoaded      = $SummaryLoaded
        TranscriptBytes    = $TranscriptSize
        ComputerName       = $env:COMPUTERNAME
        UserName           = "$env:USERDOMAIN\$env:USERNAME"
    }

    try {
        $ReportJson = $Report | ConvertTo-Json -Depth 5
        $ReportPath = Join-Path $Script:CurrentRunFolder "gui_run_report.json"
        $Utf8BomRpt = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($ReportPath, $ReportJson, $Utf8BomRpt)
        Add-GuiLog -Tag "INFO" -Message ("Run report written: " + $ReportPath)
    }
    catch {
        Add-GuiLog -Tag "WARN" -Message ("Failed to write run report: " + $_.Exception.Message)
    }

    Add-GuiLog -Tag "INFO" -Message ("RUN RESULT | outcome=" + $Outcome + " | exit=" + $ExitCode + " | tasks=" + $DoneCount + "/" + $Script:TotalTasks + " | duration=" + $DurationSec + "s | final=" + $FinalAnswerFound)
}

function Set-GuiStatus {
    param([string]$Text)

    if ($null -ne $Script:Ctl_StatusText) {
        $Script:Ctl_StatusText.Text = $Text
    }
}

function Set-RunCompleteSignal {
    param([bool]$Success)

    try {
        if ($Success -eq $true) { [System.Media.SystemSounds]::Asterisk.Play() }
        else { [System.Media.SystemSounds]::Exclamation.Play() }
    }
    catch {
    }
    $Fg = "#0B6A0B"
    $Bg = "#CFEFCF"
    if ($Success -ne $true) { $Fg = "#A4262C"; $Bg = "#F6D6D6" }
    if ($null -ne $Script:Ctl_StatusText) { $Script:Ctl_StatusText.Foreground = New-GuiBrush -ColorText $Fg }
    if ($null -ne $Script:Ctl_StatusBarBorder) { $Script:Ctl_StatusBarBorder.Background = New-GuiBrush -ColorText $Bg }
}

function Reset-RunCompleteSignal {
    if ($null -ne $Script:Ctl_StatusText) { $Script:Ctl_StatusText.Foreground = New-GuiBrush -ColorText "#000000" }
    if ($null -ne $Script:Ctl_StatusBarBorder) { $Script:Ctl_StatusBarBorder.Background = New-GuiBrush -ColorText "#E0E0E0" }
}

function Set-GuiLogPanelHeight {
    param([double]$Height)

    if ($null -eq $Script:Ctl_LogBox) { return }

    if ($Height -lt 0) { $Height = 0 }
    if ($Height -gt 360) { $Height = 360 }

    $Script:Ctl_LogBox.Height = $Height
    if ($Height -le 0) {
        $Script:Ctl_LogBox.Visibility = [System.Windows.Visibility]::Collapsed
        if ($null -ne $Script:Ctl_LblLogHeader) { $Script:Ctl_LblLogHeader.Text = "Logs (collapsed)" }
        if ($null -ne $Script:Ctl_BtnToggleLog) { $Script:Ctl_BtnToggleLog.Content = "Expand" }
    }
    else {
        $Script:Ctl_LogBox.Visibility = [System.Windows.Visibility]::Visible
        $Script:GuiLogExpandedHeight = $Height
        if ($null -ne $Script:Ctl_LblLogHeader) { $Script:Ctl_LblLogHeader.Text = "Logs (latest)" }
        if ($null -ne $Script:Ctl_BtnToggleLog) { $Script:Ctl_BtnToggleLog.Content = "Collapse" }
        try { $Script:Ctl_LogBox.ScrollToEnd() } catch { }
    }
}

function Set-GuiBusy {
    param([bool]$Busy)

    $Script:IsBusy = $Busy
    if ($Busy -eq $true) { Reset-RunCompleteSignal }

    if ($null -ne $Script:Ctl_BtnRun) {
        # Keep the Run button enabled while busy so WPF does not render it as pale/invisible.
        # The click handler already ignores clicks when Script:IsBusy is true.
        $Script:Ctl_BtnRun.IsEnabled = $true
        if ($Busy -eq $true) {
            $Script:Ctl_BtnRun.Content = "Running..."
            $Script:Ctl_BtnRun.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#D6D6D6"))
            $Script:Ctl_BtnRun.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#333333"))
        }
        else {
            Update-RunButtonState
        }
    }

    if ($null -ne $Script:Ctl_BtnStop) {
        $Script:Ctl_BtnStop.IsEnabled = $Busy

        # Explicit colors so the disabled state stays clearly readable.
        if ($Busy -eq $true) {
            $Script:Ctl_BtnStop.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#A4262C"))
            $Script:Ctl_BtnStop.Foreground = [System.Windows.Media.Brushes]::White
        }
        else {
            $Script:Ctl_BtnStop.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#D6D6D6"))
            $Script:Ctl_BtnStop.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#666666"))
        }
    }
    if ($null -ne $Script:Ctl_PromptBox) { $Script:Ctl_PromptBox.IsReadOnly = $Busy }
    if ($null -ne $Script:Ctl_PresetCombo) { $Script:Ctl_PresetCombo.IsEnabled = (-not $Busy) }
    if ($null -ne $Script:Ctl_SplitCombo)  { $Script:Ctl_SplitCombo.IsEnabled  = (-not $Busy) }
    if ($null -ne $Script:Ctl_BtnDetect)   { $Script:Ctl_BtnDetect.IsEnabled   = (-not $Busy) }
}

function Get-ApiKeyReadiness {
    $SecretsOk = $false
    $EnvOk = $false

    if (Test-Path -LiteralPath $SecretsPath) {
        $SecretsOk = $true
    }

    if (-not [string]::IsNullOrWhiteSpace($env:OPENAI_API_KEY)) {
        if (-not [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) {
            $EnvOk = $true
        }
    }

    $Result = [PSCustomObject]@{
        SecretsFileExists = $SecretsOk
        EnvVarsPresent    = $EnvOk
        Ready             = ($SecretsOk -or $EnvOk)
    }

    return $Result
}

function Update-RunButtonState {
    if ($Script:IsBusy -eq $true) { return }
    if ($null -eq $Script:Ctl_BtnRun) { return }
    $State = Get-ApiKeyReadiness
    $Script:KeysReady = ($State.Ready -eq $true)
    if ($Script:KeysReady -eq $true) {
        $RunText = "Run"
        $EnableRun = $true
        if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0 -and $null -ne $Script:Ctl_ChkUseEditedTasks -and $Script:Ctl_ChkUseEditedTasks.IsChecked -eq $true) {
            $Total = @($Script:TaskReviewRows).Count
            $Selected = @(Get-SelectedTaskReviewRows).Count
            if ($Selected -le 0) {
                $RunText = "Select tasks to run"
                $EnableRun = $false
            }
            else {
                $TaskWord = "tasks"
                if ($Selected -eq 1) { $TaskWord = "task" }
                $RunText = "Run (" + $Selected + " " + $TaskWord + ")"
                if ($null -ne $Script:PreRunPredictedCostUsd) {
                    $RunText = $RunText + " - est. " + (Format-RailCost -Value ([double]$Script:PreRunPredictedCostUsd))
                }
            }
        }
        $Script:Ctl_BtnRun.Content = $RunText
        $Script:Ctl_BtnRun.IsEnabled = $EnableRun
        if ($EnableRun -eq $true) {
            $Script:Ctl_BtnRun.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#0B6A0B"))
            $Script:Ctl_BtnRun.ToolTip = "Run the selected task list."
        }
        else {
            $Script:Ctl_BtnRun.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#777777"))
            $Script:Ctl_BtnRun.ToolTip = "Select at least one task to run."
        }
        $Script:Ctl_BtnRun.Foreground = [System.Windows.Media.Brushes]::White
    }
    else {
        $Script:Ctl_BtnRun.IsEnabled = $true
        $Script:Ctl_BtnRun.Content = "Set API keys to run"
        $Script:Ctl_BtnRun.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#0078D7"))
        $Script:Ctl_BtnRun.Foreground = [System.Windows.Media.Brushes]::White
        $Script:Ctl_BtnRun.ToolTip = "Open the API keys dialog before running."
    }
}

function Update-ApiStatusHeader {
    if ($null -eq $Script:Ctl_HdrApiStatus) { return }
    $State = Get-ApiKeyReadiness
    if ($State.Ready -eq $true) {
        $Script:Ctl_HdrApiStatus.Text = "API keys: OK"
        $Script:Ctl_HdrApiStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#7CD992"))
    }
    else {
        $Script:Ctl_HdrApiStatus.Text = "API keys: missing"
        $Script:Ctl_HdrApiStatus.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString("#FF8A80"))
    }
    Update-RightRailApiStatus
}

function Select-MainTab {
    param([string]$Header)

    if ($null -eq $Script:Ctl_MainTabs) { return $false }
    foreach ($Item in @($Script:Ctl_MainTabs.Items)) {
        if ([string]$Item.Header -eq $Header) {
            $Script:Ctl_MainTabs.SelectedItem = $Item
            return $true
        }
    }
    return $false
}

function New-GuiBrush {
    param([string]$ColorText)

    return New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($ColorText))
}

function Format-RecentRunAge {
    param([datetime]$When)

    $Span = (Get-Date) - $When
    if ($Span.TotalMinutes -lt 1) { return "now" }
    if ($Span.TotalMinutes -lt 60) { return ([int]$Span.TotalMinutes).ToString() + "m ago" }
    if ($Span.TotalHours -lt 24) { return ([int]$Span.TotalHours).ToString() + "h ago" }
    if ($Span.TotalDays -lt 2) { return "Yesterday" }
    if ($Span.TotalDays -lt 7) { return ([int]$Span.TotalDays).ToString() + "d ago" }
    return $When.ToString("yyyy-MM-dd")
}

function Update-SidebarRecentRuns {
    $NameControls = @(
        $Script:Ctl_TxtSideRecent1Name,
        $Script:Ctl_TxtSideRecent2Name,
        $Script:Ctl_TxtSideRecent3Name,
        $Script:Ctl_TxtSideRecent4Name
    )
    $TimeControls = @(
        $Script:Ctl_TxtSideRecent1Time,
        $Script:Ctl_TxtSideRecent2Time,
        $Script:Ctl_TxtSideRecent3Time,
        $Script:Ctl_TxtSideRecent4Time
    )
    $ButtonControls = @(
        $Script:Ctl_BtnSideRecent1,
        $Script:Ctl_BtnSideRecent2,
        $Script:Ctl_BtnSideRecent3,
        $Script:Ctl_BtnSideRecent4
    )

    if ($null -eq $NameControls[0]) { return }

    for ($i = 0; $i -lt $NameControls.Count; $i++) {
        if ($null -ne $NameControls[$i]) { $NameControls[$i].Text = "" }
        if ($null -ne $TimeControls[$i]) { $TimeControls[$i].Text = "" }
        if ($null -ne $ButtonControls[$i]) {
            $ButtonControls[$i].Tag = $null
            $ButtonControls[$i].IsEnabled = $false
        }
    }

    $Runs = @()
    try {
        if (Test-Path -LiteralPath $OutputRoot) {
            $Runs = @(Get-ChildItem -Path $OutputRoot -Directory -Filter "Run_*" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4)
        }
    }
    catch {
        $Runs = @()
    }

    if (@($Runs).Count -le 0) {
        $NameControls[0].Text = "No runs yet"
        return
    }

    for ($i = 0; $i -lt @($Runs).Count; $i++) {
        if ($i -ge $NameControls.Count) { break }
        if ($null -ne $NameControls[$i]) { $NameControls[$i].Text = [string]$Runs[$i].Name }
        if ($null -ne $TimeControls[$i]) { $TimeControls[$i].Text = Format-RecentRunAge -When $Runs[$i].LastWriteTime }
        if ($null -ne $ButtonControls[$i]) {
            $ButtonControls[$i].Tag = [string]$Runs[$i].FullName
            $ButtonControls[$i].IsEnabled = $true
            $ButtonControls[$i].ToolTip = "Load results from " + [string]$Runs[$i].Name
        }
    }
}

$Script:UsdToIls = 3.7

function Format-CostUsdIls {
    param([double]$Value)
    if ($Value -le 0) { return '$0.00 / 0.00 ILS' }
    $Usd = "{0:N2}" -f $Value
    $Ils = "{0:N2}" -f ($Value * $Script:UsdToIls)
    return ('$' + $Usd + ' / ' + $Ils + ' ILS')
}

function Format-RailCost {
    param([double]$Value)

    if ($Value -le 0) { return '$0.00' }
    if ($Value -lt 0.01) { return ("$" + ("{0:N2}" -f $Value)) }
    return ("$" + ("{0:N2}" -f $Value))
}

function Format-RailNumber {
    param([double]$Value)

    return ("{0:N0}" -f $Value)
}

function Set-RightRailCost {
    param([double]$CostValue)

    # v0.8.52: budget is configurable via Output.CostBudgetUsd (default 10). 0 = no budget (hidden).
    $BudgetValue = 10.0
    try {
        if (($null -ne $Script:MultiLLMConfig) -and ($null -ne $Script:MultiLLMConfig.Output) -and ($null -ne $Script:MultiLLMConfig.Output.CostBudgetUsd)) {
            $BudgetValue = [double]$Script:MultiLLMConfig.Output.CostBudgetUsd
        }
    }
    catch {
        $BudgetValue = 10.0
    }
    $BudgetEnabled = ($BudgetValue -gt 0)
    if ($CostValue -lt 0) { $CostValue = 0 }

    if ($null -ne $Script:Ctl_TxtRailCostBig) {
        $Script:Ctl_TxtRailCostBig.Text = Format-RailCost -Value $CostValue
    }
    if ($null -ne $Script:Ctl_TxtRailCostIls) {
        $Script:Ctl_TxtRailCostIls.Text = "~" + ("{0:N2}" -f ($CostValue * $Script:UsdToIls)) + " ILS"
    }
    if ($null -ne $Script:Ctl_TxtRailBudget) {
        if ($BudgetEnabled -eq $true) { $Script:Ctl_TxtRailBudget.Text = Format-RailCost -Value $BudgetValue }
        else { $Script:Ctl_TxtRailBudget.Text = "off" }
    }
    if ($null -ne $Script:Ctl_PbRailCost) {
        if ($BudgetEnabled -eq $true) {
            $Script:Ctl_PbRailCost.Visibility = [System.Windows.Visibility]::Visible
            $Script:Ctl_PbRailCost.Minimum = 0
            $Script:Ctl_PbRailCost.Maximum = $BudgetValue
            if ($CostValue -gt $BudgetValue) { $Script:Ctl_PbRailCost.Value = $BudgetValue }
            else { $Script:Ctl_PbRailCost.Value = $CostValue }
            if ($CostValue -gt $BudgetValue) { $Script:Ctl_PbRailCost.Foreground = New-GuiBrush -ColorText "#A4262C" }
            else { $Script:Ctl_PbRailCost.Foreground = New-GuiBrush -ColorText "#0B6A0B" }
        }
        else {
            $Script:Ctl_PbRailCost.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
    if ($null -ne $Script:Ctl_TxtRailBudgetPct) {
        if ($BudgetEnabled -eq $true) {
            $Pct = ($CostValue / $BudgetValue) * 100.0
            if ($CostValue -gt $BudgetValue) {
                $Script:Ctl_TxtRailBudgetPct.Text = ("{0:N1}% - over budget" -f $Pct)
                $Script:Ctl_TxtRailBudgetPct.Foreground = New-GuiBrush -ColorText "#A4262C"
            }
            else {
                $Script:Ctl_TxtRailBudgetPct.Text = ("{0:N1}%" -f $Pct)
                $Script:Ctl_TxtRailBudgetPct.Foreground = New-GuiBrush -ColorText "#555555"
            }
            $Script:Ctl_TxtRailBudgetPct.Visibility = [System.Windows.Visibility]::Visible
        }
        else {
            $Script:Ctl_TxtRailBudgetPct.Text = ""
            $Script:Ctl_TxtRailBudgetPct.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

function Update-RightRailApiStatus {
    if ($null -eq $Script:Ctl_TxtRailApiStatus) { return }
    $State = Get-ApiKeyReadiness
    if ($State.Ready -eq $true) {
        $Script:Ctl_TxtRailApiStatus.Text = "OK"
        $Script:Ctl_TxtRailApiStatus.Foreground = New-GuiBrush -ColorText "#0B6A0B"
    }
    else {
        $Script:Ctl_TxtRailApiStatus.Text = "Missing"
        $Script:Ctl_TxtRailApiStatus.Foreground = New-GuiBrush -ColorText "#A4262C"
    }
}

function Update-RightRailFromPreview {
    $Estimate = $Script:LastTaskReviewEstimate
    if ($null -eq $Estimate -or $Estimate.Total -le 0) {
        if ($null -ne $Script:Ctl_TxtRailPreRunCost) { $Script:Ctl_TxtRailPreRunCost.Text = "-" }
        if ($null -ne $Script:Ctl_TxtRailPreRunTime) { $Script:Ctl_TxtRailPreRunTime.Text = "-" }
        if ($null -ne $Script:Ctl_TxtRailPreRunTasks) { $Script:Ctl_TxtRailPreRunTasks.Text = "-" }
        if ($null -ne $Script:Ctl_TxtRailInputTokens) { $Script:Ctl_TxtRailInputTokens.Text = "-" }
        if ($null -ne $Script:Ctl_TxtRailOutputTokens) { $Script:Ctl_TxtRailOutputTokens.Text = "-" }
        if ($null -ne $Script:Ctl_TxtRailTotalTokens) { $Script:Ctl_TxtRailTotalTokens.Text = "-" }
        $Script:PreRunPredictedCostUsd = $null
        if ($null -ne $Script:Ctl_TxtRailCostCompare) { $Script:Ctl_TxtRailCostCompare.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($null -ne $Script:Ctl_TxtRailCostLabel) { $Script:Ctl_TxtRailCostLabel.Text = "Estimated cost" }
        Set-RightRailCost -CostValue 0
        return
    }

    if ($null -ne $Script:Ctl_TxtRailPreRunCost) { $Script:Ctl_TxtRailPreRunCost.Text = [string]$Estimate.CostText }
    if ($null -ne $Script:Ctl_TxtRailPreRunTime) { $Script:Ctl_TxtRailPreRunTime.Text = [string]$Estimate.TimeText }
    if ($null -ne $Script:Ctl_TxtRailPreRunTasks) { $Script:Ctl_TxtRailPreRunTasks.Text = ([string]$Estimate.Selected + " / " + [string]$Estimate.Total) }
    if ($null -ne $Script:Ctl_TxtRailInputTokens) { $Script:Ctl_TxtRailInputTokens.Text = "est." }
    if ($null -ne $Script:Ctl_TxtRailOutputTokens) { $Script:Ctl_TxtRailOutputTokens.Text = "est." }
    if ($null -ne $Script:Ctl_TxtRailTotalTokens) { $Script:Ctl_TxtRailTotalTokens.Text = Format-RailNumber -Value ([double]$Estimate.TokensValue) }
    $Script:PreRunPredictedCostUsd = [double]$Estimate.CostValue
    if ($null -ne $Script:Ctl_TxtRailCostCompare) { $Script:Ctl_TxtRailCostCompare.Visibility = [System.Windows.Visibility]::Collapsed }
    if ($null -ne $Script:Ctl_TxtRailCostLabel) { $Script:Ctl_TxtRailCostLabel.Text = "Estimated cost" }
    Set-RightRailCost -CostValue ([double]$Estimate.CostValue)
}

function Update-RightRailFromRun {
    param(
        [string]$RunFolderPath,
        [string]$StatusText
    )

    if ([string]::IsNullOrWhiteSpace($RunFolderPath)) { return }
    $RunNameText = Split-Path -Path $RunFolderPath -Leaf
    if ($null -ne $Script:Ctl_TxtRailRunName) { $Script:Ctl_TxtRailRunName.Text = $RunNameText }
    if ($null -ne $Script:Ctl_TxtRailLastRun) { $Script:Ctl_TxtRailLastRun.Text = (Get-Date -Format "HH:mm:ss") }
    if ($null -ne $Script:Ctl_TxtRailRunStatus) { $Script:Ctl_TxtRailRunStatus.Text = $StatusText }

    try {
        if (Test-Path -LiteralPath $RunFolderPath) {
            $Item = Get-Item -LiteralPath $RunFolderPath
            if ($null -ne $Script:Ctl_TxtRailCreated) { $Script:Ctl_TxtRailCreated.Text = $Item.CreationTime.ToString("MM/dd HH:mm") }
        }
    }
    catch {
    }

    $TimingPath = Join-Path $RunFolderPath "timing_summary.json"
    $TimingText = Get-FileTextSafe -Path $TimingPath
    if ([string]::IsNullOrWhiteSpace($TimingText)) { return }

    $Timing = $null
    try { $Timing = $TimingText | ConvertFrom-Json -ErrorAction Stop } catch { $Timing = $null }
    if ($null -eq $Timing) { return }

    if ($null -ne $Script:Ctl_TxtRailInputTokens) { $Script:Ctl_TxtRailInputTokens.Text = Format-RailNumber -Value ([double]$Timing.TotalInputTokens) }
    if ($null -ne $Script:Ctl_TxtRailOutputTokens) { $Script:Ctl_TxtRailOutputTokens.Text = Format-RailNumber -Value ([double]$Timing.TotalOutputTokens) }
    if ($null -ne $Script:Ctl_TxtRailTotalTokens) { $Script:Ctl_TxtRailTotalTokens.Text = Format-RailNumber -Value ([double]$Timing.TotalTokens) }
    if ($null -ne $Script:Ctl_TxtRailLatencyTotal) { $Script:Ctl_TxtRailLatencyTotal.Text = ([string]$Timing.PipelineTotalSeconds + "s") }
    if ($null -ne $Script:Ctl_TxtRailLatencyAvg) {
        $TaskCount = [int]$Timing.TaskCount
        if ($TaskCount -gt 0) {
            $Avg = [Math]::Round(([double]$Timing.PipelineTotalSeconds / $TaskCount), 1)
            $Script:Ctl_TxtRailLatencyAvg.Text = ([string]$Avg + "s")
        }
        else {
            $Script:Ctl_TxtRailLatencyAvg.Text = "-"
        }
    }
    if ($null -ne $Script:Ctl_TxtRailSuccessRate) {
        if ($StatusText -eq "Completed") { $Script:Ctl_TxtRailSuccessRate.Text = "100%" }
        elseif ($StatusText -eq "Failed") { $Script:Ctl_TxtRailSuccessRate.Text = "0%" }
        else { $Script:Ctl_TxtRailSuccessRate.Text = "-" }
    }
    $ActualCost = [double]$Timing.EstimatedCostUsd
    Set-RightRailCost -CostValue $ActualCost
    if ($null -ne $Script:Ctl_TxtRailCostLabel) { $Script:Ctl_TxtRailCostLabel.Text = "Actual cost" }

    if ($null -ne $Script:Ctl_TxtRailCostCompare) {
        $HavePrediction = $false
        $Predicted = 0.0
        if ($null -ne $Script:PreRunPredictedCostUsd) {
            $Predicted = [double]$Script:PreRunPredictedCostUsd
            if ($Predicted -gt 0) { $HavePrediction = $true }
        }
        if ($HavePrediction -eq $true) {
            $Pct = (($ActualCost - $Predicted) / $Predicted) * 100.0
            $DirWord = "on target"
            if ($Pct -le -1) { $DirWord = "lower than predicted" }
            elseif ($Pct -ge 1) { $DirWord = "higher than predicted" }
            $CompareText = ("Predicted {0} -> actual {1}  ({2:+0.0;-0.0;0.0}%, {3})" -f (Format-RailCost -Value $Predicted), (Format-RailCost -Value $ActualCost), $Pct, $DirWord)
            $Script:Ctl_TxtRailCostCompare.Text = $CompareText
            $Script:Ctl_TxtRailCostCompare.Visibility = [System.Windows.Visibility]::Visible
            if ($Pct -ge 1) { $Script:Ctl_TxtRailCostCompare.Foreground = New-GuiBrush -ColorText "#A4262C" }
            elseif ($Pct -le -1) { $Script:Ctl_TxtRailCostCompare.Foreground = New-GuiBrush -ColorText "#0B6A0B" }
            else { $Script:Ctl_TxtRailCostCompare.Foreground = New-GuiBrush -ColorText "#555555" }
            Add-GuiLog -Tag "INFO" -Message ("Cost compare: " + $CompareText)
        }
        else {
            $Script:Ctl_TxtRailCostCompare.Text = ""
            $Script:Ctl_TxtRailCostCompare.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

function Reset-GuiForNewRun {
    if ($Script:IsBusy -eq $true) {
        Add-GuiLog -Tag "WARN" -Message "Cannot start a new draft while a run is active."
        return
    }

    $Script:CurrentRunFolder = ""
    $Script:CurrentFinalAnswerPath = ""
    $Script:CurrentImprovedPrompt = ""
    $Script:TaskReviewRows = $null
    $Script:LastTaskReviewEstimate = $null
    $Script:PreRunPredictedCostUsd = $null
    $Script:TotalTasks = 0
    $Script:LastDoneCount = -1
    $Script:LastTranscriptLen = 0

    if ($null -ne $Script:Ctl_PromptBox) { $Script:Ctl_PromptBox.Text = "" }
    if ($null -ne $Script:Ctl_PresetCombo) { $Script:Ctl_PresetCombo.SelectedItem = "Custom" }
    if ($null -ne $Script:Ctl_FinalBox) { $Script:Ctl_FinalBox.Text = "" }
    Clear-MetricsTab
    if ($null -ne $Script:Ctl_RunLogBox) { $Script:Ctl_RunLogBox.Text = "" }
    if ($null -ne $Script:Ctl_TasksGrid) { $Script:Ctl_TasksGrid.ItemsSource = $null }
    if ($null -ne $Script:Ctl_TasksEditBox) { $Script:Ctl_TasksEditBox.Text = "" }
    Update-TaskDetailsPanel -Row $null
    if ($null -ne $Script:Ctl_TaskDetailPromptBox) { $Script:Ctl_TaskDetailPromptBox.Text = "" }
    if ($null -ne $Script:Ctl_HdrRunFolder) { $Script:Ctl_HdrRunFolder.Text = "" }
    if ($null -ne $Script:Ctl_LblTaskReviewSummary) { $Script:Ctl_LblTaskReviewSummary.Text = "No tasks detected yet" }
    if ($null -ne $Script:Ctl_LblCostEstimate) { $Script:Ctl_LblCostEstimate.Text = "Pre-run est: -" }
    if ($null -ne $Script:Ctl_LblTasksDone) { $Script:Ctl_LblTasksDone.Text = "Tasks: 0 / 0" }
    if ($null -ne $Script:Ctl_LblElapsed) { $Script:Ctl_LblElapsed.Text = "Elapsed: 0 s" }
    if ($null -ne $Script:Ctl_TxtRailRunName) { $Script:Ctl_TxtRailRunName.Text = "-" }
    if ($null -ne $Script:Ctl_TxtRailCreated) { $Script:Ctl_TxtRailCreated.Text = "-" }
    if ($null -ne $Script:Ctl_TxtRailLastRun) { $Script:Ctl_TxtRailLastRun.Text = "-" }
    if ($null -ne $Script:Ctl_TxtRailRunStatus) { $Script:Ctl_TxtRailRunStatus.Text = "Ready" }
    if ($null -ne $Script:Ctl_TxtRailLatencyTotal) { $Script:Ctl_TxtRailLatencyTotal.Text = "-" }
    if ($null -ne $Script:Ctl_TxtRailLatencyAvg) { $Script:Ctl_TxtRailLatencyAvg.Text = "-" }
    if ($null -ne $Script:Ctl_TxtRailSuccessRate) { $Script:Ctl_TxtRailSuccessRate.Text = "-" }
    Update-RightRailFromPreview
    Update-RightRailApiStatus
    if ($null -ne $Script:Ctl_PbTasks) {
        $Script:Ctl_PbTasks.Minimum = 0
        $Script:Ctl_PbTasks.Maximum = 1
        $Script:Ctl_PbTasks.Value = 0
    }
    if ($null -ne $Script:Ctl_BtnImproved) { $Script:Ctl_BtnImproved.IsEnabled = $false }

    [void](Select-MainTab -Header "Full Answer")
    Set-GuiStatus "New run ready"
    Add-GuiLog -Tag "INFO" -Message "New run draft opened from the left rail."
    if ($null -ne $Script:Ctl_PromptBox) { $Script:Ctl_PromptBox.Focus() | Out-Null }
    Update-RunButtonState
}

function Get-GuiComboText {
    param(
        [object]$Combo,
        [string]$Fallback
    )

    if ($null -ne $Combo) {
        $Text = [string]$Combo.Text
        if ([string]::IsNullOrWhiteSpace($Text)) {
            $Text = [string]$Combo.SelectedItem
        }
        if (-not [string]::IsNullOrWhiteSpace($Text)) {
            return $Text.Trim()
        }
    }
    return $Fallback
}

function Get-GuiSelectedWorkMode {
    $Mode = "Auto"
    if ($null -ne $Script:Ctl_WorkCombo) {
        $Mode = [string]$Script:Ctl_WorkCombo.SelectedItem
    }
    if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = "Auto" }
    return $Mode
}

function Get-GuiSelectedUiMode {
    $Mode = "Review"
    if ($null -ne $Script:Ctl_UiModeCombo) {
        $Mode = [string]$Script:Ctl_UiModeCombo.SelectedItem
    }
    if ([string]::IsNullOrWhiteSpace($Mode)) { $Mode = "Review" }
    return $Mode
}

function Get-GuiTaskWorkModeForEstimate {
    param(
        [string]$PromptText,
        [string]$TaskType
    )

    $Mode = Get-GuiSelectedWorkMode
    if ($Mode -eq "Review" -or $Mode -eq "Script") { return $Mode }

    $UiMode = Get-GuiSelectedUiMode
    $Lower = $PromptText.ToLower()

    if ($TaskType -eq "ui_code") {
        if ($Lower.Contains("complete script") -or $Lower.Contains("full script") -or $Lower.Contains("runnable script") -or $Lower.Contains("create script") -or $Lower.Contains("write script")) { return "Script" }
        return $UiMode
    }

    if ($TaskType -eq "technical") {
        if ($Lower.Contains("safe powershell") -or
            $Lower.Contains("powershell 5.1 correction") -or
            $Lower.Contains("propose a safe") -or
            $Lower.Contains("correction") -or
            $Lower.Contains("provide a script") -or
            $Lower.Contains("complete script") -or
            $Lower.Contains("runnable script") -or
            $Lower.Contains("fix ") -or
            $Lower.Contains(" fix") -or
            $Lower.Contains("correct ")) {
            return "Script"
        }
    }

    if ($Lower.Contains("review") -or $Lower.Contains("analyze") -or $Lower.Contains("audit") -or $Lower.Contains("suggest") -or $Lower.Contains("explain the bug")) {
        if (-not ($Lower.Contains("complete script") -or $Lower.Contains("full script") -or $Lower.Contains("runnable script") -or $Lower.Contains("create script") -or $Lower.Contains("write script"))) {
            return "Review"
        }
    }

    if ($TaskType -eq "code") {
        if ($Lower.Contains("script") -or $Lower.Contains("code") -or $Lower.Contains("function") -or $Lower.Contains("wpf") -or $Lower.Contains("xaml")) { return "Script" }
    }

    return "Review"
}

function Get-GuiTaskTypeLabel {
    param([string]$TaskType)

    if ($TaskType -eq "code") { return "Script" }
    if ($TaskType -eq "ui_code") { return "GUI" }
    if ($TaskType -eq "documentation") { return "Summary" }
    if ($TaskType -eq "creative") { return "Creative" }
    if ($TaskType -eq "technical") { return "Audit" }
    return "General"
}

function Get-GuiTaskExcerpt {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $Clean = ($Text -replace '\s+', ' ').Trim()
    if ($Clean.Length -gt 118) { return $Clean.Substring(0, 115) + "..." }
    return $Clean
}

function Normalize-GuiTaskText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    return (($Text -replace '\s+', ' ').Trim().ToLowerInvariant())
}

function Get-GuiApproxTokenCount {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) { return 1 }
    $Count = [int][Math]::Ceiling(([double]$Text.Length) / 4.0)
    if ($Count -lt 1) { $Count = 1 }
    return $Count
}

function Get-GuiTaskEstimate {
    param(
        [string]$PromptText,
        [string]$TypeOverride = "",
        [string]$WorkModeOverride = ""
    )

    $TaskType = Get-TaskType -PromptText $PromptText
    $ValidTaskTypes = @("simple", "technical", "code", "ui_code", "documentation", "creative")
    if (-not [string]::IsNullOrWhiteSpace($TypeOverride) -and ($ValidTaskTypes -contains $TypeOverride)) { $TaskType = $TypeOverride }
    $WorkMode = Get-GuiTaskWorkModeForEstimate -PromptText $PromptText -TaskType $TaskType
    if ($WorkModeOverride -eq "Review" -or $WorkModeOverride -eq "Script") { $WorkMode = $WorkModeOverride }
    $UseOpenAI = $true
    $UseAnthropicAnswer = $true
    $UseJudge = $true
    $Reason = "Default multi-model route."

    if ($SkipMultiForSimple -eq $true -and $TaskType -eq "simple") {
        $UseAnthropicAnswer = $false
        $UseJudge = $SimpleTasksUseJudge
        $Reason = "Simple prompt: using one fast answer model only."
    }

    if ($TaskType -eq "creative") {
        if ($CreativeTasksUseSingleModel -eq $true) {
            $UseOpenAI = $false
            $UseAnthropicAnswer = $true
            $UseJudge = $CreativeTasksUseJudge
            $Reason = "Creative task: using Anthropic answer only."
        }
    }
    elseif ($TaskType -eq "documentation") {
        if ($DocumentationTasksUseSingleModel -eq $true) {
            $UseOpenAI = $false
            $UseAnthropicAnswer = $true
            $UseJudge = $DocumentationTasksUseJudge
            $Reason = "Documentation task: using Anthropic answer only."
        }
    }
    elseif ($TaskType -eq "code" -or $TaskType -eq "ui_code" -or $TaskType -eq "technical") {
        $UseOpenAI = $true
        $UseAnthropicAnswer = $true
        $UseJudge = $true
        $Reason = "Technical/code task: both answer models and Judge."
    }

    $JudgeModePolicy = "Skipped"
    if ($UseJudge -eq $true) {
        if ($WorkMode -eq "Review" -or $TaskType -eq "ui_code") { $JudgeModePolicy = "ReviewOnly" }
        else { $JudgeModePolicy = "Auto" }
    }

    $TimeoutSettings = Get-TaskTimeoutSettings -TaskType $TaskType
    $OutputSettings = Get-TaskOutputTokenSettings -TaskType $TaskType
    $EffectivePromptText = Get-EffectivePromptForWorkMode -PromptText $PromptText -TaskType $TaskType -WorkMode $WorkMode
    $InputTokens = (Get-GuiApproxTokenCount -Text $EffectivePromptText) + 600
    $AnswerOutputTokens = [int]$OutputSettings.AnswerMaxTokens
    $JudgeOutputTokens = [int]$OutputSettings.JudgeMaxTokens

    $ModelA = Get-GuiComboText -Combo $Script:Ctl_ModelACombo -Fallback $OpenAIModel_Answer
    $ModelB = Get-GuiComboText -Combo $Script:Ctl_ModelBCombo -Fallback $AnthropicModel_Answer
    $JudgeSelected = Get-GuiComboText -Combo $Script:Ctl_JudgeCombo -Fallback $AnthropicModel_Judge
    $ReviewJudge = Get-GuiComboText -Combo $Script:Ctl_CheapJudgeCombo -Fallback $AnthropicModel_JudgeCheap
    $UseReviewJudge = $false
    if ($null -ne $Script:Ctl_ChkCheapJudge -and $Script:Ctl_ChkCheapJudge.IsChecked -eq $true) { $UseReviewJudge = $true }

    $AnswerCount = 0
    $RouteParts = @()
    $CostTotal = 0.0
    $HasCost = $false

    if ($UseOpenAI -eq $true) {
        $AnswerCount++
        $RouteParts += "A"
        $CostA = Get-EstimatedCostUsd -Provider "OpenAI" -Model $ModelA -InputTokens $InputTokens -OutputTokens $AnswerOutputTokens
        if ($null -ne $CostA) { $CostTotal += [double]$CostA; $HasCost = $true }
    }

    if ($UseAnthropicAnswer -eq $true) {
        $AnswerCount++
        $RouteParts += "B"
        $CostB = Get-EstimatedCostUsd -Provider "Anthropic" -Model $ModelB -InputTokens $InputTokens -OutputTokens $AnswerOutputTokens
        if ($null -ne $CostB) { $CostTotal += [double]$CostB; $HasCost = $true }
    }

    $JudgeMode = "Skipped"
    $JudgeModel = ""
    if ($UseJudge -eq $true) {
        if ($AnswerCount -ge 2) { $JudgeMode = "Full" }
        else { $JudgeMode = "Light" }
        if ($JudgeModePolicy -eq "ReviewOnly") { $JudgeMode = "ReviewOnly" }

        if ($JudgeMode -eq "Full") { $JudgeModel = $AnthropicModel_JudgeStrong }
        else {
            $JudgeModel = $JudgeSelected
            if ($UseReviewJudge -eq $true) { $JudgeModel = $ReviewJudge }
        }

        $JudgeInputTokens = $InputTokens + ($AnswerOutputTokens * $AnswerCount) + 400
        $CostJ = Get-EstimatedCostUsd -Provider $JudgeProvider -Model $JudgeModel -InputTokens $JudgeInputTokens -OutputTokens $JudgeOutputTokens
        if ($null -ne $CostJ) { $CostTotal += [double]$CostJ; $HasCost = $true }
    }

    $RouteLabel = "-"
    if ($RouteParts.Count -gt 0) { $RouteLabel = ($RouteParts -join "/") }
    if ($JudgeMode -ne "Skipped") { $RouteLabel = $RouteLabel + "+J" }

    $CostText = "~n/a"
    $CostValue = $null
    if ($HasCost -eq $true) {
        $CostValue = [Math]::Round($CostTotal, 2)
        $CostText = "~" + (Format-CostUsdIls -Value $CostValue)
    }

    $TimeSec = [int]$TimeoutSettings.TotalRequestTimeoutSec
    if ($JudgeMode -ne "Skipped") { $TimeSec += [int]$JudgeTimeoutSec }
    $TimeText = "~" + $TimeSec + "s"
    if ($TimeSec -ge 60) { $TimeText = "~" + [Math]::Round($TimeSec / 60.0, 1) + "m" }

    $TotalEstTokens = $InputTokens + ($AnswerOutputTokens * $AnswerCount)
    if ($JudgeMode -ne "Skipped") { $TotalEstTokens += $JudgeOutputTokens }

    return [PSCustomObject]@{
        TaskType          = $TaskType
        TypeLabel         = Get-GuiTaskTypeLabel -TaskType $TaskType
        WorkMode          = $WorkMode
        Route             = $RouteLabel
        JudgeMode         = $JudgeMode
        JudgeModel        = $JudgeModel
        EstimatedCostText = $CostText
        EstimatedCost     = $CostValue
        EstimatedTimeText = $TimeText
        EstimatedTimeSec  = $TimeSec
        EstimatedTokens   = $TotalEstTokens
        Reason            = $Reason + " WorkMode=" + $WorkMode + "; JudgeMode=" + $JudgeMode + "."
    }
}

function Get-TaskReviewRowsFromTasks {
    param([object[]]$Tasks)

    $Rows = New-Object System.Collections.ArrayList
    foreach ($Task in @($Tasks)) {
        $PromptText = [string]$Task.PromptText
        if ([string]::IsNullOrWhiteSpace($PromptText)) { continue }
        $Estimate = Get-GuiTaskEstimate -PromptText $PromptText
        $Title = [string]$Task.TaskTitle
        if ([string]::IsNullOrWhiteSpace($Title)) { $Title = Get-TaskTitleFromText -Text $PromptText }
        [void]$Rows.Add([PSCustomObject]@{
            IsSelected   = $true
            Id           = $Task.TaskId
            Type         = $Estimate.TaskType
            TypeLabel    = $Estimate.TypeLabel
            WorkMode     = $Estimate.WorkMode
            Title        = $Title
            Excerpt      = Get-GuiTaskExcerpt -Text $PromptText
            PromptText   = $PromptText.Trim()
            Status       = "Ready"
            Route        = $Estimate.Route
            JudgeMode    = $Estimate.JudgeMode
            JudgeModel   = $Estimate.JudgeModel
            EstCost      = $Estimate.EstimatedCostText
            EstCostValue = $Estimate.EstimatedCost
            EstTime      = $Estimate.EstimatedTimeText
            EstTimeSec   = $Estimate.EstimatedTimeSec
            EstTokens    = $Estimate.EstimatedTokens
            Reason       = $Estimate.Reason
            Success      = ""
            Answers      = ""
            Completeness = ""
            Tokens       = ""
            Cost         = ""
            Error        = ""
            TaskFolder   = ""
            TypeOverride = ""
            WorkModeOverride = ""
        })
    }
    return $Rows
}

function Update-TaskReviewRowEstimate {
    param([object]$Row)

    if ($null -eq $Row) { return }
    $TypeOvr = ""
    if ($Row.PSObject.Properties.Name -contains "TypeOverride") { $TypeOvr = [string]$Row.TypeOverride }
    $WorkOvr = ""
    if ($Row.PSObject.Properties.Name -contains "WorkModeOverride") { $WorkOvr = [string]$Row.WorkModeOverride }
    $Estimate = Get-GuiTaskEstimate -PromptText ([string]$Row.PromptText) -TypeOverride $TypeOvr -WorkModeOverride $WorkOvr
    $Row.Type = $Estimate.TaskType
    $Row.TypeLabel = $Estimate.TypeLabel
    $Row.WorkMode = $Estimate.WorkMode
    $Row.Route = $Estimate.Route
    $Row.JudgeMode = $Estimate.JudgeMode
    if ($Row.PSObject.Properties.Name -contains "JudgeModel") { $Row.JudgeModel = $Estimate.JudgeModel }
    $Row.EstCost = $Estimate.EstimatedCostText
    $Row.EstCostValue = $Estimate.EstimatedCost
    $Row.EstTime = $Estimate.EstimatedTimeText
    $Row.EstTimeSec = $Estimate.EstimatedTimeSec
    $Row.EstTokens = $Estimate.EstimatedTokens
    $Row.Reason = $Estimate.Reason
}

function Update-AllTaskReviewRowEstimates {
    if ($null -eq $Script:TaskReviewRows) { return }
    $Recalculated = $false
    foreach ($Row in @($Script:TaskReviewRows)) {
        if ([string]$Row.Status -eq "Ready" -or [string]$Row.Status -eq "Not selected") {
            Update-TaskReviewRowEstimate -Row $Row
            $Recalculated = $true
        }
    }
    if ($Recalculated -eq $true) {
        Update-TaskReviewSelectionSummary
        if ($null -ne $Script:Ctl_TasksGrid -and $null -ne $Script:Ctl_TasksGrid.SelectedItem) {
            Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
        }
        Refresh-TaskReviewGrid
    }
}

function Invoke-DetectTasks {
    param([switch]$Announce)

    $DetectPrompt = [string]$Script:Ctl_PromptBox.Text
    if ([string]::IsNullOrWhiteSpace($DetectPrompt)) { return 0 }
    $DetectSplitMode = [string]$Script:Ctl_SplitCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($DetectSplitMode)) { $DetectSplitMode = "Heuristic" }
    $PreviewTasks = @(Split-UserPromptIntoTasks -PromptText $DetectPrompt -Mode $DetectSplitMode -MaxTasks $MaxTasksPerPrompt)
    $PreviewRows = Get-TaskReviewRowsFromTasks -Tasks $PreviewTasks
    Set-TaskReviewRows -Rows $PreviewRows
    if ($null -ne $Script:Ctl_ChkUseEditedTasks) { $Script:Ctl_ChkUseEditedTasks.IsChecked = $true }
    if ($Announce -eq $true) {
        Add-GuiLog -Tag "INFO" -Message ("Detected " + @($PreviewRows).Count + " task(s). All are selected by default; uncheck any task you do not want to run.")
        if ($null -ne $Script:LastTaskReviewEstimate) {
            Add-GuiLog -Tag "INFO" -Message ("Pre-run estimate: selected " + $Script:LastTaskReviewEstimate.CostText + " | all " + $Script:LastTaskReviewEstimate.AllCostText + " | selected time " + $Script:LastTaskReviewEstimate.TimeText)
        }
    }
    if ($null -ne $Script:Ctl_PbTasks) {
        $Script:Ctl_PbTasks.Value = 0
        $Script:Ctl_PbTasks.Maximum = [Math]::Max(1, @($PreviewRows).Count)
    }
    if ($null -ne $Script:Ctl_LblTasksDone) { $Script:Ctl_LblTasksDone.Text = "Tasks: 0 / " + @($PreviewRows).Count }
    return @($PreviewRows).Count
}

function Refresh-TaskReviewGrid {
    if ($null -eq $Script:Ctl_TasksGrid) { return }
    if ($Script:IsRefreshingTaskGrid -eq $true) { return }
    $Script:IsRefreshingTaskGrid = $true
    try {
        $SelectedRow = $Script:Ctl_TasksGrid.SelectedItem
        try { $Script:Ctl_TasksGrid.Items.Refresh() } catch { }
        if ($null -ne $SelectedRow) {
            try { $Script:Ctl_TasksGrid.SelectedItem = $SelectedRow } catch { }
        }
    }
    finally {
        $Script:IsRefreshingTaskGrid = $false
    }
}

function Commit-TaskReviewGridEdit {
    if ($null -eq $Script:Ctl_TasksGrid) { return }
    try {
        [void]$Script:Ctl_TasksGrid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Cell, $true)
        [void]$Script:Ctl_TasksGrid.CommitEdit([System.Windows.Controls.DataGridEditingUnit]::Row, $true)
    }
    catch {
    }
}

function Get-VisualChildrenByType {
    param(
        [object]$Parent,
        [type]$TargetType
    )

    $Results = @()
    if ($null -eq $Parent) { return $Results }

    $Count = 0
    try {
        $Count = [System.Windows.Media.VisualTreeHelper]::GetChildrenCount($Parent)
    }
    catch {
        return $Results
    }

    for ($Index = 0; $Index -lt $Count; $Index++) {
        $Child = [System.Windows.Media.VisualTreeHelper]::GetChild($Parent, $Index)
        if ($null -ne $Child) {
            if ($TargetType.IsInstanceOfType($Child)) {
                $Results += $Child
            }
            $Results += Get-VisualChildrenByType -Parent $Child -TargetType $TargetType
        }
    }

    return $Results
}

function Get-VisualParentByType {
    param(
        [object]$Child,
        [type]$TargetType
    )

    $Node = $Child
    while ($null -ne $Node) {
        if ($TargetType.IsInstanceOfType($Node)) {
            return $Node
        }
        try {
            $Node = [System.Windows.Media.VisualTreeHelper]::GetParent($Node)
        }
        catch {
            return $null
        }
    }
    return $null
}

function Sync-TaskReviewSelectionFromVisualGrid {
    if ($Script:SkipTaskReviewVisualSync -eq $true) { return }
    Commit-TaskReviewGridEdit
    if ($null -eq $Script:Ctl_TasksGrid) { return }
    if ($null -eq $Script:TaskReviewRows) { return }

    try { $Script:Ctl_TasksGrid.UpdateLayout() } catch { }

    $CheckBoxes = @(Get-VisualChildrenByType -Parent $Script:Ctl_TasksGrid -TargetType ([System.Windows.Controls.CheckBox]))
    foreach ($CheckBox in $CheckBoxes) {
        $Row = $CheckBox.DataContext
        if ($null -eq $Row) { continue }
        if (-not ($Row.PSObject.Properties.Name -contains "IsSelected")) { continue }
        $ContentText = [string]$CheckBox.Content
        if ($ContentText -eq "Include this task in next run") { continue }
        $Row.IsSelected = ($CheckBox.IsChecked -eq $true)
    }
}

function Sync-TaskReviewEditBox {
    if ($null -eq $Script:Ctl_TasksEditBox) { return }
    if ($null -eq $Script:TaskReviewRows) { return }

    $Lines = @()
    foreach ($Row in @($Script:TaskReviewRows)) {
        if ($Row.IsSelected -eq $true -and -not [string]::IsNullOrWhiteSpace([string]$Row.PromptText)) {
            $Lines += ([string]$Row.PromptText).Trim()
        }
    }
    $Script:Ctl_TasksEditBox.Text = ($Lines -join "`r`n")
    if ($null -ne $Script:Ctl_ChkUseEditedTasks) {
        if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
            $Script:Ctl_ChkUseEditedTasks.IsChecked = $true
        }
        else {
            $Script:Ctl_ChkUseEditedTasks.IsChecked = ($Lines.Count -gt 0)
        }
    }
}

function Update-TaskDetailsPanel {
    param([object]$Row)

    if ($null -eq $Row) {
        if ($null -ne $Script:Ctl_TxtTaskDetailTitle) { $Script:Ctl_TxtTaskDetailTitle.Text = "Select a task" }
        if ($null -ne $Script:Ctl_TxtDetailType) { $Script:Ctl_TxtDetailType.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailStatus) { $Script:Ctl_TxtDetailStatus.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailCost) { $Script:Ctl_TxtDetailCost.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailTokens) { $Script:Ctl_TxtDetailTokens.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailTime) { $Script:Ctl_TxtDetailTime.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailJudge) { $Script:Ctl_TxtDetailJudge.Text = "-" }
        if ($null -ne $Script:Ctl_TxtDetailValueKind) { $Script:Ctl_TxtDetailValueKind.Text = "" }
        if ($null -ne $Script:Ctl_TxtTaskDetailPromptLabel) { $Script:Ctl_TxtTaskDetailPromptLabel.Visibility = [System.Windows.Visibility]::Collapsed }
        if ($null -ne $Script:Ctl_TaskDetailPromptBox) { $Script:Ctl_TaskDetailPromptBox.Text = "" }
        if ($null -ne $Script:Ctl_TaskDetailPromptBox) { $Script:Ctl_TaskDetailPromptBox.Visibility = [System.Windows.Visibility]::Collapsed }
        $Script:SuppressOverrideCombo = $true
        try {
            if ($null -ne $Script:Ctl_CmbTaskTypeOverride) { $Script:Ctl_CmbTaskTypeOverride.SelectedIndex = 0; $Script:Ctl_CmbTaskTypeOverride.IsEnabled = $false }
            if ($null -ne $Script:Ctl_CmbTaskWorkModeOverride) { $Script:Ctl_CmbTaskWorkModeOverride.SelectedIndex = 0; $Script:Ctl_CmbTaskWorkModeOverride.IsEnabled = $false }
        }
        finally { $Script:SuppressOverrideCombo = $false }
        return
    }

    if ($null -ne $Script:Ctl_TxtTaskDetailTitle) { $Script:Ctl_TxtTaskDetailTitle.Text = [string]$Row.Title }
    $TypeText = "-"
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.TypeLabel)) { $TypeText = [string]$Row.TypeLabel }
    if ($null -ne $Script:Ctl_TxtDetailType) { $Script:Ctl_TxtDetailType.Text = $TypeText }
    if ($null -ne $Script:Ctl_TxtDetailStatus) { $Script:Ctl_TxtDetailStatus.Text = [string]$Row.Status }
    $CostDisplay = "-"
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.EstCost)) { $CostDisplay = [string]$Row.EstCost }
    if ($null -ne $Script:Ctl_TxtDetailCost) { $Script:Ctl_TxtDetailCost.Text = $CostDisplay }
    $TokensDisplay = "-"
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.EstTokens)) { $TokensDisplay = [string]$Row.EstTokens + " tokens" }
    if ($null -ne $Script:Ctl_TxtDetailTokens) { $Script:Ctl_TxtDetailTokens.Text = $TokensDisplay }
    $TimeDisplay = "-"
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.EstTime)) { $TimeDisplay = [string]$Row.EstTime }
    if ($null -ne $Script:Ctl_TxtDetailTime) { $Script:Ctl_TxtDetailTime.Text = $TimeDisplay }
    $JudgeDisplay = "Not used"
    if (-not [string]::IsNullOrWhiteSpace([string]$Row.JudgeMode) -and [string]$Row.JudgeMode -ne "Skipped") {
        $JudgeModelText = ""
        if ($Row.PSObject.Properties.Name -contains "JudgeModel") { $JudgeModelText = [string]$Row.JudgeModel }
        if (-not [string]::IsNullOrWhiteSpace($JudgeModelText)) { $JudgeDisplay = $JudgeModelText + " (" + [string]$Row.JudgeMode + ")" }
        else { $JudgeDisplay = [string]$Row.JudgeMode }
    }
    if ($null -ne $Script:Ctl_TxtDetailJudge) { $Script:Ctl_TxtDetailJudge.Text = $JudgeDisplay }
    if ($null -ne $Script:Ctl_TxtDetailValueKind) {
        if ([string]$Row.Status -eq "Ready" -or [string]$Row.Status -eq "Not selected") { $Script:Ctl_TxtDetailValueKind.Text = "Cost / tokens / time are estimates (before the run)." }
        else { $Script:Ctl_TxtDetailValueKind.Text = "Cost / tokens / time are actual values from the run." }
    }
    if ($null -ne $Script:Ctl_TaskDetailPromptBox) {
        $TitleText = [string]$Row.Title
        $PromptText = [string]$Row.PromptText
        if ((Normalize-GuiTaskText -Text $TitleText) -eq (Normalize-GuiTaskText -Text $PromptText)) {
            $Script:Ctl_TaskDetailPromptBox.Text = ""
            $Script:Ctl_TaskDetailPromptBox.Visibility = [System.Windows.Visibility]::Collapsed
            if ($null -ne $Script:Ctl_TxtTaskDetailPromptLabel) { $Script:Ctl_TxtTaskDetailPromptLabel.Visibility = [System.Windows.Visibility]::Collapsed }
        }
        else {
            $Script:Ctl_TaskDetailPromptBox.Text = $PromptText
            $Script:Ctl_TaskDetailPromptBox.Visibility = [System.Windows.Visibility]::Visible
            if ($null -ne $Script:Ctl_TxtTaskDetailPromptLabel) { $Script:Ctl_TxtTaskDetailPromptLabel.Visibility = [System.Windows.Visibility]::Visible }
        }
    }
    $IsPreRunRow = ([string]$Row.Status -eq "Ready" -or [string]$Row.Status -eq "Not selected")
    $Script:SuppressOverrideCombo = $true
    try {
        if ($null -ne $Script:Ctl_CmbTaskTypeOverride) {
            $TypeOvrSel = "Auto"
            if ($Row.PSObject.Properties.Name -contains "TypeOverride") {
                $RowTypeOvr = [string]$Row.TypeOverride
                if (-not [string]::IsNullOrWhiteSpace($RowTypeOvr)) { $TypeOvrSel = $RowTypeOvr }
            }
            $Script:Ctl_CmbTaskTypeOverride.SelectedItem = $TypeOvrSel
            $Script:Ctl_CmbTaskTypeOverride.IsEnabled = $IsPreRunRow
        }
        if ($null -ne $Script:Ctl_CmbTaskWorkModeOverride) {
            $WorkOvrSel = "Auto"
            if ($Row.PSObject.Properties.Name -contains "WorkModeOverride") {
                $RowWorkOvr = [string]$Row.WorkModeOverride
                if (-not [string]::IsNullOrWhiteSpace($RowWorkOvr)) { $WorkOvrSel = $RowWorkOvr }
            }
            $Script:Ctl_CmbTaskWorkModeOverride.SelectedItem = $WorkOvrSel
            $Script:Ctl_CmbTaskWorkModeOverride.IsEnabled = $IsPreRunRow
        }
    }
    finally { $Script:SuppressOverrideCombo = $false }
}

function Get-SelectedTaskReviewRows {
    Sync-TaskReviewSelectionFromVisualGrid
    $Rows = @()
    if ($null -eq $Script:TaskReviewRows) { return $Rows }
    foreach ($Row in @($Script:TaskReviewRows)) {
        if ($Row.IsSelected -eq $true) { $Rows += $Row }
    }
    return $Rows
}

function Set-AllTaskReviewRowsSelected {
    param([bool]$Selected)

    if ($null -eq $Script:TaskReviewRows) { return }

    $Script:SkipTaskReviewVisualSync = $true
    try {
        foreach ($Row in @($Script:TaskReviewRows)) {
            $Row.IsSelected = $Selected
            if ($Selected -eq $true) {
                if ([string]$Row.Status -eq "Not selected") { $Row.Status = "Ready" }
            }
            else {
                $Row.Status = "Not selected"
            }
        }
        Sync-TaskReviewEditBox
        Update-TaskReviewSelectionSummary
        Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
        Refresh-TaskReviewGrid
    }
    finally {
        $Script:SkipTaskReviewVisualSync = $false
    }
}

function Update-TaskReviewSelectionSummary {
    Sync-TaskReviewSelectionFromVisualGrid
    $Total = 0
    $Selected = 0
    $CostTotal = 0.0
    $HasCost = $false
    $TimeTotal = 0
    $TokensTotal = 0
    $AllCostTotal = 0.0
    $AllHasCost = $false
    $AllTimeTotal = 0
    $AllTokensTotal = 0
    $HasActualRows = $false

    if ($null -ne $Script:TaskReviewRows) {
        foreach ($Row in @($Script:TaskReviewRows)) {
            $Total++
            if ([string]$Row.Status -eq "Done" -or [string]$Row.Status -eq "Failed") { $HasActualRows = $true }
            if ($null -ne $Row.EstCostValue) { $AllCostTotal += [double]$Row.EstCostValue; $AllHasCost = $true }
            if ($null -ne $Row.EstTimeSec) { $AllTimeTotal += [int]$Row.EstTimeSec }
            if ($null -ne $Row.EstTokens -and -not [string]::IsNullOrWhiteSpace([string]$Row.EstTokens)) { $AllTokensTotal += [int]$Row.EstTokens }
            if ($Row.IsSelected -eq $true) {
                $Selected++
                if ($null -ne $Row.EstCostValue) { $CostTotal += [double]$Row.EstCostValue; $HasCost = $true }
                if ($null -ne $Row.EstTimeSec) { $TimeTotal += [int]$Row.EstTimeSec }
                if ($null -ne $Row.EstTokens -and -not [string]::IsNullOrWhiteSpace([string]$Row.EstTokens)) { $TokensTotal += [int]$Row.EstTokens }
                if ([string]$Row.Status -eq "Not selected") { $Row.Status = "Ready" }
            }
            else {
                $Row.Status = "Not selected"
            }
        }
    }

    $CostText = "~n/a"
    if ($HasCost -eq $true) {
        if ($HasActualRows -eq $true) { $CostText = Format-RailCost -Value $CostTotal }
        else { $CostText = "~" + (Format-CostUsdIls -Value $CostTotal) }
    }
    $AllCostText = "~n/a"
    if ($AllHasCost -eq $true) {
        if ($HasActualRows -eq $true) { $AllCostText = Format-RailCost -Value $AllCostTotal }
        else { $AllCostText = "~" + (Format-CostUsdIls -Value $AllCostTotal) }
    }
    $TimeText = "~" + $TimeTotal + "s"
    if ($TimeTotal -ge 60) { $TimeText = "~" + [Math]::Round($TimeTotal / 60.0, 1) + "m" }
    if ($HasActualRows -eq $true) {
        if ($TimeTotal -ge 60) { $TimeText = [string]([Math]::Round($TimeTotal / 60.0, 1)) + "m" }
        else { $TimeText = [string]([Math]::Round($TimeTotal, 1)) + "s" }
    }
    $AllTimeText = "~" + $AllTimeTotal + "s"
    if ($AllTimeTotal -ge 60) { $AllTimeText = "~" + [Math]::Round($AllTimeTotal / 60.0, 1) + "m" }
    if ($HasActualRows -eq $true) {
        if ($AllTimeTotal -ge 60) { $AllTimeText = [string]([Math]::Round($AllTimeTotal / 60.0, 1)) + "m" }
        else { $AllTimeText = [string]([Math]::Round($AllTimeTotal, 1)) + "s" }
    }
    $TokensText = "~" + ("{0:N0}" -f $TokensTotal)
    $AllTokensText = "~" + ("{0:N0}" -f $AllTokensTotal)
    if ($HasActualRows -eq $true) {
        $TokensText = "{0:N0}" -f $TokensTotal
        $AllTokensText = "{0:N0}" -f $AllTokensTotal
    }

    if ($null -ne $Script:Ctl_LblTaskReviewSummary) {
        if ($Total -gt 0) {
            $SummaryLabel = "Estimate"
            if ($HasActualRows -eq $true) { $SummaryLabel = "Actual" }
            $Script:Ctl_LblTaskReviewSummary.Text = ($Total.ToString() + " detected | " + $Selected.ToString() + " selected | " + $SummaryLabel + " " + $CostText + " / " + $TimeText + " / " + $TokensText + " tokens | All " + $AllCostText)
        }
        else { $Script:Ctl_LblTaskReviewSummary.Text = "No tasks detected yet" }
    }
    if ($null -ne $Script:Ctl_LblCostEstimate) {
        if ($Total -gt 0) {
            if ($HasActualRows -eq $true) { $Script:Ctl_LblCostEstimate.Text = "Actual: selected " + $CostText + " | all " + $AllCostText }
            else { $Script:Ctl_LblCostEstimate.Text = "Pre-run est: selected " + $CostText + " | all " + $AllCostText }
        }
        else { $Script:Ctl_LblCostEstimate.Text = "Pre-run est: -" }
    }
    if ($null -ne $Script:Ctl_ChkTaskRunAll) {
        if ($Total -le 0) {
            $Script:Ctl_ChkTaskRunAll.IsEnabled = $false
            $Script:Ctl_ChkTaskRunAll.IsChecked = $false
        }
        else {
            $Script:Ctl_ChkTaskRunAll.IsEnabled = $true
            if ($Selected -eq 0) { $Script:Ctl_ChkTaskRunAll.IsChecked = $false }
            elseif ($Selected -eq $Total) { $Script:Ctl_ChkTaskRunAll.IsChecked = $true }
            else { $Script:Ctl_ChkTaskRunAll.IsChecked = $null }
        }
    }

    $Script:LastTaskReviewEstimate = [PSCustomObject]@{
        Total         = $Total
        Selected      = $Selected
        CostText      = $CostText
        CostValue     = $CostTotal
        TimeText      = $TimeText
        TimeSec       = $TimeTotal
        TokensText    = $TokensText
        TokensValue   = $TokensTotal
        AllCostText   = $AllCostText
        AllCostValue  = $AllCostTotal
        AllTimeText   = $AllTimeText
        AllTimeSec    = $AllTimeTotal
        AllTokensText = $AllTokensText
        AllTokensValue = $AllTokensTotal
        HasActualRows = $HasActualRows
    }
    Update-RightRailFromPreview
    Refresh-TaskReviewGrid
    Update-RunButtonState
}

function Set-TaskReviewRows {
    param([object]$Rows)

    $NormalizedRows = New-Object System.Collections.ArrayList
    if ($null -ne $Rows) {
        if ($Rows -is [System.Collections.IEnumerable] -and -not ($Rows -is [string])) {
            foreach ($Row in $Rows) {
                if ($null -ne $Row) { [void]$NormalizedRows.Add($Row) }
            }
        }
        else {
            [void]$NormalizedRows.Add($Rows)
        }
    }

    $Script:TaskReviewRows = $NormalizedRows
    if ($null -ne $Script:Ctl_TasksGrid) { $Script:Ctl_TasksGrid.ItemsSource = $Script:TaskReviewRows }
    if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
        $Script:Ctl_TasksGrid.SelectedIndex = 0
        Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
    }
    else {
        Update-TaskDetailsPanel -Row $null
    }
    Sync-TaskReviewEditBox
    Update-TaskReviewSelectionSummary
}

function Update-TasksGridFromSummary {
    param([string]$RunFolderPath)

    $SummaryPath = Join-Path $RunFolderPath "task_results_summary.json"
    $SummaryText = Get-FileTextSafe -Path $SummaryPath

    if ([string]::IsNullOrWhiteSpace($SummaryText)) {
        return $false
    }

    $Summary = $null
    try {
        $Summary = $SummaryText | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return $false
    }

    if ($null -eq $Summary) {
        return $false
    }

    $TaskDurationById = @{}
    $StageMetricsPath = Join-Path $RunFolderPath "stage_metrics.csv"
    if (Test-Path -LiteralPath $StageMetricsPath) {
        try {
            foreach ($StageItem in @(Import-Csv -LiteralPath $StageMetricsPath)) {
                if ([string]$StageItem.StageName -eq "Task_Total") {
                    $TaskDurationById[[string]$StageItem.TaskId] = [double]$StageItem.DurationSeconds
                }
            }
        }
        catch {
            $TaskDurationById = @{}
        }
    }

    $Rows = @()
    foreach ($Item in @($Summary)) {
        $StatusText = "Done"
        if ([string]$Item.Success -eq "False") { $StatusText = "Failed" }
        $CostValue = $null
        if ($null -ne $Item.EstimatedCostUsd -and -not [string]::IsNullOrWhiteSpace([string]$Item.EstimatedCostUsd)) {
            $CostValue = [double]$Item.EstimatedCostUsd
        }
        $CostText = ""
        if ($null -ne $CostValue) { $CostText = Format-CostUsdIls -Value $CostValue }
        $TokenText = ""
        if ($null -ne $Item.TotalTokens -and -not [string]::IsNullOrWhiteSpace([string]$Item.TotalTokens)) {
            $TokenText = "{0:N0}" -f ([double]$Item.TotalTokens)
        }
        $TimeSec = 0
        $TimeText = ""
        $TaskIdKey = [string]$Item.TaskId
        if ($TaskDurationById.ContainsKey($TaskIdKey)) {
            $TimeSec = [double]$TaskDurationById[$TaskIdKey]
            if ($TimeSec -ge 60) { $TimeText = ([string]([Math]::Round($TimeSec / 60.0, 1)) + "m") }
            else { $TimeText = ([string]([Math]::Round($TimeSec, 1)) + "s") }
        }
        $Rows += [PSCustomObject]@{
            IsSelected   = $true
            Id           = $Item.TaskId
            Title        = $Item.TaskTitle
            Type         = $Item.TaskType
            TypeLabel    = Get-GuiTaskTypeLabel -TaskType $Item.TaskType
            WorkMode     = $Item.WorkMode
            Excerpt      = Get-GuiTaskExcerpt -Text $Item.TaskTitle
            PromptText   = $Item.TaskTitle
            Status       = $StatusText
            Route        = ""
            Success      = [string]$Item.Success
            Answers      = $Item.AnswerCount
            JudgeMode    = $Item.JudgeMode
            Completeness = $Item.Completeness
            EstCost      = $CostText
            EstCostValue = $CostValue
            EstTime      = $TimeText
            EstTimeSec   = $TimeSec
            EstTokens    = $TokenText
            Tokens       = $Item.TotalTokens
            Cost         = $Item.EstimatedCostUsd
            Error        = $Item.Error
            TaskFolder   = $Item.TaskFolder
        }
    }

    Set-TaskReviewRows -Rows $Rows
    return $true
}

function Format-AlignedTable {
    # Builds a monospace, column-aligned text table (header + separator + rows). The Metrics
    # TextBox is Consolas + NoWrap + horizontal scroll, so aligned columns line up cleanly.
    # $Rows is an array of string arrays (one per row), each the same length as $Headers.
    param(
        [string[]]$Headers,
        [object[]]$Rows,
        [bool[]]$RightAlign
    )

    $ColCount = @($Headers).Count
    $Widths = New-Object 'int[]' $ColCount
    for ($c = 0; $c -lt $ColCount; $c++) { $Widths[$c] = ([string]$Headers[$c]).Length }
    foreach ($Row in @($Rows)) {
        for ($c = 0; $c -lt $ColCount; $c++) {
            $Cell = [string]$Row[$c]
            if ($Cell.Length -gt $Widths[$c]) { $Widths[$c] = $Cell.Length }
        }
    }

    $Out = @()
    $HeaderCells = @()
    $SepCells = @()
    for ($c = 0; $c -lt $ColCount; $c++) {
        $H = [string]$Headers[$c]
        if ($RightAlign[$c] -eq $true) { $HeaderCells += $H.PadLeft($Widths[$c]) }
        else { $HeaderCells += $H.PadRight($Widths[$c]) }
        $SepCells += ("-" * $Widths[$c])
    }
    $Out += ($HeaderCells -join "  ")
    $Out += ($SepCells -join "  ")

    foreach ($Row in @($Rows)) {
        $RowCells = @()
        for ($c = 0; $c -lt $ColCount; $c++) {
            $Cell = [string]$Row[$c]
            if ($RightAlign[$c] -eq $true) { $RowCells += $Cell.PadLeft($Widths[$c]) }
            else { $RowCells += $Cell.PadRight($Widths[$c]) }
        }
        $Out += ($RowCells -join "  ")
    }

    return $Out
}

function Get-CostRecommendations {
    # Offline cost advice (v0.8.64): pure heuristics over THIS run's metric JSON plus the totals of
    # recent prior runs. No API call - everything read from files the child already wrote. Returns @()
    # when there is no cost/task data yet (in-progress or empty run folder) so the caller skips the section.
    param([string]$RunFolderPath)

    $Timing = $null
    $TimingText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "timing_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TimingText)) {
        try { $Timing = $TimingText | ConvertFrom-Json -ErrorAction Stop } catch { $Timing = $null }
    }

    $CostRole = $null
    $CostRoleText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_summary_by_role.json")
    if (-not [string]::IsNullOrWhiteSpace($CostRoleText)) {
        try { $CostRole = $CostRoleText | ConvertFrom-Json -ErrorAction Stop } catch { $CostRole = $null }
    }

    $TaskSummary = $null
    $TaskSummaryText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "task_results_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TaskSummaryText)) {
        try { $TaskSummary = $TaskSummaryText | ConvertFrom-Json -ErrorAction Stop } catch { $TaskSummary = $null }
    }

    $CostWarn = $null
    $CostWarnText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_warnings.json")
    if (-not [string]::IsNullOrWhiteSpace($CostWarnText)) {
        try { $CostWarn = $CostWarnText | ConvertFrom-Json -ErrorAction Stop } catch { $CostWarn = $null }
    }

    if ($null -eq $CostRole -and $null -eq $TaskSummary -and $null -eq $Timing) {
        return @()
    }

    $TotalCost = 0.0
    if ($null -ne $Timing -and $null -ne $Timing.EstimatedCostUsd) {
        $TotalCost = [double]$Timing.EstimatedCostUsd
    }
    elseif ($null -ne $CostRole) {
        foreach ($r in @($CostRole)) { $TotalCost += [double]$r.EstimatedCostUsd }
    }

    $Recs = @()

    # 1. Compare to the average of recent prior runs (reads each prior Run_* timing total).
    $History = @()
    try {
        $RunRoot = Split-Path -Parent $RunFolderPath
        $CurrentName = Split-Path -Leaf $RunFolderPath
        if (-not [string]::IsNullOrWhiteSpace($RunRoot) -and (Test-Path -LiteralPath $RunRoot)) {
            $PastRuns = @(Get-ChildItem -Path $RunRoot -Directory -Filter "Run_*" -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -ne $CurrentName } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 10)
            foreach ($PastRun in $PastRuns) {
                $PastText = Get-FileTextSafe -Path (Join-Path $PastRun.FullName "timing_summary.json")
                if (-not [string]::IsNullOrWhiteSpace($PastText)) {
                    $PastTiming = $null
                    try { $PastTiming = $PastText | ConvertFrom-Json -ErrorAction Stop } catch { $PastTiming = $null }
                    if ($null -ne $PastTiming -and $null -ne $PastTiming.EstimatedCostUsd) {
                        $History += [double]$PastTiming.EstimatedCostUsd
                    }
                }
            }
        }
    }
    catch {
        $History = @()
    }

    if (@($History).Count -gt 0) {
        $Avg = ($History | Measure-Object -Average).Average
        $Recs += ("[i] This run $" + ("{0:0.######}" -f $TotalCost) + " vs average of the last " + @($History).Count + " run(s) $" + ("{0:0.######}" -f $Avg) + ".")
        if ($Avg -gt 0) {
            $Delta = (($TotalCost - $Avg) / $Avg) * 100.0
            if ($Delta -ge 25) {
                $Recs += ("[!] " + ("{0:0}" -f $Delta) + "% above your recent average - check the Task Summary for an outlier task or the strong judge on a light task.")
            }
            elseif ($Delta -le -25) {
                $Recs += ("[ok] " + ("{0:0}" -f [Math]::Abs($Delta)) + "% below your recent average.")
            }
        }
    }
    else {
        $Recs += "[i] No previous runs to compare against yet."
    }

    # 2. Judge share of cost - only worth flagging if a Full/strong judge actually ran.
    $JudgeCost = 0.0
    $AnswerCost = 0.0
    foreach ($r in @($CostRole)) {
        if ([string]$r.Role -eq "Judge") { $JudgeCost = [double]$r.EstimatedCostUsd }
        elseif ([string]$r.Role -eq "Answer") { $AnswerCost = [double]$r.EstimatedCostUsd }
    }
    $RoleTotal = $JudgeCost + $AnswerCost
    $AnyFullJudge = $false
    foreach ($t in @($TaskSummary)) {
        if ([string]$t.JudgeMode -match "Full") { $AnyFullJudge = $true }
    }
    if ($RoleTotal -gt 0 -and $AnyFullJudge) {
        $JudgePct = ($JudgeCost / $RoleTotal) * 100.0
        if ($JudgePct -ge 60) {
            $Recs += ("[!] The Judge is " + ("{0:0}" -f $JudgePct) + "% of this run's cost. For light tasks, turn on 'Use review judge for light checks' - the strong judge is only needed for Script-mode Full comparisons.")
        }
    }

    # 3. Strong judge on a light task type (a routing/override that can usually be downgraded).
    $LightTypes = @("simple", "technical", "documentation", "creative")
    $StrongOnLight = @()
    foreach ($t in @($TaskSummary)) {
        if (($LightTypes -contains ([string]$t.TaskType)) -and ([string]$t.JudgeMode -match "Full")) {
            $StrongOnLight += $t
        }
    }
    if (@($StrongOnLight).Count -gt 0) {
        $Ids = (@($StrongOnLight | ForEach-Object { [string]$_.TaskId }) -join ", ")
        $Recs += ("[!] " + @($StrongOnLight).Count + " light task(s) (id " + $Ids + ") used the Full/strong judge. A Work Mode = Review override or the review judge would cut their cost.")
    }

    # 4. One task dominating the run cost.
    if ($TotalCost -gt 0) {
        $Ranked = @(@($TaskSummary) | Sort-Object { [double]$_.EstimatedCostUsd } -Descending)
        if (@($Ranked).Count -ge 2) {
            $Top = $Ranked[0]
            $TopPct = ([double]$Top.EstimatedCostUsd / $TotalCost) * 100.0
            if ($TopPct -ge 50) {
                $TopTitle = [string]$Top.TaskTitle
                if ($TopTitle.Length -gt 40) { $TopTitle = $TopTitle.Substring(0, 37) + "..." }
                $Recs += ("[i] Task " + [string]$Top.TaskId + " (" + $TopTitle + ") is " + ("{0:0}" -f $TopPct) + "% of this run - drop it on runs where you do not need it.")
            }
        }
    }

    # 5. Models with no configured price -> the totals understate real spend.
    if ($null -ne $CostWarn -and @($CostWarn).Count -gt 0) {
        $Models = (@(@($CostWarn) | ForEach-Object { [string]$_.Model }) | Sort-Object -Unique) -join ", "
        $Recs += ("[!] No price configured for: " + $Models + ". The costs above UNDERSTATE real spend - add these to CostPer1MTokens in MultiLLM.config.json.")
    }

    if (@($Recs).Count -eq 0) {
        $Recs += "[ok] Nothing stands out - costs look reasonable for this run."
    }

    return $Recs
}

function Clear-MetricsTab {
    # Reset every control on the Cost & Metrics tab (recommendations text, the three DataGrids,
    # and the timing/warnings text box) when starting or clearing a run (v0.8.66).
    if ($null -ne $Script:Ctl_MetricsRecBox)   { $Script:Ctl_MetricsRecBox.Text = "Run a prompt to see cost recommendations." }
    if ($null -ne $Script:Ctl_MetricsBox)      { $Script:Ctl_MetricsBox.Text = "" }
    if ($null -ne $Script:Ctl_CostRoleGrid)    { $Script:Ctl_CostRoleGrid.ItemsSource = $null }
    if ($null -ne $Script:Ctl_CostModelGrid)   { $Script:Ctl_CostModelGrid.ItemsSource = $null }
    if ($null -ne $Script:Ctl_MetricsTaskGrid) { $Script:Ctl_MetricsTaskGrid.ItemsSource = $null }
}

function Update-MetricsTabFromRun {
    # v0.8.66: Cost by Role, Cost by Model, and the Task Summary now render as real DataGrids (normal
    # GUI view) instead of monospace text. Recommendations stay as text at the top; timing + warnings
    # stay as text at the bottom. All read-only over the run-folder JSON the child already wrote.
    param([string]$RunFolderPath)

    $UsdFmt = "0.######"

    # --- Recommendations (offline heuristics; see Get-CostRecommendations) ---
    $RecLines = @(Get-CostRecommendations -RunFolderPath $RunFolderPath)
    if ($null -ne $Script:Ctl_MetricsRecBox) {
        if (@($RecLines).Count -gt 0) {
            $Script:Ctl_MetricsRecBox.Text = ($RecLines -join [Environment]::NewLine)
        }
        else {
            $Script:Ctl_MetricsRecBox.Text = "No cost data for this run yet."
        }
    }

    # --- Cost by Role grid ---
    $CostRole = $null
    $CostRoleText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_summary_by_role.json")
    if (-not [string]::IsNullOrWhiteSpace($CostRoleText)) {
        try { $CostRole = $CostRoleText | ConvertFrom-Json -ErrorAction Stop } catch { $CostRole = $null }
    }
    if ($null -ne $Script:Ctl_CostRoleGrid) {
        $RoleRows = @()
        foreach ($Item in @($CostRole)) {
            if ($null -eq $Item) { continue }
            $RoleRows += [PSCustomObject]@{
                Role            = [string]$Item.Role
                RequestCount    = $Item.RequestCount
                DurationSeconds = $Item.DurationSeconds
                InputTokens     = $Item.InputTokens
                OutputTokens    = $Item.OutputTokens
                TotalTokens     = $Item.TotalTokens
                CostText        = "$" + ($UsdFmt -f [double]$Item.EstimatedCostUsd)
            }
        }
        $Script:Ctl_CostRoleGrid.ItemsSource = $RoleRows
    }

    # --- Cost by Model grid ---
    $CostModel = $null
    $CostModelText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_summary_by_model.json")
    if (-not [string]::IsNullOrWhiteSpace($CostModelText)) {
        try { $CostModel = $CostModelText | ConvertFrom-Json -ErrorAction Stop } catch { $CostModel = $null }
    }
    if ($null -ne $Script:Ctl_CostModelGrid) {
        $ModelRows = @()
        foreach ($Item in @($CostModel)) {
            if ($null -eq $Item) { continue }
            $ModelRows += [PSCustomObject]@{
                Provider        = [string]$Item.Provider
                Model           = [string]$Item.Model
                Roles           = [string]$Item.Roles
                RequestCount    = $Item.RequestCount
                DurationSeconds = $Item.DurationSeconds
                InputTokens     = $Item.InputTokens
                OutputTokens    = $Item.OutputTokens
                TotalTokens     = $Item.TotalTokens
                CostText        = "$" + ($UsdFmt -f [double]$Item.EstimatedCostUsd)
            }
        }
        $Script:Ctl_CostModelGrid.ItemsSource = $ModelRows
    }

    # --- Task summary grid ---
    $TaskSummary = $null
    $TaskSummaryText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "task_results_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TaskSummaryText)) {
        try { $TaskSummary = $TaskSummaryText | ConvertFrom-Json -ErrorAction Stop } catch { $TaskSummary = $null }
    }
    if ($null -ne $Script:Ctl_MetricsTaskGrid) {
        $TaskRows = @()
        foreach ($Item in @($TaskSummary)) {
            if ($null -eq $Item) { continue }
            $Comp = "OK"
            if ($Item.CompletenessWarning -eq $true) { $Comp = "WARN" }
            $TaskRows += [PSCustomObject]@{
                TaskId         = $Item.TaskId
                TaskType       = [string]$Item.TaskType
                WorkMode       = [string]$Item.WorkMode
                Success        = $Item.Success
                AnswerCount    = $Item.AnswerCount
                JudgeMode      = [string]$Item.JudgeMode
                JudgeModelUsed = [string]$Item.JudgeModelUsed
                Completeness   = $Comp
                TotalTokens    = $Item.TotalTokens
                CostText       = "$" + ($UsdFmt -f [double]$Item.EstimatedCostUsd)
                Title          = [string]$Item.TaskTitle
            }
        }
        $Script:Ctl_MetricsTaskGrid.ItemsSource = $TaskRows
    }

    # --- Timing + warnings (text) ---
    $Lines = @()

    $Timing = $null
    $TimingText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "timing_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TimingText)) {
        try { $Timing = $TimingText | ConvertFrom-Json -ErrorAction Stop } catch { $Timing = $null }
    }
    if ($null -ne $Timing) {
        $Lines += "TIMING SUMMARY"
        $Lines += "=============="
        foreach ($Prop in $Timing.PSObject.Properties) {
            if ($Prop.Name -ne "CostByRole" -and $Prop.Name -ne "CostByModel") {
                $Lines += ("{0,-28} : {1}" -f $Prop.Name, $Prop.Value)
            }
        }
        $Lines += ""
    }

    $CostWarn = $null
    $CostWarnText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_warnings.json")
    if (-not [string]::IsNullOrWhiteSpace($CostWarnText)) {
        try { $CostWarn = $CostWarnText | ConvertFrom-Json -ErrorAction Stop } catch { $CostWarn = $null }
    }
    if ($null -ne $CostWarn -and @($CostWarn).Count -gt 0) {
        $Lines += "COST WARNINGS"
        $Lines += "============="
        foreach ($Item in @($CostWarn)) {
            $Lines += ("[WARN] {0}|{1} : {2}" -f $Item.Provider, $Item.Model, $Item.Reason)
            $Lines += ("{0,-28} : {1}" -f "Roles", $Item.Roles)
            $Lines += ("{0,-28} : {1}" -f "Requests", $Item.RequestCount)
            $Lines += ("{0,-28} : {1}" -f "InputTokens", $Item.InputTokens)
            $Lines += ("{0,-28} : {1}" -f "OutputTokens", $Item.OutputTokens)
            $Lines += ""
        }
    }

    $CompWarnText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "completeness_warnings.json")
    if (-not [string]::IsNullOrWhiteSpace($CompWarnText)) {
        $Lines += "COMPLETENESS WARNINGS (raw JSON)"
        $Lines += "--------------------------------"
        $Lines += $CompWarnText
    }

    if ($null -ne $Script:Ctl_MetricsBox) {
        $Script:Ctl_MetricsBox.Text = ($Lines -join [Environment]::NewLine)
    }
}

function ConvertTo-HtmlText {
    # Minimal HTML escaping so run data (titles, model ids, warnings) can never break the markup.
    param([string]$Text)
    if ($null -eq $Text) { return "" }
    $t = $Text -replace "&", "&amp;"
    $t = $t -replace "<", "&lt;"
    $t = $t -replace ">", "&gt;"
    $t = $t -replace '"', "&quot;"
    return $t
}

function New-RunHtmlReport {
    # v0.8.67: build a self-contained, modern-looking HTML cost/metrics report for a run, written next
    # to the run output as cost_report.html. No external files, no JS, no API call - just the run-folder
    # JSON the child already wrote, rendered with inline CSS so it opens in any browser. Returns the file
    # path, or $null when the folder is missing or has no cost/task/timing data yet.
    param(
        [string]$RunFolderPath,
        [string]$ToolVersion
    )

    if ([string]::IsNullOrWhiteSpace($RunFolderPath) -or (-not (Test-Path -LiteralPath $RunFolderPath))) {
        return $null
    }

    $Timing = $null
    $TimingText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "timing_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TimingText)) {
        try { $Timing = $TimingText | ConvertFrom-Json -ErrorAction Stop } catch { $Timing = $null }
    }

    $CostRole = $null
    $CostRoleText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_summary_by_role.json")
    if (-not [string]::IsNullOrWhiteSpace($CostRoleText)) {
        try { $CostRole = $CostRoleText | ConvertFrom-Json -ErrorAction Stop } catch { $CostRole = $null }
    }

    $CostModel = $null
    $CostModelText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_summary_by_model.json")
    if (-not [string]::IsNullOrWhiteSpace($CostModelText)) {
        try { $CostModel = $CostModelText | ConvertFrom-Json -ErrorAction Stop } catch { $CostModel = $null }
    }

    $TaskSummary = $null
    $TaskSummaryText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "task_results_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TaskSummaryText)) {
        try { $TaskSummary = $TaskSummaryText | ConvertFrom-Json -ErrorAction Stop } catch { $TaskSummary = $null }
    }

    $CostWarn = $null
    $CostWarnText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "cost_warnings.json")
    if (-not [string]::IsNullOrWhiteSpace($CostWarnText)) {
        try { $CostWarn = $CostWarnText | ConvertFrom-Json -ErrorAction Stop } catch { $CostWarn = $null }
    }

    if ($null -eq $CostRole -and $null -eq $TaskSummary -and $null -eq $Timing) {
        return $null
    }

    $TotalCost = 0.0
    if ($null -ne $Timing -and $null -ne $Timing.EstimatedCostUsd) {
        $TotalCost = [double]$Timing.EstimatedCostUsd
    }
    elseif ($null -ne $CostRole) {
        foreach ($r in @($CostRole)) { $TotalCost += [double]$r.EstimatedCostUsd }
    }

    $RecLines = @(Get-CostRecommendations -RunFolderPath $RunFolderPath)
    $RunName = Split-Path -Leaf $RunFolderPath
    $GeneratedAt = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('<!DOCTYPE html>')
    [void]$sb.AppendLine('<html lang="en"><head><meta charset="utf-8">')
    [void]$sb.AppendLine('<title>Multi-LLM Prompter - Cost Report</title>')
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine('*{box-sizing:border-box;} body{font-family:"Segoe UI",Arial,sans-serif;margin:0;background:#f3f3f3;color:#1b2545;}')
    [void]$sb.AppendLine('.header{background:#0f3460;color:#fff;padding:18px 28px;} .header h1{margin:0;font-size:20px;} .header .sub{color:#b0c4de;font-size:13px;margin-top:4px;}')
    [void]$sb.AppendLine('.wrap{max-width:1100px;margin:0 auto;padding:22px 28px 44px;}')
    [void]$sb.AppendLine('.card{background:#fff;border:1px solid #d0d7de;border-radius:8px;padding:16px 18px;margin:0 0 20px;box-shadow:0 1px 3px rgba(0,0,0,.06);}')
    [void]$sb.AppendLine('h2{font-size:15px;color:#0b2545;margin:0 0 10px;}')
    [void]$sb.AppendLine('.total{font-size:34px;font-weight:700;color:#0b6a0b;} .total small{font-size:14px;color:#555;font-weight:600;}')
    [void]$sb.AppendLine('table{border-collapse:collapse;width:100%;font-size:13px;} th{background:#1f4788;color:#fff;text-align:left;padding:7px 10px;font-weight:600;}')
    [void]$sb.AppendLine('td{padding:6px 10px;border-bottom:1px solid #ececec;} tr:nth-child(even) td{background:#f2f6ff;} td.num,th.num{text-align:right;}')
    [void]$sb.AppendLine('ul.recs{list-style:none;padding:0;margin:0;} ul.recs li{padding:8px 11px;border-left:4px solid #9aa7b4;background:#f7f9fc;margin-bottom:6px;border-radius:3px;}')
    [void]$sb.AppendLine('li.warn{border-left-color:#a4262c;background:#fdecee;} li.ok{border-left-color:#0b6a0b;background:#eaf6ea;} li.info{border-left-color:#0078d7;background:#eef5fc;}')
    [void]$sb.AppendLine('.muted{color:#777;font-size:12px;} pre{white-space:pre-wrap;font-family:Consolas,monospace;font-size:12px;color:#333;margin:0;}')
    [void]$sb.AppendLine('</style></head><body>')

    [void]$sb.AppendLine('<div class="header"><h1>Multi-LLM Prompter - Cost Report</h1>')
    [void]$sb.AppendLine('<div class="sub">' + (ConvertTo-HtmlText $ToolVersion) + ' &middot; run ' + (ConvertTo-HtmlText $RunName) + ' &middot; generated ' + (ConvertTo-HtmlText $GeneratedAt) + '</div></div>')
    [void]$sb.AppendLine('<div class="wrap">')

    [void]$sb.AppendLine('<div class="card"><h2>Total estimated cost</h2><div class="total">$' + (ConvertTo-HtmlText ("{0:0.######}" -f $TotalCost)) + ' <small>USD</small></div></div>')

    if (@($RecLines).Count -gt 0) {
        [void]$sb.AppendLine('<div class="card"><h2>Cost recommendations</h2><ul class="recs">')
        foreach ($line in $RecLines) {
            $cls = "info"
            $txt = [string]$line
            if ($txt.StartsWith("[!]")) { $cls = "warn"; $txt = $txt.Substring(3).Trim() }
            elseif ($txt.StartsWith("[ok]")) { $cls = "ok"; $txt = $txt.Substring(4).Trim() }
            elseif ($txt.StartsWith("[i]")) { $cls = "info"; $txt = $txt.Substring(3).Trim() }
            [void]$sb.AppendLine('<li class="' + $cls + '">' + (ConvertTo-HtmlText $txt) + '</li>')
        }
        [void]$sb.AppendLine('</ul></div>')
    }

    if ($null -ne $CostRole -and @($CostRole).Count -gt 0) {
        [void]$sb.AppendLine('<div class="card"><h2>Cost by role</h2><table>')
        [void]$sb.AppendLine('<tr><th>Role</th><th class="num">Requests</th><th class="num">Seconds</th><th class="num">Input</th><th class="num">Output</th><th class="num">Total</th><th class="num">Cost USD</th></tr>')
        foreach ($r in @($CostRole)) {
            if ($null -eq $r) { continue }
            [void]$sb.AppendLine('<tr><td>' + (ConvertTo-HtmlText ([string]$r.Role)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$r.RequestCount)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$r.DurationSeconds)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$r.InputTokens)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$r.OutputTokens)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$r.TotalTokens)) + '</td><td class="num">$' + (ConvertTo-HtmlText ("{0:0.######}" -f [double]$r.EstimatedCostUsd)) + '</td></tr>')
        }
        [void]$sb.AppendLine('</table></div>')
    }

    if ($null -ne $CostModel -and @($CostModel).Count -gt 0) {
        [void]$sb.AppendLine('<div class="card"><h2>Cost by model</h2><table>')
        [void]$sb.AppendLine('<tr><th>Provider</th><th>Model</th><th>Roles</th><th class="num">Reqs</th><th class="num">Seconds</th><th class="num">Input</th><th class="num">Output</th><th class="num">Total</th><th class="num">Cost USD</th></tr>')
        foreach ($m in @($CostModel)) {
            if ($null -eq $m) { continue }
            [void]$sb.AppendLine('<tr><td>' + (ConvertTo-HtmlText ([string]$m.Provider)) + '</td><td>' + (ConvertTo-HtmlText ([string]$m.Model)) + '</td><td>' + (ConvertTo-HtmlText ([string]$m.Roles)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$m.RequestCount)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$m.DurationSeconds)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$m.InputTokens)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$m.OutputTokens)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$m.TotalTokens)) + '</td><td class="num">$' + (ConvertTo-HtmlText ("{0:0.######}" -f [double]$m.EstimatedCostUsd)) + '</td></tr>')
        }
        [void]$sb.AppendLine('</table></div>')
    }

    if ($null -ne $TaskSummary -and @($TaskSummary).Count -gt 0) {
        [void]$sb.AppendLine('<div class="card"><h2>Task summary</h2><table>')
        [void]$sb.AppendLine('<tr><th class="num">#</th><th>Type</th><th>Work</th><th>OK</th><th class="num">Ans</th><th>Judge</th><th>Judge Model</th><th>Compl</th><th class="num">Tokens</th><th class="num">Cost USD</th><th>Title</th></tr>')
        foreach ($t in @($TaskSummary)) {
            if ($null -eq $t) { continue }
            $Comp = "OK"
            if ($t.CompletenessWarning -eq $true) { $Comp = "WARN" }
            [void]$sb.AppendLine('<tr><td class="num">' + (ConvertTo-HtmlText ([string]$t.TaskId)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.TaskType)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.WorkMode)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.Success)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$t.AnswerCount)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.JudgeMode)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.JudgeModelUsed)) + '</td><td>' + (ConvertTo-HtmlText $Comp) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$t.TotalTokens)) + '</td><td class="num">$' + (ConvertTo-HtmlText ("{0:0.######}" -f [double]$t.EstimatedCostUsd)) + '</td><td>' + (ConvertTo-HtmlText ([string]$t.TaskTitle)) + '</td></tr>')
        }
        [void]$sb.AppendLine('</table></div>')
    }

    if ($null -ne $Timing) {
        [void]$sb.AppendLine('<div class="card"><h2>Timing summary</h2><table>')
        foreach ($p in $Timing.PSObject.Properties) {
            if ($p.Name -eq "CostByRole" -or $p.Name -eq "CostByModel") { continue }
            [void]$sb.AppendLine('<tr><td>' + (ConvertTo-HtmlText ([string]$p.Name)) + '</td><td class="num">' + (ConvertTo-HtmlText ([string]$p.Value)) + '</td></tr>')
        }
        [void]$sb.AppendLine('</table></div>')
    }

    if ($null -ne $CostWarn -and @($CostWarn).Count -gt 0) {
        [void]$sb.AppendLine('<div class="card"><h2>Cost warnings</h2><ul class="recs">')
        foreach ($w in @($CostWarn)) {
            if ($null -eq $w) { continue }
            [void]$sb.AppendLine('<li class="warn">' + (ConvertTo-HtmlText (([string]$w.Provider) + " | " + ([string]$w.Model) + " : " + ([string]$w.Reason))) + '</li>')
        }
        [void]$sb.AppendLine('</ul></div>')
    }

    $CompWarnText = Get-FileTextSafe -Path (Join-Path $RunFolderPath "completeness_warnings.json")
    if (-not [string]::IsNullOrWhiteSpace($CompWarnText)) {
        [void]$sb.AppendLine('<div class="card"><h2>Completeness warnings (raw)</h2><pre>' + (ConvertTo-HtmlText $CompWarnText) + '</pre></div>')
    }

    [void]$sb.AppendLine('<div class="muted">Generated offline by Multi-LLM Prompter ' + (ConvertTo-HtmlText $ToolVersion) + ' from ' + (ConvertTo-HtmlText $RunFolderPath) + '</div>')
    [void]$sb.AppendLine('</div></body></html>')

    $OutPath = Join-Path $RunFolderPath "cost_report.html"
    $Utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutPath, $sb.ToString(), $Utf8NoBom)
    return $OutPath
}

function Complete-GuiRun {
    param([int]$ExitCode)

    if ($null -ne $Script:PollTimer) {
        $Script:PollTimer.Stop()
    }

    Set-GuiBusy -Busy $false

    $FinalPath = Join-Path $Script:CurrentRunFolder "final_answer.md"
    $Script:CurrentFinalAnswerPath = $FinalPath
    $FinalText = Get-FileTextSafe -Path $FinalPath

    $SummaryLoaded = Update-TasksGridFromSummary -RunFolderPath $Script:CurrentRunFolder
    Update-MetricsTabFromRun -RunFolderPath $Script:CurrentRunFolder
    $StatusDone = "Done"
    $TimingForStatusText = Get-FileTextSafe -Path (Join-Path $Script:CurrentRunFolder "timing_summary.json")
    if (-not [string]::IsNullOrWhiteSpace($TimingForStatusText)) {
        $TimingForStatus = $null
        try {
            $TimingForStatus = $TimingForStatusText | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            $TimingForStatus = $null
        }
        if ($null -ne $TimingForStatus) {
            $StatusDone = "Done | Tasks " + $TimingForStatus.TaskCount + " | Tokens " + $TimingForStatus.TotalTokens + " | Est. " + '$' + $TimingForStatus.EstimatedCostUsd
        }
    }

    $TranscriptFile = Join-Path $Script:CurrentRunFolder "console_transcript.txt"
    $Script:Ctl_RunLogBox.Text = Get-FileTextSafe -Path $TranscriptFile -MaxChars 40000
    $Script:Ctl_RunLogBox.ScrollToEnd()

    $FinalFound = (-not [string]::IsNullOrWhiteSpace($FinalText))
    $Outcome = "Failed"

    if ($ExitCode -eq 0 -and $FinalFound -eq $true) {
        $Outcome = "Completed"
        $Script:Ctl_FinalBox.Text = $FinalText
        [void](Select-MainTab -Header "Full Answer")
        Add-GuiLog -Tag "OK" -Message ("Run finished. Final answer loaded from " + $FinalPath)
        Set-GuiStatus $StatusDone

        $Script:CurrentImprovedPrompt = Get-ImprovedPromptFromFinal -FinalText $FinalText
        if (-not [string]::IsNullOrWhiteSpace($Script:CurrentImprovedPrompt)) {
            $Script:Ctl_BtnImproved.IsEnabled = $true
            Add-GuiLog -Tag "INFO" -Message "Improved prompt available (Improved Prompt button)."
        }

        if ($Script:Ctl_ChkOpenNotepad.IsChecked -eq $true) {
            Start-Process notepad.exe $FinalPath
        }
        if ($Script:Ctl_ChkOpenFolder.IsChecked -eq $true) {
            Start-Process explorer.exe $Script:CurrentRunFolder
        }
    }
    else {
        if ($ExitCode -eq 0) {
            $Outcome = "CompletedNoFinal"
        }
        [void](Select-MainTab -Header "Run Log")
        Add-GuiLog -Tag "ERROR" -Message ("Run failed or produced no final answer. Exit code: " + $ExitCode + ". See Run Log tab and " + $Script:CurrentRunFolder)
        Set-GuiStatus "Failed"
    }

    if ($SummaryLoaded -eq $false) {
        Add-GuiLog -Tag "WARN" -Message "task_results_summary.json was not found or did not parse."
    }

    Set-RunCompleteSignal -Success ($Outcome -eq "Completed")

    Write-GuiRunReport -Outcome $Outcome -ExitCode $ExitCode -FinalAnswerFound $FinalFound -SummaryLoaded $SummaryLoaded

    $Script:ChildProcess = $null
    Update-SidebarRecentRuns
    Update-RightRailFromRun -RunFolderPath $Script:CurrentRunFolder -StatusText $Outcome
}

function Open-PastRun {
    param([string]$RunFolderPath)

    if ([string]::IsNullOrWhiteSpace($RunFolderPath)) { return }
    if (-not (Test-Path -LiteralPath $RunFolderPath)) {
        Add-GuiLog -Tag "WARN" -Message ("Run folder not found: " + $RunFolderPath)
        Set-GuiStatus "That run folder no longer exists"
        Update-SidebarRecentRuns
        return
    }
    if ($Script:IsBusy -eq $true) {
        Add-GuiLog -Tag "WARN" -Message "A run is in progress - stop or finish it before loading a past run."
        Set-GuiStatus "Cannot load a past run while a run is in progress"
        return
    }

    $RunName = Split-Path -Path $RunFolderPath -Leaf
    $Script:CurrentRunFolder = $RunFolderPath

    $FinalPath = Join-Path $RunFolderPath "final_answer.md"
    $Script:CurrentFinalAnswerPath = $FinalPath
    $FinalText = Get-FileTextSafe -Path $FinalPath

    $SummaryLoaded = Update-TasksGridFromSummary -RunFolderPath $RunFolderPath
    Update-MetricsTabFromRun -RunFolderPath $RunFolderPath

    $TranscriptFile = Join-Path $RunFolderPath "console_transcript.txt"
    if ($null -ne $Script:Ctl_RunLogBox) {
        $Script:Ctl_RunLogBox.Text = Get-FileTextSafe -Path $TranscriptFile -MaxChars 40000
        $Script:Ctl_RunLogBox.ScrollToEnd()
    }

    if (-not [string]::IsNullOrWhiteSpace($FinalText)) {
        if ($null -ne $Script:Ctl_FinalBox) { $Script:Ctl_FinalBox.Text = $FinalText }
        $Script:CurrentImprovedPrompt = Get-ImprovedPromptFromFinal -FinalText $FinalText
        if ($null -ne $Script:Ctl_BtnImproved) {
            $Script:Ctl_BtnImproved.IsEnabled = (-not [string]::IsNullOrWhiteSpace($Script:CurrentImprovedPrompt))
        }
        [void](Select-MainTab -Header "Full Answer")
    }
    else {
        if ($null -ne $Script:Ctl_FinalBox) { $Script:Ctl_FinalBox.Text = "(This run has no final_answer.md - see the Tasks and Run Log tabs.)" }
        if ($null -ne $Script:Ctl_BtnImproved) { $Script:Ctl_BtnImproved.IsEnabled = $false }
        [void](Select-MainTab -Header "Tasks")
    }

    Update-RightRailFromRun -RunFolderPath $RunFolderPath -StatusText "Loaded"
    if ($null -ne $Script:Ctl_HdrRunFolder) { $Script:Ctl_HdrRunFolder.Text = $RunName }
    Set-GuiStatus ("Loaded past run: " + $RunName)
    Add-GuiLog -Tag "INFO" -Message ("Loaded past run from " + $RunFolderPath + " (summaryLoaded=" + $SummaryLoaded + ")")
}

function Get-ImprovedPromptFromFinal {
    param([string]$FinalText)

    if ([string]::IsNullOrWhiteSpace($FinalText)) {
        return ""
    }

    $Marker = "## Improved Prompt"
    $Idx = $FinalText.LastIndexOf($Marker)

    if ($Idx -lt 0) {
        return ""
    }

    return $FinalText.Substring($Idx + $Marker.Length).Trim()
}

function Show-TaskDetailsWindow {
    param(
        [string]$WindowTitle,
        [string]$BodyText
    )

    if ([string]::IsNullOrWhiteSpace($BodyText)) {
        Add-GuiLog -Tag "WARN" -Message "No content available for this task."
        return
    }

    # Standalone here-string window: inline styles only, no StaticResource references.
    $TaskXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Task Details"
        Width="860" Height="600" MinWidth="600" MinHeight="400"
        WindowStartupLocation="CenterOwner" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="11">
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="52">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0">
        <TextBlock Text="&#x1F4C4;" FontSize="20" Foreground="White" Margin="0,0,10,0" VerticalAlignment="Center"/>
        <TextBlock Name="TaskHdrTitle" Text="TASK DETAILS" FontSize="13" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
      </StackPanel>
    </Border>
    <Border DockPanel.Dock="Bottom" Background="#F3F3F3" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC" Padding="8,6">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="TaskBtnCopy" Content="&#x1F4CB; Copy" Width="100" Height="30"
                Background="#0078D7" Foreground="White" Margin="0,0,6,0"/>
        <Button Name="TaskBtnClose" Content="&#x2716; Close" Width="90" Height="30"/>
      </StackPanel>
    </Border>
    <TextBox Name="TaskTextBox" Margin="8" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12" Background="White"/>
  </DockPanel>
</Window>
"@

    $TaskWindow = $null
    try {
        $TaskXmlDoc = New-Object System.Xml.XmlDocument
        $TaskXmlDoc.LoadXml($TaskXaml)
        $TaskReader = New-Object System.Xml.XmlNodeReader($TaskXmlDoc)
        $TaskWindow = [System.Windows.Markup.XamlReader]::Load($TaskReader)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to load Task Details window: " + $_.Exception.Message)
        return
    }

    $TaskWindow.Owner = $GuiWindow
    $TaskWindow.Title = $WindowTitle

    $TaskHdrTitle = $TaskWindow.FindName("TaskHdrTitle")
    $TaskTextBox  = $TaskWindow.FindName("TaskTextBox")
    $TaskBtnCopy  = $TaskWindow.FindName("TaskBtnCopy")
    $TaskBtnClose = $TaskWindow.FindName("TaskBtnClose")

    $TaskHdrTitle.Text = $WindowTitle.ToUpper()
    $TaskTextBox.Text = $BodyText

    $TaskBtnCopy.Add_Click({
        try {
            Set-Clipboard -Value $TaskTextBox.Text
            Add-GuiLog -Tag "OK" -Message "Task content copied to clipboard."
        }
        catch {
            Add-GuiLog -Tag "ERROR" -Message ("Clipboard error: " + $_.Exception.Message)
        }
    })

    $TaskBtnClose.Add_Click({
        $TaskWindow.Close()
    })

    [void]$TaskWindow.ShowDialog()
}

function Show-FinalAnswerWindow {
    param(
        [string]$FinalText,
        [string]$FinalPath
    )

    if ([string]::IsNullOrWhiteSpace($FinalText)) {
        Add-GuiLog -Tag "WARN" -Message "No final answer available for this run."
        return
    }

    # Standalone here-string window: inline styles only, no StaticResource references.
    $FinalXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Full Answer"
        Width="940" Height="680" MinWidth="640" MinHeight="420"
        WindowStartupLocation="CenterOwner" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="11">
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="52">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0">
        <TextBlock Text="&#x1F4C4;" FontSize="20" Foreground="White" Margin="0,0,10,0" VerticalAlignment="Center"/>
        <TextBlock Text="FINAL ANSWER" FontSize="14" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
      </StackPanel>
    </Border>
    <Border DockPanel.Dock="Bottom" Background="#F3F3F3" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC" Padding="8,6">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="FinalBtnCopy" Content="&#x1F4CB; Copy" Width="100" Height="30"
                Background="#0078D7" Foreground="White" Margin="0,0,6,0"/>
        <Button Name="FinalBtnNotepad" Content="Open in Notepad" Width="120" Height="30"
                Background="#0F3460" Foreground="White" Margin="0,0,6,0"/>
        <Button Name="FinalBtnClose" Content="&#x2716; Close" Width="90" Height="30"/>
      </StackPanel>
    </Border>
    <TextBox Name="FinalTextBox" Margin="8" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
             FontFamily="Consolas" FontSize="12" Background="White"/>
  </DockPanel>
</Window>
"@

    $FinalWindow = $null
    try {
        $FinalXmlDoc = New-Object System.Xml.XmlDocument
        $FinalXmlDoc.LoadXml($FinalXaml)
        $FinalReader = New-Object System.Xml.XmlNodeReader($FinalXmlDoc)
        $FinalWindow = [System.Windows.Markup.XamlReader]::Load($FinalReader)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to load Full Answer window: " + $_.Exception.Message)
        return
    }

    $FinalWindow.Owner = $GuiWindow

    $FinalTextBox    = $FinalWindow.FindName("FinalTextBox")
    $FinalBtnCopy    = $FinalWindow.FindName("FinalBtnCopy")
    $FinalBtnNotepad = $FinalWindow.FindName("FinalBtnNotepad")
    $FinalBtnClose   = $FinalWindow.FindName("FinalBtnClose")

    $FinalTextBox.Text = $FinalText

    $FinalBtnCopy.Add_Click({
        try {
            Set-Clipboard -Value $FinalTextBox.Text
            Add-GuiLog -Tag "OK" -Message "Final answer copied to clipboard."
        }
        catch {
            Add-GuiLog -Tag "ERROR" -Message ("Clipboard error: " + $_.Exception.Message)
        }
    })

    $FinalBtnNotepad.Add_Click({
        if (-not [string]::IsNullOrWhiteSpace($FinalPath)) {
            if (Test-Path -LiteralPath $FinalPath) {
                Start-Process notepad.exe $FinalPath
            }
            else {
                Add-GuiLog -Tag "WARN" -Message ("Final answer file not found: " + $FinalPath)
            }
        }
    })

    $FinalBtnClose.Add_Click({
        $FinalWindow.Close()
    })

    [void]$FinalWindow.ShowDialog()
}

function Show-ImprovedPromptWindow {
    param([string]$ImprovedText)

    if ([string]::IsNullOrWhiteSpace($ImprovedText)) {
        Add-GuiLog -Tag "WARN" -Message "No improved prompt available for this run."
        return
    }

    # Standalone here-string window: inline styles only, no StaticResource references.
    $ImpXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Improved Prompt"
        Width="820" Height="560" MinWidth="600" MinHeight="400"
        WindowStartupLocation="CenterOwner" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="11">
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="52">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0">
        <TextBlock Text="&#x1F4DD;" FontSize="20" Foreground="White" Margin="0,0,10,0" VerticalAlignment="Center"/>
        <TextBlock Text="IMPROVED PROMPT" FontSize="14" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
      </StackPanel>
    </Border>
    <Border DockPanel.Dock="Bottom" Background="#F3F3F3" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC" Padding="8,6">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="ImpBtnCopy" Content="&#x1F4CB; Copy" Width="100" Height="30"
                Background="#0078D7" Foreground="White" Margin="0,0,6,0"/>
        <Button Name="ImpBtnUse" Content="&#x25B6; Use as Prompt" Width="130" Height="30"
                Background="#0B6A0B" Foreground="White" Margin="0,0,6,0"/>
        <Button Name="ImpBtnClose" Content="&#x2716; Close" Width="90" Height="30"/>
      </StackPanel>
    </Border>
    <TextBox Name="ImpTextBox" Margin="8" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
             VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12" Background="White"/>
  </DockPanel>
</Window>
"@

    $ImpWindow = $null
    try {
        $ImpXmlDoc = New-Object System.Xml.XmlDocument
        $ImpXmlDoc.LoadXml($ImpXaml)
        $ImpReader = New-Object System.Xml.XmlNodeReader($ImpXmlDoc)
        $ImpWindow = [System.Windows.Markup.XamlReader]::Load($ImpReader)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to load Improved Prompt window: " + $_.Exception.Message)
        return
    }

    $ImpWindow.Owner = $GuiWindow

    $ImpTextBox  = $ImpWindow.FindName("ImpTextBox")
    $ImpBtnCopy  = $ImpWindow.FindName("ImpBtnCopy")
    $ImpBtnUse   = $ImpWindow.FindName("ImpBtnUse")
    $ImpBtnClose = $ImpWindow.FindName("ImpBtnClose")

    $ImpTextBox.Text = $ImprovedText

    $ImpBtnCopy.Add_Click({
        try {
            Set-Clipboard -Value $ImpTextBox.Text
            Add-GuiLog -Tag "OK" -Message "Improved prompt copied to clipboard."
        }
        catch {
            Add-GuiLog -Tag "ERROR" -Message ("Clipboard error: " + $_.Exception.Message)
        }
    })

    $ImpBtnUse.Add_Click({
        $Script:Ctl_PromptBox.Text = $ImpTextBox.Text
        $Script:Ctl_PresetCombo.SelectedItem = "Custom"
        Add-GuiLog -Tag "OK" -Message "Improved prompt loaded into the prompt box."
        $ImpWindow.Close()
    })

    $ImpBtnClose.Add_Click({
        $ImpWindow.Close()
    })

    [void]$ImpWindow.ShowDialog()
}

function Get-GuiClarifyingQuestions {
    param([string]$PromptText)

    $Questions = New-Object System.Collections.ArrayList
    $Text = [string]$PromptText
    $Lower = $Text.ToLowerInvariant()
    $Words = @([System.Text.RegularExpressions.Regex]::Matches($Text, '\b[\w-]+\b'))

    if ($Words.Count -lt 10) {
        [void]$Questions.Add("What exact outcome should the answer produce?")
    }

    if ($Lower -match '\b(fix|improve|enhance|polish|update|make better|clean up|review this|do this|help with this)\b') {
        [void]$Questions.Add("What should change, and what should stay unchanged?")
    }

    if ($Lower -match '\b(this|that|it|above|below|attached|screenshot|image|file)\b' -and $Words.Count -lt 35) {
        [void]$Questions.Add("What does the referenced item contain, and which part matters most?")
    }

    if ($Lower -notmatch '\b(script|code|summary|table|csv|json|markdown|email|report|checklist|wpf|gui|powershell|sql|steps|plan)\b') {
        [void]$Questions.Add("What output format do you want?")
    }

    if ($Lower -match '\b(script|code|powershell|wpf|gui|ad|active directory)\b') {
        if ($Lower -notmatch '\b(version|5\.1|7|ise|module|server|domain|csv|path|admin|readonly|export)\b') {
            [void]$Questions.Add("What environment, version, input source, and safety constraints should the solution assume?")
        }
    }

    $Unique = New-Object System.Collections.ArrayList
    foreach ($Question in $Questions) {
        if (-not $Unique.Contains($Question)) {
            [void]$Unique.Add($Question)
        }
        if ($Unique.Count -ge 4) { break }
    }

    return $Unique
}

function Invoke-GuiAiClarificationCheck {
    param(
        [string]$PromptText,
        [string]$Model
    )

    $Result = [PSCustomObject]@{
        Success           = $false
        NeedsClarification = $false
        Questions         = @()
        Reason            = ""
        CostUsd           = $null
        Error             = ""
    }

    if ([string]::IsNullOrWhiteSpace($AnthropicApiKey)) {
        $Result.Error = "Anthropic API key is missing."
        return $Result
    }

    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = $AnthropicModel_Judge
    }

    $Headers = @{
        "x-api-key"         = $AnthropicApiKey
        "anthropic-version" = $AnthropicVersion
        "Content-Type"      = "application/json"
    }

    $SystemPrompt = @"
You decide whether a user's initial prompt is clear enough to run.
Return only compact JSON. No Markdown.
Use this schema:
{
  "needs_clarification": true,
  "reason": "short reason",
  "questions": ["question 1", "question 2"]
}

Ask questions only when missing details are likely to change the answer materially.
Do not ask for unnecessary preferences.
Limit questions to 1-4 concise questions.
If the prompt is clear enough, set needs_clarification to false and questions to [].
"@

    $UserPrompt = @"
Review this prompt for ambiguity before a multi-model run.

PROMPT:
$PromptText
"@

    $BodyObject = [ordered]@{
        model      = $Model
        max_tokens = 700
        system     = $SystemPrompt
        messages   = @(
            [ordered]@{
                role    = "user"
                content = $UserPrompt
            }
        )
    }

    $BodyJson = $BodyObject | ConvertTo-Json -Depth 20
    $Attempt = 0
    $LastError = ""
    $LastStatusCode = $null
    $RequestStarted = Get-Date

    while ($Attempt -le $MaxRetries) {
        $Attempt++
        try {
            $Params = @{
                Uri         = $AnthropicBaseUrl
                Method      = "Post"
                Headers     = $Headers
                Body        = $BodyJson
                TimeoutSec  = 30
                ErrorAction = "Stop"
            }
            if (-not [string]::IsNullOrWhiteSpace($ProxyUrl)) {
                $Params.Proxy = $ProxyUrl
            }

            $Response = Invoke-RestMethod @Params
            $Text = Get-AnthropicTextFromResponse -ResponseObject $Response
            $Parsed = Try-ParseJsonText -JsonText $Text
            if ($null -eq $Parsed) {
                $Result.Error = "AI clarification response did not contain valid JSON."
                return $Result
            }

            $Questions = @()
            foreach ($Question in @($Parsed.questions)) {
                $QuestionText = [string]$Question
                if (-not [string]::IsNullOrWhiteSpace($QuestionText)) {
                    $Questions += $QuestionText.Trim()
                }
                if ($Questions.Count -ge 4) { break }
            }

            $InputTokens = $null
            $OutputTokens = $null
            if ($null -ne $Response.usage) {
                if ($null -ne $Response.usage.input_tokens) { $InputTokens = $Response.usage.input_tokens }
                if ($null -ne $Response.usage.output_tokens) { $OutputTokens = $Response.usage.output_tokens }
            }

            $Cost = Get-EstimatedCostUsd -Provider "Anthropic" -Model $Model -InputTokens $InputTokens -OutputTokens $OutputTokens
            $Result.Success = $true
            $Result.NeedsClarification = ($Parsed.needs_clarification -eq $true -and @($Questions).Count -gt 0)
            $Result.Questions = $Questions
            $Result.Reason = [string]$Parsed.reason
            $Result.CostUsd = $Cost
            return $Result
        }
        catch {
            $LastError = $_.Exception.Message
            $ErrorBody = Get-HttpErrorBody -ErrorRecord $_
            if (-not [string]::IsNullOrWhiteSpace($ErrorBody)) {
                $LastError = $LastError + " | ResponseBody: " + $ErrorBody
            }

            $StatusCode = $null
            if ($null -ne $_.Exception.Response) {
                try {
                    $StatusCode = [int]$_.Exception.Response.StatusCode
                    $LastStatusCode = $StatusCode
                }
                catch {
                    $StatusCode = $null
                }
            }

            $ShouldRetry = $false
            if ($null -eq $StatusCode) { $ShouldRetry = $true }
            elseif ($StatusCode -eq 429 -or $StatusCode -eq 500 -or $StatusCode -eq 502 -or $StatusCode -eq 503 -or $StatusCode -eq 504) { $ShouldRetry = $true }

            if ($ShouldRetry -eq $false) { break }
            if ($Attempt -le $MaxRetries) { Start-Sleep -Seconds 2 }
        }
    }

    $DurationSeconds = [Math]::Round(((Get-Date) - $RequestStarted).TotalSeconds, 2)
    $Result.Error = $LastError + " | duration=" + $DurationSeconds + "s | status=" + [string]$LastStatusCode
    return $Result
}

function Show-ClarifyingQuestionsWindow {
    param(
        [string]$PromptText,
        [object[]]$Questions
    )

    $Result = [PSCustomObject]@{
        Action        = "Cancel"
        Clarification = ""
    }

    if ($null -eq $Questions -or @($Questions).Count -le 0) {
        $Result.Action = "RunAnyway"
        return $Result
    }

    $ClarifyXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Clarify Prompt"
        Width="720" Height="520" MinWidth="560" MinHeight="420"
        WindowStartupLocation="CenterOwner" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="11">
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="52">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0">
        <TextBlock Text="&#x2753;" FontSize="20" Foreground="White" Margin="0,0,10,0" VerticalAlignment="Center"/>
        <TextBlock Text="CLARIFY PROMPT" FontSize="14" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
      </StackPanel>
    </Border>
    <Border DockPanel.Dock="Bottom" Background="#F3F3F3" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC" Padding="8,8">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="ClarifyBtnAdd" Content="Add Answers and Run" Width="150" Height="30"
                Background="#0B6A0B" Foreground="White" FontWeight="SemiBold" Margin="0,0,6,0"/>
        <Button Name="ClarifyBtnRunAnyway" Content="Run Anyway" Width="110" Height="30" Margin="0,0,6,0"/>
        <Button Name="ClarifyBtnCancel" Content="Cancel" Width="90" Height="30"/>
      </StackPanel>
    </Border>
    <Grid Margin="10">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
      </Grid.RowDefinitions>
      <TextBlock Grid.Row="0" Text="The prompt may be underspecified. Answer any questions that matter, or run anyway." FontWeight="SemiBold" Margin="0,0,0,8"/>
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Padding="0,0,6,0">
        <StackPanel Name="ClarifyItemsHost"/>
      </ScrollViewer>
    </Grid>
  </DockPanel>
</Window>
"@

    $ClarifyWindow = $null
    try {
        $ClarifyXmlDoc = New-Object System.Xml.XmlDocument
        $ClarifyXmlDoc.LoadXml($ClarifyXaml)
        $ClarifyReader = New-Object System.Xml.XmlNodeReader($ClarifyXmlDoc)
        $ClarifyWindow = [System.Windows.Markup.XamlReader]::Load($ClarifyReader)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to load clarification window: " + $_.Exception.Message)
        return $Result
    }

    $ClarifyWindow.Owner = $GuiWindow
    $ItemsHost = $ClarifyWindow.FindName("ClarifyItemsHost")
    $BtnAdd = $ClarifyWindow.FindName("ClarifyBtnAdd")
    $BtnRunAnyway = $ClarifyWindow.FindName("ClarifyBtnRunAnyway")
    $BtnCancel = $ClarifyWindow.FindName("ClarifyBtnCancel")

    # Build one section per question, each holding the question text AND its own answer box,
    # so the operator reads and answers each item in place (v0.8.62). Question text is set via
    # the .Text property (never embedded in XAML) so '<', '>', '&' in a question cannot break parse.
    $BorderBrush = (New-Object System.Windows.Media.BrushConverter).ConvertFromString("#D0D7DE")
    $AnswerItems = New-Object System.Collections.ArrayList
    $QuestionIndex = 0
    foreach ($Question in @($Questions)) {
        $QuestionIndex++
        $QuestionText = [string]$Question

        $Section = New-Object System.Windows.Controls.Border
        $Section.Background = [System.Windows.Media.Brushes]::White
        $Section.BorderBrush = $BorderBrush
        $Section.BorderThickness = New-Object System.Windows.Thickness -ArgumentList 1
        $Section.Padding = New-Object System.Windows.Thickness -ArgumentList 10
        $Section.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 0, 0, 10

        $Stack = New-Object System.Windows.Controls.StackPanel

        $QLabel = New-Object System.Windows.Controls.TextBlock
        $QLabel.Text = ([string]$QuestionIndex + ". " + $QuestionText)
        $QLabel.TextWrapping = "Wrap"
        $QLabel.FontWeight = "SemiBold"
        $QLabel.Margin = New-Object System.Windows.Thickness -ArgumentList 0, 0, 0, 6

        $ABox = New-Object System.Windows.Controls.TextBox
        $ABox.AcceptsReturn = $true
        $ABox.TextWrapping = "Wrap"
        $ABox.MinHeight = 56
        $ABox.VerticalScrollBarVisibility = "Auto"
        $ABox.FontFamily = New-Object System.Windows.Media.FontFamily -ArgumentList "Consolas"
        $ABox.FontSize = 12

        [void]$Stack.Children.Add($QLabel)
        [void]$Stack.Children.Add($ABox)
        $Section.Child = $Stack
        [void]$ItemsHost.Children.Add($Section)

        [void]$AnswerItems.Add([PSCustomObject]@{ Index = $QuestionIndex; Question = $QuestionText; Box = $ABox })
    }

    $BtnAdd.Add_Click({
        $Result.Action = "AddAndRun"
        $Pairs = @()
        foreach ($Item in $AnswerItems) {
            $Ans = [string]$Item.Box.Text
            if (-not [string]::IsNullOrWhiteSpace($Ans)) {
                $Pairs += ("Q" + [string]$Item.Index + ": " + $Item.Question.Trim() + [Environment]::NewLine + "A" + [string]$Item.Index + ": " + $Ans.Trim())
            }
        }
        $Result.Clarification = ($Pairs -join ([Environment]::NewLine + [Environment]::NewLine))
        $ClarifyWindow.Close()
    })

    $BtnRunAnyway.Add_Click({
        $Result.Action = "RunAnyway"
        $ClarifyWindow.Close()
    })

    $BtnCancel.Add_Click({
        $Result.Action = "Cancel"
        $ClarifyWindow.Close()
    })

    [void]$ClarifyWindow.ShowDialog()
    return $Result
}

function Show-ApiKeysWindow {
    $OpenAIState = "not set"
    if (-not [string]::IsNullOrWhiteSpace($script:OpenAIApiKey)) { $OpenAIState = "currently set" }
    $AnthropicState = "not set"
    if (-not [string]::IsNullOrWhiteSpace($script:AnthropicApiKey)) { $AnthropicState = "currently set" }

    $KeysXaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="API keys"
        Width="480" Height="360" MinWidth="420" MinHeight="320"
        WindowStartupLocation="CenterOwner" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="12" ResizeMode="NoResize">
  <DockPanel>
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="46">
      <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="16,0">
        <TextBlock Text="&#x1F511;" FontSize="18" Foreground="White" Margin="0,0,10,0" VerticalAlignment="Center"/>
        <TextBlock Text="API KEYS" FontSize="14" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
      </StackPanel>
    </Border>
    <Border DockPanel.Dock="Bottom" Background="#F3F3F3" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC" Padding="8,8">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
        <Button Name="KeyBtnSave" Content="Save" Width="100" Height="30" Background="#0B6A0B" Foreground="White" FontWeight="SemiBold" Margin="0,0,6,0"/>
        <Button Name="KeyBtnCancel" Content="Cancel" Width="90" Height="30"/>
      </StackPanel>
    </Border>
    <StackPanel Margin="16,12">
      <Border Background="#FFF4E0" BorderBrush="#E6C200" BorderThickness="1" Padding="8,6" Margin="0,0,0,14">
        <TextBlock TextWrapping="Wrap" Foreground="#7A5C00" FontSize="11" Text="Encrypted with Windows DPAPI for the current Windows user on this computer. The file is not portable to another user or PC. Keys are never written to logs."/>
      </Border>
      <TextBlock Name="KeyLblOpenAI" Text="OpenAI API key" Margin="0,0,0,4"/>
      <PasswordBox Name="KeyBoxOpenAI" Height="26"/>
      <TextBlock Name="KeyLblAnthropic" Text="Anthropic API key" Margin="0,12,0,4"/>
      <PasswordBox Name="KeyBoxAnthropic" Height="26"/>
      <TextBlock Text="Leave a field blank to keep the existing key." Foreground="#666666" FontSize="11" Margin="0,12,0,0" TextWrapping="Wrap"/>
    </StackPanel>
  </DockPanel>
</Window>
"@

    $KeysWindow = $null
    try {
        $KeysXmlDoc = New-Object System.Xml.XmlDocument
        $KeysXmlDoc.LoadXml($KeysXaml)
        $KeysReader = New-Object System.Xml.XmlNodeReader($KeysXmlDoc)
        $KeysWindow = [System.Windows.Markup.XamlReader]::Load($KeysReader)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to load API keys window: " + $_.Exception.Message)
        return
    }

    $KeysWindow.Owner = $GuiWindow

    $KeyBoxOpenAI    = $KeysWindow.FindName("KeyBoxOpenAI")
    $KeyBoxAnthropic = $KeysWindow.FindName("KeyBoxAnthropic")
    $KeyLblOpenAI    = $KeysWindow.FindName("KeyLblOpenAI")
    $KeyLblAnthropic = $KeysWindow.FindName("KeyLblAnthropic")
    $KeyBtnSave      = $KeysWindow.FindName("KeyBtnSave")
    $KeyBtnCancel    = $KeysWindow.FindName("KeyBtnCancel")

    $KeyLblOpenAI.Text = "OpenAI API key  (" + $OpenAIState + ")"
    $KeyLblAnthropic.Text = "Anthropic API key  (" + $AnthropicState + ")"

    $KeyBtnSave.Add_Click({
        $OpenSecure = $KeyBoxOpenAI.SecurePassword
        $AnthSecure = $KeyBoxAnthropic.SecurePassword
        $OpenLen = 0
        if ($null -ne $OpenSecure) { $OpenLen = $OpenSecure.Length }
        $AnthLen = 0
        if ($null -ne $AnthSecure) { $AnthLen = $AnthSecure.Length }

        $ExistingOpen = $null
        $ExistingAnth = $null
        if (Test-Path -LiteralPath $SecretsPath) {
            try {
                $CurSecrets = Import-Clixml -Path $SecretsPath -ErrorAction Stop
                if ($CurSecrets.OpenAIKey -is [System.Security.SecureString]) { $ExistingOpen = $CurSecrets.OpenAIKey }
                if ($CurSecrets.AnthropicKey -is [System.Security.SecureString]) { $ExistingAnth = $CurSecrets.AnthropicKey }
            }
            catch {
                Add-GuiLog -Tag "WARN" -Message "Could not read the existing secrets file; blank fields will not be preserved."
            }
        }

        $FinalOpen = $ExistingOpen
        if ($OpenLen -gt 0) { $FinalOpen = $OpenSecure }
        $FinalAnth = $ExistingAnth
        if ($AnthLen -gt 0) { $FinalAnth = $AnthSecure }

        $FinalOpenLen = 0
        if ($null -ne $FinalOpen) { $FinalOpenLen = $FinalOpen.Length }
        $FinalAnthLen = 0
        if ($null -ne $FinalAnth) { $FinalAnthLen = $FinalAnth.Length }

        if ($FinalOpenLen -eq 0) {
            Add-GuiLog -Tag "WARN" -Message "OpenAI API key is empty. Enter it to save."
            return
        }
        if ($FinalAnthLen -eq 0) {
            Add-GuiLog -Tag "WARN" -Message "Anthropic API key is empty. Enter it to save."
            return
        }

        try {
            Save-MultiLLMApiKeysSecure -OpenAISecure $FinalOpen -AnthropicSecure $FinalAnth
            Initialize-ApiKeys
            Add-GuiLog -Tag "OK" -Message ("API keys saved (encrypted with DPAPI) to " + $SecretsPath)
            if ((-not [string]::IsNullOrWhiteSpace($script:OpenAIApiKey)) -and (-not [string]::IsNullOrWhiteSpace($script:AnthropicApiKey))) {
                Add-GuiLog -Tag "OK" -Message "API keys are now available. You can Run."
            }
            Update-RunButtonState
            Update-ApiStatusHeader
            $KeysWindow.Close()
        }
        catch {
            Add-GuiLog -Tag "ERROR" -Message ("Failed to save API keys: " + $_.Exception.Message)
        }
    })

    $KeyBtnCancel.Add_Click({
        $KeysWindow.Close()
    })

    [void]$KeysWindow.ShowDialog()
}

# ---- XAML ----

$GuiXamlTemplate = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Multi-LLM Prompter __VERSION__"
        Width="1280" Height="780" MinWidth="1120" MinHeight="660"
        WindowStartupLocation="CenterScreen" Background="#F3F3F3"
        FontFamily="Segoe UI" FontSize="11">
  <Window.Resources>
    <!-- Light buttons (dialogs, tabs, header). v0.8.65: clear hover + hand cursor. An overlay border
         lightens on hover and darkens on press, so the button reads as clickable on any base color. -->
    <Style TargetType="Button">
      <Setter Property="Background" Value="#FFFFFF"/>
      <Setter Property="BorderBrush" Value="#9AA7B4"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Foreground" Value="#1B2545"/>
      <Setter Property="Padding" Value="6,2"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="Bd" Background="{TemplateBinding Background}" BorderBrush="{TemplateBinding BorderBrush}" BorderThickness="{TemplateBinding BorderThickness}" CornerRadius="3" SnapsToDevicePixels="True"/>
              <Border x:Name="Ov" Background="Transparent" CornerRadius="3"/>
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Bd" Property="BorderBrush" Value="#0078D7"/>
                <Setter TargetName="Ov" Property="Background" Value="#1A0078D7"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Ov" Property="Background" Value="#22000000"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Background" Value="#E6E6E6"/>
                <Setter TargetName="Bd" Property="BorderBrush" Value="#BFC7CF"/>
                <Setter Property="Foreground" Value="#8A8A8A"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Rail buttons (dark side rail). v0.8.65: chip look so each reads as a button, with an obvious
         hover lighten + press darken + hand cursor. Each button keeps its own Background (Run green,
         Stop red, etc.); the white/black overlay makes the hover visible on any of them. -->
    <Style x:Key="RailButton" TargetType="Button">
      <Setter Property="Background" Value="#15406B"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="6,2"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="HorizontalContentAlignment" Value="Left"/>
      <Setter Property="SnapsToDevicePixels" Value="True"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="Bd" Background="{TemplateBinding Background}" CornerRadius="4" SnapsToDevicePixels="True"/>
              <Border x:Name="Ov" Background="Transparent" CornerRadius="4"/>
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}" VerticalAlignment="Center" Margin="{TemplateBinding Padding}"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Ov" Property="Background" Value="#28FFFFFF"/>
              </Trigger>
              <Trigger Property="IsPressed" Value="True">
                <Setter TargetName="Ov" Property="Background" Value="#28000000"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="Bd" Property="Background" Value="#13314D"/>
                <Setter Property="Foreground" Value="#5E7C99"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Shared DataGrid styles (v0.8.66): header band + right-aligned numeric cell. -->
    <Style x:Key="GridHeader" TargetType="DataGridColumnHeader">
      <Setter Property="Background" Value="#1F4788"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Height" Value="26"/>
      <Setter Property="Padding" Value="6,0"/>
    </Style>
    <Style x:Key="GridNum" TargetType="TextBlock">
      <Setter Property="TextAlignment" Value="Right"/>
      <Setter Property="Padding" Value="0,0,8,0"/>
    </Style>
  </Window.Resources>
  <DockPanel>

    <Menu Name="TopMenu" DockPanel.Dock="Top" Background="#F3F3F3" FontSize="12"/>

    <!-- ZONE 1: HEADER -->
    <Border DockPanel.Dock="Top" Background="#0F3460" Height="58">
      <DockPanel Margin="16,0">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <TextBlock Text="&#x1F9E0;" FontSize="24" Foreground="White" Margin="0,0,12,0" VerticalAlignment="Center"/>
          <StackPanel VerticalAlignment="Center">
            <StackPanel Orientation="Horizontal">
              <TextBlock Text="MULTI-LLM PROMPTER" FontSize="16" FontWeight="Bold" Foreground="White" VerticalAlignment="Center"/>
              <Border Background="#0078D7" CornerRadius="3" Padding="7,1" Margin="10,0,0,0" VerticalAlignment="Center">
                <TextBlock Name="HdrVersion" Text="__VERSION__" FontSize="13" FontWeight="Bold" Foreground="White"/>
              </Border>
            </StackPanel>
            <TextBlock Text="Multi-model answers, Claude Opus judge, cost-aware routing" FontSize="10" Foreground="#B0C4DE"/>
          </StackPanel>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" VerticalAlignment="Center" Margin="18,0,0,0">
          <TextBlock Name="HdrApiStatus" Text="API keys: checking" FontSize="12" FontWeight="Bold" Foreground="#FFD479" HorizontalAlignment="Right" Margin="0,0,0,4"/>
          <Button Name="BtnHdrSetKeys" Content="Set API Keys" Height="24" Padding="12,0" Background="#0078D7" Foreground="White" BorderThickness="0" HorizontalAlignment="Right"/>
        </StackPanel>
        <StackPanel DockPanel.Dock="Right" VerticalAlignment="Center" HorizontalAlignment="Right">
          <Grid HorizontalAlignment="Right">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="Auto"/>
            </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBlock Grid.Row="0" Grid.Column="0" Text="Answer A:" FontSize="11" Foreground="#B0C4DE" Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="0" Grid.Column="1" Name="HdrModelA" Text="" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" FontFamily="Consolas" Margin="0,0,18,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="0" Grid.Column="2" Text="Quality:" FontSize="11" Foreground="#B0C4DE" Margin="0,0,6,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="0" Grid.Column="3" Name="HdrJudgeFull" Text="" FontSize="13" FontWeight="Bold" Foreground="#FFD479" FontFamily="Consolas" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="1" Grid.Column="0" Text="Answer B:" FontSize="11" Foreground="#B0C4DE" Margin="0,3,6,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="1" Grid.Column="1" Name="HdrModelB" Text="" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" FontFamily="Consolas" Margin="0,3,18,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="1" Grid.Column="2" Text="Fast:" FontSize="11" Foreground="#B0C4DE" Margin="0,3,6,0" VerticalAlignment="Center"/>
            <TextBlock Grid.Row="1" Grid.Column="3" Name="HdrJudgeCheap" Text="" FontSize="13" FontWeight="Bold" Foreground="#FFFFFF" FontFamily="Consolas" Margin="0,3,0,0" VerticalAlignment="Center"/>
          </Grid>
          <TextBlock Name="HdrRunFolder" Text="" FontSize="10" Foreground="#B0C4DE" HorizontalAlignment="Right" Margin="0,3,0,0"/>
        </StackPanel>
      </DockPanel>
    </Border>

    <!-- LEFT ACTION RAIL (v0.8.65: Detect-first ordering, framed groups, chip buttons with clear hover) -->
    <Border DockPanel.Dock="Left" Width="204" Background="#0C2742" BorderBrush="#0B2545" BorderThickness="0,0,1,0">
      <DockPanel LastChildFill="True">
        <!-- Primary actions frame: Detect -> Run -> Stop (workflow order), pinned at the top -->
        <Border DockPanel.Dock="Top" Margin="10,10,10,4" Background="#0A2138" BorderBrush="#1E4D7A" BorderThickness="1" CornerRadius="6" Padding="8,8">
          <StackPanel>
            <Button Name="BtnDetect" Style="{StaticResource RailButton}" Content="&#x1F50D;  Detect Tasks" Height="34" Margin="0,0,0,6"
                    Background="#1B4A86" HorizontalContentAlignment="Center"
                    ToolTip="Step 1: split the prompt into tasks and preview them in the Tasks tab. The same split the run uses."/>
            <Button Name="BtnRun" Style="{StaticResource RailButton}" Content="&#x25B6; Run" Height="42" Margin="0,0,0,6"
                    Background="#0B6A0B" FontWeight="SemiBold" FontSize="14" HorizontalContentAlignment="Center"
                    ToolTip="Step 2: run the selected tasks. Answer models run in parallel per task, then the Judge compares and synthesizes."/>
            <Button Name="BtnStop" Style="{StaticResource RailButton}" Content="&#x25A0; Stop" Height="32"
                    Background="#A4262C" IsEnabled="False" HorizontalContentAlignment="Center"
                    ToolTip="Stop the current run (kills the hidden child process)."/>
          </StackPanel>
        </Border>

        <!-- Footer: settings + exit + app version, pinned at the bottom -->
        <StackPanel DockPanel.Dock="Bottom" Margin="10,4,10,10">
          <DockPanel LastChildFill="True" Margin="0,0,0,8">
            <Button Name="BtnExit" Style="{StaticResource RailButton}" DockPanel.Dock="Right" Content="&#x2716; Exit" Width="64" Height="30"
                    Background="#123150" HorizontalContentAlignment="Center" Margin="6,0,0,0"
                    ToolTip="Close Multi-LLM Prompter."/>
            <Button Name="BtnSideSettings" Style="{StaticResource RailButton}" Content="&#x2699;  Settings" Height="30"
                    Background="#123150" Padding="12,0,0,0"
                    ToolTip="Open the config file, set API keys, or change the output folder."/>
          </DockPanel>
          <TextBlock Text="Multi-LLM Prompter" Foreground="#9DC3E6" FontSize="11"/>
          <TextBlock Name="TxtSideVersion" Text="v0.8.69" Foreground="#6F9BC2" FontSize="10" Margin="0,1,0,0"/>
        </StackPanel>

        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
          <StackPanel Margin="10,8,10,8">
            <Button Name="BtnSideNewRun" Style="{StaticResource RailButton}" Content="+  New Run" Height="32" Margin="0,0,0,8"
                    Padding="14,0,0,0"
                    ToolTip="Clear the current draft and start a new run."/>

            <Border Background="#0A2138" BorderBrush="#1E4D7A" BorderThickness="1" CornerRadius="6" Padding="8,8" Margin="0,0,0,8">
              <StackPanel>
                <TextBlock Text="RESULTS" Foreground="#7FA8CF" FontSize="10" FontWeight="SemiBold" Margin="2,0,0,6"/>
                <Button Name="BtnCopyFinal" Style="{StaticResource RailButton}" Content="&#x1F4C4;  Full Answer" Height="30" Margin="0,0,0,4"
                        Padding="12,0,0,0" ToolTip="Open the final answer in a separate window."/>
                <Button Name="BtnCopyQuick" Style="{StaticResource RailButton}" Content="&#x1F4CB;  Copy" Height="30" Margin="0,0,0,4"
                        Padding="12,0,0,0" ToolTip="Copy the final answer to the clipboard."/>
                <Button Name="BtnImproved" Style="{StaticResource RailButton}" Content="&#x1F4DD;  Improved Prompt" Height="30" Margin="0,0,0,4"
                        IsEnabled="False" Padding="12,0,0,0" ToolTip="Open the improved version of your prompt produced by the judge (available after a run)."/>
                <Button Name="BtnOpenFolder" Style="{StaticResource RailButton}" Content="&#x1F4C1;  Open Folder" Height="30" Margin="0,0,0,4"
                        Padding="12,0,0,0" ToolTip="Open the run output folder in Explorer."/>
                <Button Name="BtnHtmlReport" Style="{StaticResource RailButton}" Content="&#x1F310;  HTML Report" Height="30"
                        Padding="12,0,0,0" ToolTip="Build a shareable HTML cost report for this run and open it in your browser."/>
              </StackPanel>
            </Border>

            <Border Background="#0A2138" BorderBrush="#1E4D7A" BorderThickness="1" CornerRadius="6" Padding="8,8">
              <StackPanel>
                <TextBlock Text="RECENT RUNS" Foreground="#7FA8CF" FontSize="10" FontWeight="SemiBold" Margin="2,0,0,6"/>
                <Button Name="BtnSideRecent1" Style="{StaticResource RailButton}" Height="30" Margin="0,0,0,4" IsEnabled="False"
                        HorizontalContentAlignment="Stretch" Padding="6,0"
                        ToolTip="Load this run's results">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="&#x25CF;" Foreground="#13A10E" FontSize="10" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" Name="TxtSideRecent1Name" Text="No runs yet" Foreground="White" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Name="TxtSideRecent1Time" Text="" Foreground="#9DC3E6" FontSize="10" Margin="6,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Button>
                <Button Name="BtnSideRecent2" Style="{StaticResource RailButton}" Height="30" Margin="0,0,0,4" IsEnabled="False"
                        HorizontalContentAlignment="Stretch" Padding="6,0"
                        ToolTip="Load this run's results">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="&#x25CF;" Foreground="#13A10E" FontSize="10" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" Name="TxtSideRecent2Name" Text="" Foreground="White" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Name="TxtSideRecent2Time" Text="" Foreground="#9DC3E6" FontSize="10" Margin="6,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Button>
                <Button Name="BtnSideRecent3" Style="{StaticResource RailButton}" Height="30" Margin="0,0,0,4" IsEnabled="False"
                        HorizontalContentAlignment="Stretch" Padding="6,0"
                        ToolTip="Load this run's results">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="&#x25CF;" Foreground="#13A10E" FontSize="10" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" Name="TxtSideRecent3Name" Text="" Foreground="White" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Name="TxtSideRecent3Time" Text="" Foreground="#9DC3E6" FontSize="10" Margin="6,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Button>
                <Button Name="BtnSideRecent4" Style="{StaticResource RailButton}" Height="30" Margin="0,0,0,4" IsEnabled="False"
                        HorizontalContentAlignment="Stretch" Padding="6,0"
                        ToolTip="Load this run's results">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="14"/>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Grid.Column="0" Text="&#x25CF;" Foreground="#13A10E" FontSize="10" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="1" Name="TxtSideRecent4Name" Text="" Foreground="White" TextTrimming="CharacterEllipsis" VerticalAlignment="Center"/>
                <TextBlock Grid.Column="2" Name="TxtSideRecent4Time" Text="" Foreground="#9DC3E6" FontSize="10" Margin="6,0,0,0" VerticalAlignment="Center"/>
              </Grid>
                </Button>
              </StackPanel>
            </Border>
          </StackPanel>
        </ScrollViewer>
      </DockPanel>
    </Border>

    <!-- REDESIGN RIGHT INSPECTOR RAIL -->
    <Border DockPanel.Dock="Right" Width="280" Background="#EEF3F8" BorderBrush="#D0D7DE" BorderThickness="1,0,0,0" Padding="6">
      <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <StackPanel>
          <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" Padding="8" Margin="0,0,0,6">
            <StackPanel>
              <TextBlock Text="&#x25BE; Run Details" FontWeight="SemiBold" Foreground="#0B2545" Margin="0,0,0,8"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="78"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Run Name" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtRailRunName" Text="-" FontSize="12" TextTrimming="CharacterEllipsis" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Created" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtRailCreated" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Last Run" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Name="TxtRailLastRun" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="3" Grid.Column="0" Text="Status" FontSize="12" Foreground="#444444"/>
                <TextBlock Grid.Row="3" Grid.Column="1" Name="TxtRailRunStatus" Text="Ready" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right"/>
              </Grid>
            </StackPanel>
          </Border>

          <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" Padding="8" Margin="0,0,0,6">
            <StackPanel>
              <TextBlock Text="&#x25BE; Cost" FontWeight="SemiBold" Foreground="#0B2545" Margin="0,0,0,8"/>
              <TextBlock Name="TxtRailCostLabel" Text="Estimated cost" FontSize="11" Foreground="#777777" Margin="0,0,0,2"/>
              <DockPanel Margin="0,0,0,4">
                <TextBlock Name="TxtRailCostBig" Text="`$0.00" FontSize="24" FontWeight="Bold" Foreground="#111111"/>
                <TextBlock Text="USD" FontSize="12" Foreground="#555555" VerticalAlignment="Bottom" Margin="6,0,0,4"/>
              </DockPanel>
              <TextBlock Name="TxtRailCostIls" Text="~0.00 ILS" FontSize="13" FontWeight="SemiBold" Foreground="#333333" Margin="0,0,0,6"/>
              <TextBlock Name="TxtRailCostCompare" Text="" FontSize="12" Foreground="#555555" TextWrapping="Wrap" Margin="0,0,0,6" Visibility="Collapsed"/>
              <Grid Margin="0,0,0,4">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="Auto"/>
                </Grid.ColumnDefinitions>
                <TextBlock Text="Budget optional" FontSize="12" Foreground="#555555"/>
                <TextBlock Grid.Column="1" Name="TxtRailBudget" Text="`$10.00" FontSize="12"/>
              </Grid>
              <ProgressBar Name="PbRailCost" Minimum="0" Maximum="10" Value="0" Height="8" Foreground="#0B6A0B" Background="#E6E6E6"/>
              <TextBlock Name="TxtRailBudgetPct" Text="0.0%" FontSize="12" Foreground="#555555" HorizontalAlignment="Right" Margin="0,3,0,0"/>
              <Border Height="1" Background="#E0E0E0" Margin="0,8,0,7"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="92"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Selected" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtRailPreRunCost" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Time" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtRailPreRunTime" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Tasks" FontSize="12" Foreground="#444444"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Name="TxtRailPreRunTasks" Text="-" FontSize="12" HorizontalAlignment="Right"/>
              </Grid>
            </StackPanel>
          </Border>

          <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" Padding="8" Margin="0,0,0,6">
            <StackPanel>
              <TextBlock Text="&#x25BE; Token Usage" FontWeight="SemiBold" Foreground="#0B2545" Margin="0,0,0,8"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="92"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Input" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtRailInputTokens" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Output" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtRailOutputTokens" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Total" FontSize="12" Foreground="#444444"/>
                <TextBlock Grid.Row="2" Grid.Column="1" Name="TxtRailTotalTokens" Text="-" FontSize="12" FontWeight="SemiBold" HorizontalAlignment="Right"/>
              </Grid>
            </StackPanel>
          </Border>

          <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" Padding="8" Margin="0,0,0,6">
            <StackPanel>
              <TextBlock Text="&#x25BE; Latency" FontWeight="SemiBold" Foreground="#0B2545" Margin="0,0,0,8"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="92"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Total" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtRailLatencyTotal" Text="-" FontSize="12" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Per task avg" FontSize="12" Foreground="#444444"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtRailLatencyAvg" Text="-" FontSize="12" HorizontalAlignment="Right"/>
              </Grid>
            </StackPanel>
          </Border>

          <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" Padding="8">
            <StackPanel>
              <TextBlock Text="&#x25BE; Run Health" FontWeight="SemiBold" Foreground="#0B2545" Margin="0,0,0,8"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="92"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="API Status" FontSize="12" Foreground="#444444" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtRailApiStatus" Text="Checking" FontSize="12" FontWeight="Bold" HorizontalAlignment="Right" Margin="0,0,0,4"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Success Rate" FontSize="12" Foreground="#444444"/>
                <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtRailSuccessRate" Text="-" FontSize="12" HorizontalAlignment="Right"/>
              </Grid>
            </StackPanel>
          </Border>
        </StackPanel>
      </ScrollViewer>
    </Border>

    <!-- ZONE 6: STATUS BAR -->
    <Border Name="StatusBarBorder" DockPanel.Dock="Bottom" Background="#E0E0E0" Height="24" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC">
      <DockPanel Margin="8,0">
        <ProgressBar Name="PbTasks" Width="160" Height="14" Minimum="0" Maximum="1" Value="0" VerticalAlignment="Center"/>
        <TextBlock Name="LblTasksDone" Text="Tasks: 0 / 0" FontSize="10" Margin="10,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Name="LblElapsed" Text="Elapsed: 0 s" FontSize="10" Margin="18,0,0,0" VerticalAlignment="Center"/>
        <TextBlock Name="StatusText" Text="Ready" FontSize="10" Margin="18,0,0,0" VerticalAlignment="Center" FontWeight="SemiBold"/>
        <TextBlock Name="LblCostEstimate" Text="Pre-run est: -" FontSize="10" Margin="18,0,0,0" VerticalAlignment="Center"/>
      </DockPanel>
    </Border>

    <!-- ZONE 5: GUI LOG PANEL -->
    <Border DockPanel.Dock="Bottom" BorderThickness="0,1,0,0" BorderBrush="#CCCCCC">
      <DockPanel>
        <Border DockPanel.Dock="Top" Background="#F3F3F3" BorderBrush="#CCCCCC" BorderThickness="0,0,0,1" Height="24">
          <DockPanel Margin="8,0">
            <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
              <Button Name="BtnToggleLog" Content="Collapse" Width="80" Height="20" Margin="0,1,0,1"
                      ToolTip="Show or hide the GUI session log area."/>
            </StackPanel>
            <TextBlock Name="LblLogHeader" Text="Logs (latest)" FontSize="10" FontWeight="SemiBold"
                       Foreground="#333333" VerticalAlignment="Center"/>
          </DockPanel>
        </Border>
        <TextBox Name="LogBox" Background="#1E1E1E" Foreground="#D4D4D4"
                 FontFamily="Consolas" FontSize="12" IsReadOnly="True"
                 Height="96" MinHeight="0" MaxHeight="360"
                 VerticalScrollBarVisibility="Auto" TextWrapping="NoWrap"
                 HorizontalScrollBarVisibility="Auto" BorderThickness="0"/>
      </DockPanel>
    </Border>

    <!-- ZONE 4 actions moved into the left action rail (v0.8.61); Config folded into the rail Settings entry -->

    <!-- How it works strip (v0.8.58) -->
    <Border DockPanel.Dock="Top" Background="#F2F6FF" BorderThickness="0,0,0,1" BorderBrush="#CCCCCC" Padding="10,5">
      <TextBlock Foreground="#0F3460" FontSize="12" TextWrapping="Wrap">
        <Run Text="How it works:" FontWeight="SemiBold"/>
        <Run Text="  Prompt &#x2192; two models answer &#x2192; an Opus judge writes one final answer."/>
      </TextBlock>
    </Border>

    <!-- ZONE 2: INPUT -->
    <Border DockPanel.Dock="Top" Background="#F3F3F3" BorderThickness="0,0,0,1" BorderBrush="#CCCCCC" Padding="8,6">
      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <Grid Grid.Row="0">
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto"/>
            <ColumnDefinition Width="*"/>
          </Grid.ColumnDefinitions>
          <TextBlock Grid.Column="0" Text="Prompt:" FontWeight="SemiBold" Margin="0,4,8,0" VerticalAlignment="Top"/>
          <TextBox Grid.Column="1" Name="PromptBox" Height="84" AcceptsReturn="True" TextWrapping="Wrap"
                   VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12"/>
        </Grid>

        <!-- Essentials: Preset stays visible for first-run discovery (v0.8.60) -->
        <WrapPanel Grid.Row="1" Orientation="Horizontal" Margin="0,6,0,0">
          <TextBlock Text="Preset:" FontWeight="SemiBold" Foreground="#0F4D8C" VerticalAlignment="Center" Margin="0,0,4,0"/>
          <ComboBox Name="PresetCombo" Width="220" Height="26" IsEditable="False" ToolTip="Load a built-in prompt preset into the prompt box - a quick way to see an example." Margin="0,0,12,0" BorderBrush="#0F4D8C" BorderThickness="1" Background="#EAF1FB"/>
        </WrapPanel>

        <!-- Advanced settings: expert knobs, collapsed by default (v0.8.60). Selected models stay visible in the header panel. -->
        <Expander Grid.Row="2" Name="AdvancedExpander" Header="Advanced settings" IsExpanded="False" Margin="0,8,0,0"
                  ToolTip="Models, judge, task splitter, work mode, and output options. The defaults are fine for most prompts.">
          <StackPanel Orientation="Vertical" Margin="0,4,0,0">
            <WrapPanel Orientation="Horizontal" Margin="0,2,0,0">
              <TextBlock Text="Task splitter:" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="SplitCombo" Width="100" Height="26" IsEditable="False" Margin="0,0,12,0" ToolTip="How the prompt is split into tasks: Heuristic (auto) or None (single task)."/>
              <TextBlock Text="Work mode:" FontWeight="SemiBold" Foreground="#0F4D8C" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="WorkCombo" Width="90" Height="26" IsEditable="False" BorderBrush="#0F4D8C" BorderThickness="1" Background="#EAF1FB" Margin="0,0,12,0"
                        ToolTip="Auto: router decides per task. Review: design notes and snippets only. Script: full runnable scripts."/>
              <TextBlock Text="UI auto mode:" FontWeight="SemiBold" Foreground="#0F4D8C" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="UiModeCombo" Width="90" Height="26" IsEditable="False" BorderBrush="#0F4D8C" BorderThickness="1" Background="#EAF1FB" Margin="0,0,14,0"
                        ToolTip="Used only when Work mode = Auto: how ui_code concept tasks are handled."/>
              <CheckBox Name="ChkOpenNotepad" Content="Open final in Notepad" VerticalAlignment="Center" Margin="0,0,14,0"/>
              <CheckBox Name="ChkOpenFolder" Content="Open run folder when done" VerticalAlignment="Center" Margin="0,0,14,0"/>
              <CheckBox Name="ChkAskClarifying" Content="Ask questions if prompt is vague" VerticalAlignment="Center"
                        Margin="0,0,6,0"
                        ToolTip="Before running, stop and ask clarifying questions when the initial prompt looks underspecified."/>
              <TextBlock Text="Mode:" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="ClarifyModeCombo" Width="70" Height="26" IsEditable="False"
                        ToolTip="Local is free and heuristic. AI uses the configured review judge model to decide if clarification is needed."/>
            </WrapPanel>

            <WrapPanel Orientation="Horizontal" Margin="0,8,0,0">
              <TextBlock Text="Model A (OpenAI):" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="ModelACombo" Width="120" Height="26" IsEditable="True" Margin="0,0,12,0"/>
              <TextBlock Text="Model B (Claude):" VerticalAlignment="Center" Margin="0,0,4,0"/>
              <ComboBox Name="ModelBCombo" Width="140" Height="26" IsEditable="True" Margin="0,0,12,0"/>
              <TextBlock Text="Quality judge:" VerticalAlignment="Center" Margin="0,0,4,0" ToolTip="The strong judge used for Full comparisons (comparing two answers and synthesizing). Full mode always uses this, regardless of the Use fast judge toggle."/>
              <ComboBox Name="JudgeCombo" Width="140" Height="26" IsEditable="True" Margin="0,0,12,0"/>
              <CheckBox Name="ChkCheapJudge" Content="Use fast judge" VerticalAlignment="Center" Margin="0,0,4,0"
                        ToolTip="Full comparisons always use the Quality judge. When on, lighter Review/Light checks use the cheaper Fast judge on the right."/>
              <TextBlock Text="Fast judge:" VerticalAlignment="Center" Margin="6,0,4,0" ToolTip="The cheaper judge used only for Review/Light checks (single-answer validation) when Use fast judge is on."/>
              <ComboBox Name="CheapJudgeCombo" Width="140" Height="26" IsEditable="True"/>
              <CheckBox Name="ChkRunVerifier" Content="Run final verifier" VerticalAlignment="Center" Margin="12,0,4,0"
                        ToolTip="Optional. After the judge writes each task final answer, an independent verifier (not the judge) re-checks it for correctness, completeness, and unsupported claims. Off by default; uses the strong judge model and adds one API call per task."/>
            </WrapPanel>
          </StackPanel>
        </Expander>
      </Grid>
    </Border>

    <!-- ZONE 3: CONTENT -->
    <TabControl Name="MainTabs" Margin="6">
      <TabItem Header="Full Answer">
        <TextBox Name="FinalBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
                 VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="12"
                 Background="White"/>
      </TabItem>
      <TabItem Header="Tasks">
        <Grid Background="#F3F3F3">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
          </Grid.RowDefinitions>
          <Border Grid.Row="0" Background="#F8F8F8" BorderBrush="#D0D0D0" BorderThickness="0,0,0,1" Padding="8,6">
            <DockPanel>
              <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" Margin="0,0,12,0">
                <Button Name="BtnSelectAllTasks" Content="Enable All" Width="88" Height="26" Margin="0,0,6,0"
                        ToolTip="Enable every detected task for the next run."/>
                <Button Name="BtnClearTasks" Content="Disable All" Width="92" Height="26"
                        ToolTip="Disable every detected task. Run stays disabled until at least one task is enabled."/>
              </StackPanel>
              <StackPanel Orientation="Horizontal">
                <TextBlock Text="Task Review" FontWeight="SemiBold" VerticalAlignment="Center" Margin="0,0,12,0"/>
                <TextBlock Name="LblTaskReviewSummary" Text="No tasks detected yet" Foreground="#555555" VerticalAlignment="Center"/>
              </StackPanel>
            </DockPanel>
          </Border>
          <Grid Grid.Row="1" Margin="8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="2.2*"/>
              <ColumnDefinition Width="8"/>
              <ColumnDefinition Width="1*"/>
            </Grid.ColumnDefinitions>
            <DataGrid Grid.Column="0" Name="TasksGrid" AutoGenerateColumns="False"
                      AlternatingRowBackground="#F7FAFF" RowBackground="White"
                      SelectionMode="Single" GridLinesVisibility="Horizontal"
                      HeadersVisibility="Column" CanUserAddRows="False"
                      FontFamily="Segoe UI" FontSize="11"
                      ToolTip="Check the tasks to run. Double-click a completed task to open its final answer.">
              <DataGrid.ColumnHeaderStyle>
                <Style TargetType="DataGridColumnHeader">
                  <Setter Property="Background" Value="#1F4788"/>
                  <Setter Property="Foreground" Value="White"/>
                  <Setter Property="FontWeight" Value="SemiBold"/>
                  <Setter Property="Height" Value="28"/>
                  <Setter Property="Padding" Value="6,0"/>
                </Style>
              </DataGrid.ColumnHeaderStyle>
              <DataGrid.RowStyle>
                <Style TargetType="DataGridRow">
                  <Style.Triggers>
                    <DataTrigger Binding="{Binding IsSelected}" Value="False">
                      <Setter Property="Background" Value="#EEEEEE"/>
                      <Setter Property="Foreground" Value="#777777"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="Done">
                      <Setter Property="Background" Value="#E3F4E3"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Status}" Value="Running">
                      <Setter Property="Background" Value="#FFF0CC"/>
                      <Setter Property="FontWeight" Value="SemiBold"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Completeness}" Value="WARN">
                      <Setter Property="Background" Value="#FFF4E0"/>
                    </DataTrigger>
                    <DataTrigger Binding="{Binding Success}" Value="False">
                      <Setter Property="Background" Value="#FDE7E9"/>
                    </DataTrigger>
                  </Style.Triggers>
                </Style>
              </DataGrid.RowStyle>
              <DataGrid.Columns>
                <DataGridTemplateColumn Width="48">
                  <DataGridTemplateColumn.Header>
                    <CheckBox Name="ChkTaskRunAll" IsThreeState="True" Focusable="False"
                              HorizontalAlignment="Center" VerticalAlignment="Center"
                              ToolTip="Enable or disable all detected tasks"/>
                  </DataGridTemplateColumn.Header>
                  <DataGridTemplateColumn.CellTemplate>
                    <DataTemplate>
                      <CheckBox IsChecked="{Binding IsSelected, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"
                                Focusable="False" HorizontalAlignment="Center" VerticalAlignment="Center"
                                ToolTip="Include this task in the next run"/>
                    </DataTemplate>
                  </DataGridTemplateColumn.CellTemplate>
                </DataGridTemplateColumn>
                <DataGridTextColumn Header="#" Binding="{Binding Id}" Width="38" IsReadOnly="True"/>
                <DataGridTextColumn Header="Type" Binding="{Binding TypeLabel}" Width="78" IsReadOnly="True"/>
                <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="210" IsReadOnly="True"/>
                <DataGridTextColumn Header="Excerpt" Binding="{Binding Excerpt}" Width="*" IsReadOnly="True"/>
                <DataGridTextColumn Header="Status" Binding="{Binding Status}" Width="82" IsReadOnly="True"/>
                <DataGridTextColumn Header="Cost (USD/ILS)" Binding="{Binding EstCost}" Width="124" IsReadOnly="True">
                  <DataGridTextColumn.ElementStyle>
                    <Style TargetType="TextBlock">
                      <Setter Property="TextAlignment" Value="Right"/>
                      <Setter Property="Padding" Value="0,0,6,0"/>
                    </Style>
                  </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="Tokens" Binding="{Binding EstTokens}" Width="76" IsReadOnly="True">
                  <DataGridTextColumn.ElementStyle>
                    <Style TargetType="TextBlock">
                      <Setter Property="TextAlignment" Value="Right"/>
                      <Setter Property="Padding" Value="0,0,6,0"/>
                    </Style>
                  </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
                <DataGridTextColumn Header="Time" Binding="{Binding EstTime}" Width="64" IsReadOnly="True">
                  <DataGridTextColumn.ElementStyle>
                    <Style TargetType="TextBlock">
                      <Setter Property="TextAlignment" Value="Right"/>
                      <Setter Property="Padding" Value="0,0,6,0"/>
                    </Style>
                  </DataGridTextColumn.ElementStyle>
                </DataGridTextColumn>
              </DataGrid.Columns>
            </DataGrid>
            <GridSplitter Grid.Column="1" Width="8" HorizontalAlignment="Stretch" Background="#E3E3E3"/>
            <Border Grid.Column="2" Background="White" BorderBrush="#D0D0D0" BorderThickness="1" Padding="10">
              <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
                <StackPanel>
                <StackPanel DockPanel.Dock="Top">
                  <TextBlock Text="Selected Task Details" FontWeight="SemiBold" FontSize="13" Margin="0,0,0,8"/>
                  <TextBlock Name="TxtTaskDetailTitle" Text="Select a task" FontWeight="SemiBold" TextWrapping="Wrap" Margin="0,0,0,4"/>
                  <Grid Margin="0,2,0,8">
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="72"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Task Type" FontSize="12" Foreground="#888888"/>
                    <TextBlock Grid.Row="0" Grid.Column="1" Name="TxtDetailType" Text="-" FontSize="12" Foreground="#1B2545" FontWeight="SemiBold" TextWrapping="Wrap"/>
                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Status" FontSize="12" Foreground="#888888"/>
                    <TextBlock Grid.Row="1" Grid.Column="1" Name="TxtDetailStatus" Text="-" FontSize="12" Foreground="#1B2545" TextWrapping="Wrap"/>
                    <TextBlock Grid.Row="2" Grid.Column="0" Text="Cost" FontSize="12" Foreground="#888888"/>
                    <TextBlock Grid.Row="2" Grid.Column="1" Name="TxtDetailCost" Text="-" FontSize="12" Foreground="#0B6A0B" FontWeight="SemiBold" TextWrapping="Wrap"/>
                    <TextBlock Grid.Row="3" Grid.Column="0" Text="Tokens" FontSize="12" Foreground="#888888"/>
                    <TextBlock Grid.Row="3" Grid.Column="1" Name="TxtDetailTokens" Text="-" FontSize="12" Foreground="#1B2545" TextWrapping="Wrap"/>
                    <TextBlock Grid.Row="4" Grid.Column="0" Text="Time" FontSize="12" Foreground="#888888"/>
                    <TextBlock Grid.Row="4" Grid.Column="1" Name="TxtDetailTime" Text="-" FontSize="12" Foreground="#1B2545" TextWrapping="Wrap"/>
                    <TextBlock Grid.Row="5" Grid.Column="0" Text="Judge" FontSize="12" Foreground="#888888" Margin="0,4,0,0"/>
                    <TextBlock Grid.Row="5" Grid.Column="1" Name="TxtDetailJudge" Text="-" FontSize="12" Foreground="#0F3460" FontWeight="Bold" TextWrapping="Wrap" Margin="0,4,0,0"/>
                  </Grid>
                  <TextBlock Name="TxtDetailValueKind" Text="" FontSize="11" FontStyle="Italic" Foreground="#888888" TextWrapping="Wrap" Margin="0,4,0,0"/>
                </StackPanel>
                <StackPanel DockPanel.Dock="Top" Margin="0,0,0,8">
                  <TextBlock Text="Run as (override the auto router)" FontWeight="SemiBold" Foreground="#0B2545" FontSize="12" Margin="0,0,0,4"/>
                  <Grid>
                    <Grid.ColumnDefinitions>
                      <ColumnDefinition Width="Auto"/>
                      <ColumnDefinition Width="*"/>
                    </Grid.ColumnDefinitions>
                    <Grid.RowDefinitions>
                      <RowDefinition Height="Auto"/>
                      <RowDefinition Height="Auto"/>
                    </Grid.RowDefinitions>
                    <TextBlock Grid.Row="0" Grid.Column="0" Text="Task Type" FontSize="12" Foreground="#555555" VerticalAlignment="Center" Margin="0,0,8,4"/>
                    <ComboBox Grid.Row="0" Grid.Column="1" Name="CmbTaskTypeOverride" FontSize="12" Margin="0,0,0,4" IsEnabled="False" ToolTip="Override how this task is classified for routing. Auto = let the router decide. simple/technical are lighter; code and ui_code run both answer models plus the judge (a full script); documentation/creative use a single model. The choice changes which models and judge run, and the cost."/>
                    <TextBlock Grid.Row="1" Grid.Column="0" Text="Work Mode" FontSize="12" Foreground="#555555" VerticalAlignment="Center" Margin="0,0,8,0"/>
                    <ComboBox Grid.Row="1" Grid.Column="1" Name="CmbTaskWorkModeOverride" FontSize="12" IsEnabled="False" ToolTip="Override the answer depth. Auto = let the router decide. Review = notes and small snippets (cheaper). Script = a full, runnable script (uses the strong judge for Full comparisons)."/>
                  </Grid>
                </StackPanel>
                <TextBlock Name="TxtTaskDetailPromptLabel" DockPanel.Dock="Top" Text="Prompt" FontWeight="SemiBold" Foreground="#333333" Margin="0,0,0,4" Visibility="Collapsed"/>
                <TextBox Name="TaskDetailPromptBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto" FontFamily="Consolas" FontSize="11" Background="#FAFAFA"
                         Visibility="Collapsed" Height="110"/>
                </StackPanel>
              </ScrollViewer>
            </Border>
          </Grid>
        </Grid>
      </TabItem>
      <TabItem Header="Cost &amp; Metrics">
        <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" Background="#F3F3F3">
          <StackPanel Margin="10">

            <Border Background="White" BorderBrush="#D0D7DE" BorderThickness="1" CornerRadius="4" Padding="10" Margin="0,0,0,12">
              <StackPanel>
                <TextBlock Text="&#x1F4A1;  Cost recommendations" FontWeight="SemiBold" FontSize="13" Foreground="#0B2545" Margin="0,0,0,6"/>
                <TextBox Name="MetricsRecBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="Wrap"
                         BorderThickness="0" Background="White" FontFamily="Segoe UI" FontSize="12"
                         Text="Run a prompt to see cost recommendations."/>
              </StackPanel>
            </Border>

            <TextBlock Text="Cost by role" FontWeight="SemiBold" FontSize="13" Foreground="#0B2545" Margin="0,0,0,4"/>
            <DataGrid Name="CostRoleGrid" AutoGenerateColumns="False" AlternatingRowBackground="#F2F6FF" RowBackground="White"
                      SelectionMode="Single" GridLinesVisibility="Horizontal" HeadersVisibility="Column" CanUserAddRows="False"
                      IsReadOnly="True" FontFamily="Segoe UI" FontSize="11" MaxHeight="150" Margin="0,0,0,14"
                      ColumnHeaderStyle="{StaticResource GridHeader}">
              <DataGrid.Columns>
                <DataGridTextColumn Header="Role" Binding="{Binding Role}" Width="*"/>
                <DataGridTextColumn Header="Requests" Binding="{Binding RequestCount}" Width="84" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Seconds" Binding="{Binding DurationSeconds}" Width="84" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Input" Binding="{Binding InputTokens}" Width="84" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Output" Binding="{Binding OutputTokens}" Width="84" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Total" Binding="{Binding TotalTokens}" Width="84" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Cost USD" Binding="{Binding CostText}" Width="110" ElementStyle="{StaticResource GridNum}"/>
              </DataGrid.Columns>
            </DataGrid>

            <TextBlock Text="Cost by model" FontWeight="SemiBold" FontSize="13" Foreground="#0B2545" Margin="0,0,0,4"/>
            <DataGrid Name="CostModelGrid" AutoGenerateColumns="False" AlternatingRowBackground="#F2F6FF" RowBackground="White"
                      SelectionMode="Single" GridLinesVisibility="Horizontal" HeadersVisibility="Column" CanUserAddRows="False"
                      IsReadOnly="True" FontFamily="Segoe UI" FontSize="11" MaxHeight="190" Margin="0,0,0,14"
                      ColumnHeaderStyle="{StaticResource GridHeader}">
              <DataGrid.Columns>
                <DataGridTextColumn Header="Provider" Binding="{Binding Provider}" Width="90"/>
                <DataGridTextColumn Header="Model" Binding="{Binding Model}" Width="*"/>
                <DataGridTextColumn Header="Roles" Binding="{Binding Roles}" Width="110"/>
                <DataGridTextColumn Header="Reqs" Binding="{Binding RequestCount}" Width="64" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Seconds" Binding="{Binding DurationSeconds}" Width="80" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Input" Binding="{Binding InputTokens}" Width="80" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Output" Binding="{Binding OutputTokens}" Width="80" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Total" Binding="{Binding TotalTokens}" Width="80" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Cost USD" Binding="{Binding CostText}" Width="100" ElementStyle="{StaticResource GridNum}"/>
              </DataGrid.Columns>
            </DataGrid>

            <TextBlock Text="Task summary" FontWeight="SemiBold" FontSize="13" Foreground="#0B2545" Margin="0,0,0,4"/>
            <DataGrid Name="MetricsTaskGrid" AutoGenerateColumns="False" AlternatingRowBackground="#F2F6FF" RowBackground="White"
                      SelectionMode="Single" GridLinesVisibility="Horizontal" HeadersVisibility="Column" CanUserAddRows="False"
                      IsReadOnly="True" FontFamily="Segoe UI" FontSize="11" MaxHeight="320" Margin="0,0,0,14"
                      ColumnHeaderStyle="{StaticResource GridHeader}">
              <DataGrid.Columns>
                <DataGridTextColumn Header="#" Binding="{Binding TaskId}" Width="38" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Type" Binding="{Binding TaskType}" Width="84"/>
                <DataGridTextColumn Header="Work" Binding="{Binding WorkMode}" Width="70"/>
                <DataGridTextColumn Header="OK" Binding="{Binding Success}" Width="56"/>
                <DataGridTextColumn Header="Ans" Binding="{Binding AnswerCount}" Width="46" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Judge" Binding="{Binding JudgeMode}" Width="78"/>
                <DataGridTextColumn Header="Judge Model" Binding="{Binding JudgeModelUsed}" Width="150"/>
                <DataGridTextColumn Header="Compl" Binding="{Binding Completeness}" Width="64"/>
                <DataGridTextColumn Header="Tokens" Binding="{Binding TotalTokens}" Width="76" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Cost USD" Binding="{Binding CostText}" Width="90" ElementStyle="{StaticResource GridNum}"/>
                <DataGridTextColumn Header="Title" Binding="{Binding Title}" Width="*"/>
              </DataGrid.Columns>
            </DataGrid>

            <TextBlock Text="Timing and warnings" FontWeight="SemiBold" FontSize="13" Foreground="#0B2545" Margin="0,0,0,4"/>
            <TextBox Name="MetricsBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="NoWrap"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                     FontFamily="Consolas" FontSize="12" Background="White" Height="170"/>
          </StackPanel>
        </ScrollViewer>
      </TabItem>
      <TabItem Header="Run Log">
        <TextBox Name="RunLogBox" IsReadOnly="True" AcceptsReturn="True" TextWrapping="NoWrap"
                 VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                 FontFamily="Consolas" FontSize="12" Background="#1E1E1E" Foreground="#D4D4D4"/>
      </TabItem>
      <TabItem Header="Edit Tasks" Visibility="Collapsed">
        <DockPanel>
          <Border DockPanel.Dock="Top" Background="#F3F3F3" Padding="8,6">
            <StackPanel>
              <CheckBox Name="ChkUseEditedTasks" Content="Use this task list when I click Run (one task per line)" VerticalAlignment="Center"/>
              <TextBlock Text="Detect Tasks fills this list. Edit freely: one task per line - add lines, delete lines, reorder. Empty list = auto-split the prompt." FontSize="10" Foreground="#666666" TextWrapping="Wrap" Margin="0,4,0,0"/>
            </StackPanel>
          </Border>
          <TextBox Name="TasksEditBox" AcceptsReturn="True" TextWrapping="NoWrap" Margin="8"
                   VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                   FontFamily="Consolas" FontSize="12" Background="White"/>
        </DockPanel>
      </TabItem>
    </TabControl>

  </DockPanel>
</Window>
"@

$GuiXaml = $GuiXamlTemplate.Replace("__VERSION__", $ToolVersion)

# ---- Load XAML ----

$GuiWindow = $null
try {
    $XmlDoc = New-Object System.Xml.XmlDocument
    $XmlDoc.LoadXml($GuiXaml)
    $XmlReader = New-Object System.Xml.XmlNodeReader($XmlDoc)
    $GuiWindow = [System.Windows.Markup.XamlReader]::Load($XmlReader)
}
catch {
    Write-Host ("[ERROR] Failed to load GUI XAML: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}

# ---- Find controls ----

$Script:Ctl_PromptBox    = $GuiWindow.FindName("PromptBox")
$Script:Ctl_PresetCombo  = $GuiWindow.FindName("PresetCombo")
$Script:Ctl_SplitCombo   = $GuiWindow.FindName("SplitCombo")
$Script:Ctl_ChkOpenNotepad = $GuiWindow.FindName("ChkOpenNotepad")
$Script:Ctl_ChkOpenFolder  = $GuiWindow.FindName("ChkOpenFolder")
$Script:Ctl_ChkAskClarifying = $GuiWindow.FindName("ChkAskClarifying")
$Script:Ctl_ClarifyModeCombo = $GuiWindow.FindName("ClarifyModeCombo")
$Script:Ctl_MainTabs     = $GuiWindow.FindName("MainTabs")
$Script:Ctl_FinalBox     = $GuiWindow.FindName("FinalBox")
$Script:Ctl_TasksGrid    = $GuiWindow.FindName("TasksGrid")
$Script:Ctl_MetricsBox   = $GuiWindow.FindName("MetricsBox")
$Script:Ctl_MetricsRecBox   = $GuiWindow.FindName("MetricsRecBox")
$Script:Ctl_CostRoleGrid    = $GuiWindow.FindName("CostRoleGrid")
$Script:Ctl_CostModelGrid   = $GuiWindow.FindName("CostModelGrid")
$Script:Ctl_MetricsTaskGrid = $GuiWindow.FindName("MetricsTaskGrid")
$Script:Ctl_RunLogBox    = $GuiWindow.FindName("RunLogBox")
$Script:Ctl_LogBox       = $GuiWindow.FindName("LogBox")
$Script:Ctl_LblLogHeader = $GuiWindow.FindName("LblLogHeader")
$Script:Ctl_BtnToggleLog = $GuiWindow.FindName("BtnToggleLog")
$Script:Ctl_BtnRun       = $GuiWindow.FindName("BtnRun")
$Script:Ctl_BtnDetect    = $GuiWindow.FindName("BtnDetect")
$Script:Ctl_BtnStop      = $GuiWindow.FindName("BtnStop")
$Script:Ctl_BtnExit      = $GuiWindow.FindName("BtnExit")
$Script:Ctl_BtnCopyFinal = $GuiWindow.FindName("BtnCopyFinal")
$Script:Ctl_BtnCopyQuick = $GuiWindow.FindName("BtnCopyQuick")
$Script:Ctl_BtnImproved  = $GuiWindow.FindName("BtnImproved")
$Script:Ctl_WorkCombo    = $GuiWindow.FindName("WorkCombo")
$Script:Ctl_UiModeCombo  = $GuiWindow.FindName("UiModeCombo")
$Script:Ctl_ModelACombo  = $GuiWindow.FindName("ModelACombo")
$Script:Ctl_ModelBCombo  = $GuiWindow.FindName("ModelBCombo")
$Script:Ctl_JudgeCombo   = $GuiWindow.FindName("JudgeCombo")
$Script:Ctl_ChkCheapJudge = $GuiWindow.FindName("ChkCheapJudge")
$Script:Ctl_ChkRunVerifier = $GuiWindow.FindName("ChkRunVerifier")
$Script:Ctl_CheapJudgeCombo = $GuiWindow.FindName("CheapJudgeCombo")
$Script:Ctl_BtnOpenFolder = $GuiWindow.FindName("BtnOpenFolder")
$Script:Ctl_BtnHtmlReport = $GuiWindow.FindName("BtnHtmlReport")
$Script:Ctl_StatusText   = $GuiWindow.FindName("StatusText")
$Script:Ctl_PbTasks      = $GuiWindow.FindName("PbTasks")
$Script:Ctl_LblTasksDone = $GuiWindow.FindName("LblTasksDone")
$Script:Ctl_LblCostEstimate = $GuiWindow.FindName("LblCostEstimate")
$Script:Ctl_LblElapsed   = $GuiWindow.FindName("LblElapsed")
$Script:Ctl_HdrRunFolder = $GuiWindow.FindName("HdrRunFolder")
$Script:Ctl_HdrModelA    = $GuiWindow.FindName("HdrModelA")
$Script:Ctl_HdrModelB    = $GuiWindow.FindName("HdrModelB")
$Script:Ctl_HdrJudgeFull = $GuiWindow.FindName("HdrJudgeFull")
$Script:Ctl_HdrJudgeCheap = $GuiWindow.FindName("HdrJudgeCheap")
$Script:Ctl_HdrApiStatus = $GuiWindow.FindName("HdrApiStatus")
$Script:Ctl_BtnHdrSetKeys = $GuiWindow.FindName("BtnHdrSetKeys")
$Script:Ctl_BtnSideNewRun = $GuiWindow.FindName("BtnSideNewRun")
$Script:Ctl_BtnSideSettings = $GuiWindow.FindName("BtnSideSettings")
$Script:Ctl_TxtSideVersion = $GuiWindow.FindName("TxtSideVersion")
$Script:Ctl_BtnSideRecent1 = $GuiWindow.FindName("BtnSideRecent1")
$Script:Ctl_BtnSideRecent2 = $GuiWindow.FindName("BtnSideRecent2")
$Script:Ctl_BtnSideRecent3 = $GuiWindow.FindName("BtnSideRecent3")
$Script:Ctl_BtnSideRecent4 = $GuiWindow.FindName("BtnSideRecent4")
$Script:Ctl_TxtSideRecent1Name = $GuiWindow.FindName("TxtSideRecent1Name")
$Script:Ctl_TxtSideRecent1Time = $GuiWindow.FindName("TxtSideRecent1Time")
$Script:Ctl_TxtSideRecent2Name = $GuiWindow.FindName("TxtSideRecent2Name")
$Script:Ctl_TxtSideRecent2Time = $GuiWindow.FindName("TxtSideRecent2Time")
$Script:Ctl_TxtSideRecent3Name = $GuiWindow.FindName("TxtSideRecent3Name")
$Script:Ctl_TxtSideRecent3Time = $GuiWindow.FindName("TxtSideRecent3Time")
$Script:Ctl_TxtSideRecent4Name = $GuiWindow.FindName("TxtSideRecent4Name")
$Script:Ctl_TxtSideRecent4Time = $GuiWindow.FindName("TxtSideRecent4Time")
$Script:Ctl_TxtRailRunName = $GuiWindow.FindName("TxtRailRunName")
$Script:Ctl_TxtRailCreated = $GuiWindow.FindName("TxtRailCreated")
$Script:Ctl_TxtRailLastRun = $GuiWindow.FindName("TxtRailLastRun")
$Script:Ctl_TxtRailRunStatus = $GuiWindow.FindName("TxtRailRunStatus")
$Script:Ctl_TxtRailCostBig = $GuiWindow.FindName("TxtRailCostBig")
$Script:Ctl_TxtRailCostLabel = $GuiWindow.FindName("TxtRailCostLabel")
$Script:Ctl_TxtRailCostIls = $GuiWindow.FindName("TxtRailCostIls")
$Script:Ctl_TxtRailCostCompare = $GuiWindow.FindName("TxtRailCostCompare")
$Script:Ctl_TxtRailBudget = $GuiWindow.FindName("TxtRailBudget")
$Script:Ctl_PbRailCost = $GuiWindow.FindName("PbRailCost")
$Script:Ctl_TxtRailBudgetPct = $GuiWindow.FindName("TxtRailBudgetPct")
$Script:Ctl_TxtRailPreRunCost = $GuiWindow.FindName("TxtRailPreRunCost")
$Script:Ctl_TxtRailPreRunTime = $GuiWindow.FindName("TxtRailPreRunTime")
$Script:Ctl_TxtRailPreRunTasks = $GuiWindow.FindName("TxtRailPreRunTasks")
$Script:Ctl_TxtRailInputTokens = $GuiWindow.FindName("TxtRailInputTokens")
$Script:Ctl_TxtRailOutputTokens = $GuiWindow.FindName("TxtRailOutputTokens")
$Script:Ctl_TxtRailTotalTokens = $GuiWindow.FindName("TxtRailTotalTokens")
$Script:Ctl_TxtRailLatencyTotal = $GuiWindow.FindName("TxtRailLatencyTotal")
$Script:Ctl_TxtRailLatencyAvg = $GuiWindow.FindName("TxtRailLatencyAvg")
$Script:Ctl_TxtRailApiStatus = $GuiWindow.FindName("TxtRailApiStatus")
$Script:Ctl_TxtRailSuccessRate = $GuiWindow.FindName("TxtRailSuccessRate")
$Script:Ctl_TasksEditBox = $GuiWindow.FindName("TasksEditBox")
$Script:Ctl_ChkUseEditedTasks = $GuiWindow.FindName("ChkUseEditedTasks")
$Script:Ctl_LblTaskReviewSummary = $GuiWindow.FindName("LblTaskReviewSummary")
$Script:Ctl_BtnSelectAllTasks = $GuiWindow.FindName("BtnSelectAllTasks")
$Script:Ctl_BtnClearTasks = $GuiWindow.FindName("BtnClearTasks")
$Script:Ctl_ChkTaskRunAll = $GuiWindow.FindName("ChkTaskRunAll")
$Script:Ctl_TxtTaskDetailTitle = $GuiWindow.FindName("TxtTaskDetailTitle")
$Script:Ctl_TxtDetailType = $GuiWindow.FindName("TxtDetailType")
$Script:Ctl_TxtDetailStatus = $GuiWindow.FindName("TxtDetailStatus")
$Script:Ctl_TxtDetailCost = $GuiWindow.FindName("TxtDetailCost")
$Script:Ctl_TxtDetailTokens = $GuiWindow.FindName("TxtDetailTokens")
$Script:Ctl_TxtDetailTime = $GuiWindow.FindName("TxtDetailTime")
$Script:Ctl_TxtDetailJudge = $GuiWindow.FindName("TxtDetailJudge")
$Script:Ctl_TxtDetailValueKind = $GuiWindow.FindName("TxtDetailValueKind")
$Script:Ctl_TxtTaskDetailPromptLabel = $GuiWindow.FindName("TxtTaskDetailPromptLabel")
$Script:Ctl_TaskDetailPromptBox = $GuiWindow.FindName("TaskDetailPromptBox")
$Script:Ctl_ChkTaskDetailInclude = $GuiWindow.FindName("ChkTaskDetailInclude")
$Script:Ctl_CmbTaskTypeOverride = $GuiWindow.FindName("CmbTaskTypeOverride")
$Script:Ctl_CmbTaskWorkModeOverride = $GuiWindow.FindName("CmbTaskWorkModeOverride")
if ($null -ne $Script:Ctl_CmbTaskTypeOverride) {
    $Script:Ctl_CmbTaskTypeOverride.ItemsSource = @("Auto", "simple", "technical", "code", "ui_code", "documentation", "creative")
    $Script:Ctl_CmbTaskTypeOverride.SelectedIndex = 0
}
if ($null -ne $Script:Ctl_CmbTaskWorkModeOverride) {
    $Script:Ctl_CmbTaskWorkModeOverride.ItemsSource = @("Auto", "Review", "Script")
    $Script:Ctl_CmbTaskWorkModeOverride.SelectedIndex = 0
}

# ---- Initialize controls ----

[void]$Script:Ctl_PresetCombo.Items.Add("Custom")
[void]$Script:Ctl_PresetCombo.Items.Add("SingleAD")
[void]$Script:Ctl_PresetCombo.Items.Add("MultiTaskDemo")
$Script:Ctl_PresetCombo.SelectedIndex = 0

[void]$Script:Ctl_SplitCombo.Items.Add("Heuristic")
[void]$Script:Ctl_SplitCombo.Items.Add("None")
$Script:Ctl_SplitCombo.SelectedIndex = 0

[void]$Script:Ctl_WorkCombo.Items.Add("Auto")
[void]$Script:Ctl_WorkCombo.Items.Add("Review")
[void]$Script:Ctl_WorkCombo.Items.Add("Script")
if ($Script:Ctl_WorkCombo.Items.Contains($TaskWorkMode)) {
    $Script:Ctl_WorkCombo.SelectedItem = $TaskWorkMode
}
else {
    $Script:Ctl_WorkCombo.SelectedIndex = 0
}

[void]$Script:Ctl_UiModeCombo.Items.Add("Review")
[void]$Script:Ctl_UiModeCombo.Items.Add("Script")
if ($Script:Ctl_UiModeCombo.Items.Contains($UiCodeAutoWorkMode)) {
    $Script:Ctl_UiModeCombo.SelectedItem = $UiCodeAutoWorkMode
}
else {
    $Script:Ctl_UiModeCombo.SelectedIndex = 0
}
$Script:Ctl_UiModeCombo.IsEnabled = ([string]$Script:Ctl_WorkCombo.SelectedItem -eq "Auto")

function Initialize-ModelCombo {
    param(
        [object]$Combo,
        [string[]]$KnownModels,
        [string]$DefaultModel
    )

    foreach ($KnownModel in $KnownModels) {
        if (-not $Combo.Items.Contains($KnownModel)) {
            [void]$Combo.Items.Add($KnownModel)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($DefaultModel)) {
        if (-not $Combo.Items.Contains($DefaultModel)) {
            [void]$Combo.Items.Add($DefaultModel)
        }
        $Combo.SelectedItem = $DefaultModel
        $Combo.Text = $DefaultModel
    }
    else {
        $Combo.SelectedIndex = 0
    }
}

# Known model lists. Custom model IDs can be added via the config file Models section;
# the configured value is always injected into the list automatically.
Initialize-ModelCombo -Combo $Script:Ctl_ModelACombo -KnownModels @("gpt-4.1-mini", "gpt-4.1", "gpt-4o-mini") -DefaultModel $OpenAIModel_Answer
Initialize-ModelCombo -Combo $Script:Ctl_ModelBCombo -KnownModels @("claude-sonnet-4-6", "claude-haiku-4-5") -DefaultModel $AnthropicModel_Answer
Initialize-ModelCombo -Combo $Script:Ctl_JudgeCombo -KnownModels @("claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5") -DefaultModel $AnthropicModel_Judge
Initialize-ModelCombo -Combo $Script:Ctl_CheapJudgeCombo -KnownModels @("claude-sonnet-4-6", "claude-haiku-4-5") -DefaultModel $AnthropicModel_JudgeCheap

$Script:Ctl_ChkCheapJudge.IsChecked = $UseCheapJudgeForReview
if ($null -ne $Script:Ctl_ChkRunVerifier) { $Script:Ctl_ChkRunVerifier.IsChecked = $RunFinalVerifier }
$Script:Ctl_CheapJudgeCombo.IsEnabled = ($UseCheapJudgeForReview -eq $true)

$Script:Ctl_ChkCheapJudge.Add_Click({
    $Script:Ctl_CheapJudgeCombo.IsEnabled = ($Script:Ctl_ChkCheapJudge.IsChecked -eq $true)
    Update-AllTaskReviewRowEstimates
})

# Re-estimate detected tasks live when a model or judge selection changes, so the grid Cost and the
# per-task "Judge: <model> (<mode>)" in the detail panel update without re-running Detect Tasks.
# (Full comparison tasks always keep the strong judge by policy, so toggling the fast judge only
# changes Review/Light tasks; for Full tasks the judge stays the strong model on purpose.)
$EstimateRefreshHandler = { Update-AllTaskReviewRowEstimates }
if ($null -ne $Script:Ctl_CheapJudgeCombo) { $Script:Ctl_CheapJudgeCombo.Add_SelectionChanged($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_JudgeCombo) { $Script:Ctl_JudgeCombo.Add_SelectionChanged($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_ModelACombo) { $Script:Ctl_ModelACombo.Add_SelectionChanged($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_ModelBCombo) { $Script:Ctl_ModelBCombo.Add_SelectionChanged($EstimateRefreshHandler) }
# Typed (custom) model ids in the editable combos do not raise SelectionChanged, so also re-estimate
# when focus leaves the box - a hand-typed model id then updates the cost/judge without a re-Detect.
if ($null -ne $Script:Ctl_CheapJudgeCombo) { $Script:Ctl_CheapJudgeCombo.Add_LostFocus($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_JudgeCombo) { $Script:Ctl_JudgeCombo.Add_LostFocus($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_ModelACombo) { $Script:Ctl_ModelACombo.Add_LostFocus($EstimateRefreshHandler) }
if ($null -ne $Script:Ctl_ModelBCombo) { $Script:Ctl_ModelBCombo.Add_LostFocus($EstimateRefreshHandler) }

# Initialize prompt + preset combo from the script-level PromptPreset default.
if ($PromptPreset -eq "SingleAD") {
    $Script:Ctl_PresetCombo.SelectedItem = "SingleAD"
    $Script:Ctl_PromptBox.Text = $SingleADPrompt
}
elseif ($PromptPreset -eq "MultiTaskDemo") {
    $Script:Ctl_PresetCombo.SelectedItem = "MultiTaskDemo"
    $Script:Ctl_PromptBox.Text = $MultiTaskDemoPrompt
}
else {
    $Script:Ctl_PresetCombo.SelectedItem = "Custom"
    $Script:Ctl_PromptBox.Text = $CustomUserPrompt
}

$Script:Ctl_ChkOpenFolder.IsChecked = $false
$Script:Ctl_ChkOpenNotepad.IsChecked = $false
if ($null -ne $Script:Ctl_ChkAskClarifying) { $Script:Ctl_ChkAskClarifying.IsChecked = $false }
if ($null -ne $Script:Ctl_ClarifyModeCombo) {
    [void]$Script:Ctl_ClarifyModeCombo.Items.Add("Local")
    [void]$Script:Ctl_ClarifyModeCombo.Items.Add("AI")
    $Script:Ctl_ClarifyModeCombo.SelectedItem = "Local"
}

# ---- Poll timer (1 second) ----

$Script:PollTimer = New-Object System.Windows.Threading.DispatcherTimer
$Script:PollTimer.Interval = [TimeSpan]::FromSeconds(1)

$Script:PollTimer.Add_Tick({
    if ($Script:IsBusy -ne $true) {
        return
    }
    if ([string]::IsNullOrWhiteSpace($Script:CurrentRunFolder)) {
        return
    }

    # Elapsed
    if ($null -ne $Script:RunStartTime) {
        $ElapsedSec = [int]((Get-Date) - $Script:RunStartTime).TotalSeconds
        $Script:Ctl_LblElapsed.Text = "Elapsed: " + $ElapsedSec + " s"
    }

    # Total task count from tasks.json (written early by the pipeline)
    if ($Script:TotalTasks -le 0) {
        $TasksJsonPath = Join-Path $Script:CurrentRunFolder "tasks.json"
        $TasksText = Get-FileTextSafe -Path $TasksJsonPath
        if (-not [string]::IsNullOrWhiteSpace($TasksText)) {
            try {
                $TasksObj = $TasksText | ConvertFrom-Json -ErrorAction Stop
                $Script:TotalTasks = @($TasksObj).Count
                if ($Script:TotalTasks -gt 0) {
                    $Script:Ctl_PbTasks.Maximum = $Script:TotalTasks
                    Add-GuiLog -Tag "INFO" -Message ("Tasks detected: " + $Script:TotalTasks)
                }
            }
            catch {
            }
        }
    }

    # Completed tasks = Task_NN folders that already contain final_answer.md
    $DoneCount = 0
    try {
        $TaskFolders = @(Get-ChildItem -Path $Script:CurrentRunFolder -Directory -Filter "Task_*" -ErrorAction SilentlyContinue)
        foreach ($Folder in $TaskFolders) {
            $TaskFinal = Join-Path $Folder.FullName "final_answer.md"
            if (Test-Path -LiteralPath $TaskFinal) {
                $DoneCount++
            }
        }
    }
    catch {
        $DoneCount = 0
    }

    $TotalLabel = $Script:TotalTasks
    if ($TotalLabel -le 0) {
        $TotalLabel = "?"
    }
    $Script:Ctl_LblTasksDone.Text = "Tasks: " + $DoneCount + " / " + $TotalLabel

    if ($DoneCount -ne $Script:LastDoneCount) {
        $Script:LastDoneCount = $DoneCount
        if ($DoneCount -gt 0) {
            Add-GuiLog -Tag "INFO" -Message ("Progress: " + $DoneCount + " / " + $TotalLabel + " tasks completed")
        }
        # Live per-row status: tasks run sequentially, so the first DoneCount selected rows are Done,
        # the next one is Running, the rest still pending. Deselected (Skipped) rows are left alone. The
        # grid RowStyle colors Done green / Running amber; the post-run summary rebuild supersedes this.
        if ($null -ne $Script:TaskReviewRows) {
            $RunIdx = 0
            foreach ($Row in @($Script:TaskReviewRows)) {
                if ($Row.IsSelected -ne $true) { continue }
                if ($RunIdx -lt $DoneCount) { $Row.Status = "Done" }
                elseif ($RunIdx -eq $DoneCount) { $Row.Status = "Running" }
                else { $Row.Status = "Ready" }
                $RunIdx++
            }
            Refresh-TaskReviewGrid
        }
    }

    if ($Script:TotalTasks -gt 0) {
        if ($DoneCount -le $Script:TotalTasks) {
            $Script:Ctl_PbTasks.Value = $DoneCount
        }
    }

    # Live transcript tail into Run Log tab (only when it grew)
    $TranscriptFile = Join-Path $Script:CurrentRunFolder "console_transcript.txt"
    $TailText = Get-FileTextSafe -Path $TranscriptFile -MaxChars 20000
    if ($TailText.Length -ne $Script:LastTranscriptLen) {
        $Script:LastTranscriptLen = $TailText.Length
        $Script:Ctl_RunLogBox.Text = $TailText
        $Script:Ctl_RunLogBox.ScrollToEnd()
    }

    # Child process finished?
    if ($null -ne $Script:ChildProcess) {
        $HasExited = $false
        try {
            $HasExited = $Script:ChildProcess.HasExited
        }
        catch {
            $HasExited = $true
        }

        if ($HasExited -eq $true) {
            $ExitCode = -1
            try {
                $ExitCode = $Script:ChildProcess.ExitCode
            }
            catch {
                $ExitCode = -1
            }
            Complete-GuiRun -ExitCode $ExitCode
        }
    }
})

# ---- Event handlers ----

$Script:Ctl_WorkCombo.Add_SelectionChanged({
    if ($null -eq $Script:Ctl_UiModeCombo) {
        return
    }
    $Script:Ctl_UiModeCombo.IsEnabled = ([string]$Script:Ctl_WorkCombo.SelectedItem -eq "Auto")
})

$Script:Ctl_PresetCombo.Add_SelectionChanged({
    if ($Script:UIReady -ne $true) {
        return
    }

    $Selected = [string]$Script:Ctl_PresetCombo.SelectedItem

    if ($Selected -eq "SingleAD") {
        $Script:Ctl_PromptBox.Text = $SingleADPrompt
        Add-GuiLog -Tag "INFO" -Message "Preset loaded: SingleAD"
    }
    elseif ($Selected -eq "MultiTaskDemo") {
        $Script:Ctl_PromptBox.Text = $MultiTaskDemoPrompt
        Add-GuiLog -Tag "INFO" -Message "Preset loaded: MultiTaskDemo"
    }
})

$Script:Ctl_BtnRun.Add_Click({
    if ($Script:IsBusy -eq $true) {
        return
    }

    $PromptText = $Script:Ctl_PromptBox.Text

    if ([string]::IsNullOrWhiteSpace($PromptText)) {
        Add-GuiLog -Tag "WARN" -Message "Prompt is empty. Nothing to run."
        return
    }

    if ($null -ne $Script:Ctl_ChkAskClarifying -and $Script:Ctl_ChkAskClarifying.IsChecked -eq $true) {
        $ClarifyMode = "Local"
        if ($null -ne $Script:Ctl_ClarifyModeCombo -and -not [string]::IsNullOrWhiteSpace([string]$Script:Ctl_ClarifyModeCombo.SelectedItem)) {
            $ClarifyMode = [string]$Script:Ctl_ClarifyModeCombo.SelectedItem
        }

        $ClarifyingQuestions = @()
        if ($ClarifyMode -eq "AI") {
            $KeyStateForClarify = Get-ApiKeyReadiness
            if ($KeyStateForClarify.Ready -ne $true) {
                Add-GuiLog -Tag "WARN" -Message "AI clarification requires API keys. Opening the API keys dialog."
                Show-ApiKeysWindow
                Update-RunButtonState
                Update-ApiStatusHeader
                $KeyStateForClarify = Get-ApiKeyReadiness
                if ($KeyStateForClarify.Ready -ne $true) {
                    Add-GuiLog -Tag "WARN" -Message "API keys still missing. Falling back to local clarification check."
                    $ClarifyMode = "Local"
                }
            }
        }

        if ($ClarifyMode -eq "AI") {
            $ClarifyModel = [string]$Script:Ctl_CheapJudgeCombo.Text
            if ([string]::IsNullOrWhiteSpace($ClarifyModel)) { $ClarifyModel = [string]$Script:Ctl_JudgeCombo.Text }
            if ([string]::IsNullOrWhiteSpace($ClarifyModel)) { $ClarifyModel = $AnthropicModel_Judge }
            Add-GuiLog -Tag "INFO" -Message ("AI clarification check using " + $ClarifyModel + "...")
            Set-GuiStatus "Checking prompt clarity..."
            $AiClarify = Invoke-GuiAiClarificationCheck -PromptText $PromptText -Model $ClarifyModel
            if ($AiClarify.Success -eq $true) {
                if ($null -ne $AiClarify.CostUsd) {
                    Add-GuiLog -Tag "INFO" -Message ("AI clarification check complete. Cost estimate: $" + $AiClarify.CostUsd)
                }
                else {
                    Add-GuiLog -Tag "INFO" -Message "AI clarification check complete."
                }
                if ($AiClarify.NeedsClarification -eq $true) {
                    $ClarifyingQuestions = @($AiClarify.Questions)
                    if (-not [string]::IsNullOrWhiteSpace([string]$AiClarify.Reason)) {
                        Add-GuiLog -Tag "INFO" -Message ("AI clarity reason: " + [string]$AiClarify.Reason)
                    }
                }
            }
            else {
                Add-GuiLog -Tag "WARN" -Message ("AI clarification check failed; falling back to local check. " + $AiClarify.Error)
                $ClarifyingQuestions = @(Get-GuiClarifyingQuestions -PromptText $PromptText)
            }
        }
        else {
            $ClarifyingQuestions = @(Get-GuiClarifyingQuestions -PromptText $PromptText)
        }

        if (@($ClarifyingQuestions).Count -gt 0) {
            Add-GuiLog -Tag "INFO" -Message ($ClarifyMode + " prompt clarity check found " + @($ClarifyingQuestions).Count + " question(s).")
            $ClarifyResult = Show-ClarifyingQuestionsWindow -PromptText $PromptText -Questions $ClarifyingQuestions
            if ($ClarifyResult.Action -eq "Cancel") {
                Add-GuiLog -Tag "INFO" -Message "Run canceled during prompt clarification."
                Set-GuiStatus "Run canceled"
                return
            }
            elseif ($ClarifyResult.Action -eq "AddAndRun") {
                $ClarText = [string]$ClarifyResult.Clarification
                if (-not [string]::IsNullOrWhiteSpace($ClarText)) {
                    $PromptText = $PromptText.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + "Clarifications:" + [Environment]::NewLine + $ClarText.Trim()
                    $Script:Ctl_PromptBox.Text = $PromptText
                    $Script:Ctl_PresetCombo.SelectedItem = "Custom"
                    Add-GuiLog -Tag "OK" -Message "Clarifications added to the prompt."
                }
                else {
                    Add-GuiLog -Tag "WARN" -Message "No clarification text entered; continuing with the original prompt."
                }
            }
            else {
                Add-GuiLog -Tag "INFO" -Message "Prompt clarification skipped; running anyway."
            }
        }
        else {
            Add-GuiLog -Tag "INFO" -Message ($ClarifyMode + " prompt clarity check found no blocking questions.")
        }
    }

    if ([string]::IsNullOrWhiteSpace($Script:SelfPath) -or (-not (Test-Path -LiteralPath $Script:SelfPath))) {
        Add-GuiLog -Tag "ERROR" -Message "Cannot resolve this script's file path. Save the script to disk before running (unsaved ISE tabs are not supported)."
        return
    }

    $KeyState = Get-ApiKeyReadiness
    if ($KeyState.Ready -ne $true) {
        Add-GuiLog -Tag "WARN" -Message "API keys are missing. Opening the API keys dialog."
        Show-ApiKeysWindow
        Update-RunButtonState
        $KeyState = Get-ApiKeyReadiness
        if ($KeyState.Ready -ne $true) {
            Add-GuiLog -Tag "WARN" -Message "Still no API keys. Use Config > Set API keys, or set OPENAI_API_KEY / ANTHROPIC_API_KEY."
            return
        }
    }
    if ($KeyState.SecretsFileExists -ne $true) {
        Add-GuiLog -Tag "WARN" -Message "Secrets file not found. Using environment variables fallback."
    }

    # First-run convenience: if no tasks have been detected yet, detect them now so the user sees the
    # task list + cost estimate and the run uses that explicit list (no separate Detect Tasks click).
    if ($null -eq $Script:TaskReviewRows -or @($Script:TaskReviewRows).Count -le 0) {
        $AutoDetectCount = Invoke-DetectTasks -Announce
        if ($AutoDetectCount -gt 0) {
            Add-GuiLog -Tag "INFO" -Message ("Auto-detected " + $AutoDetectCount + " task(s) for this run.")
        }
    }

    if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0 -and $Script:Ctl_ChkUseEditedTasks.IsChecked -eq $true) {
        if (@(Get-SelectedTaskReviewRows).Count -le 0) {
            Add-GuiLog -Tag "WARN" -Message "No tasks selected. Select at least one task in the Tasks tab before running."
            Set-GuiStatus "Select tasks to run"
            Update-RunButtonState
            return
        }
    }

    # Prepare run folder up front so the GUI knows exactly where to look.
    $TimeStampGui = Get-Date -Format "yyyyMMdd_HHmmss"
    $Script:CurrentRunFolder = Join-Path $OutputRoot ($RunName + "_" + $TimeStampGui)

    try {
        New-Item -ItemType Directory -Path $Script:CurrentRunFolder -Force | Out-Null
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to create run folder: " + $_.Exception.Message)
        return
    }

    $PromptFilePath = Join-Path $Script:CurrentRunFolder "gui_prompt.txt"
    try {
        $Utf8BomGui = New-Object System.Text.UTF8Encoding($true)
        [System.IO.File]::WriteAllText($PromptFilePath, $PromptText, $Utf8BomGui)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to write prompt file: " + $_.Exception.Message)
        return
    }

    $SplitMode = [string]$Script:Ctl_SplitCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($SplitMode)) {
        $SplitMode = "Heuristic"
    }

    $WorkModeSel = [string]$Script:Ctl_WorkCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($WorkModeSel)) {
        $WorkModeSel = "Auto"
    }

    $UiModeSel = [string]$Script:Ctl_UiModeCombo.SelectedItem
    if ([string]::IsNullOrWhiteSpace($UiModeSel)) {
        $UiModeSel = "Review"
    }

    $ModelASel = [string]$Script:Ctl_ModelACombo.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($ModelASel)) {
        $ModelASel = $OpenAIModel_Answer
    }

    $ModelBSel = [string]$Script:Ctl_ModelBCombo.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($ModelBSel)) {
        $ModelBSel = $AnthropicModel_Answer
    }

    $JudgeSel = [string]$Script:Ctl_JudgeCombo.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($JudgeSel)) {
        $JudgeSel = $AnthropicModel_Judge
    }

    $CheapJudgeSel = [string]$Script:Ctl_CheapJudgeCombo.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($CheapJudgeSel)) {
        $CheapJudgeSel = $AnthropicModel_JudgeCheap
    }

    $CheapJudgeFlag = "0"
    if ($Script:Ctl_ChkCheapJudge.IsChecked -eq $true) {
        $CheapJudgeFlag = "1"
    }

    $VerifierFlag = "0"
    if ($null -ne $Script:Ctl_ChkRunVerifier -and $Script:Ctl_ChkRunVerifier.IsChecked -eq $true) {
        $VerifierFlag = "1"
        Add-GuiLog -Tag "INFO" -Message "Final verifier: ON (independent check after the judge; one extra API call per task)."
    }

    # Launch hidden headless child process running this same script.
    try {
        $Psi = New-Object System.Diagnostics.ProcessStartInfo
        $Psi.FileName = "powershell.exe"
        $Psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Script:SelfPath + '"'
        $Psi.UseShellExecute = $false
        $Psi.CreateNoWindow = $true
        $Psi.WorkingDirectory = Split-Path -Path $Script:SelfPath -Parent
        $TasksFileEnv = ""
        if ($Script:Ctl_ChkUseEditedTasks.IsChecked -eq $true) {
            $TaskInputRows = @()
            if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
                $TaskInputRows = @(Get-SelectedTaskReviewRows)
                if (@($TaskInputRows).Count -le 0) {
                    Add-GuiLog -Tag "WARN" -Message "No tasks selected. Select at least one task in the Tasks tab before running."
                    Set-GuiStatus "Select tasks to run"
                    return
                }
            }
            else {
                $EditedRaw = [string]$Script:Ctl_TasksEditBox.Text
                $EditedLines = @()
                foreach ($Ln in ([System.Text.RegularExpressions.Regex]::Split($EditedRaw, '\r?\n'))) {
                    $LnT = $Ln.Trim()
                    if (-not [string]::IsNullOrWhiteSpace($LnT)) { $EditedLines += $LnT }
                }
                $TnumFallback = 0
                foreach ($Ln in $EditedLines) {
                    $TnumFallback++
                    $TaskInputRows += [PSCustomObject]@{ Id = $TnumFallback; Title = (Get-TaskTitleFromText -Text $Ln); PromptText = $Ln }
                }
            }

            if (@($TaskInputRows).Count -gt 0) {
                $TasksInputObjects = @()
                $Tnum = 0
                foreach ($Row in $TaskInputRows) {
                    $RowText = [string]$Row.PromptText
                    if ([string]::IsNullOrWhiteSpace($RowText)) { continue }
                    $Tnum++
                    $RowTitle = [string]$Row.Title
                    if ([string]::IsNullOrWhiteSpace($RowTitle)) { $RowTitle = Get-TaskTitleFromText -Text $RowText }
                    $RowTypeOverride = ""
                    if ($Row.PSObject.Properties.Name -contains "TypeOverride") { $RowTypeOverride = [string]$Row.TypeOverride }
                    $RowWorkModeOverride = ""
                    if ($Row.PSObject.Properties.Name -contains "WorkModeOverride") { $RowWorkModeOverride = [string]$Row.WorkModeOverride }
                    $TasksInputObjects += [PSCustomObject]@{ TaskId = $Tnum; TaskTitle = $RowTitle; PromptText = $RowText.Trim(); TypeOverride = $RowTypeOverride; WorkModeOverride = $RowWorkModeOverride }
                }
                $TasksFilePath = Join-Path $Script:CurrentRunFolder "tasks_input.json"
                try {
                    $TasksJsonText = $TasksInputObjects | ConvertTo-Json -Depth 5
                    $Utf8BomTasks = New-Object System.Text.UTF8Encoding($true)
                    [System.IO.File]::WriteAllText($TasksFilePath, $TasksJsonText, $Utf8BomTasks)
                    $TasksFileEnv = $TasksFilePath
                    Add-GuiLog -Tag "INFO" -Message ("Using selected task list: " + @($TasksInputObjects).Count + " task(s).")
                    Add-GuiLog -Tag "INFO" -Message ("Selected task IDs: " + ((@($TasksInputObjects) | ForEach-Object { [string]$_.TaskId }) -join ", "))
                    if ($null -ne $Script:LastTaskReviewEstimate) {
                        Add-GuiLog -Tag "INFO" -Message ("Pre-run estimate for selected tasks: " + $Script:LastTaskReviewEstimate.CostText + " | " + $Script:LastTaskReviewEstimate.TimeText + " | " + $Script:LastTaskReviewEstimate.TokensText + " tokens")
                    }
                }
                catch {
                    Add-GuiLog -Tag "WARN" -Message ("Could not write selected task list, falling back to auto-split: " + $_.Exception.Message)
                    $TasksFileEnv = ""
                }
            }
        }
        $Psi.EnvironmentVariables["MULTILLM_HEADLESS"]    = "1"
        $Psi.EnvironmentVariables["MULTILLM_PROMPT_FILE"] = $PromptFilePath
        $Psi.EnvironmentVariables["MULTILLM_RUNFOLDER"]   = $Script:CurrentRunFolder
        $Psi.EnvironmentVariables["MULTILLM_SPLITMODE"]   = $SplitMode
        $Psi.EnvironmentVariables["MULTILLM_WORKMODE"]    = $WorkModeSel
        $Psi.EnvironmentVariables["MULTILLM_UICODE_MODE"] = $UiModeSel
        $Psi.EnvironmentVariables["MULTILLM_MODEL_OPENAI"]      = $ModelASel
        $Psi.EnvironmentVariables["MULTILLM_MODEL_ANTHROPIC"]   = $ModelBSel
        $Psi.EnvironmentVariables["MULTILLM_MODEL_JUDGE"]       = $JudgeSel
        $Psi.EnvironmentVariables["MULTILLM_MODEL_JUDGE_CHEAP"] = $CheapJudgeSel
        $Psi.EnvironmentVariables["MULTILLM_CHEAP_JUDGE"]       = $CheapJudgeFlag
        $Psi.EnvironmentVariables["MULTILLM_TASKS_FILE"]        = $TasksFileEnv
        $Psi.EnvironmentVariables["MULTILLM_PERSONA_MODE"]      = $PersonaMode
        $Psi.EnvironmentVariables["MULTILLM_PERSONA_A"]         = $PersonaA
        $Psi.EnvironmentVariables["MULTILLM_PERSONA_B"]         = $PersonaB
        $Psi.EnvironmentVariables["MULTILLM_RUNVERIFIER"]       = $VerifierFlag

        $Script:ChildProcess = [System.Diagnostics.Process]::Start($Psi)
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to start pipeline process: " + $_.Exception.Message)
        $Script:ChildProcess = $null
        Write-GuiRunReport -Outcome "LaunchError" -ExitCode -1 -FinalAnswerFound $false -SummaryLoaded $false
        return
    }

    $Script:RunStartTime = Get-Date
    $Script:TotalTasks = 0
    $Script:LastTranscriptLen = 0
    $Script:LastDoneCount = -1
    $Script:RunSplitMode = $SplitMode
    $Script:RunPromptChars = $PromptText.Length
    $Script:Ctl_PbTasks.Value = 0
    $Script:Ctl_PbTasks.Maximum = 1
    $Script:Ctl_LblTasksDone.Text = "Tasks: 0 / ?"
    $Script:Ctl_FinalBox.Text = ""
    $Script:CurrentFinalAnswerPath = ""
    Clear-MetricsTab
    $Script:Ctl_RunLogBox.Text = ""
    if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
        foreach ($Row in @($Script:TaskReviewRows)) {
            if ($Row.IsSelected -eq $true) { $Row.Status = "Queued" }
            else { $Row.Status = "Not selected" }
        }
        Refresh-TaskReviewGrid
    }
    else {
        Set-TaskReviewRows -Rows (New-Object System.Collections.ArrayList)
    }
    $Script:CurrentImprovedPrompt = ""
    $Script:Ctl_BtnImproved.IsEnabled = $false
    $Script:Ctl_HdrRunFolder.Text = $Script:CurrentRunFolder
    Update-RightRailFromRun -RunFolderPath $Script:CurrentRunFolder -StatusText "Running"
    Update-RightRailFromPreview

    Set-GuiBusy -Busy $true
    Set-GuiStatus "Running..."
    Add-GuiLog -Tag "INFO" -Message ("Pipeline started. PID: " + $Script:ChildProcess.Id + ". Run folder: " + $Script:CurrentRunFolder)
    Add-GuiLog -Tag "INFO" -Message ("Task splitter: " + $SplitMode + " | Work mode: " + $WorkModeSel + " | UI auto mode: " + $UiModeSel + " | prompt: " + $PromptText.Length + " chars")
    $CheapInfo = "off"
    if ($CheapJudgeFlag -eq "1") {
        $CheapInfo = $CheapJudgeSel
    }
    $LightReviewJudge = $JudgeSel
    if ($CheapJudgeFlag -eq "1") {
        $LightReviewJudge = $CheapJudgeSel
    }
    Add-GuiLog -Tag "INFO" -Message "Models for this run:"
    Add-GuiLog -Tag "INFO" -Message ("  Answer A                 : " + $ModelASel)
    Add-GuiLog -Tag "INFO" -Message ("  Answer B                 : " + $ModelBSel)
    Add-GuiLog -Tag "INFO" -Message ("  Quality judge            : " + $AnthropicModel_JudgeStrong)
    Add-GuiLog -Tag "INFO" -Message ("  Fast judge               : " + $LightReviewJudge)
    if ($JudgeSel -ne $AnthropicModel_JudgeStrong) {
        Add-GuiLog -Tag "WARN" -Message ("Selected judge '" + $JudgeSel + "' applies only to Light/ReviewOnly. Full comparison always uses the strong judge '" + $AnthropicModel_JudgeStrong + "'.")
    }
    $Script:Ctl_HdrModelA.Text = $ModelASel
    $Script:Ctl_HdrModelB.Text = $ModelBSel
    $Script:Ctl_HdrJudgeFull.Text = $AnthropicModel_JudgeStrong
    $Script:Ctl_HdrJudgeCheap.Text = $LightReviewJudge

    $Script:PollTimer.Start()
})

$Script:Ctl_BtnDetect.Add_Click({
    $DetectPrompt = [string]$Script:Ctl_PromptBox.Text
    if ([string]::IsNullOrWhiteSpace($DetectPrompt)) {
        Add-GuiLog -Tag "WARN" -Message "Prompt is empty. Nothing to detect."
        return
    }
    $DetectedCount = Invoke-DetectTasks -Announce
    [void](Select-MainTab -Header "Tasks")
    Set-GuiStatus ("Preview: " + $DetectedCount + " task(s) detected")
})

$Script:Ctl_TasksGrid.Add_SelectionChanged({
    Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
})

$Script:Ctl_TasksGrid.Add_PreviewMouseLeftButtonDown({
    param($Sender, $EventArgs)

    if ($null -eq $Script:TaskReviewRows -or @($Script:TaskReviewRows).Count -le 0) { return }

    $Cell = Get-VisualParentByType -Child $EventArgs.OriginalSource -TargetType ([System.Windows.Controls.DataGridCell])
    if ($null -eq $Cell) { return }
    if ($null -eq $Cell.Column -or $Cell.Column.DisplayIndex -ne 0) { return }

    $Row = $Cell.DataContext
    if ($null -eq $Row) { return }
    if (-not ($Row.PSObject.Properties.Name -contains "IsSelected")) { return }

    $Script:SkipTaskReviewVisualSync = $true
    try {
        $Row.IsSelected = (-not ($Row.IsSelected -eq $true))
        if ($Row.IsSelected -eq $true) {
            if ([string]$Row.Status -eq "Not selected") { $Row.Status = "Ready" }
        }
        else {
            $Row.Status = "Not selected"
        }
        $Script:Ctl_TasksGrid.SelectedItem = $Row
        Sync-TaskReviewEditBox
        Update-TaskReviewSelectionSummary
        Update-TaskDetailsPanel -Row $Row
        Refresh-TaskReviewGrid
    }
    finally {
        $Script:SkipTaskReviewVisualSync = $false
    }

    $EventArgs.Handled = $true
})

if ($null -ne $Script:Ctl_ChkTaskRunAll) {
    $Script:Ctl_ChkTaskRunAll.Add_PreviewMouseLeftButtonDown({
        param($Sender, $EventArgs)

        if ($null -eq $Script:TaskReviewRows -or @($Script:TaskReviewRows).Count -le 0) {
            $EventArgs.Handled = $true
            return
        }

        $Total = @($Script:TaskReviewRows).Count
        $Selected = 0
        foreach ($Row in @($Script:TaskReviewRows)) {
            if ($Row.IsSelected -eq $true) { $Selected++ }
        }

        if ($Selected -lt $Total) {
            Set-AllTaskReviewRowsSelected -Selected $true
            Add-GuiLog -Tag "INFO" -Message "All detected tasks enabled from the Run column header."
            Set-GuiStatus "All tasks enabled"
        }
        else {
            Set-AllTaskReviewRowsSelected -Selected $false
            Add-GuiLog -Tag "INFO" -Message "All detected tasks disabled from the Run column header."
            Set-GuiStatus "All tasks disabled"
        }

        $EventArgs.Handled = $true
    })
}

$Script:Ctl_TasksGrid.Add_CurrentCellChanged({
    if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
        Sync-TaskReviewEditBox
        Update-TaskReviewSelectionSummary
        Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
    }
})

$Script:Ctl_TasksGrid.Add_PreviewMouseLeftButtonUp({
    if ($null -ne $Script:TaskReviewRows -and @($Script:TaskReviewRows).Count -gt 0) {
        $RefreshAction = [Action]{
            Sync-TaskReviewEditBox
            Update-TaskReviewSelectionSummary
            Update-TaskDetailsPanel -Row $Script:Ctl_TasksGrid.SelectedItem
        }
        [void]$Script:Ctl_TasksGrid.Dispatcher.BeginInvoke($RefreshAction, [System.Windows.Threading.DispatcherPriority]::Background)
    }
})

$Script:Ctl_BtnSelectAllTasks.Add_Click({
    if ($null -eq $Script:TaskReviewRows) { return }
    Set-AllTaskReviewRowsSelected -Selected $true
    Add-GuiLog -Tag "INFO" -Message "All detected tasks enabled for the next run."
    Set-GuiStatus "All tasks enabled"
})

$Script:Ctl_BtnClearTasks.Add_Click({
    if ($null -eq $Script:TaskReviewRows) { return }
    Set-AllTaskReviewRowsSelected -Selected $false
    Add-GuiLog -Tag "INFO" -Message "All detected tasks disabled. Enable at least one task to run."
    Set-GuiStatus "All tasks disabled"
})

if ($null -ne $Script:Ctl_ChkTaskDetailInclude) {
    $Script:Ctl_ChkTaskDetailInclude.Add_Click({
        $Selected = $Script:Ctl_TasksGrid.SelectedItem
        if ($null -eq $Selected) { return }
        $Script:SkipTaskReviewVisualSync = $true
        try {
            $Selected.IsSelected = ($Script:Ctl_ChkTaskDetailInclude.IsChecked -eq $true)
            if ($Selected.IsSelected -eq $true) {
                if ([string]$Selected.Status -eq "Not selected") { $Selected.Status = "Ready" }
            }
            else {
                $Selected.Status = "Not selected"
            }
            Sync-TaskReviewEditBox
            Update-TaskReviewSelectionSummary
            Update-TaskDetailsPanel -Row $Selected
            Refresh-TaskReviewGrid
        }
        finally {
            $Script:SkipTaskReviewVisualSync = $false
        }
    })
}

$OverrideComboChanged = {
    if ($Script:SuppressOverrideCombo -eq $true) { return }
    if ($null -eq $Script:Ctl_TasksGrid) { return }
    $Row = $Script:Ctl_TasksGrid.SelectedItem
    if ($null -eq $Row) { return }
    if (-not ([string]$Row.Status -eq "Ready" -or [string]$Row.Status -eq "Not selected")) { return }
    if (-not ($Row.PSObject.Properties.Name -contains "TypeOverride")) { return }

    $TypeSel = ""
    if ($null -ne $Script:Ctl_CmbTaskTypeOverride) { $TypeSel = [string]$Script:Ctl_CmbTaskTypeOverride.SelectedItem }
    if ($TypeSel -eq "Auto") { $TypeSel = "" }
    $WorkSel = ""
    if ($null -ne $Script:Ctl_CmbTaskWorkModeOverride) { $WorkSel = [string]$Script:Ctl_CmbTaskWorkModeOverride.SelectedItem }
    if ($WorkSel -eq "Auto") { $WorkSel = "" }

    $Row.TypeOverride = $TypeSel
    $Row.WorkModeOverride = $WorkSel
    Update-TaskReviewRowEstimate -Row $Row
    Update-TaskReviewSelectionSummary
    Update-TaskDetailsPanel -Row $Row
    Refresh-TaskReviewGrid

    $TypeDisp = $TypeSel
    if ([string]::IsNullOrWhiteSpace($TypeDisp)) { $TypeDisp = "auto" }
    $WorkDisp = $WorkSel
    if ([string]::IsNullOrWhiteSpace($WorkDisp)) { $WorkDisp = "auto" }
    Add-GuiLog -Tag "INFO" -Message ("Task " + [string]$Row.Id + " route override -> type: " + $TypeDisp + ", work mode: " + $WorkDisp)
}
if ($null -ne $Script:Ctl_CmbTaskTypeOverride) { $Script:Ctl_CmbTaskTypeOverride.Add_SelectionChanged($OverrideComboChanged) }
if ($null -ne $Script:Ctl_CmbTaskWorkModeOverride) { $Script:Ctl_CmbTaskWorkModeOverride.Add_SelectionChanged($OverrideComboChanged) }

$Script:Ctl_ChkUseEditedTasks.Add_Click({
    Update-RunButtonState
})

if ($null -ne $Script:Ctl_BtnToggleLog) {
    $Script:Ctl_BtnToggleLog.Add_Click({
        if ($null -eq $Script:Ctl_LogBox) { return }
        $LogIsVisible = ($Script:Ctl_LogBox.Visibility -eq [System.Windows.Visibility]::Visible -and $Script:Ctl_LogBox.Height -gt 0)
        if ($LogIsVisible -eq $true) {
            $Script:GuiLogExpandedHeight = $Script:Ctl_LogBox.Height
            Set-GuiLogPanelHeight -Height 0
            Set-GuiStatus "Log collapsed"
        }
        else {
            $NewHeight = 160
            if ($Script:GuiLogExpandedHeight -gt 0) { $NewHeight = $Script:GuiLogExpandedHeight }
            if ($NewHeight -lt 96) { $NewHeight = 160 }
            if ($NewHeight -gt 360) { $NewHeight = 360 }
            Set-GuiLogPanelHeight -Height $NewHeight
            Set-GuiStatus ("Log expanded to " + [int]$NewHeight + " px")
        }
    })
}

# v0.8.53: recursively kill a process and all of its descendants. Used as the
# fallback when taskkill is unavailable. Kills leaf processes first, then returns
# so the caller can kill the root.
function Stop-DescendantProcesses {
    param([int]$ParentId)

    if ($ParentId -le 0) {
        return
    }

    $Children = @()
    try {
        $Children = @(Get-CimInstance -ClassName Win32_Process -Filter ("ParentProcessId = " + $ParentId) -ErrorAction Stop)
    }
    catch {
        $Children = @()
    }

    foreach ($Child in $Children) {
        $ChildId = 0
        try { $ChildId = [int]$Child.ProcessId } catch { $ChildId = 0 }
        if ($ChildId -gt 0) {
            Stop-DescendantProcesses -ParentId $ChildId
            try {
                Stop-Process -Id $ChildId -Force -ErrorAction SilentlyContinue
            }
            catch {
            }
        }
    }
}

# v0.8.53: terminate the hidden backend child AND its Start-Job grandchildren.
# Each Start-Job (answer / judge) spawns its own powershell.exe, so killing only
# the child leaves those jobs running their in-flight API calls until the per-model
# timeout - real money after a Stop. PS 5.1 has no [Process].Kill($true) tree
# overload, so shell out to taskkill /T (kills the whole tree); fall back to a
# Win32_Process tree-walk if taskkill cannot run. Returns $true if the tree was
# terminated by taskkill.
function Stop-ChildProcessTree {
    param([object]$Process)

    if ($null -eq $Process) {
        return $false
    }

    $ProcId = 0
    try { $ProcId = [int]$Process.Id } catch { $ProcId = 0 }
    if ($ProcId -le 0) {
        return $false
    }

    $TreeKilled = $false

    try {
        $Tk = Start-Process -FilePath "taskkill.exe" -ArgumentList @("/PID", $ProcId, "/T", "/F") -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
        if ($null -ne $Tk) {
            # 0 = terminated; 128 = process not found (already gone). Either way the tree is down.
            if ($Tk.ExitCode -eq 0 -or $Tk.ExitCode -eq 128) {
                $TreeKilled = $true
            }
        }
    }
    catch {
        $TreeKilled = $false
    }

    if ($TreeKilled -ne $true) {
        Stop-DescendantProcesses -ParentId $ProcId
        try {
            if ($Process.HasExited -ne $true) {
                $Process.Kill()
            }
        }
        catch {
        }
    }

    return $TreeKilled
}

$Script:Ctl_BtnStop.Add_Click({
    if ($null -eq $Script:ChildProcess) {
        return
    }

    try {
        if ($Script:ChildProcess.HasExited -ne $true) {
            $TreeKilled = Stop-ChildProcessTree -Process $Script:ChildProcess
            if ($TreeKilled -eq $true) {
                Add-GuiLog -Tag "WARN" -Message "Run stopped by the user. Terminated the backend process and all of its answer/judge model jobs, so no further API calls will be made."
            }
            else {
                Add-GuiLog -Tag "WARN" -Message "Run stopped by the user. Terminated the backend; if any model job survived it will stop at its per-model timeout."
            }
        }
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to stop pipeline process: " + $_.Exception.Message)
    }

    if ($null -ne $Script:PollTimer) {
        $Script:PollTimer.Stop()
    }

    Set-GuiBusy -Busy $false
    Set-GuiStatus "Stopped"

    Write-GuiRunReport -Outcome "StoppedByUser" -ExitCode -1 -FinalAnswerFound $false -SummaryLoaded $false

    $Script:ChildProcess = $null
})

$Script:Ctl_BtnImproved.Add_Click({
    Show-ImprovedPromptWindow -ImprovedText $Script:CurrentImprovedPrompt
})

$Script:Ctl_TasksGrid.Add_MouseDoubleClick({
    $Selected = $Script:Ctl_TasksGrid.SelectedItem

    if ($null -eq $Selected) {
        return
    }

    $TaskFolderSel = [string]$Selected.TaskFolder

    if ([string]::IsNullOrWhiteSpace($TaskFolderSel) -or (-not (Test-Path -LiteralPath $TaskFolderSel))) {
        Update-TaskDetailsPanel -Row $Selected
        Set-GuiStatus "Preview task selected; run it to create output."
        return
    }

    $TaskFinalPath = Join-Path $TaskFolderSel "final_answer.md"
    $TaskFinalText = Get-FileTextSafe -Path $TaskFinalPath

    if ([string]::IsNullOrWhiteSpace($TaskFinalText)) {
        Add-GuiLog -Tag "WARN" -Message ("No final answer file found: " + $TaskFinalPath)
        return
    }

    $TitleText = "Task " + $Selected.Id + " - " + $Selected.Type
    Show-TaskDetailsWindow -WindowTitle $TitleText -BodyText $TaskFinalText
})

$Script:Ctl_BtnCopyFinal.Add_Click({
    $TextToShow = $Script:Ctl_FinalBox.Text

    if ([string]::IsNullOrWhiteSpace($TextToShow)) {
        Add-GuiLog -Tag "WARN" -Message "Final answer is empty. Nothing to show."
        return
    }

    Show-FinalAnswerWindow -FinalText $TextToShow -FinalPath $Script:CurrentFinalAnswerPath
})

$Script:Ctl_BtnCopyQuick.Add_Click({
    $TextToCopy = $Script:Ctl_FinalBox.Text

    if ([string]::IsNullOrWhiteSpace($TextToCopy)) {
        Add-GuiLog -Tag "WARN" -Message "Final answer is empty. Nothing to copy."
        return
    }

    try {
        Set-Clipboard -Value $TextToCopy
        Add-GuiLog -Tag "OK" -Message "Final answer copied to clipboard."
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Clipboard error: " + $_.Exception.Message)
    }
})

$Script:Ctl_BtnOpenFolder.Add_Click({
    $FolderToOpen = $Script:CurrentRunFolder

    if ([string]::IsNullOrWhiteSpace($FolderToOpen) -or (-not (Test-Path -LiteralPath $FolderToOpen))) {
        $FolderToOpen = $OutputRoot
    }

    if (Test-Path -LiteralPath $FolderToOpen) {
        Start-Process explorer.exe $FolderToOpen
    }
    else {
        Add-GuiLog -Tag "WARN" -Message ("Folder not found: " + $FolderToOpen)
    }
})

$Script:Ctl_BtnHtmlReport.Add_Click({
    $FolderToReport = $Script:CurrentRunFolder
    if ([string]::IsNullOrWhiteSpace($FolderToReport) -or (-not (Test-Path -LiteralPath $FolderToReport))) {
        Add-GuiLog -Tag "WARN" -Message "No run folder yet. Run a prompt, or open a recent run, first."
        return
    }

    $ReportPath = $null
    try {
        $ReportPath = New-RunHtmlReport -RunFolderPath $FolderToReport -ToolVersion $ToolVersion
    }
    catch {
        Add-GuiLog -Tag "ERROR" -Message ("Failed to build HTML report: " + $_.Exception.Message)
        return
    }

    if ([string]::IsNullOrWhiteSpace($ReportPath) -or (-not (Test-Path -LiteralPath $ReportPath))) {
        Add-GuiLog -Tag "WARN" -Message "No cost or task data to report yet for this run."
        return
    }

    Start-Process $ReportPath
    Add-GuiLog -Tag "OK" -Message ("HTML report written and opened in your browser: " + $ReportPath)
})

$Script:Ctl_ConfigMenu = New-Object System.Windows.Controls.ContextMenu
$Script:Ctl_MiOpenConfig = New-Object System.Windows.Controls.MenuItem
$Script:Ctl_MiOpenConfig.Header = "Open config file"
$Script:Ctl_MiSetKeys = New-Object System.Windows.Controls.MenuItem
$Script:Ctl_MiSetKeys.Header = "Set API keys..."
[void]$Script:Ctl_ConfigMenu.Items.Add($Script:Ctl_MiOpenConfig)
[void]$Script:Ctl_ConfigMenu.Items.Add($Script:Ctl_MiSetKeys)
$Script:Ctl_BtnSideSettings.ContextMenu = $Script:Ctl_ConfigMenu

$Script:Ctl_MiOpenConfig.Add_Click({
    if (Test-Path -LiteralPath $ConfigPath) {
        Start-Process notepad.exe $ConfigPath
        Add-GuiLog -Tag "INFO" -Message ("Opened config: " + $ConfigPath)
    }
    else {
        Add-GuiLog -Tag "WARN" -Message ("Config file not found yet. It is created on the first pipeline run: " + $ConfigPath)
    }
})

$Script:Ctl_MiSetKeys.Add_Click({
    Show-ApiKeysWindow
    Update-RunButtonState
    Update-ApiStatusHeader
})

$Script:Ctl_BtnHdrSetKeys.Add_Click({
    Show-ApiKeysWindow
    Update-RunButtonState
    Update-ApiStatusHeader
})

$Script:Ctl_TopMenu = $GuiWindow.FindName("TopMenu")
if ($null -ne $Script:Ctl_TopMenu) {
    $MiSettings = New-Object System.Windows.Controls.MenuItem
    $MiSettings.Header = "Settings"
    $MiSetOpenConfig = New-Object System.Windows.Controls.MenuItem
    $MiSetOpenConfig.Header = "Open config file"
    $MiSetKeysMenu = New-Object System.Windows.Controls.MenuItem
    $MiSetKeysMenu.Header = "Set API keys..."
    $MiSetOutput = New-Object System.Windows.Controls.MenuItem
    $MiSetOutput.Header = "Open output folder"
    [void]$MiSettings.Items.Add($MiSetOpenConfig)
    [void]$MiSettings.Items.Add($MiSetKeysMenu)
    [void]$MiSettings.Items.Add($MiSetOutput)

    $MiHelp = New-Object System.Windows.Controls.MenuItem
    $MiHelp.Header = "Help"
    $MiHelpAbout = New-Object System.Windows.Controls.MenuItem
    $MiHelpAbout.Header = "About Multi-LLM Prompter"
    $MiHelpLog = New-Object System.Windows.Controls.MenuItem
    $MiHelpLog.Header = "Open session log"
    $MiHelpDev = New-Object System.Windows.Controls.MenuItem
    $MiHelpDev.Header = "Open developer notes"
    [void]$MiHelp.Items.Add($MiHelpAbout)
    [void]$MiHelp.Items.Add($MiHelpLog)
    [void]$MiHelp.Items.Add($MiHelpDev)

    [void]$Script:Ctl_TopMenu.Items.Add($MiSettings)
    [void]$Script:Ctl_TopMenu.Items.Add($MiHelp)

    $MiSetOpenConfig.Add_Click({
        if (Test-Path -LiteralPath $ConfigPath) {
            Start-Process notepad.exe $ConfigPath
            Add-GuiLog -Tag "INFO" -Message ("Opened config: " + $ConfigPath)
        }
        else {
            Add-GuiLog -Tag "WARN" -Message ("Config file not found yet: " + $ConfigPath)
        }
    })
    $MiSetKeysMenu.Add_Click({
        Show-ApiKeysWindow
        Update-RunButtonState
        Update-ApiStatusHeader
    })
    $MiSetOutput.Add_Click({
        try {
            if (-not (Test-Path -LiteralPath $OutputRoot)) { New-Item -ItemType Directory -Path $OutputRoot -Force | Out-Null }
            Start-Process explorer.exe $OutputRoot
        }
        catch {
            Add-GuiLog -Tag "ERROR" -Message ("Could not open output folder: " + $_.Exception.Message)
        }
    })
    $MiHelpLog.Add_Click({
        if (Test-Path -LiteralPath $GuiSessionLogPath) { Start-Process notepad.exe $GuiSessionLogPath }
        else { Add-GuiLog -Tag "WARN" -Message "Session log not found yet." }
    })
    $MiHelpDev.Add_Click({
        $DevDoc = ""
        if (-not [string]::IsNullOrWhiteSpace($Script:SelfPath)) { $DevDoc = Join-Path (Split-Path -Path $Script:SelfPath -Parent) "DEVELOPER.md" }
        if ((-not [string]::IsNullOrWhiteSpace($DevDoc)) -and (Test-Path -LiteralPath $DevDoc)) { Start-Process notepad.exe $DevDoc }
        else { Add-GuiLog -Tag "WARN" -Message "DEVELOPER.md not found next to the script." }
    })
    $MiHelpAbout.Add_Click({
        $AboutText = "Multi-LLM Prompter " + $ToolVersion + "`r`n`r`n" + "Sends one prompt to two answer models in parallel, a Judge compares and synthesizes, and writes a final answer plus a full cost and timing audit trail." + "`r`n`r`n" + "Output folder: " + $OutputRoot + "`r`n" + "Config file: " + $ConfigPath
        [void][System.Windows.MessageBox]::Show($AboutText, "About Multi-LLM Prompter", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
    })
}

if ($null -ne $Script:Ctl_BtnSideNewRun) {
    $Script:Ctl_BtnSideNewRun.Add_Click({
        Reset-GuiForNewRun
    })
}

if ($null -ne $Script:Ctl_BtnSideSettings) {
    $Script:Ctl_BtnSideSettings.Add_Click({
        if ($null -ne $Script:Ctl_ConfigMenu) {
            $Script:Ctl_ConfigMenu.PlacementTarget = $Script:Ctl_BtnSideSettings
            $Script:Ctl_ConfigMenu.Placement = [System.Windows.Controls.Primitives.PlacementMode]::Right
            $Script:Ctl_ConfigMenu.IsOpen = $true
        }
        Add-GuiLog -Tag "INFO" -Message "Settings: opened the settings menu (config file, API keys, output folder)."
    })
}

# Recent-run buttons in the left rail: click to load that past run's results (v0.8.61).
$RecentRunButtons = @($Script:Ctl_BtnSideRecent1, $Script:Ctl_BtnSideRecent2, $Script:Ctl_BtnSideRecent3, $Script:Ctl_BtnSideRecent4)
foreach ($RecentRunButton in $RecentRunButtons) {
    if ($null -ne $RecentRunButton) {
        $RecentRunButton.Add_Click({
            param($EventSender, $EventArgs)
            if ($null -eq $EventSender) { return }
            $PathTag = [string]$EventSender.Tag
            if (-not [string]::IsNullOrWhiteSpace($PathTag)) {
                Open-PastRun -RunFolderPath $PathTag
            }
        })
    }
}

$Script:Ctl_BtnExit.Add_Click({
    $GuiWindow.Close()
})

$GuiWindow.Add_Closing({
    if ($null -ne $Script:PollTimer) {
        $Script:PollTimer.Stop()
    }

    if ($null -ne $Script:ChildProcess) {
        try {
            if ($Script:ChildProcess.HasExited -ne $true) {
                Stop-ChildProcessTree -Process $Script:ChildProcess | Out-Null
            }
        }
        catch {
        }
    }
})

# ---- Startup info + show window ----

if ($EnableGuiSessionLog -eq $true) {
    try {
        $SessionSep = "================ GUI SESSION START " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " ================"
        [System.IO.File]::AppendAllText($GuiSessionLogPath, $SessionSep + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
    catch {
    }
}

Add-GuiLog -Tag "INFO" -Message ("Multi-LLM Prompter " + $ToolVersion + " GUI ready.")
Add-GuiLog -Tag "INFO" -Message ("GUI session log: " + $GuiSessionLogPath)
Add-GuiLog -Tag "INFO" -Message ("Models: A=" + $OpenAIModel_Answer + " B=" + $AnthropicModel_Answer + " | Full comparisons always judged by " + $AnthropicModel_JudgeStrong + " | reviews judged by " + $AnthropicModel_JudgeCheap)
Add-GuiLog -Tag "INFO" -Message ("Output root: " + $OutputRoot)

$StartupKeyState = Get-ApiKeyReadiness
if ($StartupKeyState.Ready -eq $true) {
    if ($StartupKeyState.SecretsFileExists -eq $true) {
        Add-GuiLog -Tag "OK" -Message "Encrypted secrets file found."
    }
    else {
        Add-GuiLog -Tag "OK" -Message "API keys found in environment variables."
    }
}
else {
    Add-GuiLog -Tag "WARN" -Message ("No API keys detected. Create the secrets file (run once with LaunchGui = false) or set environment variables. Expected: " + $SecretsPath)
}

$Script:Ctl_HdrModelA.Text = $OpenAIModel_Answer
$Script:Ctl_HdrModelB.Text = $AnthropicModel_Answer
$Script:Ctl_HdrJudgeFull.Text = $AnthropicModel_JudgeStrong
$Script:Ctl_HdrJudgeCheap.Text = $AnthropicModel_Judge

Update-RunButtonState
Update-ApiStatusHeader
if ($null -ne $Script:Ctl_TxtSideVersion) { $Script:Ctl_TxtSideVersion.Text = $ToolVersion }
Update-SidebarRecentRuns
Update-RightRailFromPreview
Update-RightRailApiStatus

# Apply the initial (disabled) Stop button style.
Set-GuiBusy -Busy $false
Set-GuiLogPanelHeight -Height 96

$Script:UIReady = $true
Set-GuiStatus "Ready"

[void]$GuiWindow.ShowDialog()

}
