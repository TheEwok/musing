-- musing/sidecar.lua — Read/write TOML sidecar files
-- Handles the subset of TOML used by musing: strings, numbers, booleans, flat/nested tables.

local M = {}

-- ============================================================
-- TOML Parser (minimal, covers our sidecar format)
-- ============================================================

local function trim(s) return s:match("^%s*(.-)%s*$") end

local function parse_value(raw)
  raw = trim(raw)
  if raw == "true" then return true end
  if raw == "false" then return false end
  -- Number
  local num = tonumber(raw)
  if num then return num end
  -- Quoted string
  local str = raw:match('^"(.*)"$')
  if str then return str end
  return raw
end

function M.parse(text)
  local root = {}
  local current = root
  local path = {}

  for line in text:gmatch("[^\r\n]+") do
    line = trim(line)
    -- Skip comments and blanks
    if line == "" or line:match("^#") then goto continue end

    -- Table header: [foo] or [foo."bar"]
    local header = line:match("^%[([^%[%]]+)%]$")
    if header then
      current = root
      for key in header:gmatch('[^%.]+') do
        key = key:match('^"(.*)"$') or trim(key)
        if not current[key] then current[key] = {} end
        current = current[key]
      end
      goto continue
    end

    -- Key = value
    local key, val = line:match("^([%w_]+)%s*=%s*(.+)$")
    if not key then
      -- Try quoted key
      key, val = line:match('^"([^"]+)"%s*=%s*(.+)$')
    end
    if key and val then
      -- Strip inline comment
      local in_str = false
      for ci = 1, #val do
        local c = val:sub(ci, ci)
        if c == '"' then in_str = not in_str end
        if c == '#' and not in_str then
          val = val:sub(1, ci - 1)
          break
        end
      end
      current[key] = parse_value(val)
    end

    ::continue::
  end
  return root
end

-- ============================================================
-- TOML Writer (produces our sidecar format)
-- ============================================================

local function quote(s)
  return '"' .. tostring(s):gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
end

local function write_value(v)
  if type(v) == "string" then return quote(v) end
  if type(v) == "boolean" then return tostring(v) end
  if type(v) == "number" then
    if v == math.floor(v) then return tostring(math.floor(v)) end
    return tostring(v)
  end
  return quote(tostring(v))
end

local function is_table(v) return type(v) == "table" end

--- Sort keys: numeric-looking ranges first (by start line), then alpha.
local function sort_keys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local na = tonumber(a:match("^(%d+)"))
    local nb = tonumber(b:match("^(%d+)"))
    if na and nb then return na < nb end
    if na then return true end
    if nb then return false end
    return a < b
  end)
  return keys
end

function M.serialize(data)
  local out = {}
  local function emit(s) out[#out + 1] = s end

  -- Top-level scalar values
  for _, k in ipairs(sort_keys(data)) do
    if not is_table(data[k]) then
      emit(k .. " = " .. write_value(data[k]))
    end
  end

  -- Sections
  for _, section in ipairs(sort_keys(data)) do
    if is_table(data[section]) then
      local sect = data[section]
      for _, key in ipairs(sort_keys(sect)) do
        if is_table(sect[key]) then
          -- Nested: [section."key"]
          emit("")
          emit("[" .. section .. "." .. quote(key) .. "]")
          for _, k2 in ipairs(sort_keys(sect[key])) do
            emit(k2 .. " = " .. write_value(sect[key][k2]))
          end
        end
      end
      -- Flat keys in section
      local has_flat = false
      for _, key in ipairs(sort_keys(sect)) do
        if not is_table(sect[key]) then has_flat = true; break end
      end
      if has_flat then
        emit("")
        emit("[" .. section .. "]")
        for _, key in ipairs(sort_keys(sect)) do
          if not is_table(sect[key]) then
            emit(key .. " = " .. write_value(sect[key]))
          end
        end
      end
    end
  end

  return table.concat(out, "\n") .. "\n"
end

-- ============================================================
-- Sidecar file operations
-- ============================================================

function M.sidecar_path(filepath)
  return filepath .. ".musing.toml"
end

function M.read(filepath)
  local spath = M.sidecar_path(filepath)
  local f = io.open(spath, "r")
  if not f then return { version = 1, elements = {}, overrides = {}, meta = {} } end
  local text = f:read("*a")
  f:close()
  local data = M.parse(text)
  data.version = data.version or 1
  data.elements = data.elements or {}
  data.overrides = data.overrides or {}
  data.meta = data.meta or {}
  return data
end

function M.write(filepath, elements)
  local spath = M.sidecar_path(filepath)

  -- Read existing to preserve overrides and meta
  local existing = M.read(filepath)

  local data = {
    version = 1,
    elements = {},
    overrides = existing.overrides,
    meta = existing.meta,
  }

  -- Convert element list to keyed table
  for _, el in ipairs(elements) do
    local key = el.start_line == el.end_line
      and tostring(el.start_line)
      or (el.start_line .. "-" .. el.end_line)
    local entry = { type = el.type }
    for k, v in pairs(el.attrs) do entry[k] = v end
    if el.confidence and el.confidence < 1.0 then
      entry.confidence = el.confidence
    end
    data.elements[key] = entry
  end

  local f = io.open(spath, "w")
  f:write("# Auto-generated by musing. Manual edits to [overrides] and [meta] are preserved.\n")
  f:write(M.serialize(data))
  f:close()
end

return M
