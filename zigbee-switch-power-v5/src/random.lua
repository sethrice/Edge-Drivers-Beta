--- Smartthings library load ---
local capabilities = require "st.capabilities"
local zcl_clusters = require "st.zigbee.zcl.clusters"
local OnOff = zcl_clusters.OnOff
local Groups = zcl_clusters.Groups
local constants = require "st.zigbee.constants"
local ElectricalMeasurement = zcl_clusters.ElectricalMeasurement
local SimpleMetering = zcl_clusters.SimpleMetering

local write = require "writeAttribute"
local customDivisors = require "customDivisors"


---- Load handlers written in dimmer.lua
local driver_handler = {}

--- Device running and update preferences variables
local device_running = {}
local oldPreferenceValue ={}
local newParameterValue ={}

-- Random tables variables
local random_Step = {}
local random_totalStep = {}
local random_timer = {}

-- Custom Capability Randon On Off
local random_On_Off = capabilities["legendabsolute60149.randomOnOff2"]
local random_Next_Step = capabilities["legendabsolute60149.randomNextStep2"]
local get_Groups = capabilities["legendabsolute60149.getGroups"]

----- do_init device tables create for dimming variables ----
function driver_handler.do_init (self, device)
  print("<<< random.do_init >>>")
  local device_exist = "no"
  for id, value in pairs(device_running) do
   if device_running[id] == device then
    device_exist = "si"
   end
  end
 ---- If is new device initialize table values
 if device_exist == "no" then
  device_running[device]= device
  oldPreferenceValue[device] = "-"
  newParameterValue[device] = "-"
  random_Step[device] = 1
  random_totalStep[device] =2
  random_timer[device] = math.random(10, 20)

  -- send zigbee event if random on-off Inactive or nil
  --print("<<<< random_state >>>>",device:get_field("random_state"))
  if device:get_field("random_state") == "Inactive"  or device:get_field("random_state") == nil then
   device:emit_event(random_On_Off.randomOnOff("Inactive"))
   device:emit_event(random_Next_Step.randomNext("Inactive"))
   device:set_field("random_state", "Inactive", {persist = true})
  end

  ----- print device init values for debug------
  for id, value in pairs(device_running) do
    if device.preferences.logDebugPrint == true then
      print("device_running[id]=",device_running[id])
      print("device_running, random_Step=",device_running[id],random_Step[id])
      print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
      print("device_running, random_timer=",device_running[id],random_timer[id])
    end
  end
 end
  --restart random on-off if active
  if device.preferences.logDebugPrint == true then
    print("random_state >>>>>",device:get_field("random_state"))
  end
  if device:get_field("random_state") ~= "Inactive" and device:get_field("random_state") ~= nil then  
    driver_handler.random_on_off_handler(self,device,"Active")
  end

  -- Configure OnOff monitoring attribute
  local interval =  device.preferences.onOffReports
  if  device.preferences.onOffReports == nil then interval = 300 end
  local config ={
    cluster = zcl_clusters.OnOff.ID,
    attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
    minimum_interval = 0,
    maximum_interval = interval,
    data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
  }
  --device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, device.preferences.onOffReports))
  device:add_configured_attribute(config)
  device:add_monitored_attribute(config)
end

---- do_removed device procedure: delete all device data
function driver_handler.do_removed(self,device)
  for id, value in pairs(device_running) do
    if device_running[id] == device then
    device_running[device] =nil
    oldPreferenceValue[device] = nil
    newParameterValue[device] = nil
    random_Step[device] = nil
    random_totalStep[device] = nil
    random_timer[device] = nil
   end
  end
  
  -----print tables of devices no removed from driver ------
  for id, value in pairs(device_running) do
    if device.preferences.logDebugPrint == true then
      print("device_running[id]",device_running[id])
      print("device_running, random_Step=",device_running[id],random_Step[id])
      print("device_running, random_totalStep=",device_running[id],random_totalStep[id])
      print("device_running, random_timer=",device_running[id],random_timer[id])
    end
  end
end

