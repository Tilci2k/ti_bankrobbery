-- fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

author 'Tilci'
description 'Pacific Standard Bank Robbery for QBox'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'locales/*.json'
}

dependencies {
    'qbx_core',
    'ox_lib',
    'ox_inventory',
    'ox_doorlock',
    'ps-dispatch',
    'iconminigame'
}

lua54 'yes'