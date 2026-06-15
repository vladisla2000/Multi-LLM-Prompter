---
name: multi-llm-prompter
description: Load when working on the Multi-LLM Prompter tool (single-file PowerShell 5.1 + WPF utility - one prompt to two answer models in parallel, a Judge compares/synthesizes, writes a final answer plus a full audit trail; the same .ps1 also runs as a hidden headless child) or similar multi-model judge pipelines. Covers the judge marker contract and the Full-mode-always-uses-the-strong-judge policy; the router task-types and the frozen Get-TaskWorkMode and Get-EstimatedCostUsd logic; embedded answer/judge prompt rules for generated PowerShell plus the fix-the-prompt-not-the-tool layering rule; the env-var GUI-to-child contract and headless model; and version-bump and validate-before-delivery release discipline. Pair with ps-wpf-core and vlad-wpf-design for GUI work.
---

# Multi-LLM Prompter

Load this with `ps-wpf-core` (and `vlad-wpf-design` for GUI work) when working on
Multi-LLM Prompter. It is a mature daily driver: most "do not touch" rules below are
load-bearing because a past regression already proved the cost of breaking them.

## Read this skill when

- touching the judge, router, work-mode, parallelism, or cost logic
- editing the answer/judge prompts that tell the LLMs how to write PowerShell
- changing the env-var GUI-to-child contract or the headless run flow
- bumping a version, or validating the file before delivery
- planning Detect Tasks Phase 2, the v0.9 benchmark, or any GUI change

## Workflow

1. Read `references/pipeline-and-judge.md` for the router, the judge marker contract,
   the Full-always-strong-judge policy, and the frozen / duplicated patterns that must
   not be "cleaned up."
2. Read `references/generated-code-prompt-rules.md` for the rules embedded in the
   answer/judge prompts, and the layering rule: a flaw in a GENERATED script is fixed
   in the PROMPT, not in the tool's own code.
3. Read `references/architecture-and-conventions.md` for the single-file / no-param /
   env-var design, the source encoding rules, and the release + validate-before-
   delivery discipline.
4. Read `references/gui-and-roadmap.md` for the GUI zones/tabs, the model-combo
   exception, the Detect Tasks Phase 2 ownership change, and the known-issue and
   roadmap watch-list.
