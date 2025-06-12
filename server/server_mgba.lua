-- Script for complete POKEMON TEAM monitoring in mGBA
-- Compatible with mGBA API v0.10+

-- mGBA environment verification
if not emu then
    console:error("ERROR: This script must be executed in mGBA")
    console:error("Go to Tools > Scripting... and load this script")
    return
end

-- Configuration
local BASE_ADDRESS = 0x02024284    -- Base address of the first Pokemon in team
local POKEMON_SIZE = 100           -- Each Pokemon occupies 100 bytes
local MAX_TEAM_SIZE = 6           -- Maximum of 6 Pokemon in team
local UPDATE_FREQUENCY = 1000      -- How many frames to update (60 = ~1 second)

-- Global variables
local frame_count = 0
local last_team_data = {}

-- Socket server variables (based on test_server.lua)

-- local socket = require("socket")
local server = nil


-- Import modules
local readPokemonData = require("read_pokemon_data")
local socket_server = require("socket_server")




-- Function to serialize data to simple JSON
local function tableToJson(data)
    if type(data) ~= "table" then
        if type(data) == "string" then
            return '"' .. data .. '"'
        elseif type(data) == "boolean" then
            return data and "true" or "false"
        else
            return tostring(data)
        end
    end
    
    local json_parts = {}
    table.insert(json_parts, "{")
    
    local first = true
    for key, value in pairs(data) do
        if not first then
            table.insert(json_parts, ",")
        end
        first = false
        
        -- Key
        table.insert(json_parts, '"' .. tostring(key) .. '":')
        
        -- Value
        if type(value) == "table" then
            table.insert(json_parts, tableToJson(value))
        elseif type(value) == "string" then
            table.insert(json_parts, '"' .. value .. '"')
        elseif type(value) == "boolean" then
            table.insert(json_parts, value and "true" or "false")
        else
            table.insert(json_parts, tostring(value))
        end
    end
    
    table.insert(json_parts, "}")
    return table.concat(json_parts)
end

-- Function to send data to all connected clients
local function sendDataToClients(data)
    if #socket_server.socketList == 0 then return end
    
    local json_data = tableToJson(data)
    local clients_to_remove = {}
    
    for i, client in ipairs(socket_server.socketList) do
        local result, err = client:send(json_data .. "\n")
        if not result then
            console:log("🔌 Client disconnected")
            table.insert(clients_to_remove, i)
        end
    end
    
    -- Remove disconnected clients
    for i = #clients_to_remove, 1, -1 do
        local client = socket_server.socketList[clients_to_remove[i]]
        client:close()
        table.remove(socket_server.socketList, clients_to_remove[i])
    end
end

-- Function to convert team data to JSON format
local function teamDataToJson(team_data, pokemon_count)
    local json_team = {
        timestamp = os.time(),
        frame = frame_count,
        pokemon_count = pokemon_count,
        team = {}
    }
    
    for slot = 1, MAX_TEAM_SIZE do
        local pokemon = team_data[slot]
        if pokemon then
            json_team.team[slot] = {
                slot = slot,
                species = pokemon.species,
                level = pokemon.level,
                hp_current = pokemon.hp_current,
                hp_max = pokemon.hp_max
            }
        end
    end
    
    return json_team
end

-- Function to calculate the address of a specific Pokemon
local function getPokemonAddress(slot)
    if slot < 1 or slot > MAX_TEAM_SIZE then
        console:error("Invalid slot: " .. slot .. ". Use values from 1 to " .. MAX_TEAM_SIZE)
        return nil
    end
    return BASE_ADDRESS + ((slot - 1) * POKEMON_SIZE)
end

-- Function to read data from the entire team
local function readTeamData()
    local team = {}
    local pokemon_count = 0
    
    for slot = 1, MAX_TEAM_SIZE do
        local address = getPokemonAddress(slot)
        if address then
            local pokemon_data = readPokemonData.read_party_pokemon(address)
            if pokemon_data and pokemon_data.species > 0 then
                team[slot] = pokemon_data
                pokemon_count = pokemon_count + 1
            else
                team[slot] = nil
            end
        end
    end
    
    return team, pokemon_count
end

