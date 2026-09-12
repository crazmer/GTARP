fx_version 'cerulean'
game 'gta5'

name 'botrp_identity'
description 'BotRP normalized character identity and licensing service'
version '0.4.0'
author 'BotRP'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
    'qbx_idcard',
    'botrp_core',
    'ox_target',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
