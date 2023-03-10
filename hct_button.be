import hct_entity

class Button : hct_entity.Entity

    static var platform='button'

end

var mod = module("hct_button")
mod.Button=Button
return mod