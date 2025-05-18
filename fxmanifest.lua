fx_version 'cerulean'
game 'rdr3'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'

description 'Notice System using ox_lib'
version '1.0.0'
author 'Phil Mcracken'
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