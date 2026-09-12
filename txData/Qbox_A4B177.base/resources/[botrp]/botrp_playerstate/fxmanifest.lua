fx_version 'cerulean'
game 'gta5'

name 'botrp_playerstate'
description 'BotRP centralized player state service'
version '0.1.0'
author 'BotRP'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

server_scripts {
    'server/main.lua',
}

client_scripts {
    'client/main.lua',
}

dependencies {
    'ox_lib',
    'qbx_core',
    'botrp_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
