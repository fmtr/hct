var VERSION='0.1.8'
var NAME='hct'
import mqtt
import json
import string
import math
import uuid

class Config

    # Module-wide configuration
    
    static var USE_LONG_NAMES=false
    static var IS_DEBUG=false
    static var URL_VERSION='https://raw.githubusercontent.com/fmtr/hct/release/version'
    static var PATH_MODULE='/hct.be'
    static var URL_MODULE='https://raw.githubusercontent.com/fmtr/hct/release/hct.be'

    
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

log_debug("hct.be compiling...")

var RULE_MQTT_CONNECTED='Mqtt#Connected'
var MAC_EMPTY='00:00:00:00:00:00'
var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

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

def to_bool(value)
  return [str(true),str(1),string.tolower(ON)].find(string.tolower(str(value)))!=nil
end

def from_bool(value)
  return to_bool(value)?ON:OFF
end

def get_mac()
    
    var status_net=tasmota.cmd('status 5').find('StatusNET',{})
    var mac_wifi=status_net.find('Mac', MAC_EMPTY)
    var mac_ethernet=status_net.find('Ethernet', {}).find('Mac', MAC_EMPTY)    
    
    if [MAC_EMPTY,nil].find(mac_ethernet)==nil
        return mac_ethernet
    elif [MAC_EMPTY,nil].find(mac_wifi)==nil
        return mac_wifi
    end
    
    raise "Couldn't get MAC address"
end
var MAC=get_mac()

def get_topic()
    var topic=tasmota.cmd('topic').find('Topic')
    if !topic
        raise "Couldn't get topic"
    end
    return topic
end
var TOPIC=get_topic()
var TOPIC_LWT=['tele',TOPIC,'LWT'].concat('/')

def get_device_name()
    var device_name=tasmota.cmd('DeviceName').find('DeviceName')
    if !device_name
        raise "Couldn't get device name"
    end
    return device_name
end
var DEVICE_NAME=get_device_name()

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



def list_to_map(as_list)
    var as_map={}
    for value: as_list
        as_map[/value->value]=value
    end
    return as_map
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

class Publish
    var value

    def init(value)
        self.value=value
    end
end

class NoPublish    
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

def get_latest_version(value)

    log('Fetching hct latest version...')

    var version=read_url(Config.URL_VERSION)
    if version
        return version
    else
        log('Reading URL failed.')
        return false
    end

end

# End of utility functions.


def handle_incoming_default(value, topic, code, value_raw, value_bytes)    
    var value_str={'value':value,'topic':topic,'code':code,'value_raw':value_raw,'value_bytes':value_bytes}.tostring()
    print('Command Handler got '+value_str)
    print('Either provide a function/closure as a `handle_incoming` parameter, or override the `handle_incoming` method')

  end

def handle_outgoing_wrapper(handler, entity,name, value_raw, trigger, message)   
    var converter=entity.endpoint_data[name].find('out',{}).find('converter',/value->value)
    var topic=entity.endpoint_data[name].find('out',{}).find('topic')

    log_debug([entity.name,'Outgoing input:', handler, entity,name, value_raw, trigger, message])

    var output_raw=handler(value_raw,entity, value_raw, trigger, message)

    log_debug([entity.name,'Outgoing handler output:',name, output_raw])

    if classname(output_raw)==classname(NoPublish)
        return    
    end
    
    if output_raw==nil 
        output_raw=value_raw
    end    

    var output=json.dump({'value':converter(output_raw)})

    log_debug([entity.name,'Outgoing handler publishing:',entity.name,name, output])

    mqtt.publish(topic,output)
    entity.value=output_raw
end

def handle_incoming_wrapper(handler, entity, name, topic, code, value_raw, value_bytes)

    log_debug([entity.name,'Incoming input:', handler, entity, name, topic, code, value_raw, value_bytes])

    var converter=entity.endpoint_data[name].find('in',{}).find('converter',/value->value)
    var converter_out=entity.endpoint_data[name].find('out',{}).find('converter',/value->value)
    var topic_out=entity.endpoint_data[name].find('out',{}).find('topic')

    var value=converter(value_raw)
    var output_raw=handler(value,entity, topic, code, value_raw, value_bytes)

    if classname(output_raw)==classname(Publish)
        output_raw=output_raw.value
    elif classname(output_raw)==classname(NoPublish)
        return
    else
        output_raw=value
    end

    var output=json.dump({'value':converter_out(output_raw)})

    log_debug([entity.name,name,'Incoming publishing to state topic:', output])

    if topic_out
        mqtt.publish(topic_out,output)
    end

    entity.value=output_raw

    return true 

