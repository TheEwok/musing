-- musing/heuristics.lua — Tier 1 document structure classifier
-- Pure Lua, no dependencies. Takes lines, returns elements.

local M = {}

-- Patterns
local BLANK_PAT = "^%s*$"
local ULIST_PAT = "^%s*[%-%*%+]%s+"
local OLIST_PAT = "^%s*%d+[%.%)]%s+"
local QUOTE_PAT = "^%s*>%s?"
local INDENT_PAT = "^    " -- 4+ spaces or tab
local TAB_PAT = "^\t"
local HRULE_PAT = "^%s*[%-%*_][%-%*_][%-%*_]%s*$"
local TABLE_SEP_PAT = "^[%s|%-:]+"

--- Check if a line looks like a heading.
--- Short line, followed by a blank (or EOF), not punctuation-heavy.
local function is_heading_line(line, next_line, prev_line)
  if #line == 0 or #line > 120 then return false end
  -- Must be followed by blank or EOF
  if next_line and not next_line:match(BLANK_PAT) then return false end
  -- Skip lines that look like list items, quotes, etc.
  if line:match(ULIST_PAT) or line:match(OLIST_PAT) or line:match(QUOTE_PAT) then
    return false
  end
  -- Heuristic: short, no trailing punctuation typical of sentences
  if #line > 80 then return false end
  if line:match("[%.,%;]%s*$") then return false end
  -- Reject data-like lines: contain digits mixed with words
  local trimmed = line:match("^%s*(.-)%s*$")
  if trimmed:match("%d") and trimmed:match("%a") and #trimmed:gsub("%s+", " "):gsub("[^ ]", "") >= 2 then
    return false
  end
  -- If previous line has similar structure (same indent, similar length), not a heading
  if prev_line and not prev_line:match(BLANK_PAT) then
    local indent_cur = #(line:match("^(%s*)") or "")
    local indent_prev = #(prev_line:match("^(%s*)") or "")
    if indent_cur == indent_prev and math.abs(#line - #prev_line) < 20 then
      return false
    end
  end
  return true
end

--- Guess heading level from visual cues.
local function heading_level(line, line_num)
  -- ALL CAPS = likely level 1
  local alpha = line:gsub("[^%a]", "")
  if #alpha > 1 and line:upper() == line then return 1 end
  -- Very short (< 30 chars) at top of doc = level 1
  if line_num <= 3 and #line < 40 then return 1 end
  return 2
end

--- Detect table rows: lines with 2+ pipe characters or consistent multi-space gaps.
local function is_table_row(line)
  -- Pipe-delimited (unambiguous)
  local pipes = 0
  for _ in line:gmatch("|") do pipes = pipes + 1 end
  if pipes >= 2 then return true end
  return false
end

local function is_table_separator(line)
  return line:match(TABLE_SEP_PAT) and line:match("[%-]") and not line:match("[%a]")
end

--- Classify all lines. Returns a list of element tables:
--- { start_line, end_line, type, attrs, confidence }
function M.classify(lines)
  local elements = {}
  local i = 1
  local n = #lines

  local function add(start_l, end_l, etype, attrs, conf)
    elements[#elements + 1] = {
      start_line = start_l,
      end_line = end_l,
      type = etype,
      attrs = attrs or {},
      confidence = conf or 1.0,
    }
  end

  while i <= n do
    local line = lines[i]
    local next_line = lines[i + 1]

    -- Blank lines
    if line:match(BLANK_PAT) then
      local start = i
      while i <= n and lines[i]:match(BLANK_PAT) do i = i + 1 end
      add(start, i - 1, "blank")

    -- Thematic break / horizontal rule
    elseif line:match(HRULE_PAT) then
      add(i, i, "thematic_break")
      i = i + 1

    -- Blockquote
    elseif line:match(QUOTE_PAT) then
      local start = i
      while i <= n and lines[i]:match(QUOTE_PAT) do i = i + 1 end
      add(start, i - 1, "blockquote")

    -- Unordered list
    elseif line:match(ULIST_PAT) then
      local start = i
      i = i + 1
      -- Continuation: next lines that are list items or indented continuations
      while i <= n do
        local l = lines[i]
        if l:match(ULIST_PAT) or (l:match("^%s%s+%S") and not l:match(BLANK_PAT)) then
          i = i + 1
        else
          break
        end
      end
      add(start, i - 1, "list", { style = "unordered" })

    -- Ordered list
    elseif line:match(OLIST_PAT) then
      local start = i
      i = i + 1
      while i <= n do
        local l = lines[i]
        if l:match(OLIST_PAT) or (l:match("^%s%s+%S") and not l:match(BLANK_PAT)) then
          i = i + 1
        else
          break
        end
      end
      add(start, i - 1, "list", { style = "ordered" })

    -- Indented block (code)
    elseif line:match(INDENT_PAT) or line:match(TAB_PAT) then
      local start = i
      while i <= n and (lines[i]:match(INDENT_PAT) or lines[i]:match(TAB_PAT) or lines[i]:match(BLANK_PAT)) do
        -- Don't let trailing blanks get swallowed unless followed by more indented lines
        if lines[i]:match(BLANK_PAT) then
          local j = i + 1
          if j <= n and (lines[j]:match(INDENT_PAT) or lines[j]:match(TAB_PAT)) then
            i = i + 1
          else
            break
          end
        else
          i = i + 1
        end
      end
      add(start, i - 1, "code", {}, 0.7) -- lower confidence: could be a paragraph

    -- Table
    elseif is_table_row(line) then
      local start = i
      local col_count = 0
      for _ in line:gmatch("|") do col_count = col_count + 1 end
      col_count = math.max(col_count - 1, 1)
      i = i + 1
      while i <= n and (is_table_row(lines[i]) or is_table_separator(lines[i])) do
        i = i + 1
      end
      add(start, i - 1, "table", { columns = col_count })

    -- Heading (must check after lists/quotes/code since those take priority)
    elseif is_heading_line(line, next_line, lines[i - 1]) then
      add(i, i, "heading", { level = heading_level(line, i) }, 0.8)
      i = i + 1

    -- Default: paragraph
    else
      local start = i
      i = i + 1
      while i <= n do
        local l = lines[i]
        if l:match(BLANK_PAT) or l:match(ULIST_PAT) or l:match(OLIST_PAT)
          or l:match(QUOTE_PAT) or l:match(HRULE_PAT) or is_table_row(l)
          or (l:match(INDENT_PAT) or l:match(TAB_PAT)) then
          break
        end
        if is_heading_line(l, lines[i + 1], lines[i - 1]) then break end
        i = i + 1
      end
      -- Lower confidence for blocks of short lines that look data-like
      -- (multiple words per line, similar lengths) — LLM should review
      local block_len = (i - 1) - start + 1
      local conf = 1.0
      if block_len >= 2 then
        local short_count = 0
        local has_digits = false
        for j = start, i - 1 do
          if #lines[j] < 50 then short_count = short_count + 1 end
          if lines[j]:match("%d") then has_digits = true end
        end
        if short_count == block_len and has_digits then conf = 0.5 end
      end
      add(start, i - 1, "paragraph", {}, conf)
    end
  end

  return elements
end

return M
