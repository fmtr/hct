import mqtt
import json
import string

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

def to_chars(s)
    var chars=[]
    for i: 0..(size(s)-1) 
        chars.push(s[i]) 
    end 
    return chars
end





CHARS_ALLOWED=to_chars('abcdefghijklmnopqrstuvwxyz0123456789_-')
TOPIC=get_topic()
TOPIC_LWT=['tele',TOPIC,'LWT'].concat('/')	
MAC=get_mac()
TYPES_LITERAL=['string','int','real']
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
        if CHARS_ALLOWED.find(c)
            chars.push(c)
        else
            chars.push(sep)
        end        
    end 
    return chars.concat()
end

def handle_incoming_default(value, topic, code, value_raw, value_bytes)    
    var value_str={'value':value,'topic':topic,'code':code,'value_raw':value_raw,'value_bytes':value_bytes}.tostring()
	print('Command Handler got '+value_str)
    print('Either provide a function/closure as a `handle_incoming` parameter, or override the `handle_incoming` method')

  end
  
  def handle_state_default(value, trigger, message)
    var value_str={'value':value,'trigger':trigger,'message':message}.tostring()
	print('State Handler got '+value_str)
    print('Either provide a function/closure as a `handle_outgoings` parameter, or override the `handle_outgoings` method')

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
	self.entity_id=nil
    self.icon=icon	

    self.name_sanitized=sanitize_name(self.name)		

	self.topic_command=['cmnd',TOPIC, string.toupper(self.name_sanitized)].concat('/')		
	self.topic_state=['stat',TOPIC,string.toupper(self.name_sanitized)].concat('/')	
	self.topic_announce=['homeassistant',self.platform,TOPIC,self.get_unique_id(),self.mac,'config'].concat('/')    
	
    handle_outgoings= handle_outgoings ? handle_outgoings : {} 
    var closure_state 
    var handler
    for rule: handle_outgoings.keys()
        handler=handle_outgoings[rule]
        closure_state=(
            / value trigger message -> 
            mqtt.publish(
                self.topic_state, 
                infer_serialisation(
                    handler(value, trigger, message)
                )
            )
        )
        tasmota.add_rule(string.toupper(rule),closure_state)
    end

    handle_incoming= handle_incoming ? handle_incoming : handle_incoming_default    
	var closure_command=(
        / topic code value value_bytes -> 
        bool(
                [
                    handle_incoming(self.options_map.find(value), topic, code, value, value_bytes), 
                    mqtt.publish(self.topic_state,value)
                ]
            )
    )
	mqtt.subscribe(self.topic_command, closure_command)

    tasmota.add_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())
    self.announce()
	
	    
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
	  var options_map      

	def init(name, options, entity_id, icon, handle_outgoings, handle_incoming)
	  

      if classname(options)=='list'       
        
        self.options=options
        
        self.options_map={} 
        for option: options
          self.options_map[option]=option		
        end	  	  
        
      else
        
        self.options_map=options
  
        self.options=[] 
        for option: options.keys()
          self.options.push(option)
        end	
        
      end

      super(self).init(name, entity_id, icon, handle_outgoings, handle_incoming)      

	end

    def get_data_announce()
  
        var data=super(self).get_data_announce()
        data['options']=self.options        

        return data

    end
end


# Write an incoming handler to tell Tasmota about changes on the Home Assistant side.

def set_relay_state(value)
    
    print('USER Command Handler got '+[value].tostring())

    if value=='H'
        tasmota.set_power(1,true)
    else
        tasmota.set_power(1,false)
    end
end

# Write an outgoing handler to tell Home Assistant about changes on the Tasmota side.

def publish_relay_state(value)

    print('USER State/Outgoing Handler got '+[value].tostring())
    
    if tasmota.get_power()[1]
        return 'H'
    else
        return 'L'
    end
end

select=Select(   
   'West Window Speed Select',              # Name   
   {'L':'L','M':'M','H':'H'},               # Options   
   nil,                                     # Entity ID
   'mdi:alert',                             # Icon
   {                                        # Mapping from rules to outgoing handlers, 
    'Power2':publish_relay_state, 
    'Mqtt#Connected': publish_relay_state
    },                          
    set_relay_state                          # Incoming handler, to tell Tasmota about changes on the Home Assistant side.
   )

print(select.get_unique_id())

