# Pacific Standard Bank Robbery for QBox/FiveM

A fully featured bank robbery system for Pacific Standard Bank in FiveM QBox servers. This script provides an immersive and challenging bank robbery experience with multiple security layers and strategic gameplay elements.

## Features

### 🔐 Multi-Layer Security System
- **Vault Terminal Hacking**: Primary entry point requiring electronic kit
- **Optional Security System**: Pre-hack security terminal to delay police dispatch
- **Inner Vault Doors**: Two reinforced doors requiring lockpicks
- **Deposit Boxes**: Multiple loot containers with varying rewards

### 🚨 Dynamic Police Response
- **Immediate Dispatch**: Police alerted instantly when vault is hacked without disabling security
- **Delayed Dispatch**: 1-minute delay when security system is disabled first
- **PS-Dispatch Integration**: Full compatibility with PS-Dispatch system

### ⚙️ Advanced Mechanics
- **Item Consumption**: Electronic kits, lockpicks, and drills are consumed during use
- **Failure Penalties**: Items can break during failed attempts
- **Auto-Locking Doors**: All doors automatically re-lock after 10 minutes
- **Cooldown System**: Configurable robbery cooldown period
- **Progressive Difficulty**: Increasing challenge with each security layer

### 🎯 Interactive Elements
- **OX_Target Integration**: Modern targeting system with contextual interactions
- **OX_Doorlock Integration**: Seamless door control system
- **Minigame Support**: IconMinigame integration for hacking and lockpicking
- **Dynamic Zones**: Deposit box zones appear only after doors are unlocked

### 📦 Reward System
- **Variable Loot**: Different rewards with configurable chances
- **Random Amounts**: Cash rewards with randomized values
- **Rare Items**: High-value items with low spawn rates
- **Inventory Management**: Proper ox_inventory integration

## Requirements

- **QBox Core** - Main framework
- **OX_Lib** - Library utilities
- **OX_Inventory** - Inventory system
- **OX_Doorlock** - Door control system
- **OX_Target** - Targeting system
- **PS-Dispatch** - Police dispatch system
- **IconMinigame** - Minigame system
- **OneSync** - Required for entity management

## Installation

### 1. Download & Extract
Download the latest release and extract to your `resources` folder:
resources/
└── [scripts(or wherever you want)]/
└── ti_bankrobbery/

### 2. Configure Dependencies
Ensure all required resources are installed and started:
```cfg
ensure qbx_core
ensure ox_lib
ensure ox_inventory
ensure ox_doorlock
ensure ox_target
ensure ps_dispatch
ensure iconminigame

### 3.Door Setup
Enter the game and configure doors using OX_Doorlock:
Vault door (main entrance)
Inner vault door 1
Inner vault door 2
Note the door IDs assigned by OX_Doorlock
Update the door IDs in config.lua

### 4.Configuration
Edit config.lua to match your server preferences:
Set door coordinates and IDs
Adjust cooldown times
Configure item requirements
Modify reward amounts and chances

### 5.Item Setup
Ensure the following items exist in your ox_inventory:
electronickit - For hacking terminals
lockpick - For lockpicking doors
drill - For drilling deposit boxes
markedbills - For cash rewards
goldbar - For gold rewards
Any custom items you've configured

### 6. Start the Resource
Add to your server.cfg:
ensure ti_bankrobbery
*Add only if you put it outside [standalone]

### Items

['electronickit'] = {
    label = 'Electronic Kit',
    weight = 500,
    stack = false,
    close = true,
    description = 'A kit with various electronic tools for hacking',
    client = {
        image = 'electronickit.png'
    }
},

['lockpick'] = {
    label = 'Lockpick',
    weight = 100,
    stack = false,
    close = true,
    description = 'A tool used for picking locks',
    client = {
        image = 'lockpick.png'
    }
},

['drill'] = {
    label = 'Drill',
    weight = 2000,
    stack = false,
    close = true,
    description = 'A powerful drill for breaking into things',
    client = {
        image = 'drill.png'
    }
},

['goldbar'] = {
    label = 'Gold Bar',
    weight = 5000,
    stack = true,
    close = true,
    description = 'A valuable gold bar',
    client = {
        image = 'goldbar.png'
    }
},

['markedbills'] = {
    label = 'Marked Bills',
    weight = 100,
    stack = true,
    close = true,
    description = 'Bills marked by the bank',
    client = {
        image = 'markedbills.png'
    }
},