# To use this code, add it to your `autoexec.be` - or upload this script to your device and add `load("/proscenic_t21.be")`.
# Before using this code, make sure you've completed the initial Tuya setup, as shown here: https://templates.blakadder.com/proscenic_T21.html

#First we import this library.

import hct

log("Setting up Proscenic T21...")

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

# The below is some extra configuration for when pseudo power-monitoring is enabled (i.e. Option A2)

var is_power_mon=tasmota.cmd('voltageset').find('Command')!='Unknown'

if is_power_mon

    log("Setting up Proscenic T21 Power Calibrator...")
    
    def apply_calibration(value)

        # Only set to the "Cooking" relay to high power when it is switched on and the "Delayed Cooking" one is not enabled.

        var powers=tasmota.get_power()
        if powers[1] && !powers[3]
            log('Applying high power calibration')
            tasmota.cmd('currentset2 4000')
            tasmota.cmd('powerset2 960.0')
        else
            log('Applying low power calibration')
            tasmota.cmd('currentset2 1000')
            tasmota.cmd('powerset2 1.0')
        end
    end
    
    tasmota.add_rule('Power2',/value->apply_calibration(value),'apply_calibration_power_2')
    tasmota.add_rule('Power4',/value->apply_calibration(value),'apply_calibration_power_4')

    log("Setting up Proscenic T21 Save Data on Cooking Complete...")

    class DataSaverOnComplete

        # On some versions of the T21, the power to the ESP is cut whenever the drawer is removed from the fryer.
        # This ungraceful restart wipes out any energy statistics recorded during cooking.
        # Hence this object monitors for when the "Cooking Complete" status appears, and saves data then.

        static var STATUSES={0:'Ready',1:'Delayed Cook',2:'Cooking',3:'Keep Warm',4:'Off',5:'Cooking Complete'}
        static var WRITE_LIMIT_SECONDS=60
        static var SAVE_ON_STATUS='Cooking Complete'
        static var TRIGGER='tuyareceived#dptype4id5'

        var uptime_last

        def init()
            self.uptime_last=0
            var rule_id=classname(self)
            tasmota.remove_rule(self.TRIGGER,rule_id)
            tasmota.add_rule(self.TRIGGER,/value->self.run(value),rule_id)
        end

        def get_uptime()
            return tasmota.cmd('state')['UptimeSec']
        end

        def run(value)
            var uptime=self.get_uptime()
            value=self.STATUSES[value]

            if uptime-self.uptime_last<self.WRITE_LIMIT_SECONDS
                return
            end

            if value==self.SAVE_ON_STATUS
                tasmota.cmd('savedata')
                self.uptime_last=uptime
            end

        end
    end

    DataSaverOnComplete()

end