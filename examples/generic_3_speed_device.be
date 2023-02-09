# Config for generic 3 speed (i.e. power plus low/medium/high) devices. Provides speed pull-down menu.
# See the following for additional relay config: https://gist.github.com/ejohb/07484e1a158baca4c7d33ffa8787699b

import hct

log('Setting up 3 speed device with hct...')

TRIGGERS_SPEEDS={'Power2#state=1': "Low",'Power3#state=1': "Medium",'Power4#state=1': "High"}
OPTIONS_RELAY_IDS={'Off':nil, 'Low':2,'Medium':3,'High':4}

def are_any_speeds_on()
	var powers=tasmota.get_power()
	return powers[1] || powers[2] || powers[3]
end

def callback_out()
    var powers=tasmota.get_power()
    var i
    for key: OPTIONS_RELAY_IDS.keys()        
        i=OPTIONS_RELAY_IDS[key]
        if i==nil            
        else
            if powers[i-1]
                return key
            end
        end
    end
    return 'Off'
end

def callback_in(value)
    if !value 
        tasmota.cmd('Power1 0') 
    else
        tasmota.cmd('Power'+str(value)+" 1")     
    end

end

hct.Select(
    'Speed',
    OPTIONS_RELAY_IDS,
    nil,
    'mdi:fan-speed-3',
    {
        callback_out: ['Power2#state','Power3#state','Power4#state'],
        /->'Off':'Power1#state=0'
    },
    callback_in
)