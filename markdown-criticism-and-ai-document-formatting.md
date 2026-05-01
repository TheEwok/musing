# Markdown Criticism & AI-Powered Document Formatting Research

*Compiled: 2026-04-30*

---

## Part 1: Recent Markdown Criticism (Past 12 Months)

### Most Commonly Cited Problems

**Fragmentation / "Flavor Hell"** — The #1 complaint across nearly every article. There is no single "Markdown" — there's CommonMark, GFM, MultiMarkdown, MDX, and dozens of tool-specific dialects. Documents that render correctly in one tool break in another. Karl Voit's widely-shared article calls this the fundamental, unfixable problem: the battle for a single standard is already lost.

**Syntax Inconsistency** — Multiple ways to express the same thing (two heading styles, multiple emphasis markers, multiple list syntaxes) make the language harder to learn and remember than it appears. The link syntax `[text](url)` vs `(text)[url]` confusion has become a meme. Adding image alt-text or titles requires looking it up every time for infrequent users.

**Parsing Complexity & Security** — What looks like a "simple" format is actually nightmarish to parse correctly. The CommonMark spec is hundreds of pages. This complexity makes parsers vulnerable to ReDoS (Regular Expression Denial of Service) attacks. Inline HTML support means Markdown parsers effectively need a full HTML parser too, which opens the door to XSS vulnerabilities.

**Lack of Semantic Structure** — Markdown has no schema, no typing, no way to express semantic meaning. This makes it unsuitable for content reuse, multi-channel publishing (HTML, PDF, ePub), and machine parsing by LLMs and search engines. Custom extensions like MDX try to bolt on semantics but are brittle and non-portable.

**Tooling Fragmentation** — Developers are forced to choose between context-switching (external editors like Typora), wasted screen space (split-pane previews), or buggy/paywalled IDE extensions. None of the options are great.

**Inline HTML as an Escape Hatch** — For anything beyond basic formatting (complex tables, multi-column layouts, image sizing), you end up writing raw HTML inside Markdown, defeating the purpose of a "lightweight" markup language.

### Suggested Alternatives

**Orgdown / Org-mode syntax** — Karl Voit's preferred alternative. Consistent, well-designed syntax with no flavor fragmentation, excellent tool support (not just Emacs — many parsers exist), and covers more use cases out of the box. GitHub and GitLab already render `.org` files.

**AsciiDoc** — Frequently recommended for technical documentation. One standard (no flavor problem), richer feature set (tables, cross-references, admonitions, multi-format output), and readable syntax. The Asciidoctor toolchain is mature.

**reStructuredText (reST)** — The Python ecosystem's standard (Sphinx). More powerful than Markdown for structured docs, but commonly criticized as harder to write and less visually clean.

**Djot** — Created by John MacFarlane (the author of Pandoc and a key CommonMark contributor). Designed as a direct successor to Markdown with an unambiguous grammar, cleaner syntax, built-in support for definition lists, footnotes, math, attributes, and generic containers. Growing adoption with parsers in multiple languages.

**"Build system" approach** — Burak Güngör (BGs Labs, March 2026) argues none of the existing LMLs are sufficient. His proposal: a purpose-built markup language with a formal grammar, no inline HTML, well-defined shortcodes/functions, and compile-time hooks — essentially treating document generation as a proper build pipeline.

**Plain text / HTML directly** — The skeptic's position: for simple things, plain text is enough; for complex things, you're going to end up writing HTML anyway, so skip the middleman.

### Key Takeaway

The criticism isn't that lightweight markup is a bad idea — everyone agrees it's great. The argument is that Markdown specifically is a poor implementation of that idea, and its dominance through network effects prevents better-designed alternatives from gaining traction. The "flavor hell" problem is considered unfixable because standardization would break existing content.

### Sources

