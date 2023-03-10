import hct_entity
import hct_tools as tools

var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

class Light : hct_entity.Entity

    static var platform='light'

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def extend_endpoint_data(data)

        data['state']['out']['template_key']='state_value_template'

        return data

    end

end

var mod = module("hct_light")
mod.Light=Light
return mod