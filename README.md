Widget
======

## About

This plugin is widgets for awesome wm.

## Usage

``` lua
local widget  = require( "widget" )

s.mywibox:setup {
  layout = wibox.layout.align.horizontal,
    -- ommision
    { -- Right widgets
      widget:wifi( 'wlan0' , 'WIFI' , 1 ) ,
      widget:swap( "Swap" , 10 ) ,
      widget:cpu( "CPU" , 1 ) ,
      widget:ram( "RAM" , 10 ) ,
      widget:battery( "Battery" , 60 ) ,
      widget:cputemp( 1 ) ,
      widget:date( " %m/%d %a %H:%M:%S " , 1 , "Asia/Tokyo" )
    },
  }
```
