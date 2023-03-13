import hct_constants as constants

import hct_entity
import hct_tools as tools

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

        self.add_endpoint_data(data,'temperature',constants.OUT,numeric_converter)
        self.add_endpoint_data(data,'temperature',constants.IN,numeric_converter)

        self.add_endpoint_data(data,'target_humidity',constants.OUT,numeric_converter)
        self.add_endpoint_data(data,'target_humidity',constants.IN,numeric_converter)

        self.add_endpoint_data(data,'aux',constants.OUT,tools.from_bool)
        self.add_endpoint_data(data,'aux',constants.IN,tools.to_bool)

        self.add_endpoint_data(
            data,
            'current_humidity',
            constants.OUT,
            numeric_converter,
            {
                'topic_key': 'current_humidity_topic',
                'template_key': 'current_humidity_template'
            }
        )

        self.add_endpoint_data(
            data,
            'current_temperature',
            constants.OUT,
            numeric_converter,
            {
                'topic_key': 'current_temperature_topic',
                'template_key': 'current_temperature_template'
            }
        )

        self.add_endpoint_data(
            data,
            'action',
            constants.OUT,
            nil,
            {
                'topic_key': 'action_topic',
                'template_key': 'action_template'
            }
        )


        self.add_endpoint_data(data,'fan_mode',constants.OUT)
        self.add_endpoint_data(data,'fan_mode',constants.IN)

        self.add_endpoint_data(data,'mode',constants.OUT)
        self.add_endpoint_data(data,'mode',constants.IN)

        self.add_endpoint_data(
            data,
            'preset_mode',
            constants.OUT,
            nil,
            {
                'template_key': 'preset_mode_value_template'
            }
        )

        self.add_endpoint_data(data,'preset_mode',constants.IN)

        self.add_endpoint_data(data,'swing_mode',constants.OUT)
        self.add_endpoint_data(data,'swing_mode',constants.IN)

        self.add_endpoint_data(data,'temperature_high',constants.OUT,numeric_converter)
        self.add_endpoint_data(data,'temperature_high',constants.IN,numeric_converter)

        self.add_endpoint_data(data,'temperature_low',constants.OUT,numeric_converter)
        self.add_endpoint_data(data,'temperature_low',constants.IN,numeric_converter)



        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={

            'payload_on':constants.ON,
            'payload_off':constants.OFF,
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