end


class Entity

    static var platform=nil
    static var mac=string.split(string.tolower(MAC),':').concat()      

    var value

    var topic_command
    var topic_state
    var topic_announce
    var name  
    var name_sanitized
    var unique_id
    var entity_id
    var icon 
    var rule_registry

    var handle_outgoings
    var handle_incoming

    var endpoint_data

    def init(name, entity_id, icon, handle_outgoings, handle_incoming)

        self.value=nil

        if Config.USE_LONG_NAMES        
            name=[DEVICE_NAME,name].concat(' ')
        end

        self.name=name
        self.entity_id=entity_id
        self.icon=icon	
        self.name_sanitized=sanitize_name(self.name)	
        
        self.handle_incoming=handle_incoming
        self.handle_outgoings=handle_outgoings

        self.rule_registry={}
        #self.register_rule('System#Save',/value->self.close())    
        self.topic_announce=self.get_topic_announce()
        self.subscribe_announce()

        self.endpoint_data=self.extend_endpoint_data(self.get_endpoint_data())    
        for key: self.endpoint_data.keys()
            self.subscribe_out(key)
            self.subscribe_in(key)
        end

        var mqtt_count=tasmota.cmd('status 6').find('StatusMQT',{}).find('MqttCount',0)
        if mqtt_count>0
            self.announce()    
        end
        
    end

    def get_endpoint_data()

        var data={}

        if self.handle_incoming
            set_default(data,'state',{})
            data['state']['in']={
                'topic': self.get_topic('command','state'),
                'topic_key': 'command_topic',
                'callbacks': self.handle_incoming,
                'converter': /value->self.converter_state_in(value)
                }
        end

        if self.handle_outgoings
            set_default(data,'state',{})
            data['state']['out']={
                'topic': self.get_topic('state','state'),
                'topic_key': 'state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'value_template',
                'callbacks': self.handle_outgoings,
                'converter': /value->self.converter_state_out(value)
                }
        end

        return data

    end

    def extend_endpoint_data(data)

        return data

    end

    def register_rule(trigger,closure)
        var id=[str(classname(self)),str(closure)].concat('_')
        var entry=add_rule(id,trigger,closure)        
        log_debug([self.name,'Adding rule',entry,id])        
        self.rule_registry[id]=entry
        return id
    end

    def subscribe_announce()
        self.register_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())    
    end

    def subscribe_out(name)      

        var handle_outgoings=self.endpoint_data[name].find('out',{}).find('callbacks')

        handle_outgoings= handle_outgoings ? handle_outgoings : {}

        if !handle_outgoings
            handle_outgoings={}
        end

        if type(handle_outgoings)=='string'
            handle_outgoings=[handle_outgoings]
        end

        if classname(handle_outgoings)=='list'
            handle_outgoings=list_to_map(handle_outgoings)
        end

        var closure_outgoing         
        for handler: handle_outgoings.keys()
            var trigger_handlers=handle_outgoings[handler]        
            if type(trigger_handlers)=='string'
                trigger_handlers=[trigger_handlers]
            end
            for trigger_handler: trigger_handlers
                closure_outgoing=(
                    / value trigger message -> 
                    handle_outgoing_wrapper(handler, self, name, value, trigger, message)
                )
                self.register_rule(trigger_handler,closure_outgoing)
                
            end
        end
    end

    def subscribe_in(name)
        
        var handle_incoming=self.endpoint_data[name].find('in',{}).find('callbacks')

        if !handle_incoming
            return
        end

        assert self.endpoint_data[name].contains('in')
        var topic=self.endpoint_data[name]['in']['topic']

        handle_incoming= handle_incoming ? handle_incoming : (/ value -> value)    
        var closure_incoming=(
            / topic code value value_bytes -> 
            handle_incoming_wrapper(handle_incoming, self,name, topic, code, value, value_bytes)      
        )  
        mqtt.subscribe(topic, closure_incoming) # topic_command

    end

    def get_topic(type_topic, endpoint)

        type_topic={'command':'cmnd','state':'stat'}[type_topic]
        return [type_topic,TOPIC, string.toupper(self.name_sanitized),endpoint].concat('/')	

    end


    def get_topic_announce()
        return ['homeassistant',self.platform,TOPIC,self.get_unique_id(),'config'].concat('/')    
    end

    def translate_value_in(value)
        return value
    end

    def translate_value_out(value)
        return value
    end

    def get_unique_id()

        var uid_segs=[string.split(TOPIC,'-').concat('_')]   

        if string.find(string.tolower(TOPIC),self.mac)<0
            uid_segs+=[self.mac]
        end
        uid_segs+=[self.name]

        var unique_id=sanitize_name(uid_segs.concat(' '), '_')

        return unique_id

    end

    def get_data_announce()

    var data
        data= {
            'device': {
                'connections': [['mac', self.mac]],
                'identifiers': self.mac
            },
            'name': self.name,
            'unique_id': self.get_unique_id(),		
            'force_update': True,
            'payload_available': 'Online',
            'payload_not_available': 'Offline',
            'availability_topic': TOPIC_LWT,		
            
        }

        var data_update={      
            'icon':self.icon,
            'object_id':self.entity_id
        }

        for name: self.endpoint_data.keys()
            var dir_data=self.endpoint_data[name]
            for io_data: [dir_data.find('in',{}),dir_data.find('out',{})]
            for keyfix: ['topic','template','payload_on','payload_off']
                data_update[io_data.find(keyfix+'_key')]=io_data.find(keyfix)
            end
            end
        end

        data=update_map(data,data_update)

        return data

    end

    def announce()	
        var data=self.get_data_announce()
        log_debug([self.name, 'Doing announce', data])
        return mqtt.publish(self.topic_announce, json.dump(data))
    end

    def close()

        log_debug(['Closing',classname(self),self.name,'...'].concat(' '))
        var entry
        for id: self.rule_registry.keys()
            entry=self.rule_registry[id]    
            remove_rule(id, entry)
        end
    end

    def converter_state_in(value)
        return str(value)
    end

    def converter_state_out(value)
        return str(value)
    end
  
