-- Função para ler dados completos do Pokémon
local function readPokemonData(base_address)
    if not base_address then
        console:error("BASE_ADDRESS não foi fornecido para readPokemonData")
        return nil
    end

    local success, data = pcall(function()
        return {
                 -- Tipo do Pokémon
            type = emu:read8(0x0300500C + 0x0000),
            species = emu:read16(base_address + 0x20),    -- ID do Pokémon
            hp_current = emu:read16(base_address + 0x56), -- HP atual
            hp_max = emu:read16(base_address + 0x58),     -- HP máximo
            level = emu:read8(base_address + 0x54)        -- Nível
        }
    end)

    if success and data.species > 0 then
        return data
    else
        console:warn("Não foi possível ler dados do Pokémon no endereço " .. string.format("0x%X", base_address))
        return nil
    end
end

-- Retorna a função para ser usada por outros scripts
return readPokemonData