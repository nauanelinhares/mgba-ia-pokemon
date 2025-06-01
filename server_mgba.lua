-- Script para monitoramento completo de Pokémon no mGBA
-- Compatível com a API do mGBA v0.10+

-- Verificação do ambiente mGBA
if not emu then
    console:error("ERRO: Este script deve ser executado no mGBA")
    console:error("Vá em Tools > Scripting... e carregue este script")
    return
end

-- Configurações
local BASE_ADDRESS = 0x02024284 -- Endereço base do primeiro Pokémon no time
local UPDATE_FREQUENCY = 30     -- A cada quantos frames atualizar (60 = ~1 segundo)

-- Variáveis globais
local frame_count = 0
local last_pokemon_data = {}

-- Importa a função de leitura de dados do Pokémon
local readPokemonData = require("read_pokemon_data")

-- Função para salvar dados em arquivo
local function savePokemonDataToFile(data)
    local file = io.open("pokemon_data.txt", "w")
    if file then
        local content = string.format("Espécie: %d | Nível: %d | HP: %d/%d",
            data.species, data.level, data.hp_current, data.hp_max)
        file:write(content)
        file:close()
        return true
    else
        console:error("Erro ao abrir arquivo pokemon_data.txt para escrita")
        return false
    end
end

-- Função para comparar dados e detectar mudanças
local function detectChanges(current, previous)
    if not previous.species then
        return "Pokémon detectado pela primeira vez"
    end

    local changes = {}

    if current.species ~= previous.species then
        table.insert(changes, string.format("Pokémon mudou (ID: %d → %d)", previous.species, current.species))
    end

    if current.level ~= previous.level then
        table.insert(changes, string.format("Nível: %d → %d", previous.level, current.level))
    end

    if current.hp_current ~= previous.hp_current then
        local diff = current.hp_current - previous.hp_current
        if diff > 0 then
            table.insert(changes, string.format("HP recuperou +%d pontos", diff))
        else
            table.insert(changes, string.format("HP perdeu %d pontos", math.abs(diff)))
        end
    end

    if current.hp_max ~= previous.hp_max then
        local diff = current.hp_max - previous.hp_max
        table.insert(changes, string.format("HP máximo: %d → %d (%+d)", previous.hp_max, current.hp_max, diff))
    end

    return table.concat(changes, " | ")
end

-- Função executada a cada frame
local function onFrame()
    frame_count = frame_count + 1

    -- Atualiza a cada UPDATE_FREQUENCY frames
    if frame_count % UPDATE_FREQUENCY == 0 then
        local pokemon_data = readPokemonData(BASE_ADDRESS)

        if pokemon_data then
            -- Salva no arquivo
            if savePokemonDataToFile(pokemon_data) then
                console:log(string.format("Frame %d - Espécie: %d | Nível: %d | HP: %d/%d",
                    frame_count, pokemon_data.species, pokemon_data.level,
                    pokemon_data.hp_current, pokemon_data.hp_max))

                -- Detecta mudanças
                local changes = detectChanges(pokemon_data, last_pokemon_data)
                if changes and changes ~= "" then
                    console:log("MUDANÇA: " .. changes)
                end

                last_pokemon_data = pokemon_data
            end
        else
            console:warn("Frame " .. frame_count .. " - Falha ao ler dados do Pokémon")
        end
    end
end

-- Função executada quando o jogo inicia
local function onStart()
    console:log("=== SCRIPT POKÉMON MONITOR INICIADO ===")
    console:log("Jogo detectado: " .. (emu:getGameTitle() or "Desconhecido"))
    console:log("Código do jogo: " .. (emu:getGameCode() or "N/A"))
    console:log("Endereço base: " .. string.format("0x%X", BASE_ADDRESS))
    console:log("Frequência de atualização: a cada " .. UPDATE_FREQUENCY .. " frames")

    -- Teste inicial
    local initial_data = readPokemonData(BASE_ADDRESS)
    if initial_data then
        console:log(string.format("Pokémon inicial - Espécie: %d | Nível: %d | HP: %d/%d",
            initial_data.species, initial_data.level,
            initial_data.hp_current, initial_data.hp_max))
        savePokemonDataToFile(initial_data)
        last_pokemon_data = initial_data
    else
        console:warn("Não foi possível detectar Pokémon inicial")
        console:warn("Verifique se o endereço de memória está correto")
    end
end

-- Registra os callbacks
callbacks:add("start", onStart)
callbacks:add("frame", onFrame)

-- Se o jogo já está rodando, executa onStart imediatamente
if emu:getGameTitle() then
    onStart()
end

