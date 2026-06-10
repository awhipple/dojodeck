-- main.lua — the dojodeck HUB. The single thing Aaron adds to Steam.
-- It's a controller-navigable menu of games. The host wrapper (../dojodeck) does the
-- one-time launch sync (self-update + pull every game), writes a list file, runs this
-- hub, reads back the choice, and launches the picked game — then loops back here.
--   in : --list FILE   tab-separated rows "slug<TAB>path<TAB>subtitle"
--   out: --out  FILE   one line: "PLAY<TAB>slug<TAB>path" | "QUIT"
--
-- Re-sync (Y) pulls ONLY the highlighted game, in-process and asynchronously (a
-- love.thread runs git), so the menu stays on screen with a spinner instead of
-- blacking out. Launching is disabled while a pull is in progress.
-- Self-test: --shot N --shotout PATH captures a frame and exits (run natively).
--            --demo-pull forces the spinner overlay on (for that screenshot).

local VW, VH = 1280, 800
local canvas

local opt = { list = nil, out = nil, shot = nil, shotout = "/tmp/dojodeck-shot.png",
              select = 1, ver = nil, demopull = false }

local items = {}        -- { {slug=, path=, sub=}, ... }
local selected = 1
local result = "QUIT"   -- what we tell the wrapper if the window is just closed
local frame = 0
local captured = false

-- in-process per-game pull state
local pull = { active = false, t = 0, status = nil, thread = nil, index = nil, demo = false }

-- thread body: pull one repo, then read back its short commit line. Args via ...
local PULL_SRC = [[
  local path = ...
  local function sh(cmd)
    local p = io.popen(cmd .. " 2>&1")
    local out = p and p:read("*a") or ""
    if p then p:close() end
    return out
  end
  sh("git -C '" .. path .. "' pull --ff-only")
  local sub = sh("git -C '" .. path .. "' log -1 --format='%h  %cr'")
  sub = (sub or ""):gsub("%s+$", "")
  love.thread.getChannel("pull_result"):push(sub)
]]

-- palette
local C = {
  bg     = { 0.07, 0.08, 0.11 },
  panel  = { 0.11, 0.13, 0.18 },
  sel    = { 0.20, 0.55, 0.85 },
  selbg  = { 0.16, 0.22, 0.32 },
  text   = { 0.92, 0.94, 0.98 },
  dim    = { 0.55, 0.60, 0.70 },
  accent = { 0.30, 0.80, 0.90 },
}

local font = {}

local function parseArgs()
  local a = arg or {}
  local i, n = 1, #a
  while i <= n do
    local t = tostring(a[i])
    if     t == "--list"      then i = i + 1; opt.list = a[i]
    elseif t == "--out"       then i = i + 1; opt.out = a[i]
    elseif t == "--shot"      then i = i + 1; opt.shot = tonumber(a[i])
    elseif t == "--shotout"   then i = i + 1; opt.shotout = a[i]
    elseif t == "--select"    then i = i + 1; opt.select = tonumber(a[i]) or 1
    elseif t == "--version"   then i = i + 1; opt.ver = a[i]
    elseif t == "--demo-pull" then opt.demopull = true
    end
    i = i + 1
  end
end

