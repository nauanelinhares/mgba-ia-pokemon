-- Classe base para todos os jogos Pokémon
local Utils = require("Utils.utils")
local GeneralData = require("structure_gen3.general_data")

local BaseGame = {}
BaseGame.__index = BaseGame

-- Construtor da classe base
function BaseGame:new(config)
    local instance = {
        name = config.name or "Unknown Game",
        addresses = config.addresses or {},
        detection_keywords = config.detection_keywords or {}
    }
    setmetatable(instance, self)
    return instance
end

-- Método para ler stats base (implementação padrão)
function BaseGame:readBaseStats(pokemonId)
    if not pokemonId or pokemonId <= 0 then
        console:error("ID do Pokémon inválido para readBaseStats: " .. tostring(pokemonId))
        return nil
    end

    local baseStatsAddr = self.addresses.base_stats_table_address + 
                         ((pokemonId) * self.addresses.base_stats_entry_size)
    
    local success, baseStats = pcall(function()
        return {
            hp = emu:read8(baseStatsAddr + 0),
            attack = emu:read8(baseStatsAddr + 1),
            defense = emu:read8(baseStatsAddr + 2),
            speed = emu:read8(baseStatsAddr + 3),
            sp_attack = emu:read8(baseStatsAddr + 4),
            sp_defense = emu:read8(baseStatsAddr + 5),
            type1 = emu:read8(baseStatsAddr + 6),
            type2 = emu:read8(baseStatsAddr + 7),
            catch_rate = emu:read8(baseStatsAddr + 8),
            base_exp = emu:read8(baseStatsAddr + 9)
        }
    end)

    if success then
        return baseStats
    else
        console:warn("Não foi possível ler stats base do Pokémon ID " .. pokemonId)
        return nil
    end
end

-- Método para ler estrutura do Pokémon (implementação padrão)
function BaseGame:readPokemonStructure(base_address)
    local personality_value = emu:read8(base_address + 0x00)
    local ot_id = emu:read8(base_address + 4)
    local magicword = Utils.bit_xor(personality_value, ot_id)

    local aux = personality_value % 24 + 1
    local growth_offset = (GeneralData.TableData.growth[aux] - 1) * 12
    
    local growth1 = Utils.bit_xor(
        emu:read8(base_address + GeneralData.Addresses.offsetPokemonSubstruct + growth_offset), 
        magicword
    )

    return {
        species = Utils.getbits(growth1, 0, 16),
    }
end

-- Método principal para ler dados do Pokémon da party
function BaseGame:readPartyPokemon(base_address)
    if not base_address then
        console:error("BASE_ADDRESS não foi fornecido para readPartyPokemon")
        return nil
    end

    local pokemon_structure = self:readPokemonStructure(base_address)

    if not pokemon_structure.species then 
        return nil
    end

    local species = pokemon_structure.species
    local base_stats = species > 0 and self:readBaseStats(species) or nil

    local type1 = base_stats and base_stats.type1 or 0
    local type2 = base_stats and base_stats.type2 or 0

    local success, data = pcall(function()
        return {
            type1 = type1,
            type2 = type2,
            species = species,
            hp_current = emu:read16(base_address + 0x56),
            hp_max = emu:read16(base_address + 0x58),
            level = emu:read8(base_address + 0x54)
        }
    end)

    if success then
        return data
    else
        console:warn("Não foi possível ler dados do Pokémon no endereço " .. string.format("0x%X", base_address))
        return nil
    end
end

-- Método que pode ser sobrescrito pelas classes filhas
function BaseGame:getGameSpecificData()
    return "Dados específicos do jogo base"
end

return BaseGame 