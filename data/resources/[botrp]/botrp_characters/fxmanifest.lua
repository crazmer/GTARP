fx_version 'cerulean'
game 'gta5'

author 'BotRP Development Team'
description 'Standalone BotRP character management'
version '1.0.0'

dependency 'botrp_bridge'

shared_script 'config.lua'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_script 'client.lua'
server_script 'server.lua'
