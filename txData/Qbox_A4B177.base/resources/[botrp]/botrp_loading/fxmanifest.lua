fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP cinematic loading and player loading experience'
version '0.2.0'
author 'BotRP'

-- Native FiveM loading screen and in-game NUI share the same page.
loadscreen 'web/index.html'
loadscreen_manual_shutdown 'yes'
loadscreen_cursor 'yes'
ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
}
