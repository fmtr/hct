import hct_constants as constants

class Publish
    var value

    def init(value)
        self.value=value
    end
end

class NoPublish    
end



class Callback
    static var direction
    var endpoint
    var callback
    var id
    var name_endpoint
    def init(callback, endpoint, id)
        import uuid
        self.id=id?id:callback
        self.callback=callback?callback:/value->value
        self.endpoint=endpoint?endpoint:'state'
    end

    def get_desc()
        return [self.endpoint, self.direction].concat(', ')
    end
end

class CallbackIn: Callback
    static var direction=constants.IN
    
end

class CallbackOut: Callback
    static var direction=constants.OUT
    var triggers
    def init(triggers, callback, endpoint, id)
        super(self).init(callback, endpoint, id)        
        self.triggers=classname(triggers)=='list'?triggers:[triggers]

    end
end

var mod = module("hct_callback")
mod.In=CallbackIn
mod.Out=CallbackOut
mod.Publish=Publish
mod.NoPublish=NoPublish
return mod