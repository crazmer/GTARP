fx_version 'cerulean'
game 'gta5'

author 'BotRP Development Team'
description 'BotRP Core Framework'
version '0.3.0'

shared_script 'config.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_script 'client.lua'
server_script 'server.lua'