- Karl Voit: Markdown Disaster — Why and What to Do Instead — https://karl-voit.at/2025/08/17/Markdown-disaster/
- Hackaday: Making The Case Against Markdown — https://hackaday.com/2026/04/05/making-the-case-against-markdown/
- BGs Labs: Why the heck are we still using Markdown?? — https://bgslabs.org/blog/why-are-we-using-markdown/
- Concretio: Why Developers Still Fight Markdown Editors — https://www.concret.io/blog/why-are-developers-still-fighting-their-markdown-editors
- ASCII News: Markdown's Semantic Limitations — https://ascii.co.uk/news/article/news-20251124-5b20fc2f/markdown-s-semantic-limitations-make-it-unsuitable-for-techn
- pdx.su: Writing in Djot — https://pdx.su/blog/2025-06-28-writing-in-djot
- Lullabot: Markdown Won't Solve Your Content Problems — https://www.lullabot.com/articles/markdown-wont-solve-your-content-problems

---

## Part 2: AI-Powered Document Formatting — The Missing Piece

### The Core Idea

All the Markdown criticism is missing something: with LLMs and agents available, there should be a solution where you write readable plain text and an AI infers the semantic structure, storing it separately (like the old Macintosh resource fork / data fork split). The structured result can then be "compiled" into any output format.

### What Exists Today (the pieces)

**Sidematter Format** (jlevy/sidematter-format, Feb 2026) — Almost literally the resource fork idea. You write your document as a plain file, and a sidecar `.meta.yml` file alongside it carries structured metadata (author, tags, processing history, schema). An `.assets/` directory holds related files. The content and its semantic description are cleanly separated. Format-agnostic, works with any text file.
- https://github.com/jlevy/sidematter-format

**SemDoc** (MarcelGarus/semdoc) — A binary document format that is purely semantic — it contains no presentation information at all. Writers declare *what* to display; readers control *how* to show it. Designed as a compile target, not a human-editable format. The philosophy is exactly right but the execution is aimed at replacing PDF, not at the authoring experience.
- https://github.com/MarcelGarus/semdoc

**DataBooks** (The Ontologist, Apr 2026) — A very recent proposal that uses Markdown with YAML frontmatter and typed fenced blocks as "self-describing semantic documents." The key insight: LLMs are treated as *transformation engines* in a pipeline, not as the primary agent. Documents carry provenance stamps recording what produced them. The most architecturally complete vision found, but it's a pattern for semantic web / RDF workflows, not a general-purpose authoring tool.
- https://open.substack.com/pub/ontologist/p/databooks-markdown-as-semantic-infrastructure

**Pandoc** — Already the universal document compiler. Can take nearly any input format and produce nearly any output. The missing piece is the *inference* layer — it needs explicit markup as input.

**Djot** — Created by the author of Pandoc specifically to fix Markdown's parsing ambiguity. Unambiguous grammar, richer feature set, trivially parseable. Growing adoption. The best "clean syntax" candidate if you want a human-editable source format.
- https://github.com/jgm/djot

### What Doesn't Exist Yet (the gap)

Nobody has built: **an AI agent that watches you write plain text and infers semantic structure into a sidecar file, which can then be compiled to any output format.**

### Proposed Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  document.txt   │────▶│  inference agent  │────▶│ document.sem    │
│  (plain text,   │     │  (LLM/embeddings) │     │ (semantic AST   │
│   you write in  │     │                    │     │  sidecar file)  │
│   vim)          │     └──────────────────┘     └────────┬────────┘
└─────────────────┘                                       │
                                                          ▼
                                                 ┌─────────────────┐
                                                 │   compiler      │
                                                 │   (pandoc-like) │
                                                 └───┬───┬───┬─────┘
                                                     │   │   │
                                                    HTML PDF ePub
