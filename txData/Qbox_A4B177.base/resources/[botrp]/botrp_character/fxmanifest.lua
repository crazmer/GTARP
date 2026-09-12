fx_version 'cerulean'
game 'gta5'

name 'botrp_character'
description 'BotRP custom Qbox character selection and creation experience'
version '0.1.0'
author 'BotRP'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_script 'client.lua'

dependencies {
    'qbx_core',
    'ox_lib'
}
