import hct_constants as constants
import hct_entity
import hct_tools as tools

class Switch : hct_entity.Entity

    static var platform='switch'

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()

        data['payload_on']=constants.ON
        data['payload_off']=constants.OFF

        return data

    end

end

var mod = module("hct_switch")
mod.Switch=Switch
return mod