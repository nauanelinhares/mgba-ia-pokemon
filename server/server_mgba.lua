-- Script for complete POKEMON TEAM monitoring in mGBA
-- Compatible with mGBA API v0.10+


-- Import modules
local readPokemonData = require("read_pokemon_data")
local socket_server = require("socket_server")
local GAMES = require("game.game_config")


-- mGBA environment verification
if not emu then
    console:error("ERROR: This script must be executed in mGBA")
    console:error("Go to Tools > Scripting... and load this script")
    return
end



CURRENT_GAME = GAMES.unbound:new()


-- Configuration
local GAME_NAME = CURRENT_GAME.name
local BASE_ADDRESS = CURRENT_GAME.addresses.pokemon_party_address   -- Base address of the first Pokemon in team
local BASE_ADDRESS_ENEMY = CURRENT_GAME.addresses.pokemon_party_enemy_address -- Base address of the first Pokemon in enemy team
local POKEMON_SIZE = CURRENT_GAME.addresses.pokemon_party_entry_size           -- Each Pokemon occupies 100 bytes
local BASE_STATS_TABLE_ADDRESS = CURRENT_GAME.addresses.base_stats_table_address
local BASE_STATS_ENTRY_SIZE = CURRENT_GAME.addresses.base_stats_entry_size
local MAX_TEAM_SIZE = 6           -- Maximum of 6 Pokemon in team
local UPDATE_FREQUENCY = 1000      -- How many frames to update (60 = ~1 second)

-- Global variables
local frame_count = 0
local last_team_data = {}
local last_enemy_data = {}



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
local function teamDataToJson(team_data, pokemon_count, enemy_data, enemy_count)
    local json_team = {
        timestamp = os.time(),
        frame = frame_count,
        player = {
            pokemon_count = pokemon_count,
            team = {}
        },
        enemy = {
            pokemon_count = enemy_count or 0,
            team = {}
        }
    }
    
    -- Player team
    for slot = 1, MAX_TEAM_SIZE do
        local pokemon = team_data[slot]
        if pokemon then
            json_team.player.team[slot] = {
                slot = slot,
                species = pokemon.species,
                level = pokemon.level,
                hp_current = pokemon.hp_current,
                hp_max = pokemon.hp_max,
                type1 = pokemon.type1,
                type2 = pokemon.type2
            }
        end
    end
    
    -- Enemy team
    if enemy_data then
        for slot = 1, MAX_TEAM_SIZE do
            local pokemon = enemy_data[slot]
            if pokemon then
                json_team.enemy.team[slot] = {
                    slot = slot,
                    species = pokemon.species,
                    level = pokemon.level,
                    hp_current = pokemon.hp_current,
                    hp_max = pokemon.hp_max,
                    type1 = pokemon.type1,
                    type2 = pokemon.type2
                }
            end
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

-- Function to calculate the address of a specific Enemy Pokemon
local function getEnemyPokemonAddress(slot)
    if slot < 1 or slot > MAX_TEAM_SIZE then
        console:error("Invalid enemy slot: " .. slot .. ". Use values from 1 to " .. MAX_TEAM_SIZE)
        return nil
    end
    return BASE_ADDRESS_ENEMY + ((slot - 1) * POKEMON_SIZE)
end

-- Function to read data from the entire team
local function readTeamData()
    local team = {}
    local pokemon_count = 0
    
    for slot = 1, MAX_TEAM_SIZE do
        local address = getPokemonAddress(slot)
        if address then
            local pokemon_data = CURRENT_GAME:readPartyPokemon(address)
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

