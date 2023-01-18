import mqtt
import json
import string
import math

var hct = module("hct")

def get_mac()
    var mac_empty='00:00:00:00:00:00'
    var status_net=tasmota.cmd('status 5').find('StatusNET',{})
    var mac_wifi=status_net.find('Mac', mac_empty)
    var mac_ethernet=status_net.find('Ethernet', {}).find('Mac', mac_empty)    
    
    if [mac_empty,nil].find(mac_ethernet)==nil
        return mac_ethernet
    elif [mac_empty,nil].find(mac_wifi)==nil
        return mac_wifi
    end
    
    raise "Couldn't get MAC address"
end

def get_topic()
    var topic=tasmota.cmd('topic').find('Topic')
    if !topic
        raise "Couldn't get topic"
    end
    return topic
end

def get_device_name()
    var device_name=tasmota.cmd('DeviceName').find('DeviceName')
    if !device_name
        raise "Couldn't get device name"
    end
    return device_name
end

def to_chars(s)
    var chars=[]
    for i: 0..(size(s)-1) 
        chars.push(s[i]) 
    end 
    return chars
end

var CHARS_ALLOWED=to_chars('abcdefghijklmnopqrstuvwxyz0123456789_-')
var TOPIC=get_topic()
var DEVICE_NAME=get_device_name()
var TOPIC_LWT=['tele',TOPIC,'LWT'].concat('/')	
var MAC=get_mac()
var TYPES_LITERAL=['string']
var RULE_MQTT_CONNECTED='Mqtt#Connected'

def infer_serialisation(value)    
    if TYPES_LITERAL.find(type(value))==nil
        return json.dump(value)
    else
        return value
    end
end

def sanitize_name(s, sep)
    sep= sep ? sep : '-'
    var chars=[]
    for c: to_chars(string.tolower(s))
        if CHARS_ALLOWED.find(c)==nil
            chars.push(sep)
        else
            chars.push(c)
        end        
    end 
    return chars.concat()
end

def handle_incoming_default(value, topic, code, value_raw, value_bytes)    
    var value_str={'value':value,'topic':topic,'code':code,'value_raw':value_raw,'value_bytes':value_bytes}.tostring()
	print('Command Handler got '+value_str)
    print('Either provide a function/closure as a `handle_incoming` parameter, or override the `handle_incoming` method')

  end

  def handle_outgoing_wrapper(handler, entity, value_raw, trigger, message)

    if type(handler)=='string'
        print("handler is string.:"+handler)
        return
    end

    if type(entity)=='string'
        print("Entity is string. Entity has gone? "+entity)
        return
    end

    var value=entity.translate_value_out(value_raw)
    var output_raw=handler(value,entity, value_raw, trigger, message)
    if output_raw==nil 
        output_raw=value
    end
    var output=infer_serialisation(output_raw)
    mqtt.publish(entity.topic_state,output)    

end

def handle_incoming_wrapper(handler, entity, topic, code, value_raw, value_bytes)

    var value=entity.translate_value_in(value_raw)
    var output_raw=handler(value,entity, topic, code, value_raw, value_bytes)
    if output_raw==nil 
        output_raw=value
    end
    var output=infer_serialisation(output_raw)

    if entity.has_state
        mqtt.publish(entity.topic_state,output)   
    end

    return true 

end

def list_to_map(as_list)
    var as_map={}
    for value: as_list
        as_map[/value->value]=value
    end
    return as_map
end
  
class Entity

  static var platform=nil
  static var mac=string.split(string.tolower(MAC),':').concat()  
  static var has_state=true
  static var has_command=true

  var topic_command
  var topic_state
  var topic_announce
  var name  
  var name_sanitized
  var unique_id
  var entity_id
  var icon 
  var rule_registry
  
  def init(name, entity_id, icon, handle_outgoings, handle_incoming)
  
    self.name=name
	self.entity_id=entity_id
    self.icon=icon	
    self.name_sanitized=sanitize_name(self.name)		

    self.rule_registry={}
    self.register_rule('System#Save',/value->self.close())

	self.topic_command=self.get_topic_command()	
	self.topic_state=self.get_topic_state()
	self.topic_announce=self.get_topic_announce()

    self.subscribe_announce()
    self.subscribe_out(handle_outgoings)
    self.subscribe_in(handle_incoming)

    var mqtt_count=tasmota.cmd('status 6').find('StatusMQT',{}).find('MqttCount',0)
    if mqtt_count>0
        self.announce()    
    end
	    
  end

  def register_rule(trigger,closure)
    var id=[str(classname(self)),str(closure)].concat('_')
    tasmota.add_rule(trigger,closure,id)
    self.rule_registry[id]=trigger
    return id
  end

  def subscribe_announce()
    self.register_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())    
  end

    def subscribe_out(handle_outgoings)

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
                    handle_outgoing_wrapper(handler, self, value, trigger, message)
                )
                self.register_rule(trigger_handler,closure_outgoing)
                
            end
        end
    end

    def subscribe_in(handle_incoming)


        if !self.has_command
            return
        end

        handle_incoming= handle_incoming ? handle_incoming : (/ value -> value)    
        var closure_incoming=(
            / topic code value value_bytes -> 
            handle_incoming_wrapper(handle_incoming, self, topic, code, value, value_bytes)      
        )  
        mqtt.subscribe(self.topic_command, closure_incoming)

    end

    def get_topic_command()

        if !self.has_command
            return
        end

        return ['cmnd',TOPIC, string.toupper(self.name_sanitized)].concat('/')	
    end

    def get_topic_state()

        if !self.has_state
            return
        end

        return ['stat',TOPIC,string.toupper(self.name_sanitized)].concat('/')	
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

    if self.topic_command data['command_topic']=self.topic_command end
    if self.topic_state data['state_topic']=self.topic_state end
    if self.icon data['icon']=self.icon end
    if self.entity_id data['object_id']=self.entity_id end    

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

  def translate_value_in(value)
      return self.options_map_in.find(value)
  end

  def translate_value_out(value)
      return self.options_map_out.find(value)
  end

