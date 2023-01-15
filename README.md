# Home Assistant Controls for Tasmota

This is a Tasmota Berry Script library (so requires Tasmota32) to greatly simplify the process of exposing Home Assistant controls (e.g. Pull-down Lists, Number Sliders, Text Boxes, etc.) from a Tasmota device - and handling the communication between each side.

## Do I Need This? Can't I Do this with Native Tamota?

You certainly can. But in my experience, the process is so fiddly, error-prone and hard to maintain that it's enough to deter the casual user (as I am) entirely. Plus, sharing your configuration, once you've finally got it working, means complex step-by-step guides invovlving setting up rules, finding MAC addresses and topics (in Tasmota) and numerious Blueprints, Helpers and Templates (on the Home Assistant side).

With `hct`, on the other hand, the thorny parts of the initial setup are abstracted away and your final configuration can be shared via a one-liner.

## Installing

Simply paste the following into you Berry console
```be
tasmota.urlfetch('https://raw.githubusercontent.com/fmtr/hct/master/hct.be','test.be')
```

Alternatively, manually download [hct.be](https://raw.githubusercontent.com/fmtr/hct/master/hct.be) and upload it onto your device.