fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP cinematic loading and player loading experience'
version '0.2.1'
author 'BotRP'

-- Native FiveM loading screen. Do not manually hold this screen open.
-- FiveM will close the native loadscreen when connection/game loading completes.
loadscreen 'web/index.html'
loadscreen_cursor 'yes'

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
