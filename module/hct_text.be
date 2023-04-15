import hct_entity
import hct_tools as tools

class Text : hct_entity.Entity

    static var platform='text'
    static var mode='text'

    var size_min
    var size_max
    var pattern


    def init(name,entity_id,icon,size_range,pattern,callbacks)

        if size_range
            self.size_min=size_range.lower()
            self.size_max=size_range.upper()
        end

        super(self).init(name, entity_id, icon, callbacks)

    end


    def converter_state_in(value)
        return str(value)
    end

    def converter_state_out(value)
        return str(value)
    end

    def get_data_announce()

        var data=super(self).get_data_announce()

        var data_update={
            'min':self.size_min,
            'max': self.size_max,
            'pattern': self.pattern,
            'mode': self.mode
        }

        data=tools.update_map(data,data_update)


        return data

    end

end

class Password : Text
    static var mode='password'
end

import tools as tools_be
return tools_be.module.create_module(
    'hct_text',
    [
        Text,
        Password
    ]
)