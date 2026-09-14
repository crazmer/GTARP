fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP cinematic loading and player loading experience'
version '0.4.0'
author 'BotRP'

loadscreen 'web/index.html'
loadscreen_cursor 'yes'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/assets/botrp_cinematic.svg',
    'web/assets/bg1.jpg',
    'web/assets/bg2.jpg',
    'web/assets/bg3.jpg',
    'web/assets/bg4.jpg',
    'web/assets/bg5.jpg',
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
}
