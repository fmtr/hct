import hct_constants as constants
import hct_entity
import hct_tools as tools

class Light : hct_entity.Entity

    static var platform='light'

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def extend_endpoint_data(data)

        data['state'][constants.OUT]['template_key']='state_value_template'

        return data

    end

end

var mod = module("hct_light")
mod.Light=Light
return mod