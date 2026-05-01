-- test_sidecar.lua — run with: lua test_sidecar.lua
package.path = "lua/?.lua;" .. package.path

local h = require("musing.heuristics")
local s = require("musing.sidecar")

-- Classify a small doc
local doc = {
  "My Document Title",
  "",
  "This is a paragraph that",
  "spans two lines.",
  "",
  "- item one",
  "- item two",
}

local elements = h.classify(doc)

-- Write sidecar
local test_file = "/tmp/test_musing.txt"
s.write(test_file, elements)

-- Read it back
local spath = s.sidecar_path(test_file)
local f = io.open(spath, "r")
print("=== Written sidecar ===")
print(f:read("*a"))
f:close()

-- Parse it back and verify
local data = s.read(test_file)
print("=== Parsed back ===")
for key, el in pairs(data.elements) do
  print(string.format("  %-6s  type=%s", key, el.type))
end

-- Cleanup
os.remove(spath)
os.remove(test_file)
