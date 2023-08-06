import hct_version

var VERSION=hct_version.VERSION

import string
import tools_constants
import tools as tools_be

var mod = module("hct_constants")
mod.NAME='hct'
mod.ORG='fmtr'
mod.ASSET_FILENAME=string.format('%s.tapp',mod.NAME)
mod.PATH_MODULE=string.format('/%s',mod.ASSET_FILENAME)
mod.VERSION=VERSION

mod.ON=tools_constants.ON
mod.OFF=tools_constants.OFF
mod.IN='in'
mod.OUT='out'

mod.CHARS_ALLOWED=tools_be.iterator.to_chars('abcdefghijklmnopqrstuvwxyz0123456789')
mod.SEPS_ALLOWED=tools_be.iterator.to_chars('_- ')

mod.VALUE_TEMPLATE='{{ value_json.value }}'
mod.INT_MAX=2147483647
return mod