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

var mod = module("hct_select")
mod.Select=Select
return mod