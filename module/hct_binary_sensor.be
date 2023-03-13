import hct_constants as constants
import hct_sensor
import hct_tools as tools

class BinarySensor : hct_sensor.Sensor

    static var platform='binary_sensor'
    var off_delay

    def init(name, entity_id, icon, callbacks, device_class, off_delay)

        super(self).init(name, nil, nil, entity_id, icon, callbacks, device_class)
        self.off_delay=off_delay

    end

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()

        var data_update={
            'payload_on':constants.ON,
            'payload_off':constants.OFF,
            'off_delay':self.off_delay
        }
        data=tools.update_map(data,data_update)

        return data

    end

end

var mod = module("hct_binary_sensor")
mod.BinarySensor=BinarySensor
return mod