import hct_entity
import hct_tools as tools

var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

class Humidifier : hct_entity.Entity

    static var platform='humidifier'
    static var device_class='humidifier'
    var modes
    var min_humidity
    var max_humidity

    def init(name, modes, humidity_range, entity_id, icon, callbacks)

        self.modes=modes

        if humidity_range
            self.min_humidity=humidity_range.lower()
            self.max_humidity=humidity_range.upper()
        end

        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)

        var name
        var direction
        var callbacks

        if self.callback_data.find('state',{}).find('in')
            data['state']['in']['converter']=tools.to_bool
        end

        if self.callback_data.find('state',{}).find('out')
            data['state']['out']['converter']=tools.from_bool
            data['state']['out']['template_key']='state_value_template'
        end

        name='mode'

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
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
            tools.set_default(data,name,{})
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
            tools.set_default(data,name,{})
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
            tools.set_default(data,name,{})
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

        data=tools.update_map(data,data_update)

        return data

    end

end

class Dehumidifier : Humidifier

    static var device_class='dehumidifier'

end

var mod = module("hct_humidifier")
mod.Humidifier=Humidifier
mod.Dehumidifier=Dehumidifier
return mod