-- conf.lua — dojodeck art generator (renders Steam library assets to PNG, offscreen).
function love.conf(t)
  t.window.width  = 320
  t.window.height = 200
  t.window.title  = "dojodeck-art"
  t.window.resizable = false
  t.modules.joystick = false
  t.console = false
end
