import string
import uuid
import math
import hct_constants as constants
import hct_config

var Config=hct_config.Config
var MAC_EMPTY='00:00:00:00:00:00'

def get_device_name()
    var device_name=tasmota.cmd('DeviceName').find('DeviceName')
    if !device_name
        raise "Couldn't get device name"
    end
    return device_name
end

def to_bool(value)
  return [str(true),str(1),string.tolower(constants.ON)].find(string.tolower(str(value)))!=nil
end

def from_bool(value)
  return to_bool(value)?constants.ON:constants.OFF
end



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

def read_url(url, retries)

    var client = webclient()
    client.begin(url)
    var status=client.GET()
    if status==200
        return client.get_string()
    else        
        log_hct(string.format('Error reading "%s". Code %s', url, status))
        return false
    end
    
  end

def download_url(url, file_path, retries)

    retries=retries==nil?10:retries

    try
        tasmota.urlfetch(url,file_path)
        return true
    except .. as exception

        log(['Error downloading URL',str(url),':',str(exception),'.',' Retries remaining: ',str(retries)].concat(''))      

        retries-=1
        if !retries
            return false
        else
            return download_url(url,file_path,retries)
        end

    end
end

def get_mac()
    
    var status_net=tasmota.cmd('status 5').find('StatusNET',{})
    var mac_wifi=status_net.find('Mac', MAC_EMPTY)
    var mac_ethernet=status_net.find('Ethernet', {}).find('Mac', MAC_EMPTY)    
    
    if [MAC_EMPTY,nil].find(mac_wifi)==nil
        return mac_wifi
    elif [MAC_EMPTY,nil].find(mac_ethernet)==nil
        return mac_ethernet    
    end
    
    raise "Couldn't get MAC address"
end

def get_mac_short()
    return string.split(string.tolower(get_mac()),':').concat()
end

def get_mac_last_six()
    return string.replace(string.split(get_mac(),':',3)[3],':','')
end

def get_topic()
    var topic=tasmota.cmd('topic').find('Topic')
    if !topic
        raise "Couldn't get topic"
    end   
    
    topic=string.replace(topic,'%06X',get_mac_last_six())

    return topic
end

def get_topic_lwt()
    return ['tele',get_topic(),'LWT'].concat('/')
end

def get_uptime_sec()
    var uptime=tasmota.cmd('status 11').find('StatusSTS',{}).find('UptimeSec')
    if uptime==nil
        raise "Couldn't get uptime"
    end
    return uptime
end

def to_chars(s)
    var chars=[]
    for i: 0..(size(s)-1) 
        chars.push(s[i]) 
    end 
    return chars
end

var CHARS_ALLOWED=to_chars('abcdefghijklmnopqrstuvwxyz0123456789')
var SEPS=to_chars('_- ')

def sanitize_name(s, sep)
    sep= sep ? sep : '-'
    var chars=[]
    for c: to_chars(string.tolower(s))
        if SEPS.find(c)!=nil
            chars.push(sep)
        elif CHARS_ALLOWED.find(c)!=nil
            chars.push(c)
        end        
    end 
    return chars.concat()
end

def set_default(data,key,value)
    if !data.contains(key)
        data[key]=value
    end
    return data
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

def reverse_map(data)
    var reversed={}
    for key: data.keys()
        reversed[data[key]]=key
    end
    return reversed
end

def get_keys(data)
    var keys=[]
    for key: data.keys()
        keys.push(key)
    end
    return keys
end

def update_map(data,data_update)
    for key: data_update.keys()
        var value=data_update[key]
        if value!=nil
            data[key]=value
        end
    end
    return data
end

def update_hct(url,path_module)

    url=url==nil?Config.URL_MODULE:url
    path_module=path_module==nil?Config.PATH_MODULE:path_module

    log_hct('Starting hct update...')

    var is_download_success=download_url(url,path_module)
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

    var version=read_url(url)
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
        data=int(to_bool(data))
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
mod.to_bool=to_bool
mod.from_bool=from_bool
mod.read_url=read_url
mod.log_debug=log_debug
mod.download_url=download_url
mod.get_mac=get_mac
mod.get_topic=get_topic
mod.get_topic_lwt=get_topic_lwt
mod.get_mac_short=get_mac_short
mod.get_mac_last_six=get_mac_last_six
mod.get_device_name=get_device_name
mod.get_uptime_sec=get_uptime_sec
mod.to_chars=to_chars
mod.sanitize_name=sanitize_name
mod.set_default=set_default
mod.add_rule=add_rule
mod.remove_rule=remove_rule
mod.add_rule_once=add_rule_once
mod.reverse_map=reverse_map
mod.update_map=update_map
mod.get_keys=get_keys
mod.update_hct=update_hct
mod.get_latest_version=get_latest_version
mod.tuya_send=tuya_send
mod.get_current_version_tasmota=get_current_version_tasmota
mod.get_rand=get_rand
return mod