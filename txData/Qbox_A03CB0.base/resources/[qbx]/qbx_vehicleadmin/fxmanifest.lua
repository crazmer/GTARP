fx_version 'cerulean'
game 'gta5'

name 'qbx_vehicleadmin'
description 'Qbox vehicle administration panel'
version '1.0.0'
repository 'https://github.com/crazmer/GTARP'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
    'web/style.css',
}

shared_scripts {
    '@ox_lib/init.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
