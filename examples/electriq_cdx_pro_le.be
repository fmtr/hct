# To use this code, add it to your `autoexec.be` - or upload this script to your device and add `load("/<filename>.be")`.
# Before using this code, make sure you've completed the initial Tuya setup, as shown here: https://templates.blakadder.com/electriq_CD12PW.html

var In=hct.CallbackIn
var Out=hct.CallbackOut

log("Setting up development Home Assistant controls (using hct version "+hct.VERSION+")...")

var tuyasend0=/value->tasmota.cmd('TuyaSend0')
tasmota.add_rule('power1#state=1',tuyasend0)
tasmota.add_rule('Mqtt#Connected',tuyasend0)

preset_data=hct.MapData({'Smart':0, 'High':2, 'Low':3,'Purify':1})
swing_data=hct.MapData({'Fixed 90°':1,'Fixed 45°':0,'Swing':2})

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
        nil,
        'target_humidity',
        nil,
        true
    ),
    In(
        def (value,data)
            if data.entity.values.find('preset_mode','Smart')=='Smart'
                hct.log_debug('Unit is in Smart mode, so disallowing any changes to target humidity. Force-publishing 55%.')
                return hct.Publish(55)
            else
                hct.tuya_send(2,4,value)
            end
        end,
        'target_humidity'
    ),
    Out(
        'tuyareceived#DpType2Id103',
        nil,
        'current_temperature',
        nil,
        true # Dedupe, as Tuya published every 10 seconds, including duplicates.
    ),
    Out(
        'tuyareceived#DpType2Id3',
        nil,
        'current_humidity',
        nil,
        true # Dedupe, as Tuya published every 10 seconds, including duplicates.
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
    ),
    Out(
        'tuyareceived#DpType4Id102',
        /value->swing_data.out.find(value,'Unknown'),
        'swing_mode'
    ),
    In(
        /value->hct.tuya_send(4,102,swing_data.in.find(value,0)),
        'swing_mode'
    )
]

climate=hct.Climate(
    hct.UseDeviceName,
    nil,
    nil,
    'C',
    nil,
    35..80,
    ['dry', 'fan_only','off'],
    preset_data.keys,
    nil,
    swing_data.keys,
    nil,
    callbacks
)

light_indicator=hct.Light(    
    'Humidity Health Indicator',
    nil,
    'mdi:wall-sconce-flat-variant',
    [
        In(/value->hct.tuya_send(1,101,value)),
        Out('tuyareceived#DpType1Id101'),
        Out(
            'tuyareceived#DpType2Id3',
            def (value)

                # The indicator color is not reported from the Tuya MCU, but we can infer it from the current humidity, using values from the manual.

                if value>=70
                    return hct.Light.DataRGB(255,102,102)
                elif value>=60
                    return hct.Light.DataRGB(255,178,102)
                else
                    return hct.Light.DataRGB(178,255,102)
                end
            
            end,
            'rgb',        
            nil,
            true # Dedupe.
        )
    ]
)

light_uv=hct.Light(    
    'Ultra Violet',
    nil,
    'mdi:sun-wireless',
    [
        In(/value->hct.tuya_send(1,10,value)),
        Out('tuyareceived#DpType1Id10'),
        Out(
            'tuyareceived#DpType1Id10',
            /value->hct.Light.DataRGB(178,102,255),
            'rgb',        
            nil,
            true # Dedupe.
        )
    ]

)