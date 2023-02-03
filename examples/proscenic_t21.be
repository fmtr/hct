# To use this code, add it to your `autoexec.be` - or upload this script to your device and add `load("/proscenic_t21.be")`.
# Before using this code, make sure you've completed the initial Tuya setup, as shown here: https://templates.blakadder.com/proscenic_T21.html

#First we import this library.

import hct

log("Setting up Proscenic T21 (using hct version "+hct.VERSION+")...")

# Now we add a Number slider to control cooking temperature in F.
# Since the fryer MCU uses F natively, this just the process similar to the cookbook pull-down above.

hct.Number(
    'Air Fryer Cooking Temp (F)',
    170,                     # Minimum temperature
    399,                     # Maximum temperature
    'slider',                # Input type
    nil,                     # Entity ID
    '°F',                    # Unit of measure
    nil,                     # Slider step size (if not 1).
    'mdi:temperature-fahrenheit',
    'tuyareceived#dptype2id103',
    /value->tasmota.cmd('TuyaSend2 103,'+str(value))
)

# Now a slider for temperature in C (not necessary but nice to have if you use C in your country).
# This is a little more complex as it means converting the temperature in the callbacks.
# Here our outgoing callback is a map from the conversion function to the trigger that calls it.

import math

convert_f_to_c_map={
        /value->math.ceil((value-32)/1.8):
        'tuyareceived#dptype2id103'
}

convert_c_to_f=/value->tasmota.cmd('TuyaSend2 103,'+str(int((value*1.8)+32)))

hct.Number(
    'Air Fryer Cooking Temp (C)',
    77,
    204,
    'slider',
    nil,
    '°C',
    nil,
    'mdi:temperature-celsius',
    convert_f_to_c_map,
    convert_c_to_f
)

hct.Number(
    'Air Fryer Cooking Time',
    1,
    60,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer',
    'tuyareceived#DpType2Id7',
    /value->tasmota.cmd('TuyaSend2 7,'+str(value))
)

hct.Number(
    'Air Fryer Keep Warm Time',
    5,
    120,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer-sync',
    {
        /v->v:'tuyareceived#DpType2Id105',
        /v->5:'power3#state'

    },
    def (value)
        tasmota.set_power(2,true)
        tasmota.cmd('TuyaSend2 105,'+str(value))
        return nil
    end
)

hct.Number(
    'Air Fryer Delay Time',
    0,
    720,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer-pause',
    {
        /v->v:'tuyareceived#DpType2Id6',
        /->0: 'Power4#state=0',
        /->5: 'Power4#state=1',

    },
    def (value)

        value=value!=nil ? value : 0

        if value==0
            tasmota.set_power(3,false)   
            return value     
        end
        
        value=value<5 ? 5 : value        

        if !tasmota.get_power()[3]
            hct.add_rule_once(
                'Power4#state=1',
                /->tasmota.cmd('TuyaSend2 6,'+str(value))
                
            )
            tasmota.set_power(3,true)
        else
            tasmota.cmd('TuyaSend2 6,'+str(value))
        end

        return value

    end
)

hct.Sensor(   
    'Air Fryer Status',    
    nil,
    nil,
    'mdi:playlist-play',
    {
        /value->{0:'Ready',1:'Delayed Cook',2:'Cooking',3:'Keep Warm',4:'Off',5:'Cooking Complete'}.find(value,'Unknown'):
        'tuyareceived#dptype4id5'
    }
)

# Lastly we add the cookbook pull-down. This has already been covered in the README: https://github.com/fmtr/hct#example-walkthrough

hct.Select(   
    'Air Fryer Cookbook',
    {'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4,'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10},
    nil,
    'mdi:chef-hat',
    'tuyareceived#dptype4id3',
    /value->tasmota.cmd('TuyaEnum1 '+str(value))
)  

hct.Button(        
    'Upgrade Tasmota',
    nil,
    'mdi:update',
    /value->tasmota.cmd("upgrade 1")
)

hct.Sensor(   
    'Air Fryer Time Remaining',    
    'minutes',
    nil,
    'mdi:timer',
    'tuyareceived#dptype2Id8'
)
