import string
import uuid
import hct_config

var Config=hct_config.Config

var ON='ON'
var OFF='OFF'
var MAC_EMPTY='00:00:00:00:00:00'

def get_device_name()
    var device_name=tasmota.cmd('DeviceName').find('DeviceName')
    if !device_name
        raise "Couldn't get device name"
    end
    return device_name
end

def to_bool(value)
  return [str(true),str(1),string.tolower(ON)].find(string.tolower(str(value)))!=nil
end

def from_bool(value)
  return to_bool(value)?ON:OFF
end

def read_url(url, retries)

  var client = webclient()
  client.begin(url)
  var status=client.GET()
  if status==200
      return client.get_string()
  else
      log(['Error reading',str(url),'Code',str(status)].concat(' '))
      return false
  end
  
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

    var as_str=as_strs.concat(', ')
    log(as_str)

    var timestamp=str(tasmota.cmd('Time').find('Time'))

    as_str=[timestamp,as_str].concat(': ')
    print(as_str)

end

def download_url(url, file_path, retries)

    retries=retries==nil?10:retries

    try
        tasmota.urlfetch(url,file_path)
        return true
    except .. as exception

        log(['Error downloading URL',str(url),':',str(exception),'.','retries remaining:',str(retries)].concat(' '))      

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


def update_hct(value)

    if value!='INSTALL'
        return false
    end

    log('Starting hct update...')

    var is_download_success=download_url(Config.URL_MODULE,Config.PATH_MODULE)
    if is_download_success
        log('Download succeeded. Restarting...')
        tasmota.cmd('restart 1')        
        return true
    else
        log('Download failed.')
        return false
    end
    

end

def get_latest_version(org,repo)

    log(['Fetching', org, repo, 'latest version...'].concat(' '))

    var url=[
        'https://europe-west2-extreme-flux-351112.cloudfunctions.net/get_github_latest_release_version?org=',
        org,
        '&repo=',
        repo
        ].concat()

    var version=read_url(url)
    if version
        return version
    else
        log('Reading URL failed.')
        return false
    end

end

def tuya_send(type_id,dp_id,data)

    if type_id==1
        data=int(to_bool(data))
    end

    var cmd=[
        ['TuyaSend',str(type_id)].concat(),
        [str(dp_id),str(data)].concat(','),
    ].concat(' ')
    return tasmota.cmd(cmd)
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
return mod