-- M.Colmenarejo 2023
local common = require("multi-contact/common")

local can_handle = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    if device:get_manufacturer() == "SmartThings" and device:get_model() ~="PGC313" and device:get_model() ~="PGC313EU" then
      return device:get_manufacturer() == "SmartThings"
    elseif device:get_manufacturer() == "CentraLite" then
      return device:get_manufacturer() == "CentraLite"
    end
  end
  return false
end

local smartthings_multi_sensor = {
	NAME = "SmartThings multi sensor",
    zigbee_handlers = {
        attr = {
            [common.MFG_CLUSTER] = {
                [common.ACCELERATION_ATTR_ID] = common.acceleration_handler,
                [common.X_AXIS_ATTR_ID] = common.axis_handler(3, true), -- lua indexes from 1
                [common.Y_AXIS_ATTR_ID] = common.axis_handler(2, false),
                [common.Z_AXIS_ATTR_ID] = common.axis_handler(1, false)
            },
        }
    },
    lifecycle_handlers = {
        --init = battery_defaults.build_linear_voltage_init(2.3, 3.0)
    },
	can_handle = can_handle
}

return smartthings_multi_sensor
