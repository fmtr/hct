import sys
var wd = tasmota.wd
if size(wd) sys.path().push(wd) end

import hct

if size(wd) sys.path().pop() end