-------------------------------------------------
-- Spotify Widget for Awesome Window Manager
-- Shows currently playing song on Spotify for Linux client
-- More details could be found here:
-- https://github.com/streetturtle/awesome-wm-widgets/tree/master/spotify-widget

-- @author Pavel Makhov
-- @copyright 2020 Pavel Makhov
-------------------------------------------------

local awful = require("awful")
local wibox = require("wibox")
local watch = require("awful.widget.watch")
local naughty = require("naughty")

local function ellipsize(text, length)
    return (text:len() > length and length > 0)
        and text:sub(0, length - 3) .. '...'
        or text
end

local function spotify_cmd(cmd)
  awful.spawn("dbus-send --type=method_call --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player." .. cmd)
end

local spotify_widget = {}

local function worker(args)

    local args = args or {}

    local play_icon = args.play_icon or '/usr/share/icons/Arc/actions/24/player_play.png'
    local pause_icon = args.pause_icon or '/usr/share/icons/Arc/actions/24/player_pause.png'
    local font = args.font or 'Play 9'
    local dim_when_paused = args.dim_when_paused == nil and false or args.dim_when_paused
    local dim_opacity = args.dim_opacity or 0.2
    local max_length = args.max_length or 15
    local show_tooltip = args.show_tooltip == nil and false or args.show_tooltip

    local cur_status = false
    local cur_artist = ''
    local cur_title = ''
    local cur_album = ''

    spotify_widget = wibox.widget {
        {
            id = 'artistw',
            font = font,
            widget = wibox.widget.textbox,
        },
        {
            id = "icon",
            widget = wibox.widget.imagebox,
        },
        {
            id = 'titlew',
            font = font,
            widget = wibox.widget.textbox,
        },
        layout = wibox.layout.align.horizontal,
        visible = false,
        set_status = function(self, is_playing)
            self.icon.image = (is_playing and play_icon or pause_icon)
            if dim_when_paused then
                self.icon.opacity = (is_playing and 1 or dim_opacity)

                self.titlew:set_opacity(is_playing and 1 or dim_opacity)
                self.titlew:emit_signal('widget::redraw_needed')

                self.artistw:set_opacity(is_playing and 1 or dim_opacity)
                self.artistw:emit_signal('widget::redraw_needed')
            end
        end,
        set_text = function(self, artist, song)
            local artist_to_display = ellipsize(artist, max_length)
            if self.artistw.text ~= artist_to_display then
                self.artistw.text = artist_to_display
            end
            local title_to_display = ellipsize(song, max_length)
            if self.titlew.text ~= title_to_display then
                self.titlew.text = title_to_display
            end
        end
    }

    local update_widget_icon = function(widget, status)
        cur_status = status == 'Playing' and true or false
        widget:set_status(cur_status)
        widget:set_visible(true)
    end

    local update_widget_text = function(widget, metadata)
        cur_artist = metadata['xesam:albumArtist']
        cur_title = metadata['xesam:title']
        cur_album = metadata['xesam:album']

        widget:set_text(cur_artist, cur_title)
        widget:set_visible(true)
    end

    dbus.add_match('session', "path='/org/mpris/MediaPlayer2',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'")
    dbus.connect_signal('org.freedesktop.DBus.Properties', function(metadata, name, payload)
      if name ~= 'org.mpris.MediaPlayer2.Player' then
        return
      end

      if payload.PlaybackStatus then
        update_widget_icon(spotify_widget, payload.PlaybackStatus)
      end

      if payload.Metadata then
        current_metadata = {}
        for k, v in pairs(payload.Metadata) do
          if type(v) == 'table' then
            v = table.concat(v, ' & ')
          end
          current_metadata[k] = v
        end

      --local mute, level = string.match(stdout, "(%d+)\n(%d+)")
        if current_metadata['mpris:trackid'] and string.find(current_metadata['mpris:trackid'], "^spotify:") then
          update_widget_text(spotify_widget, current_metadata)
        end
      end
    end)

    --- Adds mouse controls to the widget:
    --  - left click - play/pause
    --  - scroll up - play next song
    --  - scroll down - play previous song
    spotify_widget:connect_signal("button::press", function(_, _, _, button)
        if (button == 1) then
            spotify_cmd("PlayPause")      -- left click
        elseif (button == 4) then
            spotify_cmd("Next")           -- scroll up
        elseif (button == 5) then
            spotify_cmd("Previous")       -- scroll down
        end
    end)


    if show_tooltip then
        local spotify_tooltip = awful.tooltip {
            mode = 'outside',
            preferred_positions = {'bottom'},
         }

        spotify_tooltip:add_to_object(spotify_widget)

        spotify_widget:connect_signal('mouse::enter', function()
            spotify_tooltip.markup = '<b>Album</b>: ' .. cur_album
                .. '\n<b>Artist</b>: ' .. cur_artist
                .. '\n<b>Song</b>: ' .. cur_title
        end)
    end

    awesome.connect_signal('exit', function(restarting)
      if not restarting then return end
      local out =
        (cur_status and '1' or '0') .. '\n' ..
        cur_album .. '\n' ..
        cur_artist .. '\n' ..
        cur_title .. '\n'
      local file = io.open('/tmp/awesome-spotify-widget.txt', 'w')
      file:write(out)
      file:close()
    end)

    local file = io.open('/tmp/awesome-spotify-widget.txt', 'r');
    if file then
      cur_status = file:read() == '1' and true or false
      cur_album = file:read()
      cur_artist = file:read()
      cur_title = file:read()
      spotify_widget:set_status(cur_status)
      spotify_widget:set_text(cur_artist, cur_title)
      spotify_widget:set_visible(true)
    end
    os.remove('/tmp/awesome-spotify-widget.txt')

    return spotify_widget

end

return setmetatable(spotify_widget, { __call = function(_, ...)
    return worker(...)
end })
