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

local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OccupancySensing = zcl_clusters.OccupancySensing

--module emit signal metrics
local signal = require "signal-metrics"

local ZIGBEE_PLUGIN_MOTION_SENSOR_FINGERPRINTS = {
  { mfr = "eZEX", model = "E280-KR0A0Z0-HA" },
  { mfr = "LUMI", model = "lumi.sensor_motion.aq2" }
}

local is_zigbee_plugin_motion_sensor = function(opts, driver, device)
  if device.network_type ~= "DEVICE_EDGE_CHILD" then -- is NO CHILD DEVICE
    for _, fingerprint in ipairs(ZIGBEE_PLUGIN_MOTION_SENSOR_FINGERPRINTS) do
      if device:get_manufacturer() == fingerprint.mfr and device:get_model() == fingerprint.model then
        local subdriver = require("zigbee-plugin-motion-sensor")
          return true, subdriver
      end
    end
  end
  return false
end

local function occupancy_attr_handler(driver, device, occupancy, zb_rx)
  -- emit signal metrics
  signal.metrics(device, zb_rx)
  
  device:emit_event(((occupancy.value & 0x01) ~= 0) and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())
  --device:emit_event(occupancy.value == 0x01 and capabilities.motionSensor.motion.active() or capabilities.motionSensor.motion.inactive())

  -- Reset motion status 
  if device:get_model() ==  "lumi.sensor_motion.aq2" then
    ---- All Timers Cancel ------
    for timer in pairs(device.thread.timers) do
      print("<<<<< Cancel all timer >>>>>")
      device.thread:cancel_timer(timer)
    end

    device.thread:call_with_delay(device.preferences.motionTimeOut, function(d)
      device:emit_event(capabilities.motionSensor.motion.inactive())
    end)
  end
end

local zigbee_plugin_motion_sensor = {
  NAME = "zigbee plugin motion sensor",
  lifecycle_handlers = {
  },
  zigbee_handlers = {
    attr = {
      [OccupancySensing.ID] = {
        [OccupancySensing.attributes.Occupancy.ID] = occupancy_attr_handler
      }
    }
  },
  capability_handlers = {
    
  },
  can_handle = is_zigbee_plugin_motion_sensor
}

return zigbee_plugin_motion_sensor
