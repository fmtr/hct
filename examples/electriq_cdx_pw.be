# To use this code, add it to your `autoexec.be` - or upload this script to your device and add `load("/<filename>.be")`.
# Before using this code, make sure you've completed the initial Tuya setup, as shown here: https://templates.blakadder.com/electriq_CD12PW.html

import hct
var In=hct.CallbackIn
var Out=hct.CallbackOut

log("Setting up development Home Assistant controls (using hct version "+hct.VERSION+")...")

TUYA0_DELAY=1000
var tuyasend0=/->tasmota.cmd('TuyaSend0')
tasmota.add_rule('power1#state=1',tuyasend0)
tasmota.add_rule('Mqtt#Connected',tuyasend0)

preset_data=hct.MapData({'Smart':0, 'Purify':1})

callbacks=[
    Out(
        'tuyareceived#DpType4Id2',
        /value->value==1?'fan':'drying',
        'action'
    ),
    Out(
        'power1#state=0',
        /value->'off',
        'action'
    ),
    Out(
        'tuyareceived#DpType2Id4',
        def (value,entity)
            # Bit of a hack to workaround a bug with the MCU. Whenever Purify mode is selected, the target humidity defaults to 55%.
            # The next time Smart (Drying) mode is selected, the original target humidity is restored on the unit, but that change is never sent to the ESP.
            # The only way to resolve this is to force a full Tuya update whenever the target humidity changes to 55.
            # That update is wrapped in a delay, so that its result should not win the race condition with the original update to 55, and be overridden.
            if value==55 && entity.values.find('target_humidity')!=55
                tasmota.set_timer(TUYA0_DELAY, tuyasend0)
            end
            return value
        end,
        'target_humidity'
    ),
    In(
        /value->hct.NoPublish(hct.tuya_send(2,4,value)),
        'target_humidity'
    ),
    Out(
        'tuyareceived#DpType2Id103',
        nil,
        'current_temperature'
    ),
    Out(
        'tuyareceived#DpType2Id3',
        nil,
        'current_humidity'
    ),
    Out(
        'tuyareceived#DpType4Id2',
        /value->value==1?'fan_only':'dry',
        'mode'
    ),
    Out(
        'power1#state=0',
        /value->'off',
        'mode'
    ),
    In(
        def (value)
            if value=='off'
                tasmota.set_power(0,false)
            else
                tasmota.set_power(0,true)
                hct.tuya_send(4,2,value=='fan_only'?1:0)
            end
        end,
        'mode'
    ),
    Out(
        'tuyareceived#DpType4Id2',
        /value->preset_data.out.find(value,'Unknown'),        
        'preset_mode'
    ),
    In(
        /value->hct.tuya_send(4,2,preset_data.in.find(value,0)),        
        'preset_mode'
    )

]

climate=hct.Climate(
    'Dehumidifier',
    nil,
    nil,
    'C',
    nil,
    35..80,
    ['dry', 'fan_only','off'],
    preset_data.keys,
    nil,
    nil,
    nil,
    callbacks
)

light_indicator=hct.Light(    
    'Humidity Health Indicator',
    nil,
    'mdi:led-on',
    [
        In(/value->hct.tuya_send(1,101,value)),
        Out('tuyareceived#DpType1Id101'),
    ]
)