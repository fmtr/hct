# To use this code, add it to your `autoexec.be` - or upload this script to your device and add `load("/<filename>.be")`.
# Before using this code, make sure you've completed the initial Tuya setup, as shown here: https://templates.blakadder.com/proscenic_T21.html

var In=hct.CallbackIn
var Out=hct.CallbackOut

log("Setting up Proscenic T21 (using hct version "+hct.VERSION+")...")

# Now we add a Number slider to control cooking temperature in F.
# Since the fryer MCU uses F natively, this just the process similar to the cookbook pull-down above.

hct.Number(
    'Cooking Temperature (F)',
    170..399,                
    'slider',                # Input type
    nil,                     # Step size
    '°F',                    # Unit of measure
    nil,                     # Entity ID
    'mdi:temperature-fahrenheit',
    [
        Out('tuyareceived#dptype2id103'),
        In(
            /value->hct.tuya_send(2,103,value)
        )
    ]
)

# Now a slider for temperature in C (not necessary but nice to have if you use C in your country).
# This is a little more complex as it means converting the temperature in the callbacks.
# Here our outgoing callback is a map from the conversion function to the trigger that calls it.

import math


callback_f_to_c=Out(
        'tuyareceived#dptype2id103',
        /value->math.ceil((value-32)/1.8)
    )

callback_c_to_f=In(
    /value->hct.tuya_send(2,103,int((value*1.8)+32))
)

hct.Number(
    'Cooking Temperature (C)',
    77..204,
    'slider',
    nil,
    '°C',
    nil,
    'mdi:temperature-celsius',
    [callback_f_to_c, callback_c_to_f]
)

hct.Number(
    'Cooking Time',
    1..60,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer',
    [
        Out('tuyareceived#DpType2Id7'),
        In(
            /value->hct.tuya_send(2,7,value)
        )
    ]
)


def keep_warm_enable_if_time_set(value)

    # If the Keep Warm time is set a value greater than zero, automatically enable the Keep Warm setting, and vice versa.
    # This is more convenient as otherwise the Home Assistant user would need to juggle between two separte controls.

    value=value!=nil ? value : 0

    if value==0
        tasmota.set_power(2,false)   
        return hct.Publish(value)
    end
    
    value=value<5 ? 5 : value        

    if !tasmota.get_power()[2]
        hct.add_rule_once(
            'Power3#state=1',
            /->hct.tuya_send(2,105,value)
            
        )
        tasmota.set_power(2,true)
    else
        hct.tuya_send(2,105,value)
    end

    return hct.Publish(value)

end

hct.Number(
    'Keep Warm Time',
    0..120,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer-sync',
    [
        Out('tuyareceived#DpType2Id105'),
        Out('Power3#state=0',/->0),
        Out('Power3#state=1',/->5),
        In(keep_warm_enable_if_time_set)
    ]    
)

def delay_enable_if_time_set(value)

    # Same principle as keep_warm_enable_if_time_set above.

    value=value!=nil ? value : 0

    if value==0
        tasmota.set_power(3,false)   
        return hct.Publish(value)     
    end
    
    value=value<5 ? 5 : value        

    if !tasmota.get_power()[3]
        hct.add_rule_once(
            'Power4#state=1',
            /->hct.tuya_send(2,6,value)
            
        )
        tasmota.set_power(3,true)
    else
        hct.tuya_send(2,6,value)
    end

    return hct.Publish(value)

end

hct.Number(
    'Delay Time',
    0..720,
    'box',
    nil,
    'minutes',
    nil,
    'mdi:timer-pause',
    [
        Out('tuyareceived#DpType2Id6'),
        Out('Power4#state=0',/->0),
        Out('Power4#state=1',/->5),
        In(delay_enable_if_time_set)
    ]    
)

hct.Sensor(   
    'Status',    
    nil,
    nil,
    nil,
    'mdi:playlist-play',
    [
        Out(
            'tuyareceived#dptype4id5',
            /value->{0:'Ready',1:'Delayed Cook',2:'Cooking',3:'Keep Warm',4:'Off',5:'Cooking Complete'}.find(value,'Unknown')        
        )
    ],
    hct.Sensor.DeviceClass.ENUM
)

hct.Sensor(   
    'Time Remaining',    
    'minutes',
    nil,
    nil,
    'mdi:timer',
    Out('tuyareceived#dptype2Id8'),
    hct.Sensor.DeviceClass.DURATION
)

# Lastly we add the cookbook pull-down. This has already been covered in the README: https://github.com/fmtr/hct#example-walkthrough

food_data=hct.MapData({'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4,'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10})

hct.Select(   
    'Cookbook',
    food_data.keys,
    nil,
    'mdi:chef-hat',
    [
        Out(
            'tuyareceived#dptype4id3',
            /value->food_data.out.find(value,'Default')
        ),
        In(
            /value->hct.tuya_send(4,3,food_data.in.find(value,0))
        )
    ]
)   

# Optional, extended controls. Mainly for aesthetics, convenience in Home Assistant.

hct.Switch(   
    'Power',        
    nil,
    'mdi:power',
    [
        Out('power1#state'),    
        In(
            /value->tasmota.set_power(0,value)
        )
    ]
)

hct.Switch(   
    'Cook/Pause',        
    nil,
    'mdi:play-pause',
    [
        Out('power2#state'),    
        In(
            /value->tasmota.set_power(1,value)
        )
    ]
)

# Since the functions above make the Keep Warm/Delay switches redendant, expose them instead as sensors.

hct.BinarySensor(   
    'Keep Warm',        
    nil,
    'mdi:sync-circle',
    [Out('power3#state')]
)

hct.BinarySensor(   
    'Delay',        
    nil,
    'mdi:pause-circle',
    [Out('power4#state')]
)