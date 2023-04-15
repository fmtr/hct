import hct_entity

class Number : hct_entity.Entity

    static var platform='number'

    var min
    var max
    var mode
    var step
    var uom
    var type

    def init(name, number_range, mode, step, uom, entity_id, icon, callbacks)

        if number_range
            self.min=number_range.lower()
            self.max=number_range.upper()
        end

        self.mode=mode
        self.step=step
        self.uom=uom
        self.type=self.step==nil || self.step==1 ? int : real
        super(self).init(name, entity_id, icon, callbacks)

    end


    def get_data_announce()

        var data=super(self).get_data_announce()

        var data_update={
            'min':self.min,
            'max':self.max,
            'mode':self.mode,
            'step':self.step,
            'unit_of_measurement':self.uom
        }

        for key: data_update.keys()
            var value=data_update[key]
            if value!=nil
                data[key]=value
            end
        end

        return data

    end

    def converter_state_in(value)
        return self.type(value)
    end

    def converter_state_out(value)
        return self.type(value)
    end

end

import tools as tools_be
return tools_be.module.create_module(
    'hct_number',
    [
        Number
    ]
)
