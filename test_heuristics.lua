-- test_heuristics.lua — run with: lua test_heuristics.lua
package.path = "lua/?.lua;" .. package.path

local h = require("musing.heuristics")

local doc = {
  "My Document Title",                    -- 1: heading
  "",                                      -- 2: blank
  "This is a paragraph of text that",     -- 3-5: paragraph
  "spans multiple lines and contains",
  "some information about the topic.",
  "",                                      -- 6: blank
  "Another Section",                       -- 7: heading
  "",                                      -- 8: blank
  "- first item",                          -- 9-11: unordered list
  "- second item",
  "- third item",
  "",                                      -- 12: blank
  "1. numbered one",                       -- 13-15: ordered list
  "2. numbered two",
  "3. numbered three",
  "",                                      -- 16: blank
  "    function hello()",                  -- 17-19: code
  "        print('hi')",
  "    end",
  "",                                      -- 20: blank
  "> This is a quote",                    -- 21-22: blockquote
  "> from someone wise",
  "",                                      -- 23: blank
  "| Name  | Age | City   |",            -- 24-26: table
  "|-------|-----|--------|",
  "| Alice | 30  | Denver |",
  "",                                      -- 27: blank
  "---",                                   -- 28: thematic_break
}

local elements = h.classify(doc)

for _, el in ipairs(elements) do
  local range = el.start_line == el.end_line
    and tostring(el.start_line)
    or (el.start_line .. "-" .. el.end_line)
  local extra = ""
  for k, v in pairs(el.attrs) do extra = extra .. " " .. k .. "=" .. tostring(v) end
  if el.confidence < 1.0 then extra = extra .. " conf=" .. el.confidence end
  print(string.format("  %-8s  %-18s%s", range, el.type, extra))
end
