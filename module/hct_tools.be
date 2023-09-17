import string
import uuid
import math
import hct_constants as constants
import hct_config
import hct_logger as logger

import tools as tools_be

var Config=hct_config.Config

def sanitize_name(s, sep)
    sep= sep ? sep : '-'
    var chars=[]
    for c: tools_be.iterator.to_chars(string.tolower(s))
        if constants.SEPS_ALLOWED.find(c)!=nil
            chars.push(sep)
        elif constants.CHARS_ALLOWED.find(c)!=nil
            chars.push(c)
        end        
    end 
    return chars.concat()
end

def add_rule_once(trigger_outer, function)

    var id=uuid.uuid4()

    def wrapper(value, trigger_wrapper, message)      
        logger.logger.debug(['Removing rule-once', trigger_outer, id])          
        tasmota.remove_rule(trigger_outer,id)        
        return function(value, trigger_wrapper, message)
    end
    
    logger.logger.debug(['Adding rule-once', trigger_outer, id])          
    tasmota.add_rule(trigger_outer,wrapper, id)    

end

def update_hct(url)
    return tools_be.update.update_tapp_github_asset(url, constants.ORG, constants.NAME, constants.ASSET_FILENAME, constants.PATH_MODULE)
end

def get_topic_lwt()

    import string

    var topic_mask=tasmota.cmd('FullTopic')['FullTopic']
    var prefix=tasmota.cmd('prefix')['Prefix3']

    var topic=topic_mask
    topic=string.replace(topic,'%topic%',tools_be.mqtt.get_topic())
    topic=string.replace(topic,'%prefix%',prefix)

    return string.format('%sLWT',topic)

end

var mod = module("hct_tools")

mod.tools_be=tools_be

mod.to_bool=tools_be.converter.to_bool
mod.from_bool=tools_be.converter.from_bool
mod.sanitize_name=sanitize_name
mod.add_rule_once=add_rule_once
mod.update_hct=update_hct
mod.get_topic_lwt=get_topic_lwt


mod.get_random=tools_be.random.get_random
return mod