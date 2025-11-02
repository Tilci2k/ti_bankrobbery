-- client/main.lua
local Config = lib.require 'config'
local QBX = exports.qbx_core

local hasRobberyStarted = false
local lastRobberyTime = 0
local doorLockTimers = {} -- Track door lock timers
local depositBoxZones = {} -- Track created deposit box zones
local securitySystemDisabled = false
local securityFailures = 0

-- Timer helper functions
local timers = {}
local timerCounter = 0

function setTimeout(callback, delay)
    timerCounter = timerCounter + 1
    local timerId = timerCounter
    
    CreateThread(function()
        Wait(delay)
        if timers[timerId] then
            timers[timerId] = nil
            callback()
        end
    end)
    
    timers[timerId] = true
    return timerId
end

function clearTimeout(timerId)
    timers[timerId] = nil
end

-- Create interaction points using ox_target
CreateThread(function()
    -- Vault terminal interaction
    exports.ox_target:addBoxZone({
        coords = Config.VaultTerminal.coords,
        size = vec3(1, 1, 1),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'bank_vault_terminal',
                event = 'ti_bankrobbery:client:startVaultHack',
                icon = 'fas fa-laptop',
                label = 'Hack Vault Terminal',
                canInteract = function()
                    return not hasRobberyStarted and 
                           (GetGameTimer() - lastRobberyTime) > (Config.Cooldown * 1000)
                end
            }
        }
    })

    -- Security system terminal interaction (optional - can be done before vault hack)
    if Config.SecuritySystem and Config.SecuritySystem.coords then
        exports.ox_target:addBoxZone({
            coords = Config.SecuritySystem.coords,
            size = vec3(1, 1, 1),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = 'bank_security_terminal',
                    event = 'ti_bankrobbery:client:disableSecurity',
                    icon = 'fas fa-shield-alt',
                    label = 'Disable Security System (Optional)',
                    canInteract = function()
                        return not hasRobberyStarted and 
                               (GetGameTimer() - lastRobberyTime) > (Config.Cooldown * 1000) and
                               not securitySystemDisabled
                    end
                }
            }
        })
    end

    -- Create inner door interactions
    for i, door in ipairs(Config.InnerDoors) do
        exports.ox_target:addBoxZone({
            coords = door.coords,
            size = vec3(1, 1, 1),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = 'inner_vault_door_' .. i,
                    event = 'ti_bankrobbery:client:lockpickDoor',
                    icon = 'fas fa-lock',
                    label = 'Lockpick Door',
                    canInteract = function()
                        return hasRobberyStarted
                    end,
                    args = { doorIndex = i }
                }
            }
        })
    end
end)

-- Start vault hack
RegisterNetEvent('ti_bankrobbery:client:startVaultHack', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    if #(pos - Config.VaultTerminal.coords) > 2.0 then 
        QBX:Notify("Too far from target!", "error")
        return 
    end
    
    -- Check if player has required item
    if Config.VaultTerminal.requiredItem then
        local itemCount = exports.ox_inventory:Search('count', Config.VaultTerminal.requiredItem)
        if not itemCount or itemCount <= 0 then
            QBX:Notify("You need a " .. Config.VaultTerminal.requiredItem .. "!", "error")
            return
        end
    end
    
    -- Play animation
    RequestAnimDict("anim@heists@prison_heiststation@")
    while not HasAnimDictLoaded("anim@heists@prison_heiststation@") do
        Wait(10)
    end
    
    TaskStartScenarioInPlace(ped, "PROP_HUMAN_ATM", 0, true)
    
    -- Start terminal minigame with correct parameters
    local success = exports["iconminigame"]:Terminal(
        Config.VaultTerminal.minigame.rows or 5,
        Config.VaultTerminal.minigame.columns or 3,
        Config.VaultTerminal.minigame.viewTime or 15,
        Config.VaultTerminal.minigame.typeTime or 12,
        Config.VaultTerminal.minigame.answersNeeded or 5
    )
    
    ClearPedTasks(ped)
    
    if success then
        -- Consume the electronic kit
        TriggerServerEvent('ti_bankrobbery:server:consumeItem', Config.VaultTerminal.requiredItem, 1)
        TriggerServerEvent('ti_bankrobbery:server:vaultHackSuccess')
        hasRobberyStarted = true
    else
        QBX:Notify("Hack failed!", "error")
    end
end)

