import string
import hct_callback as callback
import hct_constants as constants

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

var mod = module("hct_debug")
mod.expose_climate=expose_climate
return mod