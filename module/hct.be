var VERSION='0.3.10'

import hct_tools as tools

tools.log_debug("hct.be compiling...")

var NAME='hct'
import mqtt
import json
import string
import math
import uuid

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

# Start module definition.

var hct = module(NAME)

hct.VERSION=VERSION
hct.Config=hct_config.Config

hct.Select=hct_select.Select
hct.Number=hct_number.Number
hct.Text=hct_text.Text
hct.Password=hct_text.Password
hct.Sensor=hct_sensor.Sensor
hct.Button=hct_button.Button
hct.Switch=hct_switch.Switch
hct.Light=hct_light.Light
hct.BinarySensor=hct_binary_sensor.BinarySensor
hct.ButtonSensor=hct_helper.ButtonSensor
hct.BinarySensorMotionSwitch=hct_helper.BinarySensorMotionSwitch

hct.Humidifier=hct_humidifier.Humidifier
hct.Dehumidifier=hct_humidifier.Dehumidifier
hct.Climate=hct_climate.Climate

hct.Fan=hct_fan.Fan

hct.Update=hct_update.Update

hct.Publish=callback.Publish
hct.NoPublish=callback.NoPublish
hct.CallbackOut=callback.Out
hct.CallbackIn=callback.In
hct.MapData=hct_helper.MapData

hct.add_rule_once=tools.add_rule_once
hct.download_url=tools.download_url
hct.read_url=tools.read_url
hct.log_debug=tools.log_debug
hct.tuya_send=tools.tuya_send

hct.TuyaIO=hct_helper.TuyaIO
hct.button_data=hct_helper.button_data

hct.expose_updater=hct_helper.expose_updater
hct.expose_updater_tasmota=hct_helper.expose_updater_tasmota
hct.expose_repl=hct_helper.expose_repl

tools.log_debug("hct.be compiled OK.")

log("HCT: Successfully imported Home Assistant Controls for Tasmota (hct) version "+hct.VERSION+". You can now access it using the `hct` module, e.g. in `autoexec.be`, Berry Console, etc.")

return hct