fx_version 'cerulean'
game 'gta5'

name 'botrp_identity'
description 'BotRP normalized character identity service'
version '0.2.1'
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
    'qbx_idcard',
    'botrp_core',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
