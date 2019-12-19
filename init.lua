local wibox = require( "wibox" )
local awful = require( "awful" )
local beautiful = require( "beautiful" )
local gears = require( "gears" )

widget = {}

function getTemplate ()
  local wrap = wibox.widget {
    {
      max_value = 1 ,
      forced_width = 60 ,
      background_color = beautiful.bg_minimize ,
      color = beautiful.bg_focus ,
      widget = wibox.widget.graph() ,
    } ,
    {
      widget = wibox.widget.textbox() ,
    } ,
    spacing = 1 ,
    layout = wibox.layout.stack
  }

  return wrap
end

-- cpu
function widget:cpu ( disp , sync )
  local old_use_time = {}
  local old_total_time = {}
  local new_use_time = {}
  local new_total_time = {}
  local label = { disp }

  local wrap = wibox.widget {
    spacing = 0,
    layout = wibox.layout.fixed.horizontal
  }

  local corenum = 1
  awful.spawn.with_line_callback( [[bash -c 'cat /proc/stat | grep "^cpu"']] , {
    stdout = function( out )
      old_use_time[ corenum ] = 0
      old_total_time[ corenum ] = 0
      if corenum == 1 then
        wrap:add( wibox.widget {
          {
            max_value = 1 ,
            forced_width = 60 ,
            background_color = beautiful.bg_minimize ,
            color = beautiful.bg_focus ,
            widget = wibox.widget.graph() ,
          } ,
          {
            widget = wibox.widget.textbox() ,
          } ,
          spacing = 1 ,
          layout = wibox.layout.stack
        } )
      else
        wrap:add( wibox.widget {
          {
            max_value = 1 ,
            background_color = beautiful.bg_minimize ,
            color = beautiful.bg_focus ,
            widget = wibox.widget.progressbar() ,
          } ,
          forced_width = 10 ,
          direction = 'east' ,
          layout = wibox.container.rotate,
        } )
        label[ corenum ] = ( corenum - 1 )
      end
      corenum = corenum + 1
    end
  } )

  local function update ()
    local corecnt = 1
    awful.spawn.with_line_callback( [[bash -c 'cat /proc/stat | grep "^cpu"']] , {
      stdout = function( out )

        local param = {}
        local cnt = 1
        for n in out:gmatch( "%s%d+" ) do
          param[ cnt ] = n
          cnt = cnt + 1
        end

        new_use_time[ corecnt ] = param[ 1 ] + param[ 2 ] + param[ 3 ]
        new_total_time[ corecnt ] = new_use_time[ corecnt ] + param[ 4 ]

        if old_use_time[ corecnt ] ~= 0 then
          local use   = new_use_time[ corecnt ]   - old_use_time[ corecnt ]
          local total = new_total_time[ corecnt ] - old_total_time[ corecnt ]
          local usage = math.floor( use / total * 100 )

          if corecnt == 1 then
            wrap.children[ corecnt ].children[ 1 ]:add_value( usage / 100 )
            wrap.children[ corecnt ].children[ 2 ]:set_text( label[ corecnt ] .. ":" .. string.format( "%3d" , usage )  .. "%" )
          else
            wrap.children[ corecnt ].children[ 1 ]:set_value( usage / 100 )
          end
        end

        old_use_time[ corecnt ] = new_use_time[ corecnt ]
        old_total_time[ corecnt ] = new_total_time[ corecnt ]
        corecnt = corecnt + 1
      end
    } )
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  return wrap
end

-- cpu temp
function widget:cputemp ( sync )
  local wrap = wibox.widget {
    spacing = 1 ,
    layout = wibox.layout.fixed.horizontal
  }

  awful.spawn.with_line_callback( [[bash -c "sensors | grep Core | awk '{ print $3 }'"]] , {
    stdout = function( out )
      local child = wibox.widget {
        {
          max_value = 1 ,
          forced_width = 40 ,
          background_color = beautiful.bg_minimize ,
          color = beautiful.bg_focus ,
          widget = wibox.widget.graph() ,
        } ,
        {
          widget = wibox.widget.textbox() ,
        } ,
        layout = wibox.layout.stack
      }
      wrap:add( child )
    end
  })

  function update()
    local cnt = 1
    awful.spawn.with_line_callback( [[bash -c "sensors | grep Core | awk '{ print $3 }'"]] , {
      stdout = function( out )
        local param = string.match( out , "%d+" )
        wrap.children[ cnt ].children[ 1 ]:add_value( param / 100 )
        wrap.children[ cnt ].children[ 2 ]:set_text( param .. "℃" )
        cnt = cnt + 1
      end
    })
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  return wrap
end

-- ram
function widget:ram ( disp , sync )
  local total = 0
  local free = 0
  local inactive = 0
  local wrap = wibox.widget {
    {
      max_value = 1 ,
      forced_width = 60 ,
      background_color = beautiful.bg_minimize ,
      color = beautiful.bg_focus ,
      widget = wibox.widget.progressbar()
    } ,
    {
      widget = wibox.widget.textbox() ,
    } ,
    spacing = 1 ,
    layout = wibox.layout.stack
  }

  local function update_cb()
    local usage = math.floor( ( ( total - free - inactive ) / total ) * 100 )
    wrap.children[ 1 ]:set_value( usage / 100 )
    wrap.children[ 2 ]:set_text( disp .. ":" .. string.format( "%3d" , usage ) .. "%" )
  end

  local function update ()
    free = 0
    inactive = 0
    awful.spawn.with_line_callback( [[bash -c "cat /proc/meminfo "]] , {
      stdout = function( out )
        if total == 0 and string.match( out , "^MemTotal:" ) then
          total = gears.string.split( out , "%s+" )[2]
        elseif string.match( out , "^MemFree:" ) then
          free = gears.string.split( out , "%s+" )[2]
        elseif string.match( out , "^Inactive:" ) then
          inactive = gears.string.split( out , "%s+" )[2]
        end
        if free ~= 0 and inactive ~= 0 then
          update_cb()
        end
      end,
    })
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  wrap:buttons(
    awful.util.table.join(
      awful.button( { } , 1 , function()
        awful.spawn.with_shell( "sudo systemctl start memory_refresh.service" )
      end )
    )
  )

  return wrap
