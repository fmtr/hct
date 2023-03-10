class Config

    # Module-wide configuration

    static var USE_LONG_NAMES=false
    static var IS_DEBUG=false
    static var URL_VERSION='https://raw.githubusercontent.com/fmtr/hct/release/version'
    static var PATH_MODULE='/hct.tapp'
    static var URL_MODULE='https://raw.githubusercontent.com/fmtr/hct/release/hct.tapp'
    static var DEVICE_NAME


end

var mod = module("hct_config")
mod.Config=Config
return mod