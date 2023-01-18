# Home Assistant Controls for Tasmota

This is a Tasmota Berry Script library (so requires Tasmota32) to greatly simplify the process of exposing Home
Assistant controls (e.g. Pull-down Lists, Number Sliders, Text Boxes, etc.) from a Tasmota device - and handling the
communication between both sides.

Using `hct` to expose, for example, an "Upgrade Tasmota Fireware" button to Home Assistant is as simple as adding the
following lines to
your `autoexec.be`:

```be
import hct

hct.Button(        
    'Upgrade Tasmota',
    nil,
    'mdi:update',
    /value->tasmota.cmd("upgrade 1")
)
```

Or, more practically, a cookbook pull-down menu, for a Tuya air fryer, might look like this:

```
hct.Select(   
    'Air Fryer Cookbook',
    {'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4,'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10},
    nil,
    'mdi:chef-hat',
    'tuyareceived#dptype4id3',
    /value->tasmota.cmd('TuyaEnum1 '+str(value))
    )  
```

For a full walk-through of configuring the cookbook entity, see the [Walkthrough Example](#example-walkthrough) below.

## Do I Need This? Can't I Do this with Native Tasmota?

You certainly can.

But in my experience, the process is so fiddly, error-prone and hard to maintain that it's enough to
deter the casual user (as I am) entirely. Plus, sharing your configuration, once you've finally got it working, can mean
complex step-by-step guides, setting up triggers, finding MAC addresses and topics (in Tasmota) - and numerious
Blueprints, Helpers and Templates (on the Home Assistant side). You can see how much work creating such guides involves
by seeing how it was [heroically undertaken by Blakadder](https://blakadder.com/proscenic-in-home-assistant/), as
compared with the [full `hct`-based equivalent](/examples/proscenic_t21.be).

With `hct`, on the other hand, the thorny parts of the initial setup are abstracted away and your final configuration
can often be shared via a one-liner, or failing that a single script. Below is a list of some of the tasks that `hct`
handles for your:

* Announcing the entity via MQTT to Home Assistant
* Generating MQTT/HA-friendly unique IDs
* Associating the entity with its parent device
* Subscribing and publishing to the relevant MQTT topics
* Managing the relevant Tasmota rules
* Appropriate serialization of data
* Translating Home Assistant messages to their to appropriate Berry data types, and vice versa


## Pre-Release

:warning: This library is currently in a pre-release state. The configuration format (and perhaps even the library name)
is likely to change, and only `Sensor`, `Select`, `Button` and `Number` entities are currently implemented.

## Installing

Simply paste the following into your Tasmota Berry Script Console:
```be
tasmota.urlfetch('https://raw.githubusercontent.com/fmtr/hct/master/hct.be','/hct.be')
```

Alternatively, manually download [hct.be](https://raw.githubusercontent.com/fmtr/hct/master/hct.be) and upload it onto
your device.

## Example Walkthrough

This walk-through is a real-world case of implementing the cookbook pull-down menu for a Proscenic T21 air fryer. It
handles defining a friendly pull-down list of food types on the Home Assistant side and mapping those values to the
corresponding IDs required by the Tuya driver on the Tasmota side.

Frist we import this library.

```be
import hct
```

Next we specify the options to show in our pull-down. This could be a list of strings (e.g. `['Foo','Bar']`) - or a mapping from "friendly" values to show in Home Assistant, to corresponding data on the Tasmota side. So here we map food descriptions to their IDs.

```be
options={'Default':0, 'Fries':1,'Shrimp':2,'Pizza':3,'Chicken':4,'Fish':5,'Steak':6,'Cake':7,'Bacon':8,'Preheat':9,'Custom':10}
```

Then we write a very simple callback closure to set those Tuya IDs (the `value` argument) on the Tasmota side, when
their names are selected in Home Assistant.

```be   
/value->tasmota.cmd('TuyaEnum1 '+str(value))
```

Now we specify a trigger defining when a change has happened on the Tasmota side that needs to be reflected in Home Assistant.

```be
trigger='tuyareceived#dptype4id3'
```

With that all done, we can define a pull-down (`hct.Select`) object.

```be
hct.Select(   
    'Air Fryer Cookbook',    # Entity name   
    options,                 # The options we defined above.
    nil,                     # Entity ID (or leave as `nil` if you're happy for Home Assistant to decide)
    'mdi:chef-hat',          # Icon the entity should have in Home Assistant    
    trigger                  # Our trigger as above.  
    set_cookbook_entry       # The handler function we defined above.
)
```

And that's it. Now `hct` will handle everything else mentioned above - and sharing what you've done just means sharing
the above script.