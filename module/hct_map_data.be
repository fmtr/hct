import tools as tools_be
import hct_entity

class MapData

    var in
    var out
    var keys

    def init(data)
        self.in=data
        self.out=tools_be.iterator.reverse_map(self.in)
        self.keys=tools_be.iterator.get_keys(self.in)
    end
end

var button_data=MapData({0:'CLEAR',1:'SINGLE',2:'DOUBLE',3:'TRIPLE',4:'QUAD',5:'PENTA',6:'HOLD'})

var mod = module("hct_map_data")
mod.MapData=MapData
mod.button_data=button_data
return mod
