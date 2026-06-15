# Multi-LLM Prompter Developer Handoff

Last updated: 2026-06-13

## Graphics

There are zero product image assets to manage. No logo, no icon font, no SVG set,
and no illustrations.

Icons are Unicode glyphs rendered by the OS font. Use the character directly, or
the matching XAML/HTML entity, always to the left of a label.

Current icon vocabulary includes:

- Play / run: `▶`
- Stop: `■`
- Exit / close: `✖`
- Brain / product mark: `🧠`
- Document / answer: `📄`
- Settings: `⚙`
- Search / detect: `🔍`
- Keys: `🔑`
- Folder: `📁`
- Clipboard / copy: `📋`
- Edit / prompt: `📝`

The complete reference sheet is:

`Multi-LLM Prompter Design System\assets\icon-sheet.png`

That PNG is a cheat-sheet only. Do not slice it, ship it as a sprite, or treat it
as the source of truth for runtime UI.

Backgrounds are flat fills. Depth comes from 1px hairlines and navy/dark bands,
not gradients, shadows, textures, or illustration.

## Fonts

Primary Windows/WPF fonts:

- UI text: `Segoe UI`
- Machine text, prompts, logs, JSON, paths, and output: `Consolas`

These are proprietary Microsoft fonts and are expected to exist on Windows. Do
not bundle them into the project.

Free web/design-system fallbacks:

- UI fallback: `Noto Sans`
- Mono fallback: `Inconsolata`

The design-system README documents font options here:

`Multi-LLM Prompter Design System\assets\README.md`

If fully offline web previews are needed later, add licensed `.woff2` files under
`assets/fonts/` and wire them with `@font-face`. For the WPF app itself, keep using
Windows system fonts.

## How To Use The Design System

For web/static prototypes:

- Link `styles.css`.
- Use tokens such as `var(--color-green)`, `var(--type-label)`,
  `var(--control-h-lg)`, and `var(--radius-sm)`.
- Treat everything visual as a token, not a one-off value.

For React prototypes:

- Load `_ds_bundle.js`.
- Use `window.MultiLLMPrompterDesignSystem_8ae687`.
- Components have adjacent `.d.ts` and `.prompt.md` files where present.

For full-screen prototypes:

- Copy from `ui_kits/multi-llm-prompter/` where present.
- Use flat `index.html` / `redesign.html` outputs as references, not as a replatforming target.

For the actual app:

- Stay WPF / PowerShell 5.1.
- Use the design system as visual guidance, not as a runtime dependency.

## Five Brand Rules

1. Navy chrome plus flat blue, green, and red actions.
2. Consolas for all machine text.
3. Near-square corners, hairlines, and no in-window shadows.
4. Unicode icons left of labels.
5. Color is never the only signal.

## Current File Map Checked

Canonical project:

`C:\_Combined\Multi-LLM-Prompter`

Design assets:

- `Multi-LLM Prompter Design System\assets\README.md`
- `Multi-LLM Prompter Design System\assets\icon-sheet.png`

Add/helper folder:

- `add\APIKeys OpenAI-Claude.txt`
- `add\Multi-LLM-Gate1-Benchmark-Prompts.csv`
- `add\Multi-LLM-RunReviewHelper-v0.1.ps1`
- `add\My Ideas.txt`

## Generated Files

Do not hand-edit generated design-system bundle outputs if they exist. Update the
source/tokens and regenerate instead.

For the PowerShell/WPF app, continue the established release discipline:

- Create a new versioned `.ps1` file for each build.
- Keep previous versions intact.
- Update the changelog.
- Validate with PowerShell parser and WPF XAML load.
- Keep frozen functions unchanged unless the user explicitly asks for that behavior change.
