# Musing — Progress & Context

*Last updated: 2026-04-30*

## What Is This?

Musing is a neovim plugin that infers document structure from plain text using
a tiered approach (heuristics + LLM), stores the structure in a TOML sidecar
file, and compiles to any output format via pandoc. The core idea: you write
readable plain text with zero markup syntax, and the tool figures out what's a
heading, paragraph, list, code block, table, etc.

Repo: git@github.com:TheEwok/musing.git

## Origin

Started from research into recent Markdown criticism (2025-2026). The common
complaints: flavor fragmentation, syntax inconsistency, parsing complexity,
lack of semantic structure, security issues (ReDoS, XSS via inline HTML).
Existing alternatives (AsciiDoc, Orgdown, Djot, reST) all propose better
syntax. Our insight: with LLMs available, eliminate syntax entirely and infer
structure from plain text. Research notes are in
`markdown-criticism-and-ai-document-formatting.md`.

## Architecture

```
neovim plugin (Lua)
  ├── Tier 1: heuristics (pure Lua, instant, handles ~80% of lines)
  ├── Tier 2: HTTP POST → llama-server (for ambiguous lines, async)
  └── Compile: text + sidecar → intermediate markdown → pandoc → output
```

**Sidecar format:** `document.txt.musing.toml` — three sections:
- `[elements]` — auto-generated on every save, line ranges → element types
- `[overrides]` — user corrections, never touched by inference
- `[meta]` — user metadata (title, author), never touched by inference

**Design constraints:**
- Hardware floor: any modern laptop (8GB+, no GPU required)
- Inference endpoint configurable: localhost or private server
- Fully offline capable (heuristics work with no server)
- Dependencies: just llama.cpp + a GGUF model + pandoc

## Files

```
lua/musing/
  init.lua        — plugin entry, setup(), commands, gutter display
  heuristics.lua  — tier 1 pattern classifier
  infer.lua       — tier 2 LLM HTTP client (async, OpenAI-compatible API)
  sidecar.lua     — TOML parse/serialize, read/write with override preservation
  compile.lua     — text + sidecar → markdown → pandoc → html/pdf/docx/epub/latex
spec.md           — sidecar format specification
test_heuristics.lua
test_sidecar.lua
markdown-criticism-and-ai-document-formatting.md — research notes
```

## Neovim Setup

Plugin registered as local dev plugin in `~/.config/nvim/init.lua`:
```lua
{ dir = "~/dev/musing", name = "musing", ft = { "text", "markdown", "" },
  config = function() require("musing").setup() end }
```

Full neovim config was created from scratch (migrated from vim). Uses lazy.nvim,
nvim-solarized-lua, lualine, nvim-tree, native LSP, fugitive, tmux-navigator,
vim-test, LuaSnip, llama.vim. Vim setup at `~/dotfiles/dotfiles/vimrc` is
untouched and independent.

## Commands

- `:MusingAnalyze` — manually run classification
- `:MusingOverride <type>` — correct classification at cursor (heading, paragraph, list, code, blockquote, table, thematic_break, blank)
- `:MusingCompile [format]` — compile to html (default), pdf, docx, epub, latex
- `:MusingClear` — hide gutter signs

Auto-analyzes on `BufWritePost` for text/markdown filetypes.

## Element Types

heading (level 1-6), paragraph, list (ordered/unordered), code (language),
blockquote, table (columns), thematic_break, blank

## Heuristics Philosophy

Keep heuristics simple and honest. Detect what's unambiguous:
- Pipe-delimited tables, list items (- * + 1.), blockquotes (>), indented
  code (4+ spaces/tab), horizontal rules (--- *** ___), blanks
- Headings: short line + followed by blank + not data-like

Flag what's ambiguous with low confidence:
- Blocks of short lines containing digits → conf=0.5 (likely tabular data)
- Indented blocks → conf=0.7 (could be code or indented paragraph)
- Headings → conf=0.8 (could be a short sentence)

Low-confidence elements get sent to the LLM tier for contextual classification.

## LLM Tier

- Sends ambiguous lines with 2 lines of surrounding context
- System prompt asks for JSON array of classifications
- Async via vim.system — heuristics display instantly, LLM refines after
- Enable: `require("musing").setup({ llm_endpoint = "http://localhost:8080" })`
- Recommended model: SmolLM2-1.7B-Instruct Q4_K_M (~1GB) via llama-server

## What's Done

1. ✅ Sidecar format spec
2. ✅ Heuristics engine (pure Lua)
3. ✅ Neovim plugin skeleton + TOML sidecar read/write
4. ✅ Gutter display (signs + virtual text for low-confidence)
5. ✅ LLM inference tier (async HTTP)
6. ✅ Pandoc compilation (auto-detects tectonic > xelatex > pdflatex for PDF)

## What's Next

- Test LLM tier end-to-end with an actual llama-server + model
- Improve override UX (the make-or-break design challenge)
- Handle edge cases: mixed-indent documents, definition lists, footnotes
- Consider: should the sidecar track document hash to detect stale analysis?
- Consider: feedback loop where overrides improve future heuristic confidence
- README for the repo

## Installed Tools

- Neovim 0.11.6 (Manjaro, pacman)
- Pandoc 3.5
- Tectonic (PDF engine, preferred over pdflatex)
- Vim 9.2 still installed and independent
