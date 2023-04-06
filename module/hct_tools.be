import string
import uuid
import math
import hct_constants as constants
import hct_config

import tools as tools_be

var Config=hct_config.Config







def log_hct(message)
    log(string.format('%s: %s',string.toupper(constants.NAME),message))
end

def log_debug(messages)

    if !Config.IS_DEBUG
        return
    end

    if classname(messages)!='list'
        messages=[messages]
    end

    var as_strs=[]

    for message: messages
        as_strs.push(str(message))
    end

    var as_str=as_strs.concat(' ')
    log_hct(as_str)

    var timestamp=str(tasmota.cmd('Time').find('Time'))
    
    print(string.format('%s: %s',timestamp, as_str))

end



def get_mac_short()
    return string.split(string.tolower(tools_be.get_mac()),':').concat()
end

def get_mac_last_six()
    return string.replace(string.split(tools_be.get_mac(),':',3)[3],':','')
end

var CHARS_ALLOWED=tools_be.to_chars('abcdefghijklmnopqrstuvwxyz0123456789')
var SEPS=tools_be.to_chars('_- ')

def sanitize_name(s, sep)
    sep= sep ? sep : '-'
    var chars=[]
    for c: tools_be.to_chars(string.tolower(s))
        if SEPS.find(c)!=nil
            chars.push(sep)
        elif CHARS_ALLOWED.find(c)!=nil
            chars.push(c)
        end        
    end 
    return chars.concat()
end

def add_rule(id,trigger,closure)   
    
    var entry
    if string.find(trigger,'cron:')!=0
        entry={'type': 'trigger', 'trigger':trigger, 'function':closure} 
        tasmota.add_rule(entry['trigger'],closure,id)           
    else
        entry={'type': 'cron', 'trigger':string.replace(trigger,'cron:',''), 'function':closure}
        tasmota.add_cron(entry['trigger'],closure,id)
    end

    return entry
end

def remove_rule(id, entry)   
            
    if entry['type']=='trigger'
        tasmota.remove_rule(entry['trigger'],id)
    else
        tasmota.remove_cron(id)
    end

end

def add_rule_once(trigger, function)

    var id=uuid.uuid4()

    def wrapper(value, trigger_wrapper, message)      
        log_debug(['Removing rule-once', trigger, id])          
        tasmota.remove_rule(trigger,id)        
        return function(value, trigger_wrapper, message)
    end
    
    log_debug(['Adding rule-once', trigger, id])          
    tasmota.add_rule(trigger,wrapper, id)    

end

def update_hct(url,path_module)

    url=url==nil?Config.URL_MODULE:url
    path_module=path_module==nil?Config.PATH_MODULE:path_module

    log_hct('Starting hct update...')

    var is_download_success=tools_be.download_url(url,path_module)
    if is_download_success
        log_hct('Download succeeded. Restarting...')
        tasmota.cmd('restart 1')        
        return true
    else
        log_hct('Download failed.')
        return false
    end    

end

def get_latest_version(org,repo)    

    log_hct(string.format('Fetching %s/%s latest version...', org, repo))

    var url=string.format(
        'https://europe-west2-extreme-flux-351112.cloudfunctions.net/get_github_latest_release_version?org=%s&repo=%s',
        org,
        repo
    )

    var version=tools_be.read_url(url)
    if version
        return version
    else
        log_hct(
            string.format('Failed reading %s/%s latest version from URL "%s".',
                org,
                repo,
                url
            )
        )
        return false
    end

end

def tuya_send(type_id,dp_id,data)

    if type_id==1
        data=int(tools_be.to_bool(data))
    end

    var cmd=string.format('TuyaSend%s %s,%s',type_id,dp_id,data)
    return tasmota.cmd(cmd)
end

def get_current_version_tasmota()

    import string 

    var version_current=tasmota.cmd('status 2').find('StatusFWR',{}).find('Version','Unknown')    
    var tas_seps=['(tasmota32)','(tasmota)']

    var sep
    for tas_sep: tas_seps
        if string.find(version_current,tas_sep)>=0
            sep=tas_sep
        end
    end

    if sep==nil
        return version_current
    end    

    return string.split(version_current,sep)[0]
end

def get_rand(limit)

    if !Config.IS_RAND_SET
        math.srand(tasmota.millis())
        Config.IS_RAND_SET=true
    end

    return math.rand()%limit
end

var mod = module("hct_tools")
mod.to_bool=tools_be.to_bool
mod.from_bool=tools_be.from_bool
mod.read_url=tools_be.read_url
mod.download_url=tools_be.download_url
mod.log_debug=log_debug

mod.get_mac=tools_be.get_mac
mod.get_topic=tools_be.get_topic
mod.get_topic_lwt=tools_be.get_topic_lwt
mod.get_mac_short=get_mac_short
mod.get_mac_last_six=get_mac_last_six
mod.get_device_name=tools_be.get_device_name
mod.get_uptime_sec=tools_be.get_uptime_sec
mod.to_chars=tools_be.to_chars
mod.sanitize_name=sanitize_name
mod.set_default=tools_be.set_default
mod.add_rule=add_rule
mod.remove_rule=remove_rule
mod.add_rule_once=add_rule_once
mod.reverse_map=tools_be.reverse_map
mod.update_map=tools_be.update_map
mod.get_keys=tools_be.get_keys
mod.update_hct=update_hct
mod.get_latest_version=get_latest_version
mod.tuya_send=tuya_send
mod.get_current_version_tasmota=get_current_version_tasmota
mod.get_rand=get_rand
return mod