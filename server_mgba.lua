-- Script para monitoramento completo do TIME DE POKÉMON no mGBA
-- Compatível com a API do mGBA v0.10+

-- Verificação do ambiente mGBA
if not emu then
    console:error("ERRO: Este script deve ser executado no mGBA")
    console:error("Vá em Tools > Scripting... e carregue este script")
    return
end

-- Configurações
local BASE_ADDRESS = 0x02024284    -- Endereço base do primeiro Pokémon no time
local POKEMON_SIZE = 100           -- Cada Pokémon ocupa 100 bytes
local MAX_TEAM_SIZE = 6           -- Máximo de 6 Pokémons no time
local UPDATE_FREQUENCY = 1000      -- A cada quantos frames atualizar (60 = ~1 segundo)

-- Variáveis globais
local frame_count = 0
local last_team_data = {}

-- Variáveis do servidor socket (baseado no test_server.lua)

-- local socket = require("socket")
local server = nil


-- Importa os módulos
local readPokemonData = require("read_pokemon_data")
local socket_server = require("socket_server")




-- Função para serializar dados para JSON simples
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
        
        -- Chave
        table.insert(json_parts, '"' .. tostring(key) .. '":')
        
        -- Valor
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

-- Função para enviar dados para todos os clientes conectados
local function sendDataToClients(data)
    if #socket_server.socketList == 0 then return end
    
    local json_data = tableToJson(data)
    local clients_to_remove = {}
    
    for i, client in ipairs(socket_server.socketList) do
        local result, err = client:send(json_data .. "\n")
        if not result then
            console:log("🔌 Cliente desconectado")
            table.insert(clients_to_remove, i)
        end
    end
    
    -- Remove clientes desconectados
    for i = #clients_to_remove, 1, -1 do
        local client = socket_server.socketList[clients_to_remove[i]]
        client:close()
        table.remove(socket_server.socketList, clients_to_remove[i])
    end
end

-- Função para converter dados do time para formato JSON
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

-- Função para calcular o endereço de um Pokémon específico
local function getPokemonAddress(slot)
    if slot < 1 or slot > MAX_TEAM_SIZE then
        console:error("Slot inválido: " .. slot .. ". Use valores de 1 a " .. MAX_TEAM_SIZE)
        return nil
    end
    return BASE_ADDRESS + ((slot - 1) * POKEMON_SIZE)
end

-- Função para ler dados de todo o time
local function readTeamData()
    local team = {}
    local pokemon_count = 0
    
    for slot = 1, MAX_TEAM_SIZE do
        local address = getPokemonAddress(slot)
        if address then
            local pokemon_data = readPokemonData(address)
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

-- Função para comparar dados e detectar mudanças no time
local function detectTeamChanges(current_team, previous_team)
    local changes = {}
    
    for slot = 1, MAX_TEAM_SIZE do
        local current = current_team[slot]
        local previous = previous_team[slot]
        
        -- Pokémon foi adicionado
        if current and not previous then
            table.insert(changes, string.format("SLOT %d: Novo Pokémon - Espécie %d Nível %d", 
                slot, current.species, current.level))
        
        -- Pokémon foi removido
        elseif not current and previous then
            table.insert(changes, string.format("SLOT %d: Pokémon removido - Era Espécie %d", 
                slot, previous.species))
        
        -- Pokémon mudou
        elseif current and previous then
            local slot_changes = {}
            
            if current.species ~= previous.species then
                table.insert(slot_changes, string.format("Espécie: %d → %d", previous.species, current.species))
            end
            
            if current.level ~= previous.level then
                table.insert(slot_changes, string.format("Nível: %d → %d", previous.level, current.level))
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

-- Função executada a cada frame
local function onFrame()
    frame_count = frame_count + 1
    
    -- Aceita novas conexões a cada frame

    -- Atualiza a cada UPDATE_FREQUENCY frames
    if frame_count % UPDATE_FREQUENCY == 0 then
        local team_data, pokemon_count = readTeamData()

        if pokemon_count > 0 then
            -- Converte dados para JSON e envia via socket
            local json_data = teamDataToJson(team_data, pokemon_count)
            sendDataToClients(json_data)
            
            console:log(string.format("Frame %d - Time com %d Pokémon(s) - Enviado para %d cliente(s)", 
                frame_count, pokemon_count, #socket_server.socketList))
            
            for slot = 1, MAX_TEAM_SIZE do
                local pokemon = team_data[slot]
                if pokemon then
                    console:log(string.format("  SLOT %d: Espécie %d | Nível %d | HP %d/%d",
                        slot, pokemon.species, pokemon.level, pokemon.hp_current, pokemon.hp_max))
                end
            end

            -- Detecta mudanças
            local changes = detectTeamChanges(team_data, last_team_data)
            if #changes > 0 then
                for _, change in ipairs(changes) do
                    console:log("MUDANÇA: " .. change)
                end
            end

            last_team_data = team_data
        end
    end
end

-- Função executada quando o jogo inicia
local function onStart()
    console:log("=== SCRIPT TEAM POKÉMON MONITOR INICIADO ===")
    console:log("Jogo detectado: " .. (emu:getGameTitle() or "Desconhecido"))
    console:log("Código do jogo: " .. (emu:getGameCode() or "N/A"))
    console:log("Endereço base: " .. string.format("0x%X", BASE_ADDRESS))
    console:log("Tamanho por Pokémon: " .. POKEMON_SIZE .. " bytes")
    console:log("Frequência de atualização: a cada " .. UPDATE_FREQUENCY .. " frames")
    console:log("Monitorando slots 1-" .. MAX_TEAM_SIZE)

    -- Inicializa servidor socket
    if socket_server.InitializeServer() then
        console:log("Aguardando conexões Python...")
    end

    -- Teste inicial do time completo
    local initial_team, pokemon_count = readTeamData()
    if pokemon_count > 0 then
        console:log(string.format("Time inicial detectado com %d Pokémon(s):", pokemon_count))
        for slot = 1, MAX_TEAM_SIZE do
            local pokemon = initial_team[slot]
            if pokemon then
                console:log(string.format("  SLOT %d: Espécie %d | Nível %d | HP %d/%d",
                    slot, pokemon.species, pokemon.level, pokemon.hp_current, pokemon.hp_max))
            end
        end
        last_team_data = initial_team
        
        -- Envia dados iniciais via socket
        local json_data = teamDataToJson(initial_team, pokemon_count)
        sendDataToClients(json_data)
    else
        console:warn("Nenhum Pokémon detectado no time inicial")
        console:warn("Verifique se o endereço de memória está correto para este jogo")
    end
end

-- Função de limpeza ao fechar
local function onShutdown()
    console:log("🔌 Encerrando servidor...")
    
    -- Fecha todas as conexões de clientes
    for _, client in ipairs(socket_server.socketList) do
        if client then
            client:send("DISCONNECT\n")
            client:close()
        end
    end
    socket_server.socketList = {}
    
    -- Fecha o servidor
    if server then
        server:close()
        server = nil
    end
    
    console:log("🔌 Servidor encerrado")
end

-- Registra os callbacks
callbacks:add("start", onStart)
callbacks:add("frame", onFrame)
callbacks:add("shutdown", onShutdown)

-- Se o jogo já está rodando, executa onStart imediatamente
if emu:getGameTitle() then
    onStart()
end

