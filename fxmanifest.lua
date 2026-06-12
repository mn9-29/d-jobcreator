fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Djonza'
description 'Job creator script (ESX / QBCore / QBX)'
version '2.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'bridge/framework.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
    'stashes-server.lua',
}

client_scripts {
    'client.lua',
    'stashes-client.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'locales/*.json',
}

dependencies {
    'ox_lib',
    'ox_target',
    'oxmysql',
}
