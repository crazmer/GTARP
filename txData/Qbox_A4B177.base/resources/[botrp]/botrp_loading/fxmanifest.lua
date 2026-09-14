fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP cinematic loading and player loading experience'
version '0.2.0'
author 'BotRP'

-- Native FiveM loading screen shown while the client connects/loads.
loadscreen 'web/load.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'

-- In-game NUI used for transitional loading states after the native loadscreen.
ui_page 'web/index.html'

files {
    'web/load.html',
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
}