-- Disable security system event (optional - can be done before vault hack)
RegisterNetEvent('ti_bankrobbery:client:disableSecurity', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    if #(pos - Config.SecuritySystem.coords) > 2.0 then 
        QBX:Notify("Too far from target!", "error")
        return 
    end
    
    -- Check if player has required item
    if Config.SecuritySystem.requiredItem then
        local itemCount = exports.ox_inventory:Search('count', Config.SecuritySystem.requiredItem)
        if not itemCount or itemCount <= 0 then
            QBX:Notify("You need a " .. Config.SecuritySystem.requiredItem .. "!", "error")
            return
        end
    end
    
    -- Play animation
    RequestAnimDict("anim@heists@prison_heiststation@")
    while not HasAnimDictLoaded("anim@heists@prison_heiststation@") do
        Wait(10)
    end
    
    TaskStartScenarioInPlace(ped, "PROP_HUMAN_ATM", 0, true)
    
    -- Start terminal minigame with correct parameters
    local success = exports["iconminigame"]:Terminal(
        Config.SecuritySystem.minigame.rows or 5,
        Config.SecuritySystem.minigame.columns or 3,
        Config.SecuritySystem.minigame.viewTime or 15,
        Config.SecuritySystem.minigame.typeTime or 12,
        Config.SecuritySystem.minigame.answersNeeded or 5
    )
    
    ClearPedTasks(ped)
    
    if success then
        -- Consume the electronic kit
        TriggerServerEvent('ti_bankrobbery:server:consumeItem', Config.SecuritySystem.requiredItem, 1)
        securitySystemDisabled = true
        securityFailures = 0
        QBX:Notify("Security system disabled! Police dispatch will be delayed by 1 minute.", "success")
        TriggerServerEvent('ti_bankrobbery:server:securityDisabled')
    else
        securityFailures = securityFailures + 1
        QBX:Notify("Security hack failed! Attempt " .. securityFailures .. "/" .. (Config.SecuritySystem.maxFailures + 1), "error")
        TriggerServerEvent('ti_bankrobbery:server:securityHackFailed', securityFailures)
    end
end)

-- Open vault door and trigger dispatch
RegisterNetEvent('ti_bankrobbery:client:openVaultDoor', function()
    -- Open the main vault door using ox_doorlock with door ID
    if Config.VaultDoor.doorId and Config.VaultDoor.doorId > 0 then
        TriggerEvent('ox_doorlock:setState', Config.VaultDoor.doorId, false) -- false = unlocked/open
        QBX:Notify("Vault door opened!", "success")
        
        -- Trigger police dispatch based on security system status
        if securitySystemDisabled then
            -- Delay police dispatch by 1 minute (60000 ms)
            QBX:Notify("Security system bypassed - police dispatch delayed by 1 minute", "success")
            setTimeout(function()
                if hasRobberyStarted then -- Only dispatch if robbery is still active
                    exports['ps-dispatch']:PacificBankRobbery(1)
                    QBX:Notify("Police have been alerted!", "error")
                end
            end, 60000) -- 1 minute delay
        else
            -- Immediate police dispatch
            exports['ps-dispatch']:PacificBankRobbery(1)
            QBX:Notify("Police have been alerted immediately!", "error")
        end
        
        -- Set timer to lock door after 10 minutes (600000 ms)
        if doorLockTimers.vault then
            clearTimeout(doorLockTimers.vault)
        end
        doorLockTimers.vault = setTimeout(function()
            if Config.VaultDoor.doorId and Config.VaultDoor.doorId > 0 then
                TriggerEvent('ox_doorlock:setState', Config.VaultDoor.doorId, true) -- true = locked
                QBX:Notify("Vault door has been secured by the security system", "primary")
            end
            doorLockTimers.vault = nil
        end, 600000) -- 10 minutes = 600000 ms
    else
        QBX:Notify("Vault door not configured properly!", "error")
    end
end)

