-- ═══ 10. mac-chain 感知层 (2026-07-22) ═══
local CHAIN_RUN = os.getenv("HOME") .. "/.myagents/projects/mino/.claude/skills/mac-chain/scripts/mac-chain-run.sh"
local function runChain(name)
  hs.task.new("/bin/bash", nil, {CHAIN_RUN, "--chain", name}):start()
end

-- 链 K: 剪贴板炼金 ⌃⌥⌘C
hs.hotkey.bind({"ctrl","alt","cmd"}, "C", function() runChain("clipboard-alchemy") end)

-- 链 A+J: Downloads 新文件 (防抖 30s) → 文件流转 + QR 行动
local dlTimer = nil
hs.pathwatcher.new(os.getenv("HOME").."/Downloads/", function()
  if dlTimer then dlTimer:stop() end
  dlTimer = hs.timer.doAfter(30, function()
    runChain("file-flow")
    runChain("qr-action")
  end)
end):start()

-- 链 G: Desktop 新截图 (防抖 15s)
local dtTimer = nil
hs.pathwatcher.new(os.getenv("HOME").."/Desktop/", function()
  if dtTimer then dtTimer:stop() end
  dtTimer = hs.timer.doAfter(15, function() runChain("screenshot-vault") end)
end):start()

-- 链 H: 语音速记目录
local voiceDir = os.getenv("HOME").."/Documents/语音速记"
os.execute("mkdir -p '" .. voiceDir .. "'")
hs.pathwatcher.new(voiceDir.."/", function()
  hs.timer.doAfter(10, function() runChain("voice-memo-scribe") end)
end):start()

hs.notify.show("Hammerspoon", "mac-chain 感知层已挂载", "⌃⌥⌘C + 3 watchers")