-- Function to read data from the entire enemy team
local function readEnemyTeamData()
    local team = {}
    local pokemon_count = 0
    
    for slot = 1, MAX_TEAM_SIZE do
        local address = getEnemyPokemonAddress(slot)
        if address then
            local pokemon_data = CURRENT_GAME:readPartyPokemon(address)
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
local function detectTeamChanges(current_team, previous_team, team_type)
    local changes = {}
    local prefix = team_type or "PLAYER"
    
    for slot = 1, MAX_TEAM_SIZE do
        local current = current_team[slot]
        local previous = previous_team[slot]
        
        -- Pokemon was added
        if current and not previous then
            table.insert(changes, string.format("%s SLOT %d: New Pokemon - Species %d Level %d", 
                prefix, slot, current.species, current.level))
        
        -- Pokemon was removed
        elseif not current and previous then
            table.insert(changes, string.format("%s SLOT %d: Pokemon removed - Was Species %d", 
                prefix, slot, previous.species))
        
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
                table.insert(changes, string.format("%s SLOT %d: %s", prefix, slot, table.concat(slot_changes, " | ")))
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
        local enemy_data, enemy_count = readEnemyTeamData()

        if pokemon_count > 0 or enemy_count > 0 then
            -- Convert data to JSON and send via socket
            local json_data = teamDataToJson(team_data, pokemon_count, enemy_data, enemy_count)
            sendDataToClients(json_data)
            
            console:log(string.format("Frame %d - Player: %d Pokemon(s) | Enemy: %d Pokemon(s) - Sent to %d client(s)", 
                frame_count, pokemon_count, enemy_count, #socket_server.socketList))
            
            -- Log player team
            if pokemon_count > 0 then
                console:log("PLAYER TEAM:")
                for slot = 1, MAX_TEAM_SIZE do
                    local pokemon = team_data[slot]
                    if pokemon then
                        console:log(string.format("  SLOT %d: Species %d | Type1 %d | Type2 %d | Level %d | HP %d/%d",
                            slot, pokemon.species, pokemon.type1, pokemon.type2, pokemon.level, pokemon.hp_current, pokemon.hp_max))
                    end
                end
            end
            
            -- Log enemy team
            if enemy_count > 0 then
                console:log("ENEMY TEAM:")
                for slot = 1, MAX_TEAM_SIZE do
                    local pokemon = enemy_data[slot]
                    if pokemon then
                        console:log(string.format("  SLOT %d: Species %d | Type1 %d | Type2 %d | Level %d | HP %d/%d",
                            slot, pokemon.species, pokemon.type1, pokemon.type2, pokemon.level, pokemon.hp_current, pokemon.hp_max))
                    end
                end
            end

            -- Detect player team changes
            local player_changes = detectTeamChanges(team_data, last_team_data, "PLAYER")
            if #player_changes > 0 then
                for _, change in ipairs(player_changes) do
                    console:log("CHANGE: " .. change)
                end
            end
            
            -- Detect enemy team changes
            local enemy_changes = detectTeamChanges(enemy_data, last_enemy_data, "ENEMY")
            if #enemy_changes > 0 then
                for _, change in ipairs(enemy_changes) do
                    console:log("CHANGE: " .. change)
                end
            end

            last_team_data = team_data
            last_enemy_data = enemy_data
        end
    end
end

-- Function executed when the game starts
local function onStart()
    console:log("=== POKEMON TEAM MONITOR SCRIPT STARTED ===")
    console:log("Game detected: " .. (emu:getGameTitle() or "Unknown"))
    console:log("Game code: " .. (emu:getGameCode() or "N/A"))
    console:log("Player base address: " .. string.format("0x%X", BASE_ADDRESS))
    console:log("Enemy base address: " .. string.format("0x%X", BASE_ADDRESS_ENEMY))
    console:log("Size per Pokemon: " .. POKEMON_SIZE .. " bytes")
    console:log("Update frequency: every " .. UPDATE_FREQUENCY .. " frames")
    console:log("Monitoring slots 1-" .. MAX_TEAM_SIZE .. " for both teams")

    -- Initialize socket server
    if socket_server.InitializeServer() then
        console:log("Waiting for Python connections...")
    end

    -- Initial complete team test
    local initial_team, pokemon_count = readTeamData()
    local initial_enemy, enemy_count = readEnemyTeamData()
    
    if pokemon_count > 0 then
        console:log(string.format("Initial PLAYER team detected with %d Pokemon(s):", pokemon_count))
        for slot = 1, MAX_TEAM_SIZE do
            local pokemon = initial_team[slot]
            if pokemon then
                console:log(string.format("  SLOT %d: Species %d | Type1 %d | Type2 %d | Level %d | HP %d/%d",
                    slot, pokemon.species, pokemon.type1, pokemon.type2, pokemon.level, pokemon.hp_current, pokemon.hp_max))
            end
        end
        last_team_data = initial_team
    else
        console:warn("No Pokemon detected in initial PLAYER team")
    end
    
    if enemy_count > 0 then
        console:log(string.format("Initial ENEMY team detected with %d Pokemon(s):", enemy_count))
        for slot = 1, MAX_TEAM_SIZE do
            local pokemon = initial_enemy[slot]
            if pokemon then
                console:log(string.format("  SLOT %d: Species %d | Type1 %d | Type2 %d | Level %d | HP %d/%d",
                    slot, pokemon.species, pokemon.type1, pokemon.type2, pokemon.level, pokemon.hp_current, pokemon.hp_max))
            end
        end
        last_enemy_data = initial_enemy
    else
        console:warn("No Pokemon detected in initial ENEMY team")
    end
    
    if pokemon_count == 0 and enemy_count == 0 then
        console:warn("Check if the memory addresses are correct for this game")
    end
        
    -- Send initial data via socket
    if pokemon_count > 0 or enemy_count > 0 then
        local json_data = teamDataToJson(initial_team, pokemon_count, initial_enemy, enemy_count)
        sendDataToClients(json_data)
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

