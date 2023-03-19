import hct_constants as constants
import hct_entity
import hct_tools as tools

class Sensor : hct_entity.Entity

    static var platform='sensor'
    static var DeviceClass=constants.SensorDeviceClass
    var device_class
    var uom
    var type

    def init(name, uom, data_type, entity_id, icon, callbacks, device_class)

        self.uom=uom
        self.type=data_type==nil ? /value->value : data_type
        self.device_class=device_class
        super(self).init(name, entity_id, icon, callbacks)

    end

    def converter_state_in(value)
        return self.type(value)
    end

    def converter_state_out(value)
        return self.type(value)
    end

    def get_data_announce()
        var data=super(self).get_data_announce()

        var data_update={
            'unit_of_measurement':self.uom,
            'device_class': self.device_class
        }
        data=tools.update_map(data,data_update)

        return data
    end

end

var mod = module("hct_sensor")
mod.Sensor=Sensor
return mod