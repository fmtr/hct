import hct_entity

class Button : hct_entity.Entity

    static var platform='button'

end

import tools as tools_be
return tools_be.module.create_module(
    'hct_button',
    [
        Button
    ]
)
