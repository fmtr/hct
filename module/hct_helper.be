import string
import hct_constants as constants
import hct_tools as tools
import hct_sensor
import hct_binary_sensor
import hct_callback as callback
import hct_update
import hct_button

var VERSION_CURRENT_TASMOTA=tools.get_current_version_tasmota()

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

class TuyaIO    
    
    var in
    var out
    var io

    def init(type_id,dp_id)
        self.in=callback.In(/value->tools.tuya_send(type_id,dp_id,value))
        self.out=callback.Out(['tuyareceived','#','DpType',type_id,'Id',dp_id].concat())
        self.io=[self.in,self.out]
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

def update_hct_cb(value)

    var install_payload='INSTALL'
    value=value==nil?install_payload:value

    if value!=install_payload
        log('Update callback got unexpected payload. Was expecting "'+str(install_payload)+'". Got "'+str(value)+'".')
        return false
    end

    log('Starting hct update...')

    return tools.update_hct()

end

def expose_updater(org,repo,version_current,callback_update)
    
    org=org?org:'fmtr'
    repo=repo?repo:'hct'
    version_current=version_current?version_current:constants.VERSION
    callback_update=callback_update?callback_update:/value->callback.NoPublish(update_hct_cb(value))

    var trigger=[tools.get_rand(60), tools.get_rand(60),tools.get_rand(12),'*','*','*'].concat(' ')    
    trigger=['cron',trigger].concat(':')

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
    return expose_updater('arendst','Tasmota',VERSION_CURRENT_TASMOTA,/value->tasmota.cmd('upgrade 1'))
end

def expose_repl()
    import hct_text
    return hct_text.Text(
        'REPL',
        nil,
        'mdi:code-braces-box',
        nil,
        nil,
        [
            callback.In(/value->hct.Publish(str(tasmota.cmd(value)))), 
            callback.Out()
        ]
)
end

var mod = module("hct_helper")
mod.MapData=MapData
mod.button_data=button_data
mod.BinarySensorMotionSwitch=BinarySensorMotionSwitch
mod.ButtonSensor=ButtonSensor
mod.TuyaIO=TuyaIO
mod.expose_updater=expose_updater
mod.expose_updater_tasmota=expose_updater_tasmota
mod.expose_repl=expose_repl

return mod