# Element Exports — Multi-LLM Prompter Design System

Individual PNG renders of every brand element, organized by category. All images are
@2x for crisp use in decks, docs, and specs.

```
exports/
├── icons/          22 PNGs — Unicode glyph vocabulary (transparent, 128×128)
├── colors/         26 PNGs — every palette swatch with hex + token (240×150)
├── type/            7 PNGs — type specimens (brand, dialog, label, body, helper, mono)
├── buttons/         8 PNGs — Button variants (run, blue, stop, navy, default, disabled, busy)
├── badges/          6 PNGs — Badge tones (type / model / OK / WARN / FAIL)
├── status-pills/    6 PNGs — StatusPill states (redesign theme)
└── components/      6 PNGs — composed elements (header bar, banner, log console,
                              stat cards, cost meter, status bar)
```

## Notes
- **Icons are reference renders of Unicode glyphs**, not production sprites. In code, use
  the character or `&#x…;` entity — see `assets/icon-sheet.png` for codepoints. (Some
  glyphs like ▶ render as color emoji on Windows; on a colored button they inherit the
  button's text color in the live components.)
- **Colors / type / spacing** are all driven by CSS tokens in `tokens/`. These PNGs are
  for visual reference and slides — the source of truth is `styles.css`.
- Fonts shown are Segoe UI / Consolas (or the renderer's nearest fallback). The system
  ships Noto Sans + Inconsolata as web fallbacks; see `assets/README.md`.
