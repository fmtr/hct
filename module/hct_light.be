import json
import hct_constants as constants
import hct_entity
import hct_tools as tools


class LightDataRGB

    var red, green, blue
    var channels

    def init(red, green, blue)
        self.red=red
        self.green=green
        self.blue=blue     
        self.channels=[red,green,blue]   
    end

    def serialize()
        return self.channels.concat(',')
    end

    static def from_channels(channels)
        return LightDataRGB(channels[0],channels[1],channels[2])
    end

    static def from_serialized(serialized)
        return LightDataRGB.from_channels(json.load('['+serialized+']'))
    end

end

class Light : hct_entity.Entity

    static var platform='light'
    static var DataRGB=LightDataRGB

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def extend_endpoint_data(data)       

        data['state'][constants.OUT]['template_key']='state_value_template'

        self.add_endpoint_data(
            data,
            'rgb',
            constants.OUT,
            /value->value.serialize(),
            {'template_key':'rgb_value_template'}
        )

        self.add_endpoint_data(data,'rgb',constants.IN,/value->self.DataRGB.from_serialized(value))
        
        return data

    end

end

var mod = module("hct_light")
mod.Light=Light
return mod