end


class Select : Entity

    static var platform='select'
    var options
    var options_map_in      
    var options_map_out     

    def init(name, options, entity_id, icon, handle_outgoings, handle_incoming)
        

        if classname(options)=='list'       
        
        self.options=options
        
        self.options_map_in={} 
        for option: options
            self.options_map_in[option]=option		
        end	  	  
        
        else
        
        self.options_map_in=options

        self.options=[] 
        for option: options.keys()
            self.options.push(option)
        end	
        
        end

        self.options_map_out={}
        for key: self.options_map_in.keys()
        self.options_map_out[self.options_map_in[key]]=key
        end

        super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        data['options']=self.options        

        return data

    end

end


class Number : Entity

    static var platform='number'

    var min
    var max
    var mode
    var step
    var uom
    var type

    def init(name, min, max, mode, step, uom, entity_id, icon, handle_outgoings, handle_incoming)

        self.min=min
        self.max=max
        self.mode=mode
        self.step=step
        self.uom=uom
        self.type=self.step==nil || self.step==1 ? int : real
        super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

    end


    def get_data_announce()

        var data=super(self).get_data_announce()

        var data_update={
            'min':self.min,
            'max':self.max,
            'mode':self.mode,
            'step':self.step,
            'unit_of_measurement':self.uom
        }

        for key: data_update.keys()
            var value=data_update[key]
            if value!=nil
                data[key]=value
            end
        end
        
        return data

    end

    def converter_state_in(value)
        return self.type(value)
    end

    def converter_state_out(value)
        return self.type(value)
    end

end

class Sensor : Entity

    static var platform='sensor'        
    var uom
    var type

    def init(name, uom, data_type, entity_id, icon, handle_outgoings)    

        self.uom=uom    
        self.type=data_type==nil ? /value->value : data_type
        super(self).init(name, entity_id, icon, handle_outgoings, nil)      

    end

    def converter_state_in(value)
        return self.type(value)
    end

    def converter_state_out(value)
        return self.type(value)
    end

    def get_data_announce()
        var data=super(self).get_data_announce()     
        if self.uom data['unit_of_measurement']=self.uom end
        return data
    end

end

