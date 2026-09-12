fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
description 'BotRP custom Qbox character selection and creation experience'
version '0.1.3'
author 'BotRP'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/botrp-ui.css',
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
