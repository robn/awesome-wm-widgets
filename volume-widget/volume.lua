-------------------------------------------------
-- Volume Widget for Awesome Window Manager
-- Shows the current volume level
-- More details could be found here:
-- https://github.com/streetturtle/awesome-wm-widgets/tree/master/volume-widget

-- @author Pavel Makhov, Aurélien Lajoie
-- @copyright 2018 Pavel Makhov
-------------------------------------------------

local wibox = require("wibox")
local watch = require("awful.widget.watch")
local spawn = require("awful.spawn")
local naughty = require("naughty")
local gfs = require("gears.filesystem")
local dpi = require('beautiful').xresources.apply_dpi

local PATH_TO_ICONS = "/usr/share/icons/Arc/status/symbolic/"

local volume = {display_notification = false, notification = nil, delta = 5}

function volume:toggle()
  volume:_pulsemixer("--toggle-mute")
end

function volume:raise()
  volume:_pulsemixer('--change-volume +' .. tostring(volume.delta))
end
function volume:lower()
  volume:_pulsemixer('--change-volume -' .. tostring(volume.delta))
end

function volume:update()
  volume:_pulsemixer()
end

local calling = false
function volume:_pulsemixer(cmd)
  if not cmd and calling then return end
  calling = true
  cmd = cmd or ''
  spawn.easy_async(
    'pulsemixer ' .. cmd .. ' --get-mute --get-volume',
    function (stdout, _, _, _)
      local mute, level = string.match(stdout, "(%d+)\n(%d+)")
      mute = tonumber(mute) == 1
      level = tonumber(level)

      if volume.mute ~= nil and volume.level ~= nil and
         volume.mute == mute and volume.level == level then
        calling = false
        return
      end

      volume.mute = mute
      volume.level = level

      volume.opacity = volume.mute and 0.2 or 1.0

      volume.icon_name =
        (volume.level < 25 and "audio-volume-muted-symbolic") or
        (volume.level < 50 and "audio-volume-low-symbolic") or
        (volume.level < 75 and "audio-volume-medium-symbolic") or
                              "audio-volume-high-symbolic"

      volume._update_icon()
      volume._update_notification()

      calling = false
    end
  )
end

function volume:_update_icon()
  volume.widget.image = volume.path_to_icons .. volume.icon_name .. ".svg"
  volume.widget:set_opacity(volume.opacity)
end

function volume:_update_notification()
  if volume.display_notification then
    local text = volume.level .. '%'
    local image = volume.path_to_icons .. volume.icon_name .. ".svg"

    if not volume.notification then
      volume.notification = naughty.notify {
        text = text,
        icon = image,
        icon_size = dpi(16),
        title = "Volume",
        timeout = 2,
        hover_timeout = 0.5,
        width = 200,
        screen = mouse.screen,
        destroy = function ()
          volume.notification = nil
        end
      }
    else
      volume.notification.iconbox.image = image
      naughty.replace_text(volume.notification, "Volume", text)
    end

    volume.notification.iconbox:set_opacity(volume.opacity)
  end
end

local function worker(args)
  local args = args or {}
  volume.display_notification = args.display_notification or false
  volume.position = args.notification_position or "top_right"
  volume.delta = args.delta or 5
  volume.path_to_icons = args.path_to_icons or PATH_TO_ICONS

  -- Check for icon path
  if not gfs.dir_readable(volume.path_to_icons) then
    naughty.notify {
      title = "Volume Widget",
      text = "Folder with icons doesn't exist: " .. volume.path_to_icons,
      preset = naughty.config.presets.critical
    }
    return
  end

  volume.widget = wibox.widget {
    {
      id = "icon",
      image = volume.path_to_icons .. "audio-volume-muted-symbolic.svg",
      resize = false,
      widget = wibox.widget.imagebox,
    },
    layout = wibox.container.margin(_, _, _, 3),
    set_image = function(self, path)
      self.icon.image = path
    end
  }

  -- mouse handler, click to toggle mute, scroll to adjust
  volume.widget:connect_signal("button::press", function(_,_,_,button)
    if (button == 4)     then volume.raise()
    elseif (button == 5) then volume.lower()
    elseif (button == 1) then volume.toggle()
    end
  end)

  -- show notification on hover
  if volume.display_notification then
    volume.widget:connect_signal("mouse::enter", function()
      if not volume.notification then
        volume._update_notification()
      end
    end)
    volume.widget:connect_signal("mouse::leave", function() naughty.destroy(volume.notification) end)
  end

  -- setup monitor
  spawn.with_line_callback('pipesig pactl subscribe', {
    stdout = function(line)
      if line == "Event 'change' on sink #0" then
        volume.update()
      end
    end,
  })

  -- set initial icon
  volume.update()

  return volume.widget
end

return setmetatable(volume, { __call = function(_, ...) return worker(...) end })