local function loadItems()
  if opt.list then
    local f = io.open(opt.list, "r")
    if f then
      for line in f:lines() do
        local slug, path, sub = line:match("^([^\t]*)\t([^\t]*)\t?(.*)$")
        if slug and slug ~= "" then
          items[#items + 1] = { slug = slug, path = path, sub = sub or "" }
        end
      end
      f:close()
    end
  end
  -- demo fallback so the hub renders standalone (e.g. for a screenshot)
  if #items == 0 and not opt.list then
    items = {
      { slug = "asteroids",  path = "/home/deck/dojodeck/games/asteroids",  sub = "a1b2c3d  2 hours ago" },
      { slug = "platformer", path = "/home/deck/dojodeck/games/platformer", sub = "9f8e7d6  yesterday" },
      { slug = "_smoke",     path = "/home/deck/dojodeck/games/_smoke",     sub = "0011223  just now" },
    }
    opt.ver = opt.ver or "edb6600  5 minutes ago"
  end
  selected = math.max(1, math.min(opt.select, math.max(1, #items)))
end

local function writeResult()
  if not opt.out then return end
  local f = io.open(opt.out, "w")
  if not f then return end
  if result == "PLAY" and items[selected] then
    f:write(("PLAY\t%s\t%s\n"):format(items[selected].slug, items[selected].path))
  else
    f:write(result .. "\n")
  end
  f:close()
end

-- input -------------------------------------------------------------------
local function move(d)
  if #items == 0 then return end
  selected = ((selected - 1 + d) % #items) + 1
end

local function choosePlay()
  if pull.active then return end                 -- no launching while a pull runs
  if #items > 0 then result = "PLAY"; writeResult(); love.event.quit() end
end
local function chooseQuit() result = "QUIT"; writeResult(); love.event.quit() end

-- kick off an async pull of the highlighted game only
local function startPull()
  if pull.active or #items == 0 then return end
  local it = items[selected]
  if not it or not it.path or it.path == "" then return end
  while love.thread.getChannel("pull_result"):pop() do end   -- drain stale
  pull.thread = love.thread.newThread(PULL_SRC)
  pull.thread:start(it.path)
  pull.active = true
  pull.index  = selected
  pull.t      = 0
  pull.status = "Updating  " .. it.slug .. "…"
end

function love.keypressed(key)
  if     key == "up"     or key == "w" then move(-1)
  elseif key == "down"   or key == "s" then move(1)
  elseif key == "return" or key == "space" then choosePlay()
  elseif key == "r"      then startPull()
  elseif key == "escape" or key == "q" then chooseQuit()
  end
end

function love.gamepadpressed(_, button)
  if     button == "dpup"   then move(-1)
  elseif button == "dpdown" then move(1)
  elseif button == "a" or button == "start" then choosePlay()
  elseif button == "y" then startPull()
  elseif button == "b" or button == "back" then chooseQuit()
  end
end

-- analog stick (poll, debounced) -----------------------------------------
local stickCd = 0
local function pollStick(dt)
  stickCd = math.max(0, stickCd - dt)
  if not love.joystick then return end
  local js = love.joystick.getJoysticks()[1]
  if not (js and js:isGamepad()) then return end
  local y = js:getGamepadAxis("lefty")
  if math.abs(y) > 0.6 and stickCd == 0 then
    move(y > 0 and 1 or -1); stickCd = 0.18
  elseif math.abs(y) < 0.3 then stickCd = 0 end
end

-- lifecycle ---------------------------------------------------------------
function love.load()
  parseArgs()
  canvas = love.graphics.newCanvas(VW, VH)
  font.title = love.graphics.newFont(40)
  font.row   = love.graphics.newFont(30)
  font.sub   = love.graphics.newFont(18)
  font.hint  = love.graphics.newFont(20)
  loadItems()
  if opt.demopull and #items > 0 then          -- screenshot aid: force the spinner on
    pull.active = true; pull.demo = true; pull.index = selected
  end
end

function love.update(dt)
  pollStick(dt)
  if pull.active then
    pull.t = pull.t + dt
    if not pull.demo then
      local res = love.thread.getChannel("pull_result"):pop()
      if res ~= nil then
        if pull.index and items[pull.index] and res ~= "" then
          items[pull.index].sub = res
        end
        pull.active = false
        pull.thread = nil
      end
    end
  end
  if opt.shot then
    frame = frame + 1
    if frame >= opt.shot and captured then love.event.quit() end
  end
end

-- a small rounded "button" pill with a centered label (default font is glyph-safe)
local function pill(x, y, label)
  local w = font.hint:getWidth(label) + 26
  local h = 36
  love.graphics.setColor(C.selbg); love.graphics.rectangle("fill", x, y, w, h, 9, 9)
  love.graphics.setColor(C.sel);   love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 9, 9)
  love.graphics.setFont(font.hint); love.graphics.setColor(C.text)
  love.graphics.printf(label, x, y + 7, w, "center")
  return w
end

-- pill with stacked up/down triangles (for "select")
local function selectPill(x, y)
  local w, h = 44, 36
  love.graphics.setColor(C.selbg); love.graphics.rectangle("fill", x, y, w, h, 9, 9)
  love.graphics.setColor(C.sel);   love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h, 9, 9)
  local cx = x + w / 2
  love.graphics.setColor(C.text)
  love.graphics.polygon("fill", cx, y + 8,  cx - 7, y + 15, cx + 7, y + 15)   -- up
  love.graphics.polygon("fill", cx, y + 28, cx - 7, y + 21, cx + 7, y + 21)   -- down
  return w
end

local function drawScene()
  love.graphics.clear(C.bg)

  -- header: drawn diamond mark + wordmark
  love.graphics.push(); love.graphics.translate(76, 72); love.graphics.rotate(math.pi / 4)
  love.graphics.setColor(C.accent); love.graphics.rectangle("fill", -16, -16, 32, 32, 5, 5)
  love.graphics.pop()
  love.graphics.setFont(font.title)
  love.graphics.setColor(C.text); love.graphics.print("dojodeck", 120, 48)
  love.graphics.setFont(font.sub)
  love.graphics.setColor(C.dim)
  local count = ("%d game%s synced"):format(#items, #items == 1 and "" or "s")
  love.graphics.printf(count, VW - 460, 64, 400, "right")

  -- list
  local x, y0, rowH, w = 56, 150, 92, VW - 112
  if #items == 0 then
    love.graphics.setFont(font.row); love.graphics.setColor(C.dim)
    love.graphics.printf("no games yet — press  Y  to sync", x, 330, w, "center")
  end
  for i, it in ipairs(items) do
    local y = y0 + (i - 1) * rowH
    if i == selected then
      love.graphics.setColor(C.selbg)
      love.graphics.rectangle("fill", x, y, w, rowH - 14, 12, 12)
      love.graphics.setColor(C.sel)
      love.graphics.rectangle("fill", x, y, 8, rowH - 14, 4, 4)
    else
      love.graphics.setColor(C.panel)
      love.graphics.rectangle("fill", x, y, w, rowH - 14, 12, 12)
    end
    love.graphics.setFont(font.row)
    love.graphics.setColor(i == selected and C.text or C.dim)
    love.graphics.print(it.slug, x + 36, y + 14)
    -- pulling marker on the row being updated: a small inline spinner + label,
    -- right where the commit line normally sits (no separate modal).
    if pull.active and pull.index == i then
      local cy = y + (rowH - 14) / 2
      local cx = x + w - 46
      love.graphics.setFont(font.sub); love.graphics.setColor(C.accent)
      local label = "updating"
      love.graphics.print(label, cx - 22 - font.sub:getWidth(label), cy - 10)
      local a = pull.t * 6
      love.graphics.setLineWidth(4)
      love.graphics.setColor(C.dim[1], C.dim[2], C.dim[3], 0.35)
      love.graphics.circle("line", cx, cy, 13)
      love.graphics.setColor(C.accent)
      love.graphics.arc("line", "open", cx, cy, 13, a, a + math.pi * 1.25)
    elseif it.sub ~= "" then
      love.graphics.setFont(font.sub)
      love.graphics.setColor(C.dim)
      love.graphics.printf(it.sub, x, y + 24, w - 36, "right")
    end
  end

  -- footer hints: button pills + labels
  local fy = VH - 60
  local fx = 56
  local function hint(drawPillFn, label)
    local w = drawPillFn(fx, fy)
    love.graphics.setFont(font.hint); love.graphics.setColor(C.dim)
    love.graphics.print(label, fx + w + 10, fy + 7)
    fx = fx + w + 10 + font.hint:getWidth(label) + 40
  end
  hint(function(x, y) return pill(x, y, "A") end, "play")
  hint(selectPill, "select")
  hint(function(x, y) return pill(x, y, "Y") end, "re-sync this")
  hint(function(x, y) return pill(x, y, "B") end, "quit")

  -- dojodeck's own version, tucked in the corner (same info games show)
  if opt.ver and opt.ver ~= "" then
    love.graphics.setFont(font.sub)
    love.graphics.setColor(C.dim[1], C.dim[2], C.dim[3], 0.55)
    love.graphics.printf("dojodeck " .. opt.ver, VW - 620, VH - 50, 600, "right")
  end
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.push("all"); love.graphics.origin()
  drawScene()
  love.graphics.pop(); love.graphics.setCanvas()

  local ww, wh = love.graphics.getDimensions()
  local s = math.min(ww / VW, wh / VH)
  love.graphics.setColor(1, 1, 1)
  love.graphics.draw(canvas, (ww - VW * s) / 2, (wh - VH * s) / 2, 0, s, s)

  if opt.shot and frame >= opt.shot and not captured then
    captured = true
    local fd = canvas:newImageData():encode("png")
    local f = io.open(opt.shotout, "wb")
    if f then f:write(fd:getString()); f:close() end
    print("[dojo-shot] " .. opt.shotout)
  end
end