end


class Number : Entity

    static var platform='number'
    var min
    var max
    var mode
    var step
    var uom

  def init(name, min, max, mode, step, uom, entity_id, icon, handle_outgoings, handle_incoming)
    
    self.min=min
    self.max=max
    self.mode=mode
    self.step=step
    self.uom=uom

    super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

  end

  def is_int()

    return self.step==nil || self.step==1

  end

  def get_data_announce()

      var data=super(self).get_data_announce()

      if self.min data['min']=self.min end
      if self.max data['max']=self.max end
      if self.mode data['mode ']=self.mode end      
      if self.step data['step']=self.step end      
      if self.uom data['unit_of_measurement']=self.uom end      
      

      return data

  end

  def translate_value_in(value)

    if self.is_int()
        return int(value)
    else
        return real(value)
    end
  end

end

class Sensor : Entity

    static var platform='sensor'
    static var has_command=false
    var uom

  def init(name, uom, entity_id, icon, handle_outgoings)    
    
    self.uom=uom
    super(self).init(name, entity_id, icon, handle_outgoings, nil)      

  end

  def get_data_announce()

      var data=super(self).get_data_announce()     
      if self.uom data['unit_of_measurement']=self.uom end      
      return data

  end


end

class Button : Entity

    static var platform='button'
    static var has_state=false
    var uom

  def init(name, entity_id, icon, handle_incoming)        
    
    super(self).init(name, entity_id, icon, nil, handle_incoming)      

  end

end

hct.Select=Select
hct.Number=Number
hct.Sensor=Sensor
hct.Button=Button

def setup_t21()

    log("Setting up Proscenic T21...")

    var options={'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4,'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10}

    def set_cookbook_entry(value)
        tasmota.cmd('TuyaEnum1 '+str(value))
    end

    var trigger='tuyareceived#dptype4id3'

    hct.Select(   
        'Air Fryer Cookbook',    # Entity name   
        options,                 # The options we defined above.
        nil,                     # Entity ID (or leave as `nil` if you're happy for Home Assistant to decide)
        'mdi:chef-hat',          # Icon the entity should have in Home Assistant    
        trigger,                 # Our trigger as above.  
        set_cookbook_entry       # The handler function we defined above.
    )   


    hct.Number(
        'Air Fryer Cooking Temp (F)',
        170,
        399,
        'slider',
        nil,
        '°F',
        nil,
        'mdi:temperature-fahrenheit',
        'tuyareceived#dptype2id103',
        /value->tasmota.cmd('TuyaSend2 103,'+str(value))
    )

    hct.Number(
        'Air Fryer Cooking Temp (C)',
        77,
        204,
        'slider',
        nil,
        '°C',
        nil,
        'mdi:temperature-celsius',
        {
            /value->math.ceil((value-32)/1.8): 'tuyareceived#dptype2id103'
        },
        /value->tasmota.cmd('TuyaSend2 103,'+str(int((value*1.8)+32)))
    )

    hct.Number(
        'Air Fryer Cooking Time',
        1,
        60,
        'box',
        nil,
        'minutes',
        nil,
        'mdi:timer',
        'tuyareceived#DpType2Id7',
        /value->tasmota.cmd('TuyaSend2 7,'+str(value))
    )

    hct.Number(
        'Air Fryer Keep Warm Time',
        5,
        120,
        'box',
        nil,
        'minutes',
        nil,
        'mdi:timer',
        {
            /v->v:'tuyareceived#DpType2Id105',
            /v->5:'power3#state'
            
        },        
        def (value)
            tasmota.set_power(2,true)
            tasmota.cmd('TuyaSend2 105,'+str(value))
            return nil 
        end 
    )

    hct.Number(
        'Air Fryer Delay Time',
        5,
        720,
        'box',
        nil,
        'minutes',
        nil,
        'mdi:timer-pause',
        {
            /v->v:'tuyareceived#DpType2Id6',
            /v->5:'power4#state'
            
        },
        def (value) tasmota.set_power(3,true) tasmota.cmd('TuyaSend2 6,'+str(value)) return nil end 
    )

    hct.Sensor(        
        'Air Fryer Test Sensor',
        'foos',
        nil,
        'mdi:timer-10',
        {/value->math.rand():'Time#Minute'}
    )

    hct.Button(        
        'Upgrade Button',
        nil,
        'mdi:update',
        /value->print("Upgrade button pressed.")
    )

    hct.Sensor(        
        'Free Space',
        'kB',
        nil,
        'mdi:harddisk-plus',
        {
            /value->tasmota.cmd('ufsfree').find('UfsFree','Unknown'):
            'Time#Minute'
        }
    )


end

hct.setup_t21=setup_t21

return hct
