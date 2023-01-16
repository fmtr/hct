import mqtt
import json
import string
import math

def get_mac()
    var mac=tasmota.eth().find('mac', tasmota.wifi().find('mac', nil))	
    if !mac
        raise "Couldn't get MAC address"
    end
    return mac
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

CHARS_ALLOWED=to_chars('abcdefghijklmnopqrstuvwxyz0123456789_-')
TOPIC=get_topic()
DEVICE_NAME=get_device_name()
TOPIC_LWT=['tele',TOPIC,'LWT'].concat('/')	
MAC=get_mac()
TYPES_LITERAL=['string']
RULE_MQTT_CONNECTED='Mqtt#Connected'

def infer_serialisation(value)    
    if TYPES_LITERAL.find(type(value))==nil
        return  json.dump(value)
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
    mqtt.publish(entity.topic_state,output)   
    return true 

end
  
class Entity

  static var platform=nil
  static var mac=string.split(string.tolower(MAC),':').concat()  

  var topic_command
  var topic_state
  var topic_announce
  var name  
  var name_sanitized
  var unique_id
  var entity_id
  var icon 
  
  def init(name, entity_id, icon, handle_outgoings, handle_incoming)
  
    self.name=name
	self.entity_id=entity_id
    self.icon=icon	

    self.name_sanitized=sanitize_name(self.name)		

	self.topic_command=['cmnd',TOPIC, string.toupper(self.name_sanitized)].concat('/')		
	self.topic_state=['stat',TOPIC,string.toupper(self.name_sanitized)].concat('/')	
	self.topic_announce=['homeassistant',self.platform,TOPIC,self.get_unique_id(),'config'].concat('/')    

    print(handle_outgoings)
    print(handle_incoming)

    if type(handle_outgoings)=='string'
        handle_outgoings={(/ value -> value):handle_outgoings}
    end
	
    handle_outgoings= handle_outgoings ? handle_outgoings : {}

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
            tasmota.add_rule(trigger_handler,closure_outgoing)
        end
    end

    handle_incoming= handle_incoming ? handle_incoming : (/ value -> value)    
	var closure_incoming=(
        / topic code value value_bytes -> 
        handle_incoming_wrapper(handle_incoming, self, topic, code, value, value_bytes)      
    )  
    mqtt.subscribe(self.topic_command, closure_incoming)

    tasmota.add_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())
    self.announce()
	
	    
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
		'state_topic': self.topic_state,
		'command_topic': self.topic_command,	
		
    }

    if self.icon data['icon']=self.icon end
    if self.entity_id data['object_id']=self.entity_id end    

    return data
  
  end
  
  def announce()	
	return mqtt.publish(self.topic_announce, json.dump(self.get_data_announce()))
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
    var step

  def init(name, min, max, step, entity_id, icon, handle_outgoings, handle_incoming)
    
    self.min=min
    self.max=max
    self.step=step

    super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

  end

  def is_int()

    return self.step==nil || self.step==1

  end

  def get_data_announce()

      var data=super(self).get_data_announce()

      if self.min data['min']=self.min end
      if self.max data['max']=self.max end
      if self.step data['step']=self.step end      

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

