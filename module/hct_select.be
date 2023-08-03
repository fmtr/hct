import tools as tools_be
import hct_entity

class Select : hct_entity.Entity

    static var platform='select'
    var options
    var options_map_in
    var options_map_out

    def init(name, options, entity_id, icon, callbacks)

        self.options=options
        super(self).init(name, entity_id, icon, callbacks)

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        data['options']=self.options

        return data

    end

end

return tools_be.module.create_module(
    'hct_select',
    [
        Select
    ]
)