--- Update preferences after infoChanged recived---
function driver_handler.do_Preferences (self, device)
  for id, value in pairs(device.preferences) do
    --print("device.preferences[infoChanged]=", device.preferences[id])
    oldPreferenceValue[device] = device:get_field(id)
    newParameterValue[device] = device.preferences[id]
    if oldPreferenceValue[device] ~= newParameterValue[device] then
      device:set_field(id, newParameterValue[device], {persist = true})
      print("<< Preference changed:", id, "old value:",oldPreferenceValue[device], "new Value:", newParameterValue[device])

      --- Groups code preference value changed
      if id == "groupAdd" then
        if device.preferences[id] > 0 then
          if device.preferences.logDebugPrint == true then
            print("Add Groups >>>>>>>>>>>>>>>>>")
          end
          local data = device.preferences[id]
          device:send(Groups.server.commands.AddGroup(device, data, "Group"..tostring(data)))
          device:send(Groups.server.commands.GetGroupMembership(device, {}))
        else
         device:send(Groups.server.commands.GetGroupMembership(device, {}))
        end
      elseif id == "groupRemove" then
        if device.preferences.logDebugPrint == true then
          print("Remove Groups >>>>>>>>>>>>>>>>>")
        end
        if device.preferences[id] > 0 then
         device:send(Groups.server.commands.RemoveGroup(device, device.preferences[id]))
        else
         device:send(Groups.server.commands.RemoveAllGroups(device, {}))
        end
        device:send(Groups.server.commands.GetGroupMembership(device, {}))
      end

      ------ Change profile & Icon
      if id == "changeProfile" then
       if newParameterValue[device] == "Switch" then
        device:try_update_metadata({profile = "switch-power"})
       elseif newParameterValue[device] == "Plug" then
        device:try_update_metadata({profile = "switch-power-plug"})
       elseif newParameterValue[device] == "Light" then
        device:try_update_metadata({profile = "switch-power-light"})
       end
      elseif id == "changeProfileEner" then
        if newParameterValue[device] == "Switch" then
         device:try_update_metadata({profile = "switch-power-energy"})
        elseif newParameterValue[device] == "Plug" then
         device:try_update_metadata({profile = "switch-power-energy-plug"})
        elseif newParameterValue[device] == "Light" then
         device:try_update_metadata({profile = "switch-power-energy-light"})
        end
      -- Any Preference timer mode changed restart timer handler
      elseif id == "randomMin" or id == "randomMax" or id == "onTime" or id == "offTime" then
        if device:get_field("random_state") ~= "Inactive" and device:get_field("random_state") ~= nil then  
          driver_handler.random_on_off_handler(self,device,"Active")
        end
      elseif id == "onOffReports" then
        -- Configure OnOff interval report
        local interval =  device.preferences.onOffReports
        if  device.preferences.onOffReports == nil then interval = 300 end
        local config ={
          cluster = zcl_clusters.OnOff.ID,
          attribute = zcl_clusters.OnOff.attributes.OnOff.ID,
          minimum_interval = 0,
          maximum_interval = interval,
          data_type = zcl_clusters.OnOff.attributes.OnOff.base_type
        }
        device:send(zcl_clusters.OnOff.attributes.OnOff:configure_reporting(device, 0, interval))
        device:add_monitored_attribute(config)

      -- set custom power and energy divisors
      elseif id == "simpleMeteringDivisor1" then
        if newParameterValue[device] > 0 then
          device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, device.preferences.simpleMeteringDivisor1, {persist = true})
        else
          device:set_field(constants.SIMPLE_METERING_DIVISOR_KEY, 1, {persist = true})
          device:send(SimpleMetering.attributes.Divisor:read(device))
          --- save optionals device divisors
          device.thread:call_with_delay(2, function() customDivisors.set_custom_divisors(self, device) end)
        end
      elseif id == "electricalMeasureDiviso1" then
        if newParameterValue[device] > 0 then
          device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, device.preferences.electricalMeasureDiviso1, {persist = true})
        else
          device:set_field(constants.ELECTRICAL_MEASUREMENT_DIVISOR_KEY, 1, {persist = true})
          device:send(ElectricalMeasurement.attributes.ACPowerDivisor:read(device))
          --- save optionals device divisors
          device.thread:call_with_delay(2, function() customDivisors.set_custom_divisors(self, device) end)
        end
      end  

      --- Configure on-off cluster, attributte 0x8002 and 4003 to value restore state in preferences
      if id == "restoreState" then
        print("<<< Write restore state >>>")
        local value_send = tonumber(newParameterValue[device])
        local data_value = {value = value_send, ID = 0x30}
        local cluster_id = {value = 0x0006}
        --write atribute for zigbee standard devices
        local attr_id = 0x4003
        write.write_attribute_function(device, cluster_id, attr_id, data_value)

        --write atribute for Tuya devices (Restore previous state = 0x02)
        if newParameterValue[device] == "255" then data_value = {value = 0x02, ID = 0x30} end
        attr_id = 0x8002
        write.write_attribute_function(device, cluster_id, attr_id, data_value)
      end
    end
  end
  --print manufacturer, model and leng of the strings
  local manufacturer = device:get_manufacturer()
  local model = device:get_model()
  local manufacturer_len = string.len(manufacturer)
  local model_len = string.len(model)

  print("Device ID", device)
  print("Manufacturer >>>", manufacturer, "Manufacturer_Len >>>",manufacturer_len)
  print("Model >>>", model,"Model_len >>>",model_len)
  -- This will print in the log the total memory in use by Lua in Kbytes
  print("Memory >>>>>>>",collectgarbage("count"), " Kbytes")
