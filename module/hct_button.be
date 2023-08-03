import tools as tools_be
import hct_entity

class Button : hct_entity.Entity

    static var platform='button'

end

return tools_be.module.create_module(
    'hct_button',
    [
        Button
    ]
)
