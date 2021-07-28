--[[
  SHIRO
  ===
  Copyright (c) 2017-2018 Kanru Hua. All rights reserved.

  This file is part of SHIRO.

  SHIRO is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  SHIRO is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with SHIRO.  If not, see <http://www.gnu.org/licenses/>.
]]

local mypath = "/content/SHIRO/"

package.path = package.path .. ";" ..
  mypath .. "?.lua;" .. mypath .. "external/?.lua"

json = require("dkjson")
getopt = require("getopt")
shiro_cli = require("cli-common")

opts = getopt(arg, "sSt")

if opts.h then
  print("Usage:")
  print("shiro-mkpm.lua path-to-phoneset\n" ..
        "  -s state-per-phoneme -S num-stream -t default-topology\n" ..
        "  -w (weak skips by default)")
  return
end

local state_per_phoneme = tonumber(opts.s or "3")
local num_stream = tonumber(opts.S or "3")
local default_topology = opts.t
local default_weak_skips = opts.w
if #opts._ < 1 then
  print("Error: shiro-mkpm requires an input phoneme set.")
  return
end
local input_list = opts._[1]

local phonemes = {}
local attrs = {}

local fh = io.open(input_list, "r")
if fh == nil then
  print("Error: cannot open " .. input_list)
  return
end
while true do
  local line = fh:read()
  if line == nil or line == "" then
    break
  end
  line = string.delimit(line, " ")
  line_attr = {}
  for i = 2, #line, 2 do
    line_attr[line[i]] = line[i + 1]
  end
  phonemes[#phonemes + 1] = line[1]
  attrs[#phonemes] = line_attr
end
io.close(fh)

local function round3(x)
  return math.round(x * 1000) / 1000
end

local stcount = 0
local output = {}
output.phone_map = {}
for i = 1, #phonemes do
  local states = {}
  for j = 1, state_per_phoneme do
    states[j] = {dur = stcount, out = {}}
    for k = 1, num_stream do
      states[j].out[k] = stcount
    end
    stcount = stcount + 1
  end
  local dst = {states = states}
  if default_topology ~= nil then
    dst.topology = default_topology
  end
  if default_weak_skips ~= nil then
    dst.pskip = 0.02
  end
  for k, v in pairs(attrs[i]) do
    if k == "durfloor" then
      dst.durfloor = {}
      for j = 1, state_per_phoneme do
        dst.durfloor[j] = round3(tonumber(v) / state_per_phoneme)
      end
    end
    if k == "durceil" then
      dst.durceil = {}
      for j = 1, state_per_phoneme do
        dst.durceil[j] = round3(tonumber(v) / state_per_phoneme)
      end
    end
  end
  output.phone_map[phonemes[i]] = dst
end
print(json.encode(output, {indent = true, keyorder = phonemes}))
