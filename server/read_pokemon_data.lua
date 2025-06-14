-- Função para ler dados completos do Pokémon

-- Importa as dependências necessárias
local Utils = require("Utils.utils")
local GeneralData = require("structure.general_data")
local PokemonFirered = require("addresses.pokemon_firered")
local PokemonUnbound = require("addresses.pokemon_unbound")





-- Endereço da tabela de stats base em Fire Red/Leaf Green
-- fired red base stats address 0x8254784
local BASE_STATS_TABLE_ADDRESS = PokemonFirered.Addresses.base_stats_table_address
local BASE_STATS_ENTRY_SIZE = PokemonFirered.Addresses.base_stats_entry_size

-- Função para ler stats base de um Pokémon por ID
local function readBaseStats(pokemonId)
    if not pokemonId or pokemonId <= 0 then
        console:error("ID do Pokémon inválido para readBaseStats: " .. tostring(pokemonId))
        return nil
    end

    -- Calcula o endereço das stats base para este Pokémon
    local baseStatsAddr = BASE_STATS_TABLE_ADDRESS + ((pokemonId) * BASE_STATS_ENTRY_SIZE)
    
    local success, baseStats = pcall(function()
        return {
            hp = emu:read8(baseStatsAddr + 0),      -- HP base
            attack = emu:read8(baseStatsAddr + 1),   -- Ataque base
            defense = emu:read8(baseStatsAddr + 2),  -- Defesa base
            speed = emu:read8(baseStatsAddr + 3),    -- Velocidade base
            sp_attack = emu:read8(baseStatsAddr + 4), -- Ataque especial base
            sp_defense = emu:read8(baseStatsAddr + 5), -- Defesa especial base
            type1 = emu:read8(baseStatsAddr + 6),    -- Tipo primário
            type2 = emu:read8(baseStatsAddr + 7),    -- Tipo secundário
            catch_rate = emu:read8(baseStatsAddr + 8), -- Taxa de captura
            base_exp = emu:read8(baseStatsAddr + 9)   -- Experiência base
        }
    end)

    if success then
        return baseStats
    else
        console:warn("Não foi possível ler stats base do Pokémon ID " .. pokemonId)
        return nil
    end
end


local function read_pokemon_structure(base_address) 
    local personality_value = emu:read8(base_address + 0x00)
    local ot_id = emu:read8(base_address + 4)

    local magicword = Utils.bit_xor(personality_value, ot_id)

    local aux = personality_value % 24 + 1
    local growth_offset = (GeneralData.TableData.growth[aux]-1) * 12
    local attack_offset = (GeneralData.TableData.attack[aux]-1) * 12
    local effort_offset = (GeneralData.TableData.effort[aux]-1) * 12
    local misc_offset = (GeneralData.TableData.misc[aux]-1) * 12

    local growth1 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + growth_offset), magicword)
	local growth2 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + growth_offset + 4), magicword) -- Experience
	local growth3 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + growth_offset + 8), magicword)
	local attack1 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + attack_offset), magicword)
	local attack2 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + attack_offset + 4), magicword)
	local attack3 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + attack_offset + 8), magicword)
	local effort1 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + effort_offset), magicword)
	local effort2 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + effort_offset + 4), magicword)
	local misc2 = Utils.bit_xor(emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + misc_offset + 4), magicword)

    return {
        species = Utils.getbits(growth1, 0, 16),
    }
end 

local function read_party_pokemon(base_address)
    if not base_address then
        console:error("BASE_ADDRESS não foi fornecido para readPokemonData")
        return nil
    end

    local pokemon_structure = read_pokemon_structure(base_address)

    if not pokemon_structure.species then 
        return nil
    end

    local species = pokemon_structure.species

    local base_stats

    if species > 0 then 
        base_stats = readBaseStats(species)
    else
        base_stats = nil
    end

    local type1
    local type2
    if base_stats then
        type1 = base_stats.type1
        type2 = base_stats.type2
    else
        type1 = 0
        type2 = 0
    end


    local success, data = pcall(function()
        return {
            type1 = type1,    -- Tipo do Pokémon
            type2 = type2,    -- Tipo do Pokémon
            species = species, -- ID do Pokémon
            hp_current = emu:read16(base_address + 0x56), -- HP atual
            hp_max = emu:read16(base_address + 0x58),     -- HP máximo
            level = emu:read8(base_address + 0x54)        -- Nível
        }
    end)

    if success  then
        -- Adiciona as stats base ao resultado
        return data
    else
        console:warn("Não foi possível ler dados do Pokémon no endereço " .. string.format("0x%X", base_address))
        return nil
    end
end



-- Retorna as funções para serem usadas por outros scripts
return {
    read_party_pokemon = read_party_pokemon,
}