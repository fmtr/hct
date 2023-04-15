import hct_constants as constants
import hct_tools as tools

tools.log_debug(["hct.be",constants.VERSION, "compiling..."])

import hct_config
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
import hct_climate
import hct_light
import hct_helper
import hct_entity

import hct_debugging

# Start module definition.

var hct = module(constants.NAME)

hct.VERSION=constants.VERSION
hct.version=constants.VERSION

hct.Config=hct_config.Config
hct.debug=hct_config.Config.debug

import tools as tools_be
tools_be.module.create_module(
    hct,
    [
        hct_select.Select,
        hct_number.Number,
        hct_text.Text,
        hct_text.Password,
        hct_sensor.Sensor,
        hct_button.Button,
        hct_switch.Switch,
        hct_light.Light,
        hct_binary_sensor.BinarySensor,
        hct_helper.ButtonSensor,
        hct_helper.BinarySensorMotionSwitch,
        hct_humidifier.Humidifier,
        hct_humidifier.Dehumidifier,
        hct_climate.Climate,
        hct_fan.Fan,
        hct_update.Update,
        callback.Publish,
        callback.NoPublish,
        hct_helper.MapData,
        hct_helper.TuyaIO,
        hct_entity.UseDeviceName
    ]
)

hct.CallbackOut=callback.Out
hct.CallbackIn=callback.In
hct.callback=callback
hct.add_rule_once=tools.add_rule_once
hct.download_url=tools.download_url
hct.read_url=tools.read_url
hct.log_debug=tools.log_debug
hct.tuya_send=tools.tuya_send

hct.button_data=hct_helper.button_data

hct.expose_updater=hct_helper.expose_updater
hct.expose_updater_tasmota=hct_helper.expose_updater_tasmota
hct.expose_repl=hct_helper.expose_repl

hct.update=tools.update_hct
hct.rs=/->tasmota.cmd('restart 1')

hct.debugging=hct_debugging

tools.log_debug(["hct.be",constants.VERSION, "compiled OK."])

def autoexec()
    tools.log_hct("Successfully imported Home Assistant Controls for Tasmota (hct) version "+hct.VERSION+". You can now access it using the `hct` module, e.g. in `autoexec.be`, Berry Console, etc.")
end

hct.autoexec=autoexec

return hct