-- Lockpick door event
RegisterNetEvent('ti_bankrobbery:client:lockpickDoor', function(data)
    -- Handle different ways ox_target might pass the data
    local doorIndex = nil
    
    if data and type(data) == "table" then
        if data.doorIndex then
            doorIndex = data.doorIndex
        elseif data.args and data.args.doorIndex then
            doorIndex = data.args.doorIndex
        end
    elseif data and type(data) == "number" then
        doorIndex = data
    end
    
    if not doorIndex then
        QBX:Notify("Invalid door index!", "error")
        return
    end
    
    local doorConfig = Config.InnerDoors[doorIndex]
    
    if not doorConfig then 
        QBX:Notify("Door configuration not found for index: " .. tostring(doorIndex), "error")
        return 
    end
    
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    if #(pos - doorConfig.coords) > 2.0 then 
        QBX:Notify("Too far from door!", "error")
        return 
    end
    
    -- Check if player has required item
    if doorConfig.requiredItem then
        local itemCount = exports.ox_inventory:Search('count', doorConfig.requiredItem)
        if not itemCount or itemCount <= 0 then
            QBX:Notify("You need a " .. doorConfig.requiredItem .. "!", "error")
            return
        end
    end
    
    -- Play lockpick animation
    RequestAnimDict("veh@break_in@0h@p_m_one@")
    while not HasAnimDictLoaded("veh@break_in@0h@p_m_one@") do
        Wait(10)
    end
    
    TaskPlayAnim(ped, "veh@break_in@0h@p_m_one@", "loop", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    Wait(1000) -- Give time for animation to start
    
    -- Start lockpick minigame with correct parameters
    local success = exports["iconminigame"]:Lockpick(
        "Custom Lockpick", 
        doorConfig.lockpick.levels or 3, 
        doorConfig.lockpick.timer or 40
    )
    
    StopAnimTask(ped, "veh@break_in@0h@p_m_one@", "loop", 1.0)
    
    if success then
        -- Consume item if configured
        if doorConfig.consumeItem and doorConfig.requiredItem then
            TriggerServerEvent('ti_bankrobbery:server:consumeItem', doorConfig.requiredItem, 1, doorIndex)
        else
            -- Open the door using door ID
            if doorConfig.doorId and doorConfig.doorId > 0 then
                TriggerEvent('ox_doorlock:setState', doorConfig.doorId, false) -- false = unlocked/open
                QBX:Notify("Door unlocked!", "success")
                
                -- Set timer to lock door after 10 minutes (600000 ms)
                if doorLockTimers["inner_" .. doorIndex] then
                    clearTimeout(doorLockTimers["inner_" .. doorIndex])
                end
                doorLockTimers["inner_" .. doorIndex] = setTimeout(function()
                    if doorConfig.doorId and doorConfig.doorId > 0 then
                        TriggerEvent('ox_doorlock:setState', doorConfig.doorId, true) -- true = locked
                        QBX:Notify("Inner vault door has been secured by the security system", "primary")
                    end
                    doorLockTimers["inner_" .. doorIndex] = nil
                end, 600000) -- 10 minutes = 600000 ms
                
                TriggerServerEvent('ti_bankrobbery:server:doorUnlocked', doorIndex)
            else
                QBX:Notify("Door not configured properly!", "error")
            end
        end
    else
        QBX:Notify("Lockpick failed!", "error")
        -- Chance to break consumable item
        if doorConfig.consumeItem and math.random(1, 100) <= 30 then
            TriggerServerEvent('ti_bankrobbery:server:consumeItem', doorConfig.requiredItem, 1, doorIndex, true) -- true for break
        else
            QBX:Notify("Failed to pick the lock!", "error")
        end
    end
end)

-- Handle item consumption result from server
RegisterNetEvent('ti_bankrobbery:client:itemConsumed', function(doorIndex, itemBroke)
    local doorConfig = Config.InnerDoors[doorIndex]
    if not doorConfig then return end
    
    if itemBroke then
        QBX:Notify("Your " .. doorConfig.requiredItem .. " broke!", "error")
    end
    
    -- Open the door using door ID
    if doorConfig.doorId and doorConfig.doorId > 0 then
        TriggerEvent('ox_doorlock:setState', doorConfig.doorId, false) -- false = unlocked/open
        QBX:Notify("Door unlocked!", "success")
        
        -- Set timer to lock door after 10 minutes (600000 ms)
        if doorLockTimers["inner_" .. doorIndex] then
            clearTimeout(doorLockTimers["inner_" .. doorIndex])
        end
        doorLockTimers["inner_" .. doorIndex] = setTimeout(function()
            if doorConfig.doorId and doorConfig.doorId > 0 then
                TriggerEvent('ox_doorlock:setState', doorConfig.doorId, true) -- true = locked
                QBX:Notify("Inner vault door has been secured by the security system", "primary")
            end
            doorLockTimers["inner_" .. doorIndex] = nil
        end, 600000) -- 10 minutes = 600000 ms
        
        TriggerServerEvent('ti_bankrobbery:server:doorUnlocked', doorIndex)
    else
        QBX:Notify("Door not configured properly!", "error")
    end
end)

-- Create deposit box interactions
RegisterNetEvent('ti_bankrobbery:client:createDepositBoxZones', function(doorIndex)
    local boxConfig = Config.DepositBoxes[doorIndex]
    if not boxConfig then return end
    
    -- Remove existing zones for this door if any
    if depositBoxZones[doorIndex] then
        for _, zoneId in ipairs(depositBoxZones[doorIndex]) do
            exports.ox_target:removeZone(zoneId)
        end
    end
    depositBoxZones[doorIndex] = {}
    
    -- Create new zones for deposit boxes
    for i, box in ipairs(boxConfig.boxes) do
        local zoneId = exports.ox_target:addBoxZone({
            coords = box.coords,
            size = vec3(0.5, 0.5, 0.5),
            rotation = 0,
            debug = false,
            options = {
                {
                    name = 'deposit_box_' .. doorIndex .. '_' .. i,
                    event = 'ti_bankrobbery:client:drillBox',
                    icon = 'fas fa-toolbox',
                    label = 'Drill Deposit Box',
                    canInteract = function()
                        return hasRobberyStarted
                    end,
                    args = { doorIndex = doorIndex, boxIndex = i }
                }
            }
        })
        
        if zoneId then
            table.insert(depositBoxZones[doorIndex], zoneId)
        end
    end
    
    QBX:Notify("Deposit boxes are now accessible!", "success")
end)

-- Remove deposit box zones
RegisterNetEvent('ti_bankrobbery:client:removeDepositBoxZones', function(doorIndex)
    if depositBoxZones[doorIndex] then
        for _, zoneId in ipairs(depositBoxZones[doorIndex]) do
            exports.ox_target:removeZone(zoneId)
        end
        depositBoxZones[doorIndex] = nil
    end
end)

-- Drill deposit box
RegisterNetEvent('ti_bankrobbery:client:drillBox', function(data)
    local doorIndex = nil
    local boxIndex = nil
    
    -- Handle different ways ox_target might pass the data
    if data and type(data) == "table" then
        if data.doorIndex and data.boxIndex then
            doorIndex = data.doorIndex
            boxIndex = data.boxIndex
        elseif data.args and data.args.doorIndex and data.args.boxIndex then
            doorIndex = data.args.doorIndex
            boxIndex = data.args.boxIndex
        end
    end
    
    if not doorIndex or not boxIndex then
        QBX:Notify("Invalid box data!", "error")
        return
    end
    
    local boxConfig = Config.DepositBoxes[doorIndex]
    
    if not boxConfig or not boxConfig.boxes[boxIndex] then 
        QBX:Notify("Box configuration not found!", "error")
        return 
    end
    
    local box = boxConfig.boxes[boxIndex]
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    
    if #(pos - box.coords) > 2.0 then 
        QBX:Notify("Too far from box!", "error")
        return 
    end
    
    -- Check if player has required item
    if Config.Drill.requiredItem then
        local itemCount = exports.ox_inventory:Search('count', Config.Drill.requiredItem)
        if not itemCount or itemCount <= 0 then
            QBX:Notify("You need a " .. Config.Drill.requiredItem .. "!", "error")
            return
        end
    end
    
    -- Play drill animation
    RequestAnimDict(Config.Drill.animDict)
    while not HasAnimDictLoaded(Config.Drill.animDict) do
        Wait(10)
    end
    
    local drillProp = CreateObject(GetHashKey(Config.Drill.prop), pos.x, pos.y, pos.z, true, true, true)
    AttachEntityToEntity(drillProp, ped, GetPedBoneIndex(ped, Config.Drill.bone), 0.0, 0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
    
    TaskPlayAnim(ped, Config.Drill.animDict, Config.Drill.animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    
    -- Start lockpick minigame (for drilling)
    local success = exports["iconminigame"]:Lockpick(
        "Drilling", 
        3, 
        30
    )
    
    ClearPedTasks(ped)
    DeleteObject(drillProp)
    
    if success then
        -- Consume drill with chance
        if math.random(1, 100) <= 10 then -- 10% chance to break drill
            TriggerServerEvent('ti_bankrobbery:server:consumeItem', Config.Drill.requiredItem, 1)
            QBX:Notify("Your drill broke!", "error")
        else
            TriggerServerEvent('ti_bankrobbery:server:giveBoxReward', doorIndex, boxIndex)
        end
    else
        QBX:Notify("Drilling failed!", "error")
    end
end)

-- Reset robbery state and clear door timers
RegisterNetEvent('ti_bankrobbery:client:resetRobbery', function()
    hasRobberyStarted = false
    lastRobberyTime = GetGameTimer()
    securitySystemDisabled = false
    securityFailures = 0
    QBX:Notify("Bank security has been reset", "primary")
    
    -- Clear all door lock timers
    for timerName, timerId in pairs(doorLockTimers) do
        clearTimeout(timerId)
        doorLockTimers[timerName] = nil
    end
    
    -- Remove all deposit box zones
    for doorIndex, _ in pairs(depositBoxZones) do
        TriggerEvent('ti_bankrobbery:client:removeDepositBoxZones', doorIndex)
    end
    depositBoxZones = {}
    
    -- Lock all doors immediately on reset
    if Config.VaultDoor.doorId and Config.VaultDoor.doorId > 0 then
        TriggerEvent('ox_doorlock:setState', Config.VaultDoor.doorId, true) -- true = locked
    end
    
    for _, doorConfig in ipairs(Config.InnerDoors) do
        if doorConfig.doorId and doorConfig.doorId > 0 then
            TriggerEvent('ox_doorlock:setState', doorConfig.doorId, true) -- true = locked
        end
    end
end)

-- Test commands
RegisterCommand('bankrobtestdoor', function(source, args)
    local playerPed = PlayerPedId()
    if GetInvokingResource() and GetInvokingResource() ~= "ti_bankrobbery" then return end
    
    local doorIndex = tonumber(args[1]) or 1
    
    if doorIndex < 1 or doorIndex > #Config.InnerDoors then
        QBX:Notify("Invalid door index! Use 1-" .. #Config.InnerDoors, "error")
        return
    end
    
    -- Simulate successful door unlock
    local doorConfig = Config.InnerDoors[doorIndex]
    if doorConfig and doorConfig.doorId and doorConfig.doorId > 0 then
        TriggerEvent('ox_doorlock:setState', doorConfig.doorId, false) -- false = unlocked
        
        -- Set timer to lock door after 10 minutes (600000 ms)
        if doorLockTimers["inner_" .. doorIndex] then
            clearTimeout(doorLockTimers["inner_" .. doorIndex])
        end
        doorLockTimers["inner_" .. doorIndex] = setTimeout(function()
            if doorConfig.doorId and doorConfig.doorId > 0 then
                TriggerEvent('ox_doorlock:setState', doorConfig.doorId, true) -- true = locked
                QBX:Notify("Inner vault door has been secured by the security system", "primary")
            end
            doorLockTimers["inner_" .. doorIndex] = nil
        end, 600000) -- 10 minutes = 600000 ms
        
        TriggerServerEvent('ti_bankrobbery:server:doorUnlocked', doorIndex)
        QBX:Notify("Door " .. doorIndex .. " opened for testing!", "success")
    end
end, false)

-- Add hint for the command
RegisterCommand('helpbankrob', function()
    print("^2=== Bank Robbery Test Commands ===^0")
    print("^3/bankrobtest start^0 - Bypass terminal and start robbery")
    print("^3/bankrobtest reset^0 - Reset robbery state")
    print("^3/bankrobtestdoor [1-2]^0 - Open specific inner door")
    print("^0")
end, false)

-- Lock all doors on resource start (to ensure they start locked)
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Wait(1000) -- Wait for ox_doorlock to be ready
        
        -- Lock all doors on startup
        if Config.VaultDoor.doorId and Config.VaultDoor.doorId > 0 then
            TriggerEvent('ox_doorlock:setState', Config.VaultDoor.doorId, true) -- true = locked
        end
        
        for _, doorConfig in ipairs(Config.InnerDoors) do
            if doorConfig.doorId and doorConfig.doorId > 0 then
                TriggerEvent('ox_doorlock:setState', doorConfig.doorId, true) -- true = locked
            end
        end
    end
end)

-- Clean up on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Clear all door lock timers
        for timerName, timerId in pairs(doorLockTimers) do
            clearTimeout(timerId)
            doorLockTimers[timerName] = nil
        end
        
        -- Remove all deposit box zones
        for doorIndex, _ in pairs(depositBoxZones) do
            TriggerEvent('ti_bankrobbery:client:removeDepositBoxZones', doorIndex)
        end
        depositBoxZones = {}
    end
end)