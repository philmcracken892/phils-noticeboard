fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'Notice System using ox_lib'
version '2.0.0'
author 'Phil Mcracken'

ui_page 'html/index.html'

files {
    'html/index.html'
}


shared_scripts {
    '@ox_lib/init.lua',
	'config.lua'
}

client_scripts {
    'client.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

dependencies {
    'rsg-core',
    'ox_lib',
    'oxmysql'
}

lua54 'yes'