class Button : Entity

    static var platform='button'        
    var uom

    def init(name, entity_id, icon, handle_incoming)        

        super(self).init(name, entity_id, icon, nil, handle_incoming)      

    end

end

class Switch : Entity

    static var platform='switch'  

    def converter_state_in(value)
        return to_bool(value)
    end

    def converter_state_out(value)
        return from_bool(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()     

        data['payload_on']=ON
        data['payload_off']=OFF
        
        return data

    end

end

class BinarySensor : Sensor

    static var platform='binary_sensor'    
    
    
    def init(name, entity_id, icon, handle_outgoings)    

        super(self).init(name, nil, nil ,entity_id, icon, handle_outgoings)      

    end


    def converter_state_in(value)
        return to_bool(value)
    end

    def converter_state_out(value)
        return from_bool(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()     

        data['payload_on']=ON
        data['payload_off']=OFF
        
        return data

    end

end


class Humidifier : Entity

    static var platform='humidifier'
    static var device_class='humidifier'
    var modes
    var min_humidity
    var max_humidity

    var handle_outgoings_mode
    var handle_incoming_mode
    var handle_outgoings_target_humidity
    var handle_incoming_target_humidity

    def init(name, modes, humidity_range, entity_id, icon, handle_outgoings, handle_incoming, handle_outgoings_mode, handle_incoming_mode, handle_outgoings_target_humidity, handle_incoming_target_humidity)
        
        self.modes=modes

        if humidity_range
            self.min_humidity=humidity_range.lower()
            self.max_humidity=humidity_range.upper()
        end  

        self.min_humidity=min_humidity
        self.max_humidity=max_humidity

        self.handle_outgoings_mode=handle_outgoings_mode
        self.handle_incoming_mode=handle_incoming_mode
        self.handle_outgoings_target_humidity=handle_outgoings_target_humidity
        self.handle_incoming_target_humidity=handle_incoming_target_humidity

        super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

    end

    def extend_endpoint_data(data)

        data['state']['in']['converter']=to_bool
        data['state']['out']['converter']=from_bool
        data['state']['out']['template_key']='state_value_template'

        if self.handle_outgoings_mode
            set_default(data,'mode',{})
            data['mode']['out']={
                'topic': self.get_topic('state','mode'),
                'topic_key': 'mode_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'mode_state_template',
                'callbacks': self.handle_outgoings_mode                
                }
        end

        if self.handle_incoming_mode
            set_default(data,'mode',{})
            data['mode']['in']={
                'topic': self.get_topic('command','mode'),
                'topic_key': 'mode_command_topic',
                'callbacks': self.handle_incoming_mode,
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', 'mode'].concat(' ')
        end

        if self.handle_outgoings_target_humidity
            set_default(data,'target_humidity',{})
            data['target_humidity']['out']={
                'topic': self.get_topic('state','target_humidity'),
                'topic_key': 'target_humidity_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'target_humidity_state_template',
                'callbacks': self.handle_outgoings_target_humidity,
                'converter': int
                }
        end

        if self.handle_incoming_target_humidity
            set_default(data,'target_humidity',{})
            data['target_humidity']['in']={
                'topic': self.get_topic('command','target_humidity'),
                'topic_key': 'target_humidity_command_topic',
                'callbacks': self.handle_incoming_target_humidity,
                'converter': int
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', 'target humidity'].concat(' ')
        end

        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={
            'modes':self.modes,
            'device_class':self.device_class,
            'payload_on':ON,
            'payload_off':OFF,
            'min_humidity':self.min_humidity,
            'max_humidity':self.max_humidity

        }

        data=update_map(data,data_update)

        return data

    end

end

class Dehumidifier : Humidifier
    
    static var device_class='dehumidifier'

end

class Fan : Entity

    static var platform='fan'
    
    var modes
    var min_speed
    var max_speed

    var handle_outgoings_mode
    var handle_incoming_mode
    var handle_outgoings_percentage
    var handle_incoming_percentage
    var handle_outgoings_oscillation
    var handle_incoming_oscillation

    def init(name, modes, speed_range, entity_id, icon, handle_outgoings, handle_incoming, handle_outgoings_mode, handle_incoming_mode, handle_outgoings_percentage, handle_incoming_percentage, handle_outgoings_oscillation, handle_incoming_oscillation)
        
        self.modes=modes
        
        if speed_range
            self.min_speed=speed_range.lower()
            self.max_speed=speed_range.upper()
        end        

        self.handle_outgoings_mode=handle_outgoings_mode
        self.handle_incoming_mode=handle_incoming_mode
        self.handle_outgoings_percentage=handle_outgoings_percentage
        self.handle_incoming_percentage=handle_incoming_percentage
        self.handle_outgoings_oscillation=handle_outgoings_oscillation
        self.handle_incoming_oscillation=handle_incoming_oscillation

        super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

    end

    def extend_endpoint_data(data)

        data['state']['in']['converter']=to_bool
        data['state']['out']['converter']=from_bool
        data['state']['out']['template_key']='state_value_template'

        var name

        name='preset_mode'
        if self.handle_outgoings_mode            
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'preset_mode_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'preset_mode_state_template',
                'callbacks': self.handle_outgoings_mode                
                }
        end
        
        if self.handle_incoming_mode
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': 'preset_mode_command_topic',
                'callbacks': self.handle_incoming_mode,
                }
        end

        name='percentage'
        if self.handle_outgoings_percentage
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'percentage_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'percentage_value_template',
                'callbacks': self.handle_outgoings_percentage,
                'converter': int
                }
        end

        if self.handle_incoming_percentage
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': 'percentage_command_topic',
                'callbacks': self.handle_incoming_percentage,
                'converter': int
                }
        end

        name='oscillation'
        if self.handle_outgoings_oscillation
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'oscillation_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'oscillation_value_template',
                'callbacks': self.handle_outgoings_oscillation,
                'converter': from_bool
                }
        end

        if self.handle_incoming_oscillation
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': 'oscillation_command_topic',
                'payload_on': ON,
                'payload_on_key': 'payload_oscillation_on',
                'payload_off': OFF,
                'payload_off_key': 'payload_oscillation_off',
                'callbacks': self.handle_incoming_oscillation,
                'converter': to_bool
                }
        end

        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={
            'preset_modes':self.modes,            
            'payload_on':ON,
            'payload_off':OFF,
            'speed_range_min':self.min_speed,
            'speed_range_max':self.max_speed
        }

        data=update_map(data,data_update)

        return data

    end

