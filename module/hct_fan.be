import hct_constants as constants
import hct_entity
import hct_tools as tools

class Fan : hct_entity.Entity

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
        direction=constants.IN

        if self.callback_data.find(name,{}).find(direction)
            data[name][direction]['converter']=tools.to_bool
        end

        direction=constants.OUT
        if self.callback_data.find(name,{}).find(direction)
            data[name][direction]['converter']=tools.from_bool
            data[name][direction]['template_key']='state_value_template'
        end

        self.add_endpoint_data(data,'preset_mode',constants.OUT)
        self.add_endpoint_data(data,'preset_mode',constants.IN)
        self.add_endpoint_data(data,'percentage',constants.OUT,int)
        self.add_endpoint_data(data,'percentage',constants.IN,int)

        self.add_endpoint_data(
            data,
            'oscillation',
            constants.OUT,
            tools.from_bool,
            {
                'template_key':'oscillation_value_template'
            }
        )

        self.add_endpoint_data(
            data,
            'oscillation',
            constants.IN,
            tools.to_bool,
            {
                'payload_on': constants.ON,
                'payload_on_key': 'payload_oscillation_on',
                'payload_off': constants.OFF,
                'payload_off_key': 'payload_oscillation_off'
            }
    )


        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={
            'preset_modes':self.modes,
            'payload_on':constants.ON,
            'payload_off':constants.OFF,
            'speed_range_min':self.min_speed,
            'speed_range_max':self.max_speed
        }

        data=tools.update_map(data,data_update)

        return data

    end

end

var mod = module("hct_fan")
mod.Fan=Fan
return mod