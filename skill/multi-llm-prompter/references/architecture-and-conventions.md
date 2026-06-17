# Architecture And Conventions

## Shape

- Single-file PS 5.1 / ISE tool (~9,580 lines as of v0.8.61). `$LaunchGui = $true` runs the
  WPF GUI; `$false` runs the classic CLI pipeline.
- The SAME .ps1 runs as a hidden headless child for the actual pipeline work
  (`MULTILLM_HEADLESS=1`). GUI writes `gui_prompt.txt`, pre-creates the run folder,
  starts the child, then polls tasks.json / Task_NN / transcript via a 1 s DispatcherTimer.
- No top-level `param()` ANYWHERE (user convention). All GUI -> child parameters travel
  via environment variables.

## Env-var contract (GUI -> headless child)

    MULTILLM_HEADLESS          "1" = run pipeline, suppress interactive prompts/popups
    MULTILLM_PROMPT_FILE       path to gui_prompt.txt (UTF-8 BOM)
    MULTILLM_RUNFOLDER         run folder pre-created by the GUI
    MULTILLM_SPLITMODE         Heuristic / None
    MULTILLM_WORKMODE          Auto / Review / Script
    MULTILLM_UICODE_MODE       Review / Script (used when WORKMODE=Auto)
    MULTILLM_MODEL_OPENAI      answer model A id
    MULTILLM_MODEL_ANTHROPIC   answer model B id
    MULTILLM_MODEL_JUDGE       selected judge id (Light/ReviewOnly-non-cheap + display)
    MULTILLM_MODEL_JUDGE_CHEAP cheap judge id (Light/ReviewOnly when toggle on)
    MULTILLM_CHEAP_JUDGE       "1"/"0" cheap-judge toggle
    MULTILLM_TASKS_FILE        path to tasks_input.json (v0.8.9). When set + file exists,
                               the child loads that explicit task list (array of
                               {TaskId, TaskTitle, PromptText, TypeOverride, WorkModeOverride})
                               INSTEAD of running the splitter; empty/absent ->
                               Split-UserPromptIntoTasks as before.
    MULTILLM_PERSONA_MODE      Off / Fixed (v0.8.41)
    MULTILLM_PERSONA_A         persona key for Answer A (architect / ui_ux / devils_advocate
                               / qa / senior_dev / none) (v0.8.41)
    MULTILLM_PERSONA_B         persona key for Answer B (v0.8.41)
    MULTILLM_RUNVERIFIER       "1"/"0" enable the final verifier for this run (v0.8.55; GUI checkbox)

- Precedence: env applied AFTER config load -> GUI choices win over config, which wins
  over top-of-script defaults.
- There is NO env var for the strong judge by design (see pipeline-and-judge.md).

## Config / secrets / outputs

- `MultiLLM.config.json` - models, endpoints, timeouts, output budgets, behavior,
  `CostPer1MTokens`. (Its own "Version" field can lag the script version; that is fine.)
- `MultiLLM.secrets.xml` - DPAPI `Export-Clixml` of SecureStrings, machine + user bound.
  Recreate via one `$LaunchGui = $false` run if keys change.
- `$ConfigPath` / `$SecretsPath` (v0.8.3+): resolved relative to the script folder
  (`$PSCommandPath`/`$MyInvocation.MyCommand.Path`), with a fallback to the legacy fixed
  path `C:\_Combined\H_Productivity\Multi-LLM-Prompter`. Prefer an existing file next to
  the .ps1, then legacy, else create next to the .ps1. Config-load guards every key with
  `IsNullOrWhiteSpace`, so a config missing `AnthropicJudgeStrong` keeps the opus default.
- Runtime outputs under `C:\Temp\MultiLLMPrompter\` (gui_session.log + per-run
  `Run_<timestamp>\` folders). Logs/outputs always under C:\Temp.

## Source encoding rules

- UTF-8 BOM, CRLF, `cls` first.
- ASCII-only source. Unicode ONLY as `&#x...;` entities inside XAML here-strings.
- No ternary, no `??`.

## Release discipline

- Full files only; never drop features.
- Bump the version EVERYWHERE + add a numbered changelog entry. Never reuse a version
  number (e.g. v0.7.9 was a rename, so the judge fix became v0.8.0).
- Distinguish layers: a flaw in a generated script is a PROMPT fix, not a tool fix.

## Validate-before-delivery checklist (no pwsh in assistant env; final check is ISE)

- Real syntax check IS available (despite older notes saying "ISE only"): run pwsh and
  `[System.Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$errs)` -
  parse-only, no execution, no API calls. 0 errors = syntactically clean. Use it every build.
- BOM present; `cls` first; 0 non-ASCII bytes.
- Here-strings balanced (`@"` count == `"@` count).
- Code-only paren balance == 0.
- Add_Click handler count matches expectation.
- Diff the frozen functions (`Get-TaskWorkMode`, `Get-EstimatedCostUsd`, judge
  selection, duplicated job helpers) to PROVE they are untouched.

## Path note

Live working copy is `C:\_Combined\Multi-LLM-Prompter`. The HANDOFFs and the pre-v0.8.3
hardcoded `$ConfigPath`/`$SecretsPath` referenced `C:\_Combined\H_Productivity\Multi-LLM-Prompter`,
which does NOT exist on disk - so older versions silently created a default config there
and re-prompted for keys. v0.8.3 fixed this with the script-relative resolver above; the
legacy path is kept only as a fallback.
