-- server/main.lua
local Config = lib.require 'config'
local QBX = exports.qbx_core

local hasRobberyStarted = false
local lastRobberyTime = 0
local unlockedDoors = {}
local robberyStartTime = 0
local securitySystemDisabled = false
local securityFailures = 0
local playerLastEvents = {} -- Anti-spam protection
local bankPlayers = {} -- Track players in the bank

-- Anti-spam function
function canPlayerTriggerEvent(src, eventName, cooldown)
    if not playerLastEvents[src] then
        playerLastEvents[src] = {}
    end
    
    local currentTime = os.time()
    local lastTime = playerLastEvents[src][eventName] or 0
    
    if currentTime - lastTime < (cooldown or 1) then
        return false
    end
    
    playerLastEvents[src][eventName] = currentTime
    return true
end

-- Validate door index
function isValidDoorIndex(doorIndex)
    return doorIndex and type(doorIndex) == "number" and 
           doorIndex >= 1 and doorIndex <= #Config.InnerDoors
end

-- Validate box index
function isValidBoxIndex(doorIndex, boxIndex)
    if not isValidDoorIndex(doorIndex) then return false end
    local boxConfig = Config.DepositBoxes[doorIndex]
    return boxConfig and boxIndex and type(boxIndex) == "number" and
           boxIndex >= 1 and boxIndex <= #boxConfig.boxes
end

-- Validate player distance to target
function isPlayerNearTarget(src, targetCoords, maxDistance)
    local ped = GetPlayerPed(src)
    if not ped then return false end
    
    local playerCoords = GetEntityCoords(ped)
    local distance = #(playerCoords - targetCoords)
    
    return distance <= (maxDistance or 2.0)
end

-- Check if player is in bank area
function isPlayerInBank(src)
    local ped = GetPlayerPed(src)
    if not ped then return false end
    
    local coords = GetEntityCoords(ped)
    -- Define bank boundaries (adjust these coordinates for your map)
    local minX, maxX = 245.0, 275.0
    local minY, maxY = 210.0, 240.0
    local minZ, maxZ = 100.0, 110.0
    
    return coords.x >= minX and coords.x <= maxX and
           coords.y >= minY and coords.y <= maxY and
           coords.z >= minZ and coords.z <= maxZ
end

-- Smart notification - only alert players in the bank
function SmartNotify(message, type, excludeSrc)
    local playersToNotify = {}
    
    -- Always notify the triggering player unless excluded
    if excludeSrc then
        -- Don't notify the triggering player
    end
    
    -- Notify all players currently in the bank
    for playerId, _ in pairs(bankPlayers) do
        if playerId ~= excludeSrc then
            table.insert(playersToNotify, playerId)
        end
    end
    
    -- If robbery is active, also notify nearby players
    if hasRobberyStarted then
        for _, playerId in ipairs(GetPlayers()) do
            local playerIdNum = tonumber(playerId)
            if playerIdNum and playerIdNum ~= excludeSrc then
                if isPlayerInBank(playerIdNum) then
                    table.insert(playersToNotify, playerIdNum)
                end
            end
        end
    end
    
    -- Send notifications
    for _, playerId in ipairs(playersToNotify) do
        TriggerClientEvent('QBX:Notify', playerId, message, type)
    end
    
    -- Also log to console for admins
    print("^3[BANK ROBBERY ALERT] " .. message .. "^0")
end

-- Vault hack success
RegisterNetEvent('ti_bankrobbery:server:vaultHackSuccess', function()
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player or not canPlayerTriggerEvent(src, 'vaultHackSuccess', 2) then return end
    
    -- Validate distance to vault terminal
    if not isPlayerNearTarget(src, Config.VaultTerminal.coords, 3.0) then
        DropPlayer(src, "Exploit detected: Invalid vault hack location")
        return
    end
    
    if hasRobberyStarted then
        DropPlayer(src, "Attempted robbery exploit")
        return
    end
    
    if (os.time() - lastRobberyTime) < Config.Cooldown then
        TriggerClientEvent('QBX:Notify', src, "The bank's security system is still active!", "error")
        return
    end
    
    hasRobberyStarted = true
    robberyStartTime = os.time()
    
    -- Add player to bank tracking
    bankPlayers[src] = true
    
    TriggerClientEvent('ti_bankrobbery:client:openVaultDoor', src)
    
    -- Smart alert - only players in bank area
    SmartNotify("An alarm has been triggered at Pacific Bank!", "error", src)
    
    print("^2[Pacific Bank Robbery] Started by Player ID: " .. src .. "^0")
end)

-- Security system disabled
RegisterNetEvent('ti_bankrobbery:server:securityDisabled', function()
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player or not canPlayerTriggerEvent(src, 'securityDisabled', 2) then return end
    
    -- Validate distance to security system
    if not isPlayerNearTarget(src, Config.SecuritySystem.coords, 3.0) then
        DropPlayer(src, "Exploit detected: Invalid security system location")
        return
    end
    
    securitySystemDisabled = true
    
    -- Smart alert - only to the player
    TriggerClientEvent('QBX:Notify', src, "Security system disabled! Police dispatch will be delayed by 1 minute.", "success")
    
    print("^2[Pacific Bank Robbery] Security system disabled by Player ID: " .. src .. "^0")
end)

