-- server/main.lua
local Config = lib.require 'config'
local QBX = exports.qbx_core

local hasRobberyStarted = false
local lastRobberyTime = 0
local unlockedDoors = {}
local robberyStartTime = 0
local securitySystemDisabled = false
local securityFailures = 0

-- Vault hack success
RegisterNetEvent('ti_bankrobbery:server:vaultHackSuccess', function()
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    if hasRobberyStarted then
        DropPlayer(src, "Attempted robbery exploit")
        return
    end
    
    if (os.time() - lastRobberyTime) < Config.Cooldown then
        TriggerClientEvent('QBX:Notify', src, "The bank's security system is still active!", "error")
        return
    end
    
    hasRobberyStarted = true
    robberyStartTime = os.time() -- Track when the robbery actually started
    -- Don't reset securitySystemDisabled here - it should persist from pre-hack
    
    -- Open vault door
    TriggerClientEvent('ti_bankrobbery:client:openVaultDoor', src)
    
    -- Notify all players
    TriggerClientEvent('QBX:Notify', -1, "An alarm has been triggered at Pacific Bank!", "error")
    
    print("^2[Pacific Bank Robbery] Started by Player ID: " .. src .. "^0")
end)

-- Security system disabled (optional - can be done before vault hack)
RegisterNetEvent('ti_bankrobbery:server:securityDisabled', function()
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    securitySystemDisabled = true
    print("^2[Pacific Bank Robbery] Security system disabled by Player ID: " .. src .. "^0")
end)

-- Security hack failed
RegisterNetEvent('ti_bankrobbery:server:securityHackFailed', function(failureCount)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    local maxFailures = Config.SecuritySystem and Config.SecuritySystem.maxFailures or 2
    
    if failureCount >= (maxFailures + 1) then
        -- Max failures reached - immediate police dispatch
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        
        -- Immediate police dispatch
        exports['ps-dispatch']:PacificBankRobbery(1)
        
        TriggerClientEvent('QBX:Notify', src, "Security breach detected! Police dispatched immediately!", "error")
        TriggerClientEvent('QBX:Notify', -1, "High priority alert at Pacific Bank!", "error")
        
        print("^1[Pacific Bank Robbery] MAX SECURITY FAILURES - Immediate police dispatch by Player ID: " .. src .. "^0")
    else
        TriggerClientEvent('QBX:Notify', src, "Security system still active. " .. (maxFailures + 1 - failureCount) .. " attempts remaining.", "primary")
    end
end)

-- Door unlocked
RegisterNetEvent('ti_bankrobbery:server:doorUnlocked', function(doorIndex)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    if not hasRobberyStarted then return end
    
    unlockedDoors[doorIndex] = true
    
    -- Create deposit box zones for this door
    TriggerClientEvent('ti_bankrobbery:client:createDepositBoxZones', src, doorIndex)
    
    print("^2[Pacific Bank Robbery] Door " .. doorIndex .. " unlocked by Player ID: " .. src .. "^0")
end)

-- Consume item event
RegisterNetEvent('ti_bankrobbery:server:consumeItem', function(itemName, count, doorIndex, itemBroke)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    -- Try to remove the item from player's inventory using proper export
    local success, response = exports.ox_inventory:RemoveItem(src, itemName, count or 1)
    
    if success then
        if itemBroke then
            TriggerClientEvent('QBX:Notify', src, "Your " .. itemName .. " broke!", "error")
        end
        -- Notify client that item was consumed and proceed with door opening
        if doorIndex then
            TriggerClientEvent('ti_bankrobbery:client:itemConsumed', src, doorIndex, itemBroke)
        end
    else
        local errorMessage = "You need a " .. itemName .. "!"
        if response then
            if response == "not_enough_items" then
                errorMessage = "You need a " .. itemName .. "!"
            elseif response == "invalid_item" then
                errorMessage = "Invalid item: " .. itemName
            elseif response == "invalid_inventory" then
                errorMessage = "Invalid inventory"
            end
        end
        TriggerClientEvent('QBX:Notify', src, errorMessage, "error")
        if doorIndex then
            TriggerClientEvent('ti_bankrobbery:client:itemConsumed', src, doorIndex, true) -- Treat as broken
        end
    end
end)

