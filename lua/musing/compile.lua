-- musing/compile.lua — Convert plain text + sidecar into output formats via pandoc

local sidecar = require("musing.sidecar")

local M = {}

--- Resolve element type for a line range, applying overrides.
local function resolve_type(data, key)
  if data.overrides[key] and data.overrides[key].type then
    return data.overrides[key], true
  end
  return data.elements[key] or { type = "paragraph" }, false
end

--- Build a lookup: line number → { key, element }
local function build_line_map(data)
  local map = {}
  local all_keys = {}
  for key in pairs(data.elements) do all_keys[#all_keys + 1] = key end
  for key in pairs(data.overrides) do
    if not data.elements[key] then all_keys[#all_keys + 1] = key end
  end
  for _, key in ipairs(all_keys) do
    local s, e = key:match("^(%d+)%-(%d+)$")
    if not s then s = key:match("^(%d+)$"); e = s end
    s, e = tonumber(s), tonumber(e)
    if s then
      for i = s, e do
        map[i] = { key = key, start_line = s, end_line = e }
      end
    end
  end
  return map
end

--- Convert plain text + sidecar to pandoc markdown.
function M.to_markdown(filepath)
  local data = sidecar.read(filepath)
  local f = io.open(filepath, "r")
  if not f then return nil, "cannot open " .. filepath end
  local lines = {}
  for line in f:lines() do lines[#lines + 1] = line end
  f:close()

  local line_map = build_line_map(data)
  local out = {}
  local i = 1

  -- Frontmatter from meta
  if next(data.meta) then
    out[#out + 1] = "---"
    for k, v in pairs(data.meta) do
      out[#out + 1] = k .. ": " .. tostring(v)
    end
    out[#out + 1] = "---"
    out[#out + 1] = ""
  end

  while i <= #lines do
    local info = line_map[i]
    if not info then
      out[#out + 1] = lines[i]
      i = i + 1
      goto continue
    end

    local el = resolve_type(data, info.key)
    local s, e = info.start_line, info.end_line

    if el.type == "blank" then
      out[#out + 1] = ""
      i = e + 1

    elseif el.type == "heading" then
      local prefix = string.rep("#", el.level or 1) .. " "
      out[#out + 1] = prefix .. lines[s]
      i = e + 1

    elseif el.type == "code" then
      local lang = el.language or ""
      out[#out + 1] = "```" .. lang
      for j = s, e do
        -- Strip leading 4-space indent if present
        local stripped = lines[j]:match("^    (.*)$") or lines[j]:match("^\t(.*)$") or lines[j]
        out[#out + 1] = stripped
      end
      out[#out + 1] = "```"
      i = e + 1

    elseif el.type == "blockquote" then
      for j = s, e do
        local text = lines[j]:match("^%s*>%s?(.*)$") or lines[j]
        out[#out + 1] = "> " .. text
      end
      i = e + 1

    elseif el.type == "list" then
      for j = s, e do
        out[#out + 1] = lines[j]
      end
      i = e + 1

    elseif el.type == "table" then
      for j = s, e do
        out[#out + 1] = lines[j]
      end
      i = e + 1

    elseif el.type == "thematic_break" then
      out[#out + 1] = "---"
      i = e + 1

    else -- paragraph and anything else
      for j = s, e do
        out[#out + 1] = lines[j]
      end
      i = e + 1
    end

    ::continue::
  end

  return table.concat(out, "\n") .. "\n"
end

--- Compile to output format via pandoc.
--- format: "html", "pdf", "docx", "epub", etc.
--- Returns output filepath on success, or nil + error.
function M.compile(filepath, format)
  format = format or "html"

  local md = M.to_markdown(filepath)
  if not md then return nil, "failed to generate markdown" end

  local base = filepath:match("(.+)%.[^%.]+$") or filepath
  local outpath = base .. "." .. format

  local tmp = os.tmpname() .. ".md"
  local f = io.open(tmp, "w")
  f:write(md)
  f:close()

  local cmd = string.format("pandoc %s -f markdown -o %s 2>&1",
    vim.fn.shellescape(tmp), vim.fn.shellescape(outpath))
  local result = vim.fn.system(cmd)
  os.remove(tmp)

  if vim.v.shell_error ~= 0 then
    return nil, "pandoc error: " .. result
  end

  return outpath
end

return M
