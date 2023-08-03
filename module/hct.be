import hct_constants as constants
import hct_logger
import tools as tools_be

var logger=hct_logger.logger

logger.debug(["hct.be",constants.VERSION, "compiling..."])

class LazyImportInterfaceHCT: tools_be.lazy_import.LazyImportInterface

    static var NAME=constants.NAME
    static var MEMBERS={

        'VERSION':def (self) return constants.VERSION end,
        'version':def (self) return constants.VERSION end,

        'logger':def (self) return logger end,
        'constants':def (self) return constants end,

        'tools_be':def (self) return tools_be end,

        'light':def (self) import hct_light return hct_light end,
        'Light':def (self) return self.light.Light end,
        'Config':def (self) import hct_config return hct_config.Config end,

        'select':def (self) import hct_select return hct_select end,
        'Select':def (self) return self.select.Select end,

        'number':def (self) import hct_number return hct_number end,
        'Number':def (self) return self.number.Number end,

        'sensor':def (self) import hct_sensor return hct_sensor end,
        'Sensor':def (self) return self.sensor.Sensor end,

        'switch':def (self) import hct_switch return hct_switch end,
        'Switch':def (self) return self.switch.Switch end,

        'button':def (self) import hct_button return hct_button end,
        'Button':def (self) return self.button.Button end,
        
        'binary_sensor':def (self) import hct_binary_sensor return hct_binary_sensor end,
        'BinarySensor':def (self) return self.binary_sensor.BinarySensor end,

        'text':def (self) import hct_text return hct_text end,
        'Text':def (self) return self.text.Text end,
        'Password':def (self) return self.text.Password end,

        'helper':def (self) import hct_helper return hct_helper end,
        'ButtonSensor':def (self) return self.helper.ButtonSensor end,
        'BinarySensorMotionSwitch':def (self) return self.helper.BinarySensorMotionSwitch end,
        'MapData':def (self) return self.helper.MapData end,
        'button_data':def (self) return self.helper.button_data end,
        'expose_updater':def (self) return self.helper.expose_updater end,
        'expose_updater_tasmota':def (self) return self.helper.expose_updater_tasmota end,
        'expose_repl':def (self) return self.helper.expose_repl end,

        'humidifier':def (self) import hct_humidifier return hct_humidifier end,
        'Humidifier':def (self) return self.humidifier.Humidifier end,
        'Dehumidifier':def (self) return self.humidifier.Dehumidifier end,

        'climate':def (self) import hct_climate return hct_climate end,
        'Climate':def (self) return self.climate.Climate end,

        'fan':def (self) import hct_fan return hct_fan end,
        'Fan':def (self) return self.fan.Fan end,

        'update':def (self) import hct_update return hct_update end,
        'Update':def (self) return self.update.Update end,

        'debugging':def (self) import hct_debugging return hct_debugging end,

        'callback':def (self) import hct_callback return hct_callback end,
        'CallbackOut':def (self) return self.callback.Out end,
        'CallbackIn':def (self) return self.callback.In end,
        'Publish':def (self) return self.callback.Publish end,
        'NoPublish':def (self) return self.callback.NoPublish end,
        'TuyaIO':def (self) return self.callback.TuyaIO end,

        'UseDeviceName':def (self) import hct_entity return hct_entity.UseDeviceName end,

        'hct_tools':def (self) import hct_tools return hct_tools end,
        'tools':def (self) return self.hct_tools end,
        'tuya':def (self) return tools_be.tuya end,

        'rs':def (self) return tasmota.cmd('restart 1') end,

    }

    def update(url)

        return self.hct_tools.update_hct(url)

    end

end

var interface=LazyImportInterfaceHCT().create_module()

logger.debug(["hct.be",constants.VERSION, "compiled OK."])

return interface