end

 --------------------------------------------------------
 --------- Handler Random ON-OFF ------------------------

function driver_handler.random_on_off_handler(_,device,command)

  ---- Timers Cancel ------
  --for timer in pairs(device.thread.timers) do
    --print("<<<<< Cancel all timer >>>>>")
    --device.thread:cancel_timer(timer)
  --end
  local set_status_timer = device:get_field("timer_random")
  if set_status_timer then
    print("<<<<< Cancelando timer_random >>>>>")
    device.thread:cancel_timer(set_status_timer)
    device:set_field("timer_random", nil)
  end
  
  local random_state = "-"
  local nextChange = "Inactive"
  if command == "Active" then
    --random_state = "Active"
    random_state = device:get_field("random_state")
  else
    random_state = command.args.value
  end
 
  if device.preferences.logDebugPrint == true then
    print("randomOnOff Value", random_state)
  end
  if random_state == "Inactive" then

    -- send zigbee event
    device:send(OnOff.server.commands.Off(device))
    device:emit_event(random_On_Off.randomOnOff("Inactive"))
    device:set_field("random_state", "Inactive", {persist = true})
    --emit time for next change
    nextChange = "Inactive"
    device:emit_event(random_Next_Step.randomNext(nextChange))

 elseif random_state == "Random" or random_state == "Program" then
    device:emit_event(random_On_Off.randomOnOff(random_state))
    device:set_field("random_state", random_state, {persist = true})
 
    if random_state == "Random" then
    --Random timer calculation
    random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
    random_Step[device] = 0
    random_totalStep[device] = math.ceil(random_timer[device] / 30)
    nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
    else
      device:send(OnOff.server.commands.On(device))
      device:set_field("last_state", "on", {persist = false})
      --Program timer calculation
      random_timer[device] = device.preferences.onTime * 60
      random_Step[device] = 0
      random_totalStep[device] = math.ceil(random_timer[device] / 30)
      nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
    end
  --emit time for next change
  device:emit_event(random_Next_Step.randomNext(nextChange))
  if device.preferences.logDebugPrint == true then
    print("random_totalStep=",random_totalStep[device])
    print("NextChange=",nextChange)
  end

  ------ Timer activation
  set_status_timer = device.thread:call_on_schedule(
  30,
    function ()
    random_Step[device] = random_Step[device] + 1
    if device.preferences.logDebugPrint == true then
      print("random_step, random_totalStep=",random_Step[device],random_totalStep[device])
    end

      if random_Step[device] >= random_totalStep[device] then

        if device:get_latest_state("main", capabilities.switch.ID, capabilities.switch.switch.NAME) == "on" then
          random_timer[device] = device.preferences.onTime * 60
          device:send(OnOff.server.commands.Off(device))
        else
          random_timer[device] = device.preferences.offTime * 60
          device:send(OnOff.server.commands.On(device))
        end
        if random_state == "Random" then
          random_timer[device] = math.random(device.preferences.randomMin * 60, device.preferences.randomMax * 60)
          random_Step[device] = 0
          random_totalStep[device] = math.ceil(random_timer[device] / 30)
          nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
        else
          --Program timer calculation
          random_Step[device] = 0
          random_totalStep[device] = math.ceil(random_timer[device] / 30)
          nextChange= os.date("%H:%M:%S",os.time() + random_timer[device] + device.preferences.localTimeOffset * 3600)
        end

        --emit time for next change
        device:emit_event(random_Next_Step.randomNext(nextChange))
        if device.preferences.logDebugPrint == true then
          print("NEW-random_totalStep=",random_totalStep[device])
          print("NextChange=",nextChange)
        end
      end
    end
  ,'Random-ON-OFF')
  device:set_field("timer_random", set_status_timer)
  end

end

  return driver_handler