-- Security hack failed
RegisterNetEvent('ti_bankrobbery:server:securityHackFailed', function(failureCount)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player or not canPlayerTriggerEvent(src, 'securityHackFailed', 2) then return end
    
    -- Validate distance to security system
    if not isPlayerNearTarget(src, Config.SecuritySystem.coords, 3.0) then
        DropPlayer(src, "Exploit detected: Invalid security hack location")
        return
    end
    
    local maxFailures = Config.SecuritySystem and Config.SecuritySystem.maxFailures or 2
    
    if failureCount >= (maxFailures + 1) then
        local ped = GetPlayerPed(src)
        local coords = GetEntityCoords(ped)
        
        -- Immediate police dispatch
        exports['ps-dispatch']:PacificBankRobbery(1)
        
        TriggerClientEvent('QBX:Notify', src, "Security breach detected! Police dispatched immediately!", "error")
        
        -- Smart alert - only players in bank area
        SmartNotify("High priority alert at Pacific Bank!", "error", src)
        
        print("^1[Pacific Bank Robbery] MAX SECURITY FAILURES - Immediate police dispatch by Player ID: " .. src .. "^0")
    else
        TriggerClientEvent('QBX:Notify', src, "Security system still active. " .. (maxFailures + 1 - failureCount) .. " attempts remaining.", "primary")
    end
end)

-- Door unlocked
RegisterNetEvent('ti_bankrobbery:server:doorUnlocked', function(doorIndex)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player or not canPlayerTriggerEvent(src, 'doorUnlocked', 2) then return end
    if not hasRobberyStarted then return end
    if not isValidDoorIndex(doorIndex) then 
        DropPlayer(src, "Exploit detected: Invalid door index")
        return 
    end
    
    -- Validate distance to door
    local doorConfig = Config.InnerDoors[doorIndex]
    if not isPlayerNearTarget(src, doorConfig.coords, 3.0) then
        DropPlayer(src, "Exploit detected: Invalid door location")
        return
    end
    
    unlockedDoors[doorIndex] = true
    
    TriggerClientEvent('ti_bankrobbery:client:createDepositBoxZones', src, doorIndex)
    
    -- Smart alert - only to the player
    TriggerClientEvent('QBX:Notify', src, "Inner vault door unlocked!", "success")
    
    print("^2[Pacific Bank Robbery] Door " .. doorIndex .. " unlocked by Player ID: " .. src .. "^0")
end)

-- Consume item event
RegisterNetEvent('ti_bankrobbery:server:consumeItem', function(itemName, count, doorIndex, itemBroke)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player or not canPlayerTriggerEvent(src, 'consumeItem', 1) then return end
    
    -- Validate parameters
    if not itemName or type(itemName) ~= "string" then
        DropPlayer(src, "Exploit detected: Invalid item name")
        return
    end
    
    if count and (type(count) ~= "number" or count < 0) then
        DropPlayer(src, "Exploit detected: Invalid item count")
        return
    end
    
    if doorIndex and not isValidDoorIndex(doorIndex) then
        DropPlayer(src, "Exploit detected: Invalid door index")
        return
    end
    
    -- Validate distance if door index is provided
    if doorIndex then
        local doorConfig = Config.InnerDoors[doorIndex]
        if doorConfig and not isPlayerNearTarget(src, doorConfig.coords, 3.0) then
            DropPlayer(src, "Exploit detected: Invalid item consumption location")
            return
        end
    end
    
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
    
    if not Player or not canPlayerTriggerEvent(src, 'giveBoxReward', 2) then return end
    if not hasRobberyStarted then return end
    if not isValidBoxIndex(doorIndex, boxIndex) then
        DropPlayer(src, "Exploit detected: Invalid box indices")
        return
    end
    
    -- Validate distance to box
    local boxConfig = Config.DepositBoxes[doorIndex]
    local box = boxConfig.boxes[boxIndex]
    if not isPlayerNearTarget(src, box.coords, 3.0) then
        DropPlayer(src, "Exploit detected: Invalid box location")
        return
    end
    
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
            bankPlayers = {} -- Clear bank player tracking
            
            -- Lock all doors and remove deposit boxes
            TriggerClientEvent('ti_bankrobbery:client:resetRobbery', -1)
            
            print("^2[Pacific Bank Robbery] System reset and ready for next robbery^0")
        end
    end
end)

-- Force reset command (for admins)
RegisterCommand("resetbankrobbery", function(source, args)
    if not QBX:HasPermission(source, 'admin') then return end
    
    hasRobberyStarted = false
    lastRobberyTime = 0
    unlockedDoors = {}
    robberyStartTime = 0
    securitySystemDisabled = false
    securityFailures = 0
    bankPlayers = {}
    
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
        bankPlayers[source] = true
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
        bankPlayers = {}
        TriggerClientEvent('ti_bankrobbery:client:resetRobbery', -1)
        TriggerClientEvent('QBX:Notify', source, "Bank robbery test reset!", "success")
        print("^3[ADMIN] Bank robbery test reset by Player ID: " .. source .. "^0")
    else
        TriggerClientEvent('QBX:Notify', source, "Usage: /bankrobtest [start/reset]", "error")
    end
end, true)

-- Track player disconnects
AddEventHandler('playerDropped', function()
    local src = source
    bankPlayers[src] = nil
end)