fx_version 'cerulean'
game 'gta5'

name 'botrp_loading'
description 'BotRP player loading experience'
version '0.1.0'
author 'BotRP'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_script 'client.lua'

dependencies {
    'qbx_core',
}
