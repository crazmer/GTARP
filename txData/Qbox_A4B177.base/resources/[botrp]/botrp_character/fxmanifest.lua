fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
description 'BotRP custom Qbox character selection and creation experience'
version '0.5.0'
author 'BotRP'

ui_page 'web/lobby-v050.html'

files {
    'web/lobby-v050.html',
    'web/botrp-character-v050.css',
    'web/app.js'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_script 'client.lua'

dependencies {
    'qbx_core',
    'ox_lib'
}