-- Function to compare data and detect team changes
local function detectTeamChanges(current_team, previous_team)
    local changes = {}
    
    for slot = 1, MAX_TEAM_SIZE do
        local current = current_team[slot]
        local previous = previous_team[slot]
        
        -- Pokemon was added
        if current and not previous then
            table.insert(changes, string.format("SLOT %d: New Pokemon - Species %d Level %d", 
                slot, current.species, current.level))
        
        -- Pokemon was removed
        elseif not current and previous then
            table.insert(changes, string.format("SLOT %d: Pokemon removed - Was Species %d", 
                slot, previous.species))
        
        -- Pokemon changed
        elseif current and previous then
            local slot_changes = {}
            
            if current.species ~= previous.species then
                table.insert(slot_changes, string.format("Species: %d → %d", previous.species, current.species))
            end
            
            if current.level ~= previous.level then
                table.insert(slot_changes, string.format("Level: %d → %d", previous.level, current.level))
            end
            
            if current.hp_current ~= previous.hp_current then
                local diff = current.hp_current - previous.hp_current
                if diff > 0 then
                    table.insert(slot_changes, string.format("HP +%d", diff))
                else
                    table.insert(slot_changes, string.format("HP %d", diff))
                end
            end
            
            if current.hp_max ~= previous.hp_max then
                table.insert(slot_changes, string.format("HP Max: %d → %d", previous.hp_max, current.hp_max))
            end
            
            if #slot_changes > 0 then
                table.insert(changes, string.format("SLOT %d: %s", slot, table.concat(slot_changes, " | ")))
            end
        end
    end
    
    return changes
end

-- Function executed every frame
local function onFrame()
    frame_count = frame_count + 1
    
    -- Accept new connections every frame

    -- Update every UPDATE_FREQUENCY frames
    if frame_count % UPDATE_FREQUENCY == 0 then
        local team_data, pokemon_count = readTeamData()

        if pokemon_count > 0 then
            -- Convert data to JSON and send via socket
            local json_data = teamDataToJson(team_data, pokemon_count)
            sendDataToClients(json_data)
            
            console:log(string.format("Frame %d - Team with %d Pokemon(s) - Sent to %d client(s)", 
                frame_count, pokemon_count, #socket_server.socketList))
            
            for slot = 1, MAX_TEAM_SIZE do
                local pokemon = team_data[slot]
                if pokemon then
                    console:log(string.format("  SLOT %d: Species %d | Type %d | Level %d | HP %d/%d",
                        slot, pokemon.species, pokemon.type, pokemon.level, pokemon.hp_current, pokemon.hp_max))
                end
            end

            -- Detect changes
            local changes = detectTeamChanges(team_data, last_team_data)
            if #changes > 0 then
                for _, change in ipairs(changes) do
                    console:log("CHANGE: " .. change)
                end
            end

            last_team_data = team_data
        end
    end
end

-- Function executed when the game starts
local function onStart()
    console:log("=== POKEMON TEAM MONITOR SCRIPT STARTED ===")
    console:log("Game detected: " .. (emu:getGameTitle() or "Unknown"))
    console:log("Game code: " .. (emu:getGameCode() or "N/A"))
    console:log("Base address: " .. string.format("0x%X", BASE_ADDRESS))
    console:log("Size per Pokemon: " .. POKEMON_SIZE .. " bytes")
    console:log("Update frequency: every " .. UPDATE_FREQUENCY .. " frames")
    console:log("Monitoring slots 1-" .. MAX_TEAM_SIZE)

    -- Initialize socket server
    if socket_server.InitializeServer() then
        console:log("Waiting for Python connections...")
    end

    -- Initial complete team test
    local initial_team, pokemon_count = readTeamData()
    if pokemon_count > 0 then
        console:log(string.format("Initial team detected with %d Pokemon(s):", pokemon_count))
        for slot = 1, MAX_TEAM_SIZE do
            local pokemon = initial_team[slot]
            if pokemon then
                console:log(string.format("  SLOT %d: Species %d | Type %d | Level %d | HP %d/%d",
                    slot, pokemon.species, pokemon.type, pokemon.level, pokemon.hp_current, pokemon.hp_max))
            end
        end
        last_team_data = initial_team
        
        -- Send initial data via socket
        local json_data = teamDataToJson(initial_team, pokemon_count)
        sendDataToClients(json_data)
    else
        console:warn("No Pokemon detected in initial team")
        console:warn("Check if the memory address is correct for this game")
    end
end

-- Cleanup function on close
local function onShutdown()
    console:log("🔌 Shutting down server...")
    
    -- Close all client connections
    for _, client in ipairs(socket_server.socketList) do
        if client then
            client:send("DISCONNECT\n")
            client:close()
        end
    end
    socket_server.socketList = {}
    
    -- Close the server
    if server then
        server:close()
        server = nil
    end
    
    console:log("🔌 Server shut down")
end

-- Register callbacks
callbacks:add("start", onStart)
callbacks:add("frame", onFrame)
callbacks:add("shutdown", onShutdown)

-- If the game is already running, execute onStart immediately
if emu:getGameTitle() then
    onStart()
end

