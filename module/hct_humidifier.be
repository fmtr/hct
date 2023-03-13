import hct_constants as constants
import hct_entity
import hct_tools as tools

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

        if self.callback_data.find('state',{}).find(constants.IN)
            data['state'][constants.IN]['converter']=tools.to_bool
        end

        if self.callback_data.find('state',{}).find(constants.OUT)
            data['state'][constants.OUT]['converter']=tools.from_bool
            data['state'][constants.OUT]['template_key']='state_value_template'
        end

        name='mode'

        direction=constants.OUT
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'mode_state_topic',
                'template':constants.VALUE_TEMPLATE,
                'template_key': 'mode_state_template',
                'callbacks': callbacks
                }
        end

        direction=constants.IN
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

        direction=constants.OUT
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'target_humidity_state_topic',
                'template':constants.VALUE_TEMPLATE,
                'template_key': 'target_humidity_state_template',
                'callbacks': callbacks,
                'converter': int
                }
        end

        direction=constants.IN
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
            'payload_on':constants.ON,
            'payload_off':constants.OFF,
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