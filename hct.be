var VERSION='0.0.18'
import mqtt
import json
import string
import math

class Config

    # Module-wide configuration
    
    static var USE_LONG_NAMES=false
    static var IS_DEBUG=false
    
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


    as_str=[str(tasmota.cmd('Time').find('Time')),as_str].concat(':')
    print(as_str)

end

log_debug("hct.be compiling...")

var RULE_MQTT_CONNECTED='Mqtt#Connected'
var MAC_EMPTY='00:00:00:00:00:00'
var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

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

# End of utility functions.

class Publish
    var value

    def init(value)
        self.value=value
    end
end

class NoPublish    
end


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

    log_debug([entity.name,'Outgoing handler output:', output_raw])

      if classname(output_raw)==classname(NoPublish)
          return    
      end
      
      if output_raw==nil 
          output_raw=value_raw
      end    

      var output=json.dump({'value':converter(output_raw)})

      log_debug([entity.name,'Outgoing handler publishing:',entity.name, output])

      mqtt.publish(topic,output)    # topic_state
      entity.value=output_raw
end

def handle_incoming_wrapper(handler, entity, name, topic, code, value_raw, value_bytes)

  var converter=entity.endpoint_data[name].find('in',{}).find('converter',/value->value)
  var topic_out=entity.endpoint_data[name].find('out',{}).find('topic')
  
  var value=converter(value_raw)
  var output_raw=handler(value,entity, topic, code, value_raw, value_bytes)

  if classname(output_raw)==classname(Publish)
      output_raw=output_raw.value
  else
      output_raw=value
  end

  var output=json.dump({'value':output_raw})

  if topic_out
      mqtt.publish(topic_out,output)   #topic_state
  end

  entity.value=output_raw

  return true 

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

class Entity

  static var platform=nil
  static var mac=string.split(string.tolower(MAC),':').concat()  

  static var has_in=true
  static var has_out=true

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

    self.rule_registry={}
    #self.register_rule('System#Save',/value->self.close())

    #self.set_topics()
    self.topic_announce=self.get_topic_announce()

    self.subscribe_announce()


    self.endpoint_data=self.extend_endpoint_data(self.get_endpoint_data(handle_outgoings, handle_incoming))    

    for key: self.endpoint_data.keys()
      self.subscribe_out(key)
      self.subscribe_in(key)
    end



    var mqtt_count=tasmota.cmd('status 6').find('StatusMQT',{}).find('MqttCount',0)
    if mqtt_count>0
        self.announce()    
    end
        
  end

  def get_endpoint_data(handle_outgoings, handle_incoming)

    var data={'state':{'in':{},'out':{}}}

    if self.has_in
        data['state']['in']={
            'topic': self.get_topic('command','state'),
            'topic_key': 'command_topic',
            'callbacks': handle_incoming,
            'converter': /value->self.converter_state_in(value)
          }
    end

    if self.has_out
        data['state']['out']={
            'topic': self.get_topic('state','state'),
            'topic_key': 'state_topic',
            'template':VALUE_TEMPLATE,
            'template_key': 'value_template',
            'callbacks': handle_outgoings,
            'converter': /value->self.converter_state_out(value)
          }
    end

    return data

  end

  def extend_endpoint_data(data)

    return data

  end

    def set_topics()

        self.topic_command=self.get_topic('command','state')	
        self.topic_state=self.get_topic('state','state')

    end

  def register_rule(trigger,closure)
    var id=[str(classname(self)),str(closure)].concat('_')

    log_debug([self.name,'Adding rule',trigger,closure,id])

    tasmota.add_rule(trigger,closure,id)
    self.rule_registry[id]=trigger
    return id
  end

  def subscribe_announce()
    self.register_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())    
  end

    def subscribe_out(name)      

        var handle_outgoings=self.endpoint_data[name]['out'].find('callbacks')

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

      var topic=self.endpoint_data[name]['in'].find('topic')
        if !topic
            return
        end

        var handle_incoming=self.endpoint_data[name]['in'].find('callbacks')

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
        for keyfix: ['topic','template']
          data_update[io_data.find(keyfix+'_key')]=io_data.find(keyfix)
        end
      end
    end

    data=update_map(data,data_update)

    return data

  end
  
  def announce()	
    return mqtt.publish(self.topic_announce, json.dump(self.get_data_announce()))
  end

  def close()

    log(['Closing',classname(self),self.name,'...'].concat(' '))
    var trigger
    for id: self.rule_registry.keys()
        trigger=self.rule_registry[id]        
        tasmota.remove_rule(trigger,id)
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
    static var has_in=false
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
    static var has_out=false
    var uom

  def init(name, entity_id, icon, handle_incoming)        
    
    super(self).init(name, entity_id, icon, nil, handle_incoming)      

  end

    def set_topics()

        self.topic_command=self.get_topic('command','state')	    

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
    static var has_in=false 
    
    
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

import uuid


def add_rule_once(trigger, function)

    var id=uuid.uuid4()

    def wrapper(value, trigger_wrapper, message)                
        tasmota.remove_rule(trigger,id)        
        return function(value, trigger_wrapper, message)
    end
    
    tasmota.add_rule(trigger,wrapper, id)    

end

var hct = module("hct")

hct.VERSION=VERSION

hct.Config=Config

hct.add_rule_once=add_rule_once

hct.Select=Select
hct.Number=Number
hct.Sensor=Sensor
hct.Button=Button
hct.Switch=Switch
hct.BinarySensor=BinarySensor

hct.Publish=Publish
hct.NoPublish=NoPublish
hct.reverse_map=reverse_map
hct.get_keys=get_keys


log_debug("hct.be compiled OK.")

return hct