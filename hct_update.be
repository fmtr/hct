import hct_entity
import hct_tools as tools

var ON='ON'
var OFF='OFF'
var VALUE_TEMPLATE='{{ value_json.value }}'

class Update : hct_entity.Entity

    static var platform='update'
    var entity_picture
    var release_url

    def init(name, release_url, entity_picture, entity_id, icon, callbacks)

        self.entity_picture=entity_picture
        self.release_url=release_url
        super(self).init(name, entity_id, icon, callbacks)

    end

    def extend_endpoint_data(data)


        data['state']['in']['converter']=str # Required?
        data['state']['out']['converter']=str     # Required?

        var name
        var direction
        var callbacks

        name='latest_version'

        direction='out'
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools.set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'latest_version_topic',
                'template':VALUE_TEMPLATE,
                'template_key': 'latest_version_template',
                'callbacks': callbacks
                }
        else
            raise 'hct_config_error', [classname(self),'requires incoming callback for', name].concat(' ')
        end

        return data

    end

    def get_data_announce()

        var data=super(self).get_data_announce()
        var data_update={
            'entity_picture':self.entity_picture,
            'payload_install':'INSTALL',
            'release_url':self.release_url
        }

        data=tools.update_map(data,data_update)

        return data

    end

end

var mod = module("hct_update")
mod.Update=Update
return mod