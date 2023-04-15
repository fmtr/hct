import hct_constants as constants
import hct_callback as callback
import hct_tools as tools
import hct_config
import mqtt
import json
import string

var Config=hct_config.Config

var TOPIC=tools.get_topic()
var TOPIC_LWT=tools.get_topic_lwt()
var MAC=tools.get_mac()
var MAC_SHORT=tools.get_mac_short()
var MAC_LAST_SIX=tools.get_mac_last_six()
var DEVICE_NAME=tools.get_device_name()
var RULE_MQTT_CONNECTED='Mqtt#Connected'

class UseDeviceName

end

class Entity

    static var platform=nil
    #static var mac=string.split(string.tolower(MAC),':').concat()

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

        self.name=self.get_name(name)
        self.entity_id=entity_id
        self.icon=icon
        self.name_sanitized=tools.sanitize_name(self.name)

        callbacks=classname(callbacks)=='list'?callbacks:[callbacks]
        self.callback_data={}
        for cb : callbacks
            tools.set_default(self.callback_data, cb.endpoint,{})
            tools.set_default(self.callback_data[cb.endpoint], cb.direction,[])
            self.callback_data[cb.endpoint][cb.direction].push(cb)
        end

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

    def get_name(name)

        if classname(name)==classname(UseDeviceName)
            return DEVICE_NAME
        end

        if Config.USE_LONG_NAMES
            name=[
                Config.DEVICE_NAME?Config.DEVICE_NAME:DEVICE_NAME,
                name
            ].concat(' ')
        end

        return name
    end

    def get_endpoint_data()

        var data={}

        var name
        var direction
        var callbacks

        name='state'

        direction=constants.IN
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
            data[name][constants.IN]={
                'topic': self.get_topic('command',name),
                'topic_key': 'command_topic',
                'callbacks': callbacks,
                'converter': /value->self.converter_state_in(value)
                }
        end

        direction=constants.OUT
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
            data[name][constants.OUT]={
                'topic': self.get_topic('state',name),
                'topic_key': 'state_topic',
                'template':constants.VALUE_TEMPLATE,
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

    def add_endpoint_data(data,name,dir,converter,extensions)

        var callbacks=self.callback_data.find(name,{}).find(dir)
        if !callbacks
            return
        end

        extensions=extensions?extensions:{}

        var dir_mqtt={constants.IN:'command',constants.OUT:'state'}[dir]

        var data_update={
                'topic': self.get_topic(dir_mqtt,name),
                'topic_key': [name,dir_mqtt,'topic'].concat('_'),
                'callbacks': callbacks,
                (converter?'converter':converter):converter
            }

        if dir==constants.OUT
            data_update=tools.update_map(
                data_update,
                {
                    'template':constants.VALUE_TEMPLATE,
                    'template_key': [name,dir_mqtt,'template'].concat('_')
                }
            )
        end

        data_update=tools.update_map(
            data_update,
            extensions
        )

        data=tools.set_default(data,name,{})
        data[name][dir]=data_update

        return data


    end

    def register_rule(trigger,closure)
        var id=[str(classname(self)),str(closure)].concat('_')
        if trigger==nil
            tools.log_debug([self.name,'Got nil trigger so skipping rule',id])
            return nil
        end
        var entry=tools.add_rule(id,trigger,closure)
        tools.log_debug([self.name,'Adding rule',entry,id])
        self.rule_registry[id]=entry
        return id
    end

    def subscribe_announce()
        self.register_rule(RULE_MQTT_CONNECTED,/ value trigger message -> self.announce())
    end

    def subscribe_out(name)

        var callback_outs=self.endpoint_data[name].find(constants.OUT,{}).find('callbacks')

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
                callback_obj.callbackw=closure_outgoing

            end
        end
    end

    def callback_out_wrapper(cbo, name, value_raw, trigger, message)

        tools.log_debug([self.name,'Outgoing input:', cbo, self,name, value_raw, trigger, message])

        var cb_data=callback.Data(
            name, #name
            value_raw, #value
            self, #entity
            cbo, #callback_obj
            value_raw, #value_raw
            trigger, #trigger
            message, #message
            nil, #topic
            nil, #code
            nil #value_bytes
        )

        var output_raw=cbo.callback(value_raw,cb_data)

        tools.log_debug([self.name,'Outgoing callback output:',name, output_raw])

        if classname(output_raw)==classname(callback.NoPublish)
            return
        end

        if output_raw==nil
            output_raw=value_raw
        end

        self.publish(name,output_raw, cbo.dedupe)

    end

    def subscribe_in(name)

        var callback_ins=self.endpoint_data[name].find(constants.IN,{}).find('callbacks')

        if !callback_ins
            return
        end

        assert self.endpoint_data[name].contains(constants.IN)
        var topic=self.endpoint_data[name][constants.IN]['topic']

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
            callback_obj.callbackw=closure_incoming

        end

    end

    def callback_in_wrapper(cbo, name, topic, code, value_raw, value_bytes)

        tools.log_debug([self.name,'Incoming input:', cbo, self, name, topic, code, value_raw, value_bytes])

        var converter=self.endpoint_data[name].find(constants.IN,{}).find('converter',/value->value)

        var value=converter(value_raw)

        var cb_data=callback.Data(
            name, #name
            value, #value
            self, #entity
            cbo, #callback_obj
            value_raw, #value_raw
            nil, #trigger
            nil, #message
            topic, #topic
            code, #code
            value_bytes #value_bytes
        )

        var output_raw=cbo.callback(value,cb_data)

        if classname(output_raw)==classname(callback.Publish)
            output_raw=output_raw.value
        elif classname(output_raw)==classname(callback.NoPublish)
            return
        else
            output_raw=value
        end

        return self.publish(name, output_raw, cbo.dedupe)

    end

    def publish(name, value, dedupe)

        var topic=self.endpoint_data[name].find(constants.OUT,{}).find('topic')

        if topic

            if dedupe && self.values.find(name)==value
                tools.log_debug([self.name,name,'not publishing duplicate value', value, topic])
            else
                var converter=self.endpoint_data[name].find(constants.OUT,{}).find('converter',/value->value)
                var output=json.dump({'value':converter(value)})
                tools.log_debug([self.name,name,'publishing', output, topic])
                mqtt.publish(topic,output,true)
            end
            
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

        if string.find(string.tolower(TOPIC),string.tolower(MAC_LAST_SIX))<0
            uid_segs+=[MAC_SHORT]
        end
        uid_segs+=[self.name]

        var unique_id=tools.sanitize_name(uid_segs.concat(' '), '_')

        return unique_id

    end

    def get_data_announce()

        var data
        data= {
            'device': {
                'connections': [['mac', MAC_SHORT]],
                'identifiers': MAC_SHORT
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
            for io_data: [dir_data.find(constants.IN,{}),dir_data.find(constants.OUT,{})]
                for keyfix: ['topic','template','payload_on','payload_off']
                    data_update[io_data.find(keyfix+'_key')]=io_data.find(keyfix)
                end
            end
        end

        data=tools.update_map(data,data_update)

        return data

    end

    def announce()
        var data=self.get_data_announce()
        tools.log_debug([self.name, 'Doing announce', data])
        return mqtt.publish(self.topic_announce, json.dump(data), true)
    end

    def close()

        tools.log_debug(['Closing',classname(self),self.name,'...'].concat(' '))
        var entry
        for id: self.rule_registry.keys()
            entry=self.rule_registry[id]
            tools.remove_rule(id, entry)
        end
    end

    def converter_state_in(value)
        return str(value)
    end

    def converter_state_out(value)
        return str(value)
    end

end

import tools as tools_be
return tools_be.module.create_module(
    'hct_entity',
    [
        Entity,
        UseDeviceName
    ]
)