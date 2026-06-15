# Pipeline And Judge

The backend brain. These contracts are load-bearing; a v0.7.8 run broke the judge
policy and shipped a wrong AD filter, which is why most of this is frozen.

## Router (task types -> routing policy)

- Types: simple / technical / code / ui_code / documentation / creative.
- `code`, `ui_code`, `technical` -> OpenAI + Sonnet + Judge.
- `documentation` -> MissingInput pre-check; if the source is absent, SKIPPED with 0 AI calls.
- `creative` -> Sonnet only, no Judge.
- `simple` -> OpenAI only.
- `Split-UserPromptIntoTasks` (Heuristic) splits only when >=2 lines look like separate
  tasks AND total non-empty lines <= 12; single-task prompts pass through untouched.
  `Get-TaskType` assigns the type. Both are top-level functions and the GUI Detect Tasks
  preview calls the SAME ones, so preview == run split. Do not fork a second splitter.

## Get-TaskWorkMode (Auto) - LOGIC FROZEN

Order matters; do not edit except the version comment:
1. ui_code: explicit complete/full/runnable/create/write script -> Script, else Review.
2. technical + correction wording -> Script (BEFORE the generic review rule).
3. generic review/analyze/audit/suggest/explain-the-bug -> Review.
4. code + script/code/function/wpf/xaml -> Script.
5. technical fallback / documentation / creative / simple -> Review.
Review = notes + small snippets; Script = full runnable scripts.

## Judge - marker contract (do not change casually)

Markdown inside JSON breaks `ConvertFrom-Json`, so keep these markers exact and keep
the JSON block clean (no markdown/code inside it):

    ---JUDGE_JSON---            (small clean JSON; no markdown/code inside)
    ---FINAL_ANSWER_MARKDOWN--- (markdown/code allowed)
    ---IMPROVED_PROMPT---       ("No improved prompt." if none)

Modes: Full (2 answers, compare + synthesize), Light (1 answer, validate), ReviewOnly
(notes/verdict only).

Judge JSON fields: `best_answer_id`, `confidence`, `scores.{A,B}.{6 criteria}`,
`problems_found[]`, `best_parts_reused[]`, and (v0.8.6) `final_answer_source` (the judge's
estimate of how much of each candidate went into the final, summing to 100; single answer
= 100/0). Read via `Get-JudgeVerdict` (defensive: missing fields degrade to blank, shares
normalized to 100). Surfaced as a plain-text "=== Judge verdict ===" block prepended to
the merged final answer (`Format-JudgeVerdictBlock`): better answer + confidence, an A/B
composition bar, average A/B scores, reused parts. Adding JSON fields is fine; the three
MARKERS are the load-bearing part - do not touch them.

## Judge model policy (v0.8.0 - the headline fix)

- Full -> ALWAYS `$AnthropicModel_JudgeStrong` (default claude-opus-4-8). The GUI Judge
  combo and the cheap-judge toggle are IGNORED for Full. If the selected judge differs
  from the strong judge, a `[WARN]` is logged.
- Light / ReviewOnly -> cheap judge if `$UseCheapJudgeForReview`, else the selected judge.
- There is intentionally NO env var for the strong judge. It comes only from the
  top-of-script default or config (`Models.AnthropicJudgeStrong`). The GUI cannot weaken
  it per run. Implemented in the per-task block:
  `if ($JudgeMode -eq "Full") { $JudgeModelToUse = $AnthropicModel_JudgeStrong }`.
- `JudgeModelUsed` (actual judge model per task, `$JudgeResult.Model` fallback
  `$JudgeModelToUse`) is carried on each TaskResult and shown as the Judge Model column.

## Parallelism / cost (do not "dedupe")

- Start-Job per answer model; per-model + total + judge timeouts (judge default 90 s).
- Retry x1 on null / 429 / 5xx; never on 400 / 401 / 403.
- Helper functions are intentionally DUPLICATED inside job scriptblocks - PS 5.1 jobs do
  NOT inherit session functions. Do not refactor the duplicates away.
- `Get-EstimatedCostUsd` is byte-frozen. Cost is keyed by "Provider|Model" from config
  `CostPer1MTokens`. Unknown-model cost is reported (cost_warnings.json), never silent.
