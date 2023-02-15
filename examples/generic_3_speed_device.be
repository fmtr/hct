# Config for generic 3 speed (i.e. power plus low/medium/high) fan.
# See the following for additional relay config: https://gist.github.com/ejohb/07484e1a158baca4c7d33ffa8787699b

import hct

log('Setting up 3 speed fan with hct...')

POWER_TRIGGERS=['Power1#state','Power2#state','Power3#state','Power4#state']

def are_any_speeds_on()
	var powers=tasmota.get_power()
	return powers[1] || powers[2] || powers[3]
end

def callback_out_percentage()
    var powers=tasmota.get_power()    
    for i : 1..size(powers)-1
        if powers[i]
            return i
        end        
    end
    return 0
end

def callback_in_percentage(value)
    
    if value==0 
        tasmota.set_power(0,false)
    else
        tasmota.set_power(value,true)  
    end

end

fan=hct.Fan(
    'Fan',
    nil,
    1..3,
    nil,
    'mdi:fan',
    {are_any_speeds_on: POWER_TRIGGERS},
    /value->tasmota.set_power(0,value),
    nil,
    nil,
    {callback_out_percentage: POWER_TRIGGERS},
    callback_in_percentage,
    nil,
    nil
)