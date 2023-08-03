import tools as tools_be
import hct_constants as constants
import hct_entity
import hct_tools as tools

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


        data['state'][constants.IN]['converter']=str # Required?
        data['state'][constants.OUT]['converter']=str     # Required?

        var name
        var direction
        var callbacks

        name='latest_version'

        direction=constants.OUT
        callbacks=self.callback_data.find(name,{}).find(direction)
        if callbacks
            tools_be.iterator.set_default(data,name,{})
            data[name][direction]={
                'topic': self.get_topic('state',name),
                'topic_key': 'latest_version_topic',
                'template':constants.VALUE_TEMPLATE,
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

        data=tools_be.iterator.update_map(data,data_update)

        return data

    end

end

return tools_be.module.create_module(
    'hct_update',
    [
        Update
    ]
)
