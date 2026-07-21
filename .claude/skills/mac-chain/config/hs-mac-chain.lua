-- mac-chain 感知层 (2026-07-22) — 独立模块, 由 init.lua 首行 dofile
local CHAIN_RUN = os.getenv("HOME") .. "/.myagents/projects/mino/.claude/skills/mac-chain/scripts/mac-chain-run.sh"
local function runChain(name)
  hs.task.new("/bin/bash", nil, {CHAIN_RUN, "--chain", name}):start()
end
hs.hotkey.bind({"ctrl","alt","cmd"}, "C", function() runChain("clipboard-alchemy") end)
local dlTimer = nil
hs.pathwatcher.new(os.getenv("HOME").."/Downloads/", function()
  if dlTimer then dlTimer:stop() end
  dlTimer = hs.timer.doAfter(30, function() runChain("file-flow"); runChain("qr-action") end)
end):start()
local dtTimer = nil
hs.pathwatcher.new(os.getenv("HOME").."/Desktop/", function()
  if dtTimer then dtTimer:stop() end
  dtTimer = hs.timer.doAfter(15, function() runChain("screenshot-vault") end)
end):start()
local vmTimer = nil
hs.pathwatcher.new(os.getenv("HOME").."/Documents/语音速记/", function()
  if vmTimer then vmTimer:stop() end
  vmTimer = hs.timer.doAfter(10, function() runChain("voice-memo-scribe") end)
end):start()
io.open("/tmp/macchain-mounted.log","w"):write(os.date().." mounted\n"):close()
