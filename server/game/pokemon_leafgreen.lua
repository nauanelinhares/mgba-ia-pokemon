local BaseGame = require("game.base_game")

local PokemonLeafgreen = {}
PokemonLeafgreen.__index = PokemonLeafgreen
setmetatable(PokemonLeafgreen, {__index = BaseGame})

-- Configurações específicas do LeafGreen
PokemonLeafgreen.Addresses = {
    base_stats_table_address = 0x8254784,
    pokemon_party_address = 0x2024284,
    pokemon_party_enemy_address = 0x202402C,
    base_stats_entry_size = 28,
    pokemon_party_entry_size = 100
}

-- Construtor específico do LeafGreen
function PokemonLeafgreen:new()
    local config = {
        name = "Pokemon LeafGreen",
        addresses = self.Addresses,
        detection_keywords = {"leaf", "bpge"}
    }
    return BaseGame.new(self, config)
end

-- Implementação específica do LeafGreen (se necessário)
function PokemonLeafgreen:getGameSpecificData()
    return "Dados específicos do Pokemon LeafGreen"
end

-- Método específico para LeafGreen (exemplo de extensão)
function PokemonLeafgreen:getLeafGreenSpecialFeature()
    return "Funcionalidade especial do LeafGreen"
end

return PokemonLeafgreen