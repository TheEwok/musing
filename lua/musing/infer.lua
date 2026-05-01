-- musing/infer.lua — Tier 2 LLM inference for ambiguous document elements
-- Calls an OpenAI-compatible endpoint (llama-server, ollama, etc.)

local M = {}

local SYSTEM_PROMPT = [[You classify plain text document elements. Given numbered lines of text, respond with a JSON array of objects: {"line":"<range>","type":"<type>","level":<n>}
Valid types: heading, paragraph, list, code, blockquote, table, thematic_break, blank
Only include "level" for headings (1-6). Only include "style" for lists ("ordered" or "unordered").
Respond with ONLY the JSON array, no explanation.]]

--- Build a prompt from ambiguous lines and their surrounding context.
local function build_prompt(lines, ambiguous)
  local parts = {}
  for _, amb in ipairs(ambiguous) do
    local s, e = amb.start_line, amb.end_line
    -- Include 2 lines of context before/after
    local ctx_start = math.max(1, s - 2)
    local ctx_end = math.min(#lines, e + 2)
    local chunk = {}
    for i = ctx_start, ctx_end do
      local marker = (i >= s and i <= e) and ">>>" or "   "
      chunk[#chunk + 1] = string.format("%s %3d: %s", marker, i, lines[i])
    end
    parts[#parts + 1] = table.concat(chunk, "\n")
  end
  return "Classify the lines marked with >>> :\n\n" .. table.concat(parts, "\n\n")
end

--- Parse JSON array from LLM response (minimal parser for our specific format).
local function parse_response(text)
  -- Find the JSON array in the response
  local json = text:match("%[.-%]")
  if not json then return {} end

  local results = {}
  -- Match each object: {"line":"...","type":"...",...}
  for obj in json:gmatch("{(.-)}") do
    local entry = {}
    for key, val in obj:gmatch('"(%w+)"%s*:%s*"?([^",}]+)"?') do
      local num = tonumber(val)
      entry[key] = num or val
    end
    if entry.line and entry.type then
      results[#results + 1] = entry
    end
  end
  return results
end

--- Call the inference endpoint synchronously via curl.
--- Returns parsed results or nil on error.
function M.call(endpoint, lines, ambiguous)
  if not endpoint or #ambiguous == 0 then return {} end

  local prompt = build_prompt(lines, ambiguous)

  local body = vim.json.encode({
    model = "default",
    messages = {
      { role = "system", content = SYSTEM_PROMPT },
      { role = "user", content = prompt },
    },
    temperature = 0,
    max_tokens = 256,
  })

  -- Write body to temp file to avoid shell escaping issues
  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(body)
  f:close()

  local cmd = string.format(
    'curl -s -X POST "%s/v1/chat/completions" -H "Content-Type: application/json" -d @%s 2>/dev/null',
    endpoint, tmp
  )

  local handle = io.popen(cmd)
  local response = handle:read("*a")
  handle:close()
  os.remove(tmp)

  -- Parse the OpenAI-format response
  local ok, decoded = pcall(vim.json.decode, response)
  if not ok or not decoded.choices or not decoded.choices[1] then
    return nil
  end

  local content = decoded.choices[1].message and decoded.choices[1].message.content or ""
  return parse_response(content)
end

--- Async version using vim.system (non-blocking).
function M.call_async(endpoint, lines, ambiguous, callback)
  if not endpoint or #ambiguous == 0 then
    callback({})
    return
  end

  local prompt = build_prompt(lines, ambiguous)

  local body = vim.json.encode({
    model = "default",
    messages = {
      { role = "system", content = SYSTEM_PROMPT },
      { role = "user", content = prompt },
    },
    temperature = 0,
    max_tokens = 256,
  })

  local tmp = os.tmpname()
  local f = io.open(tmp, "w")
  f:write(body)
  f:close()

  vim.system(
    { "curl", "-s", "-X", "POST", endpoint .. "/v1/chat/completions",
      "-H", "Content-Type: application/json", "-d", "@" .. tmp },
    { text = true },
    function(result)
      os.remove(tmp)
      if result.code ~= 0 then
        vim.schedule(function() callback(nil) end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, result.stdout)
      if not ok or not decoded.choices or not decoded.choices[1] then
        vim.schedule(function() callback(nil) end)
        return
      end
      local content = decoded.choices[1].message and decoded.choices[1].message.content or ""
      vim.schedule(function() callback(parse_response(content)) end)
    end
  )
end

return M
