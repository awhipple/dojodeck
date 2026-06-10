-- main.lua — dojodeck Steam artwork generator.
-- Renders each Steam library asset to an offscreen canvas and writes a PNG, then
-- quits. Usage: love art [--out DIR]   (DIR default "."; written via io, absolute ok)
-- Assets: capsule 600x900 (library tile), hero 1920x620 (banner), icon 256x256.

local outdir = "."
do
  local a = arg or {}
  for i = 1, #a do if a[i] == "--out" then outdir = a[i + 1] or outdir end end
end

-- palette (matches the hub + bouncer)
local ACCENT = { 0.28, 0.80, 0.93 }
local BG_TOP = { 0.10, 0.13, 0.20 }
local BG_BOT = { 0.04, 0.05, 0.08 }
local BALLS = {
  { 0.30, 0.80, 0.90 }, { 0.96, 0.55, 0.45 }, { 0.60, 0.86, 0.50 },
  { 0.82, 0.58, 0.92 }, { 0.96, 0.84, 0.42 },
}

local function lerp(a, b, t) return a + (b - a) * t end

local function gradient(w, h)
  for y = 0, h, 2 do
    local t = y / h
    love.graphics.setColor(lerp(BG_TOP[1], BG_BOT[1], t),
                           lerp(BG_TOP[2], BG_BOT[2], t),
                           lerp(BG_TOP[3], BG_BOT[3], t))
    love.graphics.rectangle("fill", 0, y, w, 3)
  end
end

-- soft radial glow (stacked translucent circles)
local function glow(cx, cy, r, col, a)
  for i = 10, 1, -1 do
    love.graphics.setColor(col[1], col[2], col[3], a * (i / 10) * 0.10)
    love.graphics.circle("fill", cx, cy, r * (i / 10))
  end
end

local function diamond(cx, cy, r, col, round)
  love.graphics.push()
  love.graphics.translate(cx, cy)
  love.graphics.rotate(math.pi / 4)
  love.graphics.setColor(col)
  love.graphics.rectangle("fill", -r, -r, r * 2, r * 2, round or r * 0.18, round or r * 0.18)
  love.graphics.pop()
end

-- the logo mark: glowing diamond with a "play" triangle cut into it
local function logo(cx, cy, r)
  glow(cx, cy, r * 2.6, ACCENT, 1)
  diamond(cx, cy, r * 1.18, { ACCENT[1], ACCENT[2], ACCENT[3], 0.25 })
  diamond(cx, cy, r, ACCENT)
  -- play triangle (optical-centered slightly right)
  local s = r * 0.5
  love.graphics.setColor(BG_BOT[1], BG_BOT[2], BG_BOT[3])
  love.graphics.polygon("fill",
    cx - s * 0.7, cy - s,
    cx - s * 0.7, cy + s,
    cx + s,       cy)
end

-- scattered decorative balls (deterministic positions from a seed list)
local function decoBalls(w, h, scale)
  local pts = {
    { 0.12, 0.16, 0.9, 1 }, { 0.86, 0.22, 1.3, 2 }, { 0.20, 0.82, 1.1, 3 },
    { 0.80, 0.78, 0.8, 4 }, { 0.50, 0.10, 0.7, 5 }, { 0.92, 0.55, 0.6, 1 },
    { 0.08, 0.50, 0.7, 3 }, { 0.65, 0.90, 0.9, 2 },
  }
  for _, p in ipairs(pts) do
    local c = BALLS[p[4]]
    love.graphics.setColor(c[1], c[2], c[3], 0.16)
    love.graphics.circle("fill", p[1] * w, p[2] * h, p[3] * 34 * scale)
    love.graphics.setColor(c[1], c[2], c[3], 0.30)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", p[1] * w, p[2] * h, p[3] * 34 * scale)
  end
end

local function centeredText(text, font, cx, y, col)
  love.graphics.setFont(font)
  love.graphics.setColor(col)
  love.graphics.printf(text, cx - 1000, y, 2000, "center")
end

-- render one asset onto a fresh canvas, return ImageData
local function renderAsset(w, h, kind)
  local canvas = love.graphics.newCanvas(w, h)
  love.graphics.setCanvas(canvas)
  love.graphics.push("all")
  love.graphics.origin()

  gradient(w, h)
  decoBalls(w, h, math.min(w, h) / 600)

  if kind == "icon" then
    logo(w / 2, h / 2, w * 0.30)
  elseif kind == "hero" then
    local cx = w / 2
    logo(cx, h * 0.40, h * 0.20)
    centeredText("dojodeck", love.graphics.newFont(h * 0.16), cx, h * 0.60, { 0.96, 0.97, 1 })
    centeredText("your games · one tap", love.graphics.newFont(h * 0.052), cx, h * 0.82, { 0.55, 0.62, 0.74 })
  else -- capsule (portrait)
    local cx = w / 2
    logo(cx, h * 0.34, w * 0.22)
    centeredText("dojodeck", love.graphics.newFont(w * 0.155), cx, h * 0.52, { 0.96, 0.97, 1 })
    centeredText("your games · one tap", love.graphics.newFont(w * 0.052), cx, h * 0.62, { 0.55, 0.62, 0.74 })
    -- bottom accent rule
    love.graphics.setColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.8)
    love.graphics.rectangle("fill", w * 0.32, h * 0.70, w * 0.36, 4, 2, 2)
  end

  love.graphics.pop()
  love.graphics.setCanvas()
  return canvas:newImageData()
end

local function save(imageData, path)
  local fd = imageData:encode("png")
  local f = assert(io.open(path, "wb"))
  f:write(fd:getString())
  f:close()
  print("[art] " .. path)
end

function love.load()
  save(renderAsset(600, 900, "capsule"), outdir .. "/capsule.png")
  save(renderAsset(1920, 620, "hero"),   outdir .. "/hero.png")
  save(renderAsset(256, 256, "icon"),    outdir .. "/icon.png")
  love.event.quit()
end

function love.draw() end
