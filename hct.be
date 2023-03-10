var VERSION='0.2.7'
var NAME='hct'
import mqtt
import json
import string
import math
import uuid


import hct_config
import hct_tools as tools
import hct_callback as callback
import hct_select
import hct_number
import hct_sensor
import hct_button
import hct_switch
import hct_binary_sensor
import hct_text
import hct_humidifier
import hct_fan
import hct_update


var Config=hct_config.Config
import hct_entity
var Entity=hct_entity.Entity


tools.log_debug("hct.be compiling...")



var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'




class MapData

    var in
    var out
    var keys

    def init(data)
        self.in=data
        self.out=tools.reverse_map(self.in)
        self.keys=tools.get_keys(self.in)
    end
end

var button_data=MapData({0:'CLEAR',1:'SINGLE',2:'DOUBLE',3:'TRIPLE',4:'QUAD',5:'PENTA',6:'HOLD'})






class Climate : Entity

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

        self.add_endpoint_data(data,'temperature','out',numeric_converter)
        self.add_endpoint_data(data,'temperature','in',numeric_converter)

        self.add_endpoint_data(data,'target_humidity','out',numeric_converter)
        self.add_endpoint_data(data,'target_humidity','in',numeric_converter)

        self.add_endpoint_data(data,'aux','out',tools.from_bool)
        self.add_endpoint_data(data,'aux','in',tools.to_bool)

        self.add_endpoint_data(
            data,
            'current_humidity',
            'out',
            numeric_converter,
            {
                'topic_key': 'current_humidity_topic',
                'template_key': 'current_humidity_template'
            }
        )

        self.add_endpoint_data(
            data,
            'current_temperature',
            'out',
            numeric_converter,
            {
                'topic_key': 'current_temperature_topic',
                'template_key': 'current_temperature_template'
            }
        )

        self.add_endpoint_data(
            data,
            'action',
            'out',
            nil,
            {
                'topic_key': 'action_topic',
                'template_key': 'action_template'
            }
        )
        

        self.add_endpoint_data(data,'fan_mode','out')
        self.add_endpoint_data(data,'fan_mode','in')

        self.add_endpoint_data(data,'mode','out')
        self.add_endpoint_data(data,'mode','in')
        
        self.add_endpoint_data(
            data,
            'preset_mode',
            'out',
            nil,
            {
                'template_key': 'preset_mode_value_template'
            }
        )

        self.add_endpoint_data(data,'preset_mode','in')

        self.add_endpoint_data(data,'swing_mode','out')
        self.add_endpoint_data(data,'swing_mode','in')

        self.add_endpoint_data(data,'temperature_high','out',numeric_converter)
        self.add_endpoint_data(data,'temperature_high','in',numeric_converter)

        self.add_endpoint_data(data,'temperature_low','out',numeric_converter)
        self.add_endpoint_data(data,'temperature_low','in',numeric_converter)



        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={

            'payload_on':ON,
            'payload_off':OFF,
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

class Light : Entity

    static var platform='light'

    def converter_state_in(value)
        return tools.to_bool(value)
    end

    def converter_state_out(value)
        return tools.from_bool(value)
    end

    def extend_endpoint_data(data)

        data['state']['out']['template_key']='state_value_template'

        return data

    end

end

# Convenience classes. Simplify common use-cases.

class BinarySensorMotionSwitch: hct_binary_sensor.BinarySensor

    # Expose motion sensors configured as switches in Tasmota.

    def init(name, switch_ids, off_delay, entity_id, icon)

        name=name?name:'Motion'        
        switch_ids=classname(switch_ids)=='list'?switch_ids:[switch_ids]

        var callbacks=[]
        for id:switch_ids
            callbacks.push(
                callback.Out('SWITCH'+str(id)+'#STATE')        
            )
        end     

        super(self).init(name, entity_id, icon, callbacks, 'motion', off_delay)

    end

end

class ButtonSensor: hct_sensor.Sensor

    # Expose a physical button as a numeric sensor outputting number of presses

    def init(name, button_id, entity_id, icon)

        name=name?name:'Button'
        icon=icon?icon:'mdi:radiobox-marked'        

        var callback=callback.Out(
            'BUTTON'+str(button_id)+'#ACTION',
            /value->button_data.out.find(value,-1)
        )        

        super(self).init(name, 'presses', int, entity_id, icon, callback, nil)

    end

end

def expose_updater(org,repo,version_current,callback_update)

    org=org?org:'fmtr'
    repo=repo?repo:'hct'
    version_current=version_current?version_current:VERSION
    callback_update=callback_update?callback_update:/value->callback.NoPublish(tools.update_hct(value))
    
    
    var trigger='cron:0 0 */12 * * *'

    def callback_latest(value)
        var version=tools.get_latest_version(org,repo)
        return version?version:callback.NoPublish()
    end

    def callback_current(value)
        return version_current
    end

    var updater=hct_update.Update(
        ['Update (',repo,')'].concat(),
        ['https://github.com',org,repo,'releases/latest'].concat('/'),
        nil,
        nil,
        nil,
        [
            callback.Out(trigger, callback_current),
            callback.In(callback_update),
            callback.Out(trigger, callback_latest,'latest_version')
        ]
        
    )

    def callback_force_publish(value)
        updater.callbacks_wrappeds[callback_current]()
        updater.callbacks_wrappeds[callback_latest]()
        return version_current
    end

    var button_check=hct_button.Button(
        ['Update (',repo,') Check'].concat(),
        nil,
        'mdi:source-branch-sync',
        [
            callback.In(callback_force_publish)
        ]
    )
    
    return updater

end

def expose_updater_tasmota()
    
    var version_current=tasmota.cmd('status 2').find('StatusFWR',{}).find('Version','Unknown')
    version_current=string.replace(version_current,'(tasmota)','')
    
    return expose_updater('arendst','Tasmota',version_current,/value->tasmota.cmd('upgrade 1'))   

end

# Start module definition.

var hct = module(NAME)

hct.VERSION=VERSION
hct.Config=Config

hct.Select=hct_select.Select
hct.Number=hct_number.Number
hct.Text=hct_text.Text
hct.Password=hct_text.Password
hct.Sensor=hct_sensor.Sensor
hct.Button=hct_button.Button
hct.Switch=hct_switch.Switch
hct.Light=Light
hct.BinarySensor=hct_binary_sensor.BinarySensor
hct.ButtonSensor=ButtonSensor
hct.BinarySensorMotionSwitch=BinarySensorMotionSwitch

hct.Humidifier=hct_humidifier.Humidifier
hct.Dehumidifier=hct_humidifier.Dehumidifier
hct.Climate=Climate

hct.Fan=hct_fan.Fan

hct.Update=hct_update.Update

hct.Publish=callback.Publish
hct.NoPublish=callback.NoPublish
hct.CallbackOut=callback.Out
hct.CallbackIn=callback.In
hct.MapData=MapData

hct.add_rule_once=tools.add_rule_once
hct.download_url=tools.download_url
hct.read_url=tools.read_url
hct.log_debug=tools.log_debug
hct.tuya_send=tools.tuya_send

hct.button_data=button_data

hct.expose_updater=expose_updater
hct.expose_updater_tasmota=expose_updater_tasmota

tools.log_debug("hct.be compiled OK.")

return hct