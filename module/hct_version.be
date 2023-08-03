var VERSION='0.3.52'

import string

var IS_DEVELOPMENT=string.find(VERSION,'development')>=0

var mod = module("hct_version")
mod.VERSION=VERSION
mod.IS_DEVELOPMENT=IS_DEVELOPMENT
return mod