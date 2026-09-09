fx_version 'cerulean'
game 'gta5'

name 'qbx_vehicleinsurance'
description 'Vehicle registration and insurance for Qbox'
version '1.0.0'
repository 'https://github.com/crazmer/GTARP'

shared_scripts {
    '@ox_lib/init.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

server_only 'yes'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