end

-- swap
function widget:swap ( disp , sync )
  local total = 0
  local free = 0
  local wrap = wibox.widget {
    {
      max_value = 1 ,
      forced_width = 60 ,
      background_color = beautiful.bg_minimize ,
      color = beautiful.bg_focus ,
      widget = wibox.widget.progressbar()
    } ,
    {
      widget = wibox.widget.textbox() ,
    } ,
    spacing = 1 ,
    layout = wibox.layout.stack
  }

  local function update_cb()
    local usage = math.floor( ( ( total - free ) / total ) * 100 )
    wrap.children[ 1 ]:set_value( usage / 100 )
    wrap.children[ 2 ]:set_text( disp .. ":" .. string.format( "%3d" , usage ) .. "%" )
  end

  local function update ()
    free = 0
    awful.spawn.with_line_callback( [[bash -c "cat /proc/meminfo "]] , {
      stdout = function( out )
        if total == 0 and string.match( out , "^SwapTotal:" ) then
          total = gears.string.split( out , "%s+" )[2]
        elseif string.match( out , "^SwapFree:" ) then
          free = gears.string.split( out , "%s+" )[2]
        end
        if free ~= 0 then
          update_cb()
        end
      end,
    })
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  wrap:buttons(
    awful.util.table.join(
      awful.button( { } , 1 , function()
        awful.spawn.with_shell( "sudo systemctl start memory_refresh.service" )
      end )
    )
  )

  return wrap
end

-- battery
function widget:getStat( path , disp , sync )
  local graph_length = 100
  local wrap = wibox.widget {
    { widget = wibox.widget.textbox( disp .. ':' ) } ,
    { widget = wibox.widget.textbox() } ,
    {
      max_value = 1 ,
      forced_width = graph_length ,
      background_color = beautiful.bg_minimize ,
      color = beautiful.bg_focus ,
      widget = wibox.widget.graph()
    } ,
    spacing = 1 ,
    layout = wibox.layout.fixed.horizontal
  }

  local tmpfile = '/tmp/battery'
  local file = io.open( tmpfile )
  local data = file:read("*all")
  file:close()
  local ary = {} ;
  local i=1
  for s in string.gmatch(data, "([^,]+)") do
    ary[i] = s
    i = i + 1
  end

  for _,v in ipairs( ary ) do
    wrap.children[ 3 ]:add_value( v / 100 )
  end

  local function save_file( value )
    table.insert( ary , value )
    while #ary > graph_length do
      table.remove( ary , 1 )
    end

    local str = ''
    local tmp
    for _,v in ipairs( ary ) do
      tmp = v
      if tmp then
        str = str .. tmp .. ','
      end
    end
    str = str .. tmp
    awful.spawn.with_shell('echo "' .. str .. '" >' .. tmpfile )
  end

  local function widget_set_value( value )
    wrap.children[ 2 ]:set_text( value )
    wrap.children[ 3 ]:add_value( value / 100 )
  end

  local function update()
    awful.spawn.with_line_callback( [[bash -c "cat ]] .. path .. [["]] , {
      stdout = function( out )
        widget_set_value( out )
        save_file( out )
      end
    })
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  return wrap
end

function widget:battery( title , sync )
  return widget:getStat( "/sys/class/power_supply/battery/capacity" , title , sync )
end

-- date
function widget:date( format , interval , timezone )
  local widget = wibox.widget.textclock( format , interval , timezone )
  return widget
end

-- wifi
function widget:wifi( wifi , disp , sync )
  local wrap = getTemplate()
  local rate
  local quality
  local speed

  local function update_cb()
    if rate == nil then
      quality = 0
      speed = 0
    elseif quality == nil then
      quality = 0
      speed = 0
    else
      speed = math.floor( rate * quality / 10 ) / 10
    end

    wrap.children[ 1 ]:add_value( quality / 100 )
    wrap.children[ 2 ]:set_text( disp .. ":" .. string.format( '%5s' , speed ) .. "Mb/s" )
  end

  local function update()
    awful.spawn.with_line_callback( [[bash -c "iwconfig ]] .. wifi .. [["]] , {
      stdout = function( out )
        if string.match( out , "Bit Rate" ) then
          rate = string.match( out , "=([%d\\.]+).*" )
        elseif string.match( out , "Link Quality" ) then
          quality = math.floor( string.match( out , "=(%d+)/%d+" ) / string.match( out , "=%d+/(%d+)" ) * 100 )
        end
      end,
      exit = function()
        update_cb()
      end
    })
  end

  local timer = gears.timer( { timeout = sync } )
  timer:connect_signal( "timeout" , function() update() end )
  update()
  timer:start()

  wrap:buttons(
    awful.util.table.join(
      awful.button( { } , 1 , function()
        awful.spawn.with_shell( "sudo systemctl stop network@" .. wifi .. ".service ; sudo systemctl stop wpa_supplicant@" .. wifi .. ".service ; sudo systemctl start wpa_supplicant@" .. wifi .. ".service ; sudo systemctl start network@" .. wifi .. ".service" )
      end )
    )
  )

  return wrap
end

return widget
