fx_version 'cerulean'
games { 'gta5' }

author 'CivDev'
description 'CivDev HUD-ESX & QBCore'
version '1.2.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/*'
}
