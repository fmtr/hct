var VERSION='0.1.15'
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

# End of utility functions.

# Helper objects

class Callback
    static var direction
    var endpoint
    var callback
    var id
    var name_endpoint
    def init(callback, endpoint, id)
        import uuid
        self.id=id?id:callback
        self.callback=callback?callback:/value->value
        self.endpoint=endpoint?endpoint:'state'
    end

    def get_desc()
        return [self.endpoint, self.direction].concat(', ')
    end
end

class CallbackIn: Callback
    static var direction='in'
    
end

class CallbackOut: Callback
    static var direction='out'
    var triggers
    def init(triggers, callback, endpoint, id)
        super(self).init(callback, endpoint, id)        
        self.triggers=classname(triggers)=='list'?triggers:[triggers]
        
    end
end

class Entity

    static var platform=nil
    static var mac=string.split(string.tolower(MAC),':').concat()      

    var values

    var topic_command
    var topic_state
    var topic_announce
    var name  
    var name_sanitized
    var unique_id
    var entity_id
    var icon 
    var rule_registry
    var callbacks_wrappeds



    var callback_data

    var endpoint_data

    def init(name, entity_id, icon, callbacks)

        self.values={}
        self.rule_registry={}
        self.callbacks_wrappeds={}

        if Config.USE_LONG_NAMES        
            name=[DEVICE_NAME,name].concat(' ')
        end

        self.name=name
        self.entity_id=entity_id
        self.icon=icon	
        self.name_sanitized=sanitize_name(self.name)	


        


        self.callback_data={}



        for cb : callbacks

            

            set_default(self.callback_data, cb.endpoint,{})
            set_default(self.callback_data[cb.endpoint], cb.direction,[])
            self.callback_data[cb.endpoint][cb.direction].push(cb)
        end

        log_debug([self.name, 'got callback data', self.callback_data])

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

        var name
        var direction
        var callbacks

        name='state'

        direction='in'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': 'command_topic',
                'callbacks': callbacks,
                'converter': /value->self.converter_state_in(value)
                }
        end

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'value_template',
                'callbacks': callbacks,
                'converter': /value->self.converter_state_out(value)
                }
        end

        return data

    end


    def extend_endpoint_data(data)

        return data

    end

    def add_endpoint_data(data,name,dir,converter)

        var callbacks=self.callback_data.find(name,{}).find(dir)
        if !callbacks
            return
        end

        var dir_mqtt={'in':'command','out':'state'}[dir]

        var data_update={
                'topic': self.get_topic(dir_mqtt,name),
                'topic_key': [name,dir_mqtt,'topic'].concat('_'),
                'callbacks': callbacks,
                (converter?'converter':converter):converter
            }

        if dir=='out'
            data_update=update_map(
                data_update,
                {
                    'template':VALUE_TEMPLATE,
                    'template_key': [name,dir_mqtt,'template'].concat('_')                        
                }
            )
        end

        data=set_default(data,name,{})
        data[name][dir]=data_update

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

        var callback_outs=self.endpoint_data[name].find('out',{}).find('callbacks')

        if !callback_outs
            return
        end

        if classname(callback_outs)!='list'
            callback_outs=[callback_outs]
        end        

        var closure_outgoing         
        for callback_obj: callback_outs

            for trigger_callback: callback_obj.triggers
                closure_outgoing=(
                    / value trigger message -> 
                    self.callback_out_wrapper(callback_obj, name, value, trigger, message)
                )
                self.register_rule(trigger_callback,closure_outgoing)
                self.callbacks_wrappeds[callback_obj.id]=closure_outgoing

            end
        end
    end

    def callback_out_wrapper(cbo, name, value_raw, trigger, message)   
  
        log_debug([self.name,'Outgoing input:', cbo, self,name, value_raw, trigger, message])
    
        var output_raw=cbo.callback(value_raw,self, value_raw, trigger, message)
    
        log_debug([self.name,'Outgoing callback output:',name, output_raw])
    
        if classname(output_raw)==classname(NoPublish)
            return    
        end
        
        if output_raw==nil 
            output_raw=value_raw
        end    

        self.publish(name,output_raw)

    end

    def subscribe_in(name)
        
        var callback_ins=self.endpoint_data[name].find('in',{}).find('callbacks')

        if !callback_ins
            return
        end

        assert self.endpoint_data[name].contains('in')
        var topic=self.endpoint_data[name]['in']['topic']

        if classname(callback_ins)!='list'
            callback_ins=[callback_ins]
        end

        for callback_obj: callback_ins
            var closure_incoming=(
                / topic code value value_bytes -> 
                self.callback_in_wrapper(callback_obj, name, topic, code, value, value_bytes)      
            )  
            mqtt.subscribe(topic, closure_incoming)
            self.callbacks_wrappeds[callback_obj.id]=closure_incoming

        end

    end

    def callback_in_wrapper(cbo, name, topic, code, value_raw, value_bytes)        

        log_debug([self.name,'Incoming input:', cbo, self, name, topic, code, value_raw, value_bytes])
    
        var converter=self.endpoint_data[name].find('in',{}).find('converter',/value->value)

        var value=converter(value_raw)
        var output_raw=cbo.callback(value,self, topic, code, value_raw, value_bytes)
    
        if classname(output_raw)==classname(Publish)
            output_raw=output_raw.value
        elif classname(output_raw)==classname(NoPublish)
            return
        else
            output_raw=value
        end
    
        return self.publish(name, output_raw) 
    
    end

    def publish(name, value)

        var topic=self.endpoint_data[name].find('out',{}).find('topic')
        
        if topic
            var converter=self.endpoint_data[name].find('out',{}).find('converter',/value->value)
            var output=json.dump({'value':converter(value)})
            log_debug([self.name,name,'Incoming publishing to state topic:', output, topic])        
            mqtt.publish(topic,output)
        end
    
        self.values[name]=value

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

    def init(name, options, entity_id, icon, callbacks)
        
        self.options=options
        super(self).init(name, entity_id, icon, callbacks)

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

    def init(name, number_range, mode, step, uom, entity_id, icon, callbacks)

        if number_range
            self.min=number_range.lower()
            self.max=number_range.upper()
        end

        self.mode=mode
        self.step=step
        self.uom=uom
        self.type=self.step==nil || self.step==1 ? int : real
        super(self).init(name, entity_id, icon, callbacks)      

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

    def init(name, uom, data_type, entity_id, icon, callbacks)

        self.uom=uom
        self.type=data_type==nil ? /value->value : data_type
        super(self).init(name, entity_id, icon, callbacks)

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

    def init(name, entity_id, icon, callbacks)

        super(self).init(name, entity_id, icon, callbacks)

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


    def init(name, entity_id, icon, callbacks)

        super(self).init(name, nil, nil ,entity_id, icon, callbacks)

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

