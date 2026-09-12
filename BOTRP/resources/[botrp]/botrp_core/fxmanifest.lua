fx_version 'cerulean'
game 'gta5'

name 'botrp_core'
description 'BotRP shared foundation for Qbox'
version '0.1.0'
author 'BotRP'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
}
