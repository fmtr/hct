import hct_entity
import hct_tools as tools

var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

class Climate : hct_entity.Entity

    static var platform='climate'

    var modes
    var preset_modes
    var fan_modes
    var swing_modes
    var precision
    var type

    var temperature_unit
    var temperature_min
    var temperature_max

    var humidity_min
    var humidity_max

    def init(name, entity_id, icon, temperature_unit, temperature_range, humidity_range, modes, preset_modes, fan_modes, swing_modes, precision, callbacks)

        self.temperature_unit=temperature_unit

        if temperature_range
            self.temperature_min=temperature_range.lower()
            self.temperature_max=temperature_range.upper()
        end

        if humidity_range
            self.humidity_min=humidity_range.lower()
            self.humidity_max=humidity_range.upper()
        end

        self.precision=precision
        self.type=self.precision==nil?(self.temperature_unit=='C'?real:int): (self.precision==1?int:real)

        self.fan_modes=fan_modes
        self.modes=modes
        self.preset_modes=preset_modes
        self.swing_modes=swing_modes


        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)

        var numeric_converter=/value->self.type(value)

        self.add_endpoint_data(data,'temperature','out',numeric_converter)
        self.add_endpoint_data(data,'temperature','in',numeric_converter)

        self.add_endpoint_data(data,'target_humidity','out',numeric_converter)
        self.add_endpoint_data(data,'target_humidity','in',numeric_converter)

        self.add_endpoint_data(data,'aux','out',tools.from_bool)
        self.add_endpoint_data(data,'aux','in',tools.to_bool)

        self.add_endpoint_data(
            data,
            'current_humidity',
            'out',
            numeric_converter,
            {
                'topic_key': 'current_humidity_topic',
                'template_key': 'current_humidity_template'
            }
        )

        self.add_endpoint_data(
            data,
            'current_temperature',
            'out',
            numeric_converter,
            {
                'topic_key': 'current_temperature_topic',
                'template_key': 'current_temperature_template'
            }
        )

        self.add_endpoint_data(
            data,
            'action',
            'out',
            nil,
            {
                'topic_key': 'action_topic',
                'template_key': 'action_template'
            }
        )


        self.add_endpoint_data(data,'fan_mode','out')
        self.add_endpoint_data(data,'fan_mode','in')

        self.add_endpoint_data(data,'mode','out')
        self.add_endpoint_data(data,'mode','in')

        self.add_endpoint_data(
            data,
            'preset_mode',
            'out',
            nil,
            {
                'template_key': 'preset_mode_value_template'
            }
        )

        self.add_endpoint_data(data,'preset_mode','in')

        self.add_endpoint_data(data,'swing_mode','out')
        self.add_endpoint_data(data,'swing_mode','in')

        self.add_endpoint_data(data,'temperature_high','out',numeric_converter)
        self.add_endpoint_data(data,'temperature_high','in',numeric_converter)

        self.add_endpoint_data(data,'temperature_low','out',numeric_converter)
        self.add_endpoint_data(data,'temperature_low','in',numeric_converter)



        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={

            'payload_on':ON,
            'payload_off':OFF,
            'fan_modes':self.fan_modes,
            'preset_modes':self.preset_modes,
            'swing_modes':self.swing_modes,
            'modes':self.modes,
            'min_temp':self.temperature_min,
            'max_temp':self.temperature_max,
            'min_humidity':self.humidity_min,
            'max_humidity':self.humidity_max,
            'precision': self.precision,
            'temperature_unit':self.temperature_unit

        }

        data=tools.update_map(data,data_update)

        return data

    end

end

var mod = module("hct_climate")
mod.Climate=Climate
return mod