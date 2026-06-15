# Assets — Multi-LLM Prompter Design System

This brand is **asset-light by design**. There is no logo file, no icon library, and no
illustration set. What lives here:

## `icon-sheet.png`
A reference render of the brand's **complete icon vocabulary** — every glyph the tool uses,
with its name and Unicode codepoint. These are **Unicode characters rendered by the OS
font** (Segoe UI Symbol / Segoe UI Emoji on Windows), not image files. To use one, type the
character or its `&#x…;` HTML entity — don't slice this PNG. The PNG is a cheat-sheet, not
a sprite.

## Fonts (not bundled — here's where to get them)

The product runs on Windows and uses two **proprietary Microsoft system fonts**. They are
already installed on every Windows machine (the tool's only platform) and **cannot be
redistributed**, so no binaries are checked in here.

| Role | Product font | License | Get it |
|---|---|---|---|
| UI | **Segoe UI** | Proprietary (Microsoft, ships with Windows) | Pre-installed on Windows. Open OSS substitute: **Selawik** — https://github.com/microsoft/Selawik (SIL OFL) |
| Mono | **Consolas** | Proprietary (Microsoft, ships with Windows / Office) | Pre-installed on Windows/Office machines |

**Free web fallbacks actually shipped by this system** (loaded via Google Fonts in
`tokens/fonts.css`, so again no local binaries):

| Substitute for | Family | Download |
|---|---|---|
| Segoe UI | **Noto Sans** | https://fonts.google.com/noto/specimen/Noto+Sans |
| Consolas | **Inconsolata** | https://fonts.google.com/specimen/Inconsolata |

If you have a Segoe UI / Consolas license (or want the OSS Selawik), drop the `.woff2`/`.ttf`
files in `assets/fonts/` and add matching `@font-face` rules to a CSS file reachable from
`styles.css` — the compiler will then ship them to consumers. Until then the system renders
Segoe UI / Consolas from the OS and falls back to Noto Sans / Inconsolata elsewhere.

> ⚠️ I can't fetch or redistribute the proprietary font binaries for you — that's a
> licensing line, not a tooling limit. The links above are the legitimate sources.
