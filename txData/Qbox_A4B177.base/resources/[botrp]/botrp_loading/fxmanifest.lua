fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP cinematic loading and player loading experience'
version '0.3.0'
author 'BotRP'

-- Native FiveM loading screen. FiveM owns the native lifecycle.
loadscreen 'web/index.html'
loadscreen_cursor 'yes'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/botrp_cinematic.svg',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
}
