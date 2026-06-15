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

- Any behavioral claim (e.g. "`$null -lt $date` returns False") must be PROVEN by a
  runnable self-check inside the generated script, not just asserted in prose.
- Test null `LastLogonDate` via `$null -eq` (not `-lt`).
- Guard `WhenCreated` in-script before using it.
- Create the export folder before writing to it.
- End with `return`, not `Exit`.

## v0.8.2 rules (AD inventory scripts) - IMPLEMENTED

Added to both answer prompts and both judge prompts in v0.8.2 (prompt-only; routing
and cost math untouched):
- Create export/output folders with `New-Item -ItemType Directory -Force` (also makes
  any missing intermediate paths).
- Include `DistinguishedName` in AD inventory/report objects (duplicate CNs are common).
- Do NOT add an `Enabled` column when the query already filters to a single Enabled
  state (e.g. `Enabled -eq $false`) - an always-constant column is noise.
