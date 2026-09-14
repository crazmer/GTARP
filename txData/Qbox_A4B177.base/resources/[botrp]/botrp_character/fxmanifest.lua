fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
description 'BotRP custom Qbox character selection and creation experience'
version '0.9.2'
author 'BotRP'

ui_page 'web/lobby-v050.html'

files {
    'web/lobby-v050.html',
    'web/botrp-character-v050.css',
    'web/botrp-character-v090.css',
    'web/botrp-character-v091.css',
    'web/botrp-character-v092.css',
    'web/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql'
}