class Text : Entity

    static var platform='text'
    static var mode='text'

    var size_min
    var size_max
    var pattern


    def init(name,entity_id, icon, size_range, pattern,callbacks)

        if size_range
            self.size_min=size_range.lower()
            self.size_max=size_range.upper()
        end

        super(self).init(name, entity_id, icon, callbacks)

    end


    def converter_state_in(value)
        return str(value)
    end

    def converter_state_out(value)
        return str(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()

        var data_update={
            'min':self.size_min,
            'max': self.size_max,
            'pattern': self.pattern,
            'mode': self.mode
        }

        data=update_map(data,data_update)


        return data

    end

end

class Password : Text
    static var mode='password'
end


class Humidifier : Entity

    static var platform='humidifier'
    static var device_class='humidifier'
    var modes
    var min_humidity
    var max_humidity

    var callback_outs_mode
    var callback_in_mode
    var callback_outs_target_humidity
    var callback_in_target_humidity

    def init(name, modes, humidity_range, entity_id, icon, callbacks, callback_outs_mode, callback_in_mode, callback_outs_target_humidity, callback_in_target_humidity)

        self.modes=modes

        if humidity_range
            self.min_humidity=humidity_range.lower()
            self.max_humidity=humidity_range.upper()
        end

        self.callback_outs_mode=callback_outs_mode
        self.callback_in_mode=callback_in_mode
        self.callback_outs_target_humidity=callback_outs_target_humidity
        self.callback_in_target_humidity=callback_in_target_humidity

        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)

        var name
        var direction
        var callbacks



        if self.callback_data.find('state',{}).find('in')
            data['state']['in']['converter']=to_bool
        end

        if self.callback_data.find('state',{}).find('out')
            data['state']['out']['converter']=from_bool
            data['state']['out']['template_key']='state_value_template'
        end

        name='mode'

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'mode_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'mode_state_template',
                'callbacks': callbacks
                }
        end
        
        direction='in'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('command',name),
                'topic_key': 'mode_command_topic',
                'callbacks': callbacks,
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', name].concat(' ')
        end

        name='target_humidity'

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'target_humidity_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'target_humidity_state_template',
                'callbacks': callbacks,
                'converter': int
                }
        end

        direction='in'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('command',name),
                'topic_key': 'target_humidity_command_topic',
                'callbacks': callbacks,
                'converter': int
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', name].concat(' ')
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


    def init(name, modes, speed_range, entity_id, icon, callbacks)

        self.modes=modes

        if speed_range
            self.min_speed=speed_range.lower()
            self.max_speed=speed_range.upper()
        end

        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)

        var name
        var callbacks
        var direction

        name='state'
        direction='in'

        if self.callback_data.find(name,{}).find(direction)
            data[name][direction]['converter']=to_bool
        end

        direction='out'
        if self.callback_data.find(name,{}).find(direction)
            data[name][direction]['converter']=from_bool
            data[name][direction]['template_key']='state_value_template'
        end

        data=self.add_endpoint_data(data,'preset_mode','out')
        data=self.add_endpoint_data(data,'preset_mode','in')
        data=self.add_endpoint_data(data,'percentage','out',int)
        data=self.add_endpoint_data(data,'percentage','in',int)
        data=self.add_endpoint_data(data,'oscillation','out',from_bool)
        data['oscillation']['out']['template_key']='oscillation_value_template'
        data=self.add_endpoint_data(data,'oscillation','in',to_bool)

        update_map(
            data['oscillation']['in'],
            {
                'payload_on': ON,
                'payload_on_key': 'payload_oscillation_on',
                'payload_off': OFF,
                'payload_off_key': 'payload_oscillation_off'
            }
        )

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

    def init(name, release_url, entity_picture, entity_id, icon, callbacks)

        self.entity_picture=entity_picture
        self.release_url=release_url        
        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)


        data['state']['in']['converter']=str # Required?
        data['state']['out']['converter']=str     # Required?

        var name
        var direction
        var callbacks

        name='latest_version'

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'latest_version_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'latest_version_template',
                'callbacks': callbacks
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

