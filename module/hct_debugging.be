import string
import hct_callback as callback
import hct_constants as constants

def get_test_callbacks(schema)

    var cbs=[]
    var count=0

    for endpoint: schema.keys()

        count+=1

        if schema[endpoint].find(constants.IN)!=nil
            cbs.push(
                callback.In(
                    /value->value,
                    endpoint
                )
            )
        end

        if schema[endpoint].find(constants.OUT)!=nil
            cbs.push(
                callback.Out(
                    string.format('var%s#state', count),
                    /value->value,
                    endpoint
                )
            )
        end

        print(string.format('Assigned Var%s to endpoint: %s', count, endpoint))

    end
    return cbs
end


def expose_climate()

    import hct_climate

    var CALLBACK_SCHEMA_CLIMATE = {
        'action': [constants.OUT],
        'temperature': [constants.IN, constants.OUT],
        'target_humidity': [constants.IN, constants.OUT],
        'aux': [constants.IN, constants.OUT],
        'current_temperature': [constants.OUT],
        'current_humidity': [constants.OUT],
        'fan_mode': [constants.IN, constants.OUT],
        'mode': [constants.IN, constants.OUT],
        'preset_mode': [constants.IN, constants.OUT],
        'swing_mode': [constants.IN, constants.OUT],
        'temperature_high': [constants.IN, constants.OUT],
        'temperature_low': [constants.IN, constants.OUT]
    }

    return hct_climate.Climate(
        'Test Climate',
        nil,
        nil,
        'C',
        10..60,
        35..80,
        nil,
        ['Preset A', 'Preset B'],
        ['Fan A', 'Fan B'],
        ['Swing A', 'Swing B'],
        nil,
        get_test_callbacks(CALLBACK_SCHEMA_CLIMATE)
    )

end

def expose_repl()
    import hct_text
    import hct_callback

    return hct_text.Text(
        'REPL',
        nil,
        'mdi:code-braces-box',
        nil,
        nil,
        [
            hct_callback.In(/value->hct_callback.Publish(str(tasmota.cmd(value)))), 
            hct_callback.Out('never')
        ]
    )   
end

def expose_memory(seconds)
    import hct_sensor
    import hct_callback
    import tools
    import string

    seconds=seconds!=nil?seconds:30

    var trigger=string.format('*/%s * * * * *',seconds)

    return hct_sensor.Sensor(   
        'Memory Free',    
        'kB',
        nil,
        nil,
        'mdi:memory',
        [
            hct_callback.Out(trigger, tools.platform.get_memory_kb, nil, nil, nil, tools.callbacks.Cron)
        ],
        hct_sensor.Sensor.DeviceClass.DATA_SIZE
    ) 
end

var mod = module("hct_debugging")
mod.expose_climate=expose_climate
mod.expose_repl=expose_repl
mod.expose_memory=expose_memory

return mod