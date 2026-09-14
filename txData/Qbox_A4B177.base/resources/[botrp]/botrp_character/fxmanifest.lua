fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
description 'BotRP custom Qbox character selection and creation experience'
version '1.0.7'
author 'BotRP'

ui_page 'web/lobby-v107.html'

files {
    'web/lobby-v107.html',
    'web/botrp-character-v107.css',
    'web/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client.lua',
    'showcase_controller.lua',
    'handoff_guard.lua'
}

server_script 'server.lua'

dependencies {
    'qbx_core',
    'ox_lib',
    'oxmysql'
}
