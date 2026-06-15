# Generated-Code Prompt Rules

These are the rules the tool embeds in BOTH answer prompts and BOTH judge prompts so
the LLMs produce safe PowerShell. They are not the tool's own coding rules - they are
what the tool tells the models to do.

## The layering rule (read first)

A flaw in a GENERATED script (a missing `-Force`, a wrong AD filter, a missing column)
is fixed by changing the answer/judge PROMPT RULES, not the tool's own code. Keep the
two layers separate: tool bugs -> edit the .ps1; bad generated output -> edit the prompt.

## Rules embedded in the answer + judge prompts

- `cls` first; variables at the top; no `param()`.
- if/else over ternary; wrap risky calls in Try/Catch.
- Never `Export-Csv` after `Format-Table` (Format-Table emits format objects, not data).
- AD `-Filter` must use `$true` / `$false` WITH the `$` sign - never the bareword
  `Enabled -eq True`. (The bareword bug is exactly what a weak Full judge let through
  before v0.8.0.)
- Wrap in `@()` before reading `.Count`.
- ASCII-only generated output.

## Self-check rules (v0.7.8)

- Any behavioral claim about PowerShell semantics must be PROVEN by a runnable self-check
  inside the generated script, not just asserted in prose. The self-check must PASS on a
  clean host (no false "UNEXPECTED" alarms) - see the v0.8.52 fix below.
- Test null `LastLogonDate` via `$null -eq` (not `-lt`).
- Guard `WhenCreated` in-script before using it.
- Create the export folder before writing to it.
- End with `return`, not `Exit`.

## v0.8.52 rules (null-comparison correctness) - IMPLEMENTED

A run review caught the prompts teaching an INVERTED fact: "`$null -lt [DateTime]` returns
`$false`, so never-logged-in accounts are dropped." That is WRONG. In PS 5.1 `$null` sorts
as LESS THAN any value, so `$null -lt`/`-le` are `$true` and a `-lt` filter INCLUDES nulls.
Two root causes, both fixed in all four answer/judge system prompts:
- (a) The rule text was NOT backtick-escaped in the double-quoted here-strings, so the model
  literally received `Enabled -eq False` and `( -eq .LastLogonDate)` (the `$false`/`$null`/`$_`
  interpolated away). Now backtick-escaped.
- (b) The null-comparison rule now states the REAL PS 5.1 semantics and FORBIDS claiming `-lt`
  drops nulls; the self-check must PASS on a clean host.
This is the canonical example of the layering rule: it was fixed in the PROMPT, not the tool.

## v0.8.2 rules (AD inventory scripts) - IMPLEMENTED

Added to both answer prompts and both judge prompts in v0.8.2 (prompt-only; routing
and cost math untouched):
- Create export/output folders with `New-Item -ItemType Directory -Force` (also makes
  any missing intermediate paths).
- Include `DistinguishedName` in AD inventory/report objects (duplicate CNs are common).
- Do NOT add an `Enabled` column when the query already filters to a single Enabled
  state (e.g. `Enabled -eq $false`) - an always-constant column is noise.