-- Give deposit box reward
RegisterNetEvent('ti_bankrobbery:server:giveBoxReward', function(doorIndex, boxIndex)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    if not hasRobberyStarted then return end
    
    local boxConfig = Config.DepositBoxes[doorIndex]
    if not boxConfig or not boxConfig.boxes[boxIndex] then return end
    
    local box = boxConfig.boxes[boxIndex]
    
    -- Check chance
    if box.chance then
        if math.random(1, 100) > box.chance then
            TriggerClientEvent('QBX:Notify', src, "This box was empty!", "error")
            return
        end
    end
    
    local rewardGiven = false
    
    -- Handle different reward types using proper ox_inventory export
    if box.reward == "markedbills" then
        local amount = box.amount
        if type(amount) == "table" then
            amount = math.random(amount[1], amount[2])
        end
        local success, response = exports.ox_inventory:AddItem(src, 'markedbills', amount)
        if success then
            rewardGiven = true
        end
    elseif box.reward == "goldbar" then
        local success, response = exports.ox_inventory:AddItem(src, 'goldbar', 1)
        if success then
            rewardGiven = true
        end
    else
        -- For other items
        local amount = box.amount or 1
        local success, response = exports.ox_inventory:AddItem(src, box.reward, amount)
        if success then
            rewardGiven = true
        end
    end
    
    if rewardGiven then
        TriggerClientEvent('QBX:Notify', src, "You found something valuable!", "success")
        print("^2[Pacific Bank Robbery] Player ID: " .. src .. " received reward: " .. box.reward .. "^0")
    else
        TriggerClientEvent('QBX:Notify', src, "Your inventory is full!", "error")
    end
end)

-- Box drilled event
RegisterNetEvent('ti_bankrobbery:server:boxDrilled', function(doorIndex, boxIndex)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    if not hasRobberyStarted then return end
    
    print("^2[Pacific Bank Robbery] Box " .. boxIndex .. " in door " .. doorIndex .. " drilled by Player ID: " .. src .. "^0")
end)

-- Reset robbery after cooldown
CreateThread(function()
    while true do
        Wait(60000) -- Check every minute
        
        if hasRobberyStarted and (os.time() - robberyStartTime) >= Config.Cooldown then
            hasRobberyStarted = false
            lastRobberyTime = os.time() -- Update last robbery time when reset
            unlockedDoors = {}
            robberyStartTime = 0
            securitySystemDisabled = false
            securityFailures = 0
            
            -- Lock all doors and remove deposit boxes
            TriggerClientEvent('ti_bankrobbery:client:resetRobbery', -1)
            
            print("^2[Pacific Bank Robbery] System reset and ready for next robbery^0")
        end
    end
end)

-- Get robbery status (for other resources to check)
lib.callback.register('ti_bankrobbery:getRobberyStatus', function()
    return {
        started = hasRobberyStarted,
        lastTime = lastRobberyTime,
        cooldown = Config.Cooldown,
        unlockedDoors = unlockedDoors,
        securityDisabled = securitySystemDisabled,
        securityFailures = securityFailures
    }
end)

-- Force reset command (for admins)
RegisterCommand("resetbankrobbery", function(source, args)
    if not QBX:HasPermission(source, 'admin') then 
        TriggerClientEvent('QBX:Notify', source, "Insufficient permissions!", "error")
        return 
    end
    
    hasRobberyStarted = false
    lastRobberyTime = 0
    unlockedDoors = {}
    robberyStartTime = 0
    securitySystemDisabled = false
    securityFailures = 0
    
    TriggerClientEvent('ti_bankrobbery:client:resetRobbery', -1)
    TriggerClientEvent('QBX:Notify', source, "Bank robbery system reset!", "success")
    
    print("^3[ADMIN] Bank robbery system manually reset by Player ID: " .. source .. "^0")
end, true)

-- Bypass terminal hack command (for testing/admins)
RegisterCommand("bankrobtest", function(source, args)
    if not QBX:HasPermission(source, 'admin') then 
        TriggerClientEvent('QBX:Notify', source, "Insufficient permissions!", "error")
        return 
    end
    
    local action = args[1] or "start"
    
    if action == "start" then
        if hasRobberyStarted then
            TriggerClientEvent('QBX:Notify', source, "Robbery already in progress!", "error")
            return
        end
        
        hasRobberyStarted = true
        robberyStartTime = os.time() -- Track when the robbery actually started
        securitySystemDisabled = false
        securityFailures = 0
        TriggerClientEvent('ti_bankrobbery:client:openVaultDoor', source)
        TriggerClientEvent('QBX:Notify', source, "Bank robbery test started - vault door opened!", "success")
        print("^3[ADMIN] Bank robbery test started by Player ID: " .. source .. "^0")
        
    elseif action == "reset" then
        hasRobberyStarted = false
        lastRobberyTime = 0
        unlockedDoors = {}
        robberyStartTime = 0
        securitySystemDisabled = false
        securityFailures = 0
        TriggerClientEvent('ti_bankrobbery:client:resetRobbery', -1)
        TriggerClientEvent('QBX:Notify', source, "Bank robbery test reset!", "success")
        print("^3[ADMIN] Bank robbery test reset by Player ID: " .. source .. "^0")
    else
        TriggerClientEvent('QBX:Notify', source, "Usage: /bankrobtest [start/reset]", "error")
    end
end, true)