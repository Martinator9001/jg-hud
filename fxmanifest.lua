fx_version 'cerulean'
game 'gta5'

author 'JG Scripts'
description 'Simple Interface for your FiveM Server'
version '2.0.0'
discord 'https://discord.gg/yurZwyAQ'

shared_script '@ox_lib/init.lua'

client_scripts {
    'client/lib.lua',
    'client/**/*.lu*'
}

ui_page 'web/index.html'

files {
    'web/**',
}

lua54 'yes'
use_fxv2_oal 'yes'
