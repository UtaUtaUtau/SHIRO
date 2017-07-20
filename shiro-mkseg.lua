--[[
  SHIRO
  ===
  Copyright (c) 2017 Kanru Hua. All rights reserved.

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

local mypath = arg[0]:match("(.-)[^\\/]+$")

json = require(mypath .. "external/dkjson")
getopt = require(mypath .. "external/getopt")
shiro_cli = require(mypath .. "cli-common")
require(mypath .. "external/misc")

opts = getopt(arg, "mdetnLR")

if opts.h then
  print("Usage:")
  print("shiro-mkseg.lua path-to-index-file\n" ..
        "  -m path-to-phonemap -d feature-directory -e feature-extension\n" ..
        "  -n frame-size -L pad-phoneme-left -R pad-phoneme-right")
  return
end

local input_index = opts._[1]
local input_phonemap = opts.m

local file_list = {}
local phonemap = {}
local ext = opts.e or ".f"
local ndim = opts.n or 36
local lpad = {}
local rpad = {}
if opts.L ~= nil then
  lpad = string.delimit(opts.L, ",")
end
if opts.R ~= nil then
  rpad = string.delimit(opts.R, ",")
end

if input_phonemap == nil then
  print("Error: shiro-mkseg requires an input phoneme map.")
  return
end

if #opts._ < 1 then
  print("Error: shiro-mkseg requires an input index file.")
  return
end

-- read and parse index file
file_list = shiro_cli.load_index_file(input_index,
  (opts.d or ".") .. "/", lpad, rpad)
if file_list == false then return end

fh = io.open(input_phonemap, "r")
if fh == nil then
  print("Error: cannot open " .. input_phonemap)
  return
end
pm = json.decode(fh:read("*a"))
io.close(fh)
if shiro_cli.checkpm(pm) == false then return end

-- generate segmentation

local seg = {file_list = {}}
for i = 1, #file_list do
  local feature_path = file_list[i].path .. ext
  fh = io.open(feature_path)
  if fh == nil then
    print("Error: cannot open " .. feature_path)
    return
  end
  local feature_size = fh:seek("end") / 4
  local nfrm = feature_size / ndim
  if nfrm ~= math.floor(nfrm) then
    print("Error: size of " .. feature_path .. " does not match the frame size.")
    return
  end
  local states = {}
  for j = 1, #file_list[i].phonemes do
    local p = file_list[i].phonemes[j]
    local pst = pm.phone_map[p]
    if pst == nil then
      print("Error: phoneme " .. p .. " is not defined in the phone map.")
      return
    end
    for k = 1, #pst.states do
      states[#states + 1] = {
        time = #states + 1,       -- state boundary
        dur = pst.states[k].dur,  -- duration state
        out = pst.states[k].out,  -- output state for each stream
        ext = {p, k - 1}          -- extra information
      }
    end
  end
  local flatdur = nfrm / #states
  for k = 1, #states do
    states[k].time = math.round(states[k].time * flatdur)
  end
  seg.file_list[i] = {filename = feature_path, states = states}
  io.close(fh)
end

print(json.encode(seg, {indent = true,
  keyorder = {"filename", "states", "time", "dur", "out", "ext"}}))
