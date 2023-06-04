import hct_constants as constants
import tools as tools_be

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
    var callbackw
    var rule_obj

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

    def init_rule(trigger,callbackw)
        self.rule_obj=tools_be.callbacks.MqttSubscription(trigger,callbackw,self.id)
        self.callbackw=callbackw
        return self.rule_obj
    end
    
end

class CallbackOut: Callback
    static var direction=constants.OUT
    var trigger
    var RuleType
    def init(trigger, callback, endpoint, id, dedupe, RuleType)
        super(self).init(callback, endpoint, id, dedupe)
        self.RuleType=RuleType?RuleType:tools_be.callbacks.Rule
        self.trigger=trigger
    end

    def init_rule(callbackw)
        self.rule_obj=self.RuleType(self.trigger,callbackw,self.id)
        self.callbackw=callbackw
        return self.rule_obj
    end

end

class CallbackData
    var name, value, entity, callback_obj, callback, callbackw, value_last, values, value_raw, trigger, message, topic, code, value_bytes

    def init(name, value, entity, callback_obj, value_raw, trigger, message, topic, code, value_bytes)
        self.name=name
        self.value=value
        self.entity=entity
        self.callback_obj=callback_obj
        self.callback=callback_obj.callback
        self.callbackw=callback_obj.callbackw
        self.value_last=entity.values.find(name)
        self.values=entity.values
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