```

The sidecar ("resource fork") would store things like:
- This line is a heading (level 2)
- This block is a code listing (language: python)
- This paragraph is a blockquote / attribution
- This section is an aside / callout
- These lines are a table (with column types)

The inference agent would use a combination of:
- **Structural heuristics** — lines that look like headings, lists, etc.
- **Embedding similarity** — classify blocks by comparing against known document element types
- **LLM inference** — for ambiguous cases, ask a model "is this a heading or emphasis?"
- **User feedback loop** — when the agent guesses wrong, the correction trains future inference

### Why This Is Very Buildable in Vim/Neovim

Neovim has everything needed:

- **Tree-sitter** already does structural parsing and could be extended with a custom grammar for the sidecar format
- **LSP protocol** — build a "document language server" that runs the inference agent and provides diagnostics/suggestions as virtual text or signs in the gutter (non-intrusive)
- **Lua plugin ecosystem** — neovim plugins can call external processes, HTTP APIs, or run local models
- **`BufWritePost` / `TextChanged` autocommands** — trigger re-inference on save or as you type

A minimal viable version would be a neovim plugin that:
1. Watches a plain text buffer
2. On save, sends the content to a local LLM (ollama, llama.cpp) or API
3. Gets back a structural annotation (JSON or YAML sidecar)
4. Displays inferred structure as virtual text / signs in the gutter
5. Lets you override any inference with a keybinding
6. Pipes the text + sidecar through pandoc (or a custom compiler) to produce output

The non-intrusive part is key — faint gutter annotations (`H2`, `CODE`, `QUOTE`) that you can ignore or correct, and the plain text stays completely clean.

### Design Constraints (Refined)

**Hardware floor:** Any modern laptop (8GB+ RAM, no discrete GPU required)
**Inference location:** Configurable — local llama-server or remote private server
**Latency budget:** < 2 seconds for full document re-analysis on save
**Offline capable:** Heuristics tier works with no server running
**Design principle:** The plugin doesn't know or care where the model runs

### Tiered Inference Architecture

**Tier 1 — Heuristics (pure Lua, always local, instant)**
Pattern matching for obvious structure: headings via capitalization/whitespace,
list items, indented code blocks, blockquotes, tables with column alignment.
Handles ~80% of lines in well-written plain text. Provides instant feedback
while typing. Works even when inference server is down (graceful degradation).

**Tier 2 — LLM classification via HTTP (configurable endpoint)**
The neovim plugin POSTs ambiguous blocks to an OpenAI-compatible API.
The endpoint is a single config value — localhost or a private server.

```
neovim plugin (Lua)
  ├── Tier 1: heuristics (pure Lua, always local, instant)
  └── Tier 2: HTTP POST → inference endpoint
                ├── http://localhost:8080  (llama-server on laptop)
                └── http://myserver:8080  (llama-server on private box)
```

**Model choices by deployment:**

| Where            | Model               | Disk   | RAM    | Speed       |
|------------------|----------------------|--------|--------|-------------|
| Laptop (light)   | SmolLM2-1.7B Q4_K_M | ~1 GB  | ~1.5GB | 15-30 tok/s |
| Laptop (better)  | Qwen2.5-3B Q4_K_M   | ~1.8GB | ~2.5GB | 8-15 tok/s  |
| Private server   | Qwen2.5-7B Q4_K_M   | ~4 GB  | ~5 GB  | 20-50+ tok/s|

Any of these produce a 50-token classification response in under 2 seconds.
On a server with decent CPU or GPU, near-instant.

### Honest Assessment

The reason this doesn't exist yet isn't technical — it's that the Markdown ecosystem has enormous inertia, and most people working on alternatives are still thinking in terms of "design a better syntax" rather than "eliminate syntax entirely and infer structure." The DataBooks and Sidematter projects show that the sidecar/separation idea is gaining traction, but they still expect humans to write the metadata.

The LLM inference piece is the novel contribution. A small local model (even something like Phi-3 or Qwen2.5 running on ollama) would be more than capable of classifying document structure from plain text — this is a much simpler task than general chat. You could fine-tune a tiny model on document structure classification and it would be fast enough to run on every save.

The biggest design challenge isn't the inference — it's the **correction/override UX**. When the agent gets it wrong, how do you tell it "no, this is a table, not a code block" in a way that's faster than just writing `|` characters? That interaction model is the make-or-break for the whole concept.

### Suggested Stack for a Prototype

- Neovim plugin (Lua) — heuristics + HTTP client
- llama.cpp server (`llama-server`) — local or remote, OpenAI-compatible API
- SmolLM2-1.7B-Instruct GGUF (default model, ~1GB)
- TOML sidecar format for the semantic AST
- Pandoc as the output compiler
- Single config value to switch local ↔ remote inference
