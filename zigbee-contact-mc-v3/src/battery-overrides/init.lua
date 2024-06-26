-- Copyright 2021 SmartThings
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

local battery_defaults = require "st.zigbee.defaults.battery_defaults"

local battery_range_2_1v_handler = {
  NAME = "Cell battery 2.1v",
  lifecycle_handlers = {
    init = battery_defaults.build_linear_voltage_init(2.1, 3.0)
  },
  can_handle = function(opts, driver, device, ...)
    if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
      if device:get_manufacturer() == "Visonic" then
        local subdriver = require("battery-overrides")
        return true, subdriver
      end
    end
    return false
  end
}

return battery_range_2_1v_handler
