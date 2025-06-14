local BaseGame = require("game.base_game")

local PokemonUnbound = {}
PokemonUnbound.__index = PokemonUnbound
setmetatable(PokemonUnbound, {__index = BaseGame})

-- Configurações específicas do Unbound
PokemonUnbound.Addresses = {
    base_stats_table_address = 0x99e0c9c,
    pokemon_party_address = 0x2024284,
    pokemon_party_enemy_address = 0x202402C,
    base_stats_entry_size = 28,
    pokemon_party_entry_size = 100
}

-- Construtor específico do Unbound
function PokemonUnbound:new()
    local config = {
        name = "Pokemon Unbound",
        addresses = self.Addresses,
        detection_keywords = {"unbound"}
    }
    return BaseGame.new(self, config)
end

-- Exemplo de POLIMORFISMO - sobrescrevendo método da classe pai
function PokemonUnbound:readPartyPokemon(base_address)
    -- Chama a implementação da classe pai primeiro

    local species = emu:read16(base_address + 0x20)

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
    
    return success and data or nil
end

return PokemonUnbound