class Climate : Entity

    static var platform='climate'

    var modes
    var preset_modes
    var fan_modes
    var swing_modes
    var precision
    var type

    var temperature_unit
    var temperature_min
    var temperature_max

    var humidity_min
    var humidity_max

    var callback_outs_target_humidity
    var callback_in_target_humidity

    var callback_outs_temperature
    var callback_in_temperature

    var callback_outs_aux
    var callback_in_aux

    var callback_outs_current_humidity

    var callback_outs_current_temperature

    var callback_outs_fan_mode
    var callback_in_fan_mode

    var callback_outs_mode
    var callback_in_mode

    var callback_outs_preset_mode
    var callback_in_preset_mode

    var callback_outs_swing_mode
    var callback_in_swing_mode

    var callback_outs_temperature_high
    var callback_in_temperature_high

    var callback_outs_temperature_low
    var callback_in_temperature_low


    def init(name, entity_id, icon, temperature_unit, temperature_range, humidity_range, modes, preset_modes, fan_modes, swing_modes, precision ,callback_outs_temperature, callback_in_temperature, callback_outs_target_humidity, callback_in_target_humidity, callback_outs_aux, callback_in_aux, callback_outs_current_temperature,callback_outs_current_humidity , callback_outs_fan_mode, callback_in_fan_mode, callback_outs_mode, callback_in_mode, callback_outs_preset_mode, callback_in_preset_mode, callback_outs_swing_mode, callback_in_swing_mode, callback_outs_temperature_high, callback_in_temperature_high, callback_outs_temperature_low, callback_in_temperature_low)

        self.temperature_unit=temperature_unit

        if temperature_range
            self.temperature_min=temperature_range.lower()
            self.temperature_max=temperature_range.upper()
        end

        if humidity_range
            self.humidity_min=humidity_range.lower()
            self.humidity_max=humidity_range.upper()
        end

        self.precision=precision
        self.type=self.precision==nil?(self.temperature_unit=='C'?real:int): (self.precision==1?int:real)

        self.fan_modes=fan_modes
        self.modes=modes
        self.preset_modes=preset_modes
        self.swing_modes=swing_modes
        self.callback_outs_aux=callback_outs_aux
        self.callback_in_aux=callback_in_aux

        self.callback_outs_current_temperature=callback_outs_current_temperature
        self.callback_outs_current_humidity=callback_outs_current_humidity
        self.callback_outs_fan_mode=callback_outs_fan_mode
        self.callback_in_fan_mode=callback_in_fan_mode
        self.callback_outs_mode=callback_outs_mode
        self.callback_in_mode=callback_in_mode
        self.callback_outs_preset_mode=callback_outs_preset_mode
        self.callback_in_preset_mode=callback_in_preset_mode
        self.callback_outs_swing_mode=callback_outs_swing_mode
        self.callback_in_swing_mode=callback_in_swing_mode
        self.callback_outs_temperature=callback_outs_temperature
        self.callback_in_temperature=callback_in_temperature
        self.callback_outs_target_humidity=callback_outs_target_humidity
        self.callback_in_target_humidity=callback_in_target_humidity

        self.callback_outs_temperature_high=callback_outs_temperature_high
        self.callback_in_temperature_high=callback_in_temperature_high

        self.callback_outs_temperature_low=callback_outs_temperature_low
        self.callback_in_temperature_low=callback_in_temperature_low

        super(self).init(name, entity_id, icon, nil, nil)

    end

    def extend_endpoint_data(data)

        var name
        var callbacks
        var direction

        name='temperature'
        if self.callback_outs_temperature
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': 'temperature_state_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'temperature_state_template',
                'callbacks': self.callback_outs_temperature,
                'converter': /value->self.type(value)
                }
        end

        if self.callback_in_temperature
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': 'temperature_command_topic',
                'callbacks': self.callback_in_temperature,
                'converter': /value->self.type(value)
                }
        end

        name='target_humidity'
        callbacks=self.callback_outs_target_humidity
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end


        


        callbacks=self.callback_in_target_humidity
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end

        name='aux'
        if self.callback_outs_aux
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': self.callback_outs_aux,
                'converter': from_bool
                }
        end

        if self.callback_in_aux
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': self.callback_in_aux,
                'converter': to_bool
                }
        end

        name='current_humidity'
        callbacks=self.callback_outs_current_humidity
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'topic'].concat('_'), #NON STANDARD
                'template':VALUE_TEMPLATE,
                'template_key': [name,'template'].concat('_'), #NON STANDARD
                'callbacks': callbacks,
                'converter': int
                }
        end

        name='current_temperature'
        callbacks=self.callback_outs_current_temperature
        if self.callback_outs_current_humidity
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'topic'].concat('_'), #NON STANDARD
                'template':VALUE_TEMPLATE,
                'template_key': [name,'template'].concat('_'), #NON STANDARD
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end

        name='fan_mode'
        callbacks=self.callback_outs_fan_mode
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks
                }
        end

        callbacks=self.callback_in_fan_mode
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks
                }
        end

        name='mode'
        callbacks=self.callback_outs_mode
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks
                }
        end

        callbacks=self.callback_in_mode
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks
                }
        end

        name='preset_mode'
        callbacks=self.callback_outs_preset_mode
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'value_template'].concat('_'),
                'callbacks': callbacks
                }
        end

        callbacks=self.callback_in_preset_mode
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks
                }
        end

        name='swing_mode'
        callbacks=self.callback_outs_swing_mode
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks
                }
        end

        callbacks=self.callback_in_swing_mode
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks
                }
        end

        name='swing_mode'
        callbacks=self.callback_outs_swing_mode
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks
                }
        end

        callbacks=self.callback_in_swing_mode
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks
                }
        end

        name='temperature_high'
        callbacks=self.callback_outs_temperature_high
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end

        callbacks=self.callback_in_temperature_high
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end

        name='temperature_low'
        callbacks=self.callback_outs_temperature_low
        if callbacks
            set_default(data,name,{})
            data[name]['out']={
                'topic': self.get_topic('state',name),
                'topic_key': [name,'state_topic'].concat('_'),
                'template':VALUE_TEMPLATE,
                'template_key': [name,'state_template'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end

        callbacks=self.callback_in_temperature_low
        if callbacks
            set_default(data,name,{})
            data[name]['in']={
                'topic': self.get_topic('command',name),
                'topic_key': [name,'command_topic'].concat('_'),
                'callbacks': callbacks,
                'converter': /value->self.type(value)
                }
        end


        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={

            'payload_on':ON,
            'payload_off':OFF,
            'fan_modes':self.fan_modes,
            'preset_modes':self.preset_modes,
            'swing_modes':self.swing_modes,
            'modes':self.modes,
            'min_temp':self.temperature_min,
            'max_temp':self.temperature_max,
            'min_humidity':self.humidity_min,
            'max_humidity':self.humidity_max,
            'precision': self.precision,
            'temperature_unit':self.temperature_unit

        }

        data=update_map(data,data_update)

        return data

    end

end

def expose_updater(org,repo,version_current,callback_update)

    org=org?org:'fmtr'
    repo=repo?repo:'hct'
    version_current=version_current?version_current:VERSION
    callback_update=callback_update?callback_update:/value->NoPublish(update_hct(value))
    
    
    var trigger='cron:0 0 */12 * * *'

    def callback_latest(value)
        var version=get_latest_version(org,repo)
        return version?version:NoPublish()
    end

    def callback_current(value)
        return version_current
    end

    var updater=Update(
        ['Update (',repo,')'].concat(),
        ['https://github.com',org,repo,'releases/latest'].concat('/'),
        nil,
        nil,
        nil,
        [
            CallbackOut(trigger, callback_current),
            CallbackIn(callback_update),
            CallbackOut(trigger, callback_latest,'latest_version')
        ]
        
    )

    def callback_force_publish(value)
        updater.callbacks_wrappeds[callback_current]()
        updater.callbacks_wrappeds[callback_latest]()
        return version_current
    end

    var button_check=Button(
        ['Update (',repo,') Check'].concat(),
        nil,
        'mdi:source-branch-sync',
        [
            CallbackIn(callback_force_publish)
        ]
    )
    
    return updater

end

def expose_updater_tasmota()
    
    var version_current=tasmota.cmd('status 2').find('StatusFWR',{}).find('Version','Unknown')
    version_current=string.replace(version_current,'(tasmota)','')
    
    return expose_updater('arendst','Tasmota',version_current,/value->tasmota.cmd('upgrade 1'))   

end

# Start module definition.

var hct = module(NAME)

hct.VERSION=VERSION
hct.Config=Config

hct.Select=Select
hct.Number=Number
hct.Text=Text
hct.Password=Password
hct.Sensor=Sensor
hct.Button=Button
hct.Switch=Switch
hct.BinarySensor=BinarySensor

hct.Humidifier=Humidifier
hct.Dehumidifier=Dehumidifier
hct.Climate=Climate

hct.Fan=Fan

hct.Update=Update

hct.Publish=Publish
hct.NoPublish=NoPublish
hct.CallbackOut=CallbackOut
hct.CallbackIn=CallbackIn

hct.add_rule_once=add_rule_once
hct.reverse_map=reverse_map
hct.get_keys=get_keys
hct.download_url=download_url
hct.read_url=read_url
hct.log_debug=log_debug

hct.get_latest_version=get_latest_version

hct.expose_updater=expose_updater
hct.expose_updater_tasmota=expose_updater_tasmota

log_debug("hct.be compiled OK.")

return hct