end

class Update : Entity

    static var platform='update'    
    var entity_picture
    var release_url
    var handle_outgoings_latest_version        

    def init(name, release_url, entity_picture, entity_id, icon, handle_outgoings, handle_incoming, handle_outgoings_latest_version)
        
        self.entity_picture=entity_picture
        self.release_url=release_url
        self.handle_outgoings_latest_version=handle_outgoings_latest_version
        super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

    end

    def extend_endpoint_data(data)

        data['state']['in']['converter']=str
        data['state']['out']['converter']=str

        var name

        name='latest_version'
        if self.handle_outgoings_latest_version            
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'latest_version_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'latest_version_template',
                'callbacks': self.handle_outgoings_latest_version                
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', name].concat(' ')
        end

        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={
            'entity_picture':self.entity_picture,            
            'payload_install':'INSTALL',
            'release_url':self.release_url
        }

        data=update_map(data,data_update)

        return data

    end

end

def expose_updater(trigger)
    
    var trigger_default='cron:* * */12 * * *'
    trigger=trigger==nil?trigger_default:trigger

    return Update(
        'Update (hct)',
        'https://github.com/fmtr/hct/releases/latest',
        nil,
        nil,
        nil,
        {/value->VERSION:['Mqtt#Connected',trigger]},
        /value->NoPublish(update_hct(value)),
        {def (value) var version=get_latest_version() return version?version:NoPublish() end:['Mqtt#Connected',trigger]}
    )

end




var hct = module(NAME)

hct.VERSION=VERSION
hct.Config=Config

hct.Select=Select
hct.Number=Number
hct.Sensor=Sensor
hct.Button=Button
hct.Switch=Switch
hct.BinarySensor=BinarySensor

hct.Humidifier=Humidifier
hct.Dehumidifier=Dehumidifier

hct.Fan=Fan

hct.Update=Update

hct.Publish=Publish
hct.NoPublish=NoPublish
hct.add_rule_once=add_rule_once
hct.reverse_map=reverse_map
hct.get_keys=get_keys
hct.download_url=download_url
hct.read_url=read_url
hct.log_debug=log_debug

hct.expose_updater=expose_updater

log_debug("hct.be compiled OK.")

return hct