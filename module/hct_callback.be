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
    var dedupe

    def init(callback, endpoint, id, dedupe)
        import uuid
        self.id=id?id:callback
        self.callback=callback?callback:/value->value
        self.endpoint=endpoint?endpoint:'state'
        self.dedupe=bool(dedupe)
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
    def init(triggers, callback, endpoint, id, dedupe)
        super(self).init(callback, endpoint, id, dedupe)        
        self.triggers=classname(triggers)=='list'?triggers:[triggers]

    end
end

class CallbackData
    var name, value, entity, callback_obj, value_last, value_raw, trigger, message, topic, code, value_bytes

    def init(name, value, entity, callback_obj, value_raw, trigger, message, topic, code, value_bytes)
        self.name=name
        self.value=value
        self.entity=entity
        self.callback_obj=callback_obj
        self.value_last=entity.values.find(name)
        self.value_raw=value_raw
        self.trigger=trigger
        self.message=message
        self.topic=topic
        self.code=code
        self.value_bytes=value_bytes
    end
end

var mod = module("hct_callback")
mod.In=CallbackIn
mod.Out=CallbackOut
mod.Publish=Publish
mod.NoPublish=NoPublish
mod.Data=CallbackData
return mod