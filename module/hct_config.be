import string
import hct_constants as constants

class Config

    # Module-wide configuration

    static var USE_LONG_NAMES=false
    static var IS_DEBUG=string.find(constants.VERSION,'development')>=0
    static var URL_VERSION='https://raw.githubusercontent.com/fmtr/hct/release/version'
    static var PATH_MODULE='/hct.tapp'
    static var URL_MODULE='https://raw.githubusercontent.com/fmtr/hct/release/hct.tapp'
    static var DEVICE_NAME
    static var IS_RAND_SET=false


    static def debug()
        Config.IS_DEBUG=!Config.IS_DEBUG
        return Config.IS_DEBUG
    end


end

var mod = module("hct_config")
mod.Config=Config
return mod