import string
import tools as tools_be
import hct_constants as constants
import hct_config as config

var Logger=tools_be.logging.Logger

var mod = module("hct_logger")

mod.logger=Logger(
    constants.NAME,
    config.Config.IS_DEVELOPMENT?Logger.DEBUG_MORE:Logger.DEBUG_MORE,
    config.Config.IS_DEVELOPMENT
)

tools_be.logger.logger=mod.logger

return mod