var VERSION='0.3.49'

import string
import tools_constants
import tools as tools_be

class BinarySensorDeviceClass
    static var NONE=nil
    static var BATTERY='battery'
    static var BATTERY_CHARGING='battery_charging'
    static var CARBON_MONOXIDE='carbon_monoxide'
    static var COLD='cold'
    static var CONNECTIVITY='connectivity'
    static var DOOR='door'
    static var GARAGE_DOOR='garage_door'
    static var GAS='gas'
    static var HEAT='heat'
    static var LIGHT='light'
    static var LOCK='lock'
    static var MOISTURE='moisture'
    static var MOTION='motion'
    static var MOVING='moving'
    static var OCCUPANCY='occupancy'
    static var OPENING='opening'
    static var PLUG='plug'
    static var POWER='power'
    static var PRESENCE='presence'
    static var PROBLEM='problem'
    static var RUNNING='running'
    static var SAFETY='safety'
    static var SMOKE='smoke'
    static var SOUND='sound'
    static var TAMPER='tamper'
    static var UPDATE='update'
    static var VIBRATION='vibration'
    static var WINDOW='window'
end

class SensorDeviceClass
    static var APPARENT_POWER = 'apparent_power'
    static var AQI = 'aqi'
    static var ATMOSPHERIC_PRESSURE = 'atmospheric_pressure'
    static var BATTERY = 'battery'
    static var CARBON_DIOXIDE = 'carbon_dioxide'
    static var CARBON_MONOXIDE = 'carbon_monoxide'
    static var CURRENT = 'current'
    static var DATA_RATE = 'data_rate'
    static var DATA_SIZE = 'data_size'
    static var DATE = 'date'
    static var DISTANCE = 'distance'
    static var DURATION = 'duration'
    static var ENERGY = 'energy'
    static var ENUM = 'enum'
    static var FREQUENCY = 'frequency'
    static var GAS = 'gas'
    static var HUMIDITY = 'humidity'
    static var ILLUMINANCE = 'illuminance'
    static var IRRADIANCE = 'irradiance'
    static var MOISTURE = 'moisture'
    static var MONETARY = 'monetary'
    static var NITROGEN_DIOXIDE = 'nitrogen_dioxide'
    static var NITROGEN_MONOXIDE = 'nitrogen_monoxide'
    static var NITROUS_OXIDE = 'nitrous_oxide'
    static var OZONE = 'ozone'
    static var PM1 = 'pm1'
    static var PM10 = 'pm10'
    static var PM25 = 'pm25'
    static var POWER_FACTOR = 'power_factor'
    static var POWER = 'power'
    static var PRECIPITATION = 'precipitation'
    static var PRECIPITATION_INTENSITY = 'precipitation_intensity'
    static var PRESSURE = 'pressure'
    static var REACTIVE_POWER = 'reactive_power'
    static var SIGNAL_STRENGTH = 'signal_strength'
    static var SOUND_PRESSURE = 'sound_pressure'
    static var SPEED = 'speed'
    static var SULPHUR_DIOXIDE = 'sulphur_dioxide'
    static var TEMPERATURE = 'temperature'
    static var TIMESTAMP = 'timestamp'
    static var VOLATILE_ORGANIC_COMPOUNDS = 'volatile_organic_compounds'
    static var VOLTAGE = 'voltage'
    static var VOLUME = 'volume'
    static var WATER = 'water'
    static var WEIGHT = 'weight'
    static var WIND_SPEED = 'wind_speed'
end

var mod = module("hct_constants")
mod.NAME='hct'
mod.ORG='fmtr'
mod.ASSET_FILENAME=string.format('%s.tapp',mod.NAME)
mod.VERSION=VERSION

mod.ON=tools_constants.ON
mod.OFF=tools_constants.OFF
mod.IN='in'
mod.OUT='out'

mod.CHARS_ALLOWED=tools_be.to_chars('abcdefghijklmnopqrstuvwxyz0123456789')
mod.SEPS_ALLOWED=tools_be.to_chars('_- ')

mod.BinarySensorDeviceClass=BinarySensorDeviceClass
mod.SensorDeviceClass=SensorDeviceClass

mod.VALUE_TEMPLATE='{{ value_json.value }}'
mod.INT_MAX=2147483647

return mod