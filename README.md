# Home Assistant Controls for Tasmota

This is a Tasmota Berry Script library (so requires Tasmota32) to greatly simplify the process of exposing Home Assistant controls (e.g. Pull-down Lists, Number Sliders, Text Boxes, etc.) from a Tasmota device - and handling the communication between both sides.


## Do I Need This? Can't I Do this with Native Tasmota?

You certainly can. But in my experience, the process is so fiddly, error-prone and hard to maintain that it's enough to deter the casual user (as I am) entirely. Plus, sharing your configuration, once you've finally got it working, can mean complex step-by-step guides, setting up triggers, finding MAC addresses and topics (in Tasmota) - and numerious Blueprints, Helpers and Templates (on the Home Assistant side).

With `hct`, on the other hand, the thorny parts of the initial setup are abstracted away and your final configuration can be shared via a one-liner.

## Installing

Simply paste the following into you Berry console
```be
tasmota.urlfetch('https://raw.githubusercontent.com/fmtr/hct/master/hct.be','/hct.be')
```

Alternatively, manually download [hct.be](https://raw.githubusercontent.com/fmtr/hct/master/hct.be) and upload it onto your device.

## Example

This is a real-world example of implementing the cookbook pull-down menu for a Proscenic T21 air fryer. It handles defining a friendly pull-down list of food types on the Home Assistant side and mapping those values to the corresponding values required by the Tuya driver on the Tasmota side.

Frist we import this library.

```be
import hct
```

Next we specify the options to show in our pull-down. This could be a list of strings (e.g. `['Foo','Bar']`) - or a mapping from "friendly" values to show in Home Assistant, to corresponding data on the Tasmota side. So here we map food descriptions to their Tuya IDs.

```be
options={'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4, 'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10}
```

Then we write a very simple handler function to set those Tuya IDs on the Tasmota side, when their values are selected in Home Assistant.

```be   
def set_cookbook_entry(value)
    tasmota.cmd('TuyaSend4 '+str(value))
end
```

Now we specify a trigger defining when a change has happened on the Tasmota side that needs to be reflected in Home Assistant.

```be
trigger='tuyareceived#dptype4id3'
```

With that all done, we can we define a pull-down (`hct.Select`) object.

```be
var select=Select(   
    'Air Fryer Cookbook',                     # Entity name   
    cookbook_data,                            # The options we defined above.
    nil,                                      # Entity ID (or leave as `nil` if you're happy for Home Assistant to decide)
    'mdi:book-open-variant',                  # Icon the entity should have in Home Assistant    
    trigger                                   # Our trigger as above.  
    set_cookbook_entry                        # The handler function we defined above.
    )
)
```

That's it. Now `hct` will handle everything else - like announcing the entity via MQTT, subscribing to the relevant topics, associating the entity with its parent device, translating Home Assistant to the provided IDs, etc. - for you.

And sharing what you've done just means sharing the above script.