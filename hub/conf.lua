-- conf.lua — the dojodeck hub (the single Steam entry on the Deck).
function love.conf(t)
  t.identity = "dojodeck"
  t.version  = "11.5"
  t.window.title  = "dojodeck"
  t.window.width  = 1280       -- Deck native
  t.window.height = 800
  t.window.resizable = true
  t.window.vsync  = 1
  t.modules.joystick = true    -- gamepad-first (it's a Deck menu)
  t.modules.physics  = false
  t.console = false
end
