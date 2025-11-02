-- config.lua
return {
    Cooldown = 3600, -- 1 hour in seconds

    VaultTerminal = {
        coords = vector3(253.21, 228.31, 101.68),
        requiredItem = "electronickit", -- Item needed to hack terminal
        minigame = {
            rows = 4,          -- Terminal rows
            columns = 2,       -- Terminal columns  
            viewTime = 15,     -- Time to view sequence
            typeTime = 20,     -- Time to type sequence
            answersNeeded = 3  -- Required answers
        }
    },

    -- Add this to your config.lua
    SecuritySystem = {
        coords = vector3(261.99, 205.79, 110.52), -- Location of security terminal
        requiredItem = "electronickit", -- Item needed to hack security terminal
        minigame = {
            rows = 4,
            columns = 2,
            viewTime = 15,
            typeTime = 25,
            answersNeeded = 5
        },
        maxFailures = 2, -- Max failures before immediate police call
        policeCallDelay = 0 -- 5 minutes delay for police call after max failures (set to 0 for immediate)
    },

    VaultDoor = {
        coords = vector3(253.66, 224.76, 102.01),
        doorId = 2 -- Set this to your actual vault door ID from in-game setup
    },

    InnerDoors = {
        {
            id = "inner_vault_1",
            coords = vector3(252.21, 220.98, 101.84),
            doorId = 3, -- Set this to your actual door ID from in-game setup
            requiredItem = "lockpick", -- Item needed to lockpick
            consumeItem = true, -- Whether to consume the item
            lockpick = {
                difficulty = 3,
                time = 40
            }
        },
        {
            id = "inner_vault_2", 
            coords = vector3(261.51, 215.21, 101.84),
            doorId = 4, -- Set this to your actual door ID from in-game setup
            requiredItem = "lockpick", -- Item needed to lockpick
            consumeItem = true, -- Whether to consume the item
            lockpick = {
                difficulty = 3,
                time = 40
            }
        }
    },

    DepositBoxes = {
        {
            doorId = "inner_vault_1",
            boxes = {
                { coords = vector3(258.31, 218.82, 101.9), reward = "goldbar", chance = 100 },
                { coords = vector3(260.97, 217.85, 101.87), reward = "markedbills", amount = {500, 2000}, chance = 80 },
                { coords = vector3(259.7, 213.31, 101.9), reward = "jewels", amount = 5, chance = 60 }
            }
        },
        {
            doorId = "inner_vault_2",
            boxes = {
                { coords = vector3(250.5, 233.0, 101.7), reward = "goldbar", chance = 100 },
                { coords = vector3(250.2, 233.5, 101.7), reward = "markedbills", amount = {1000, 5000}, chance = 90 },
                { coords = vector3(249.9, 234.0, 101.7), reward = "diamond", chance = 30 }
            }
        }
    },

    Drill = {
        animDict = "anim@heists@fleeca_bank@drilling",
        animName = "drill_straight_idle",
        prop = "hei_prop_heist_drill",
        bone = 28422,
        requiredItem = "drill" -- Item needed to drill boxes
    }
}