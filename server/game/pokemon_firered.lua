local BaseGame = require("game.base_game")

local PokemonFirered = {}
PokemonFirered.__index = PokemonFirered
setmetatable(PokemonFirered, {__index = BaseGame})

-- Configurações específicas do FireRed
PokemonFirered.Addresses = {
    base_stats_table_address = 0x8254784,
    pokemon_party_address = 0x2024284,
    pokemon_party_enemy_address = 0x202402C,
    base_stats_entry_size = 28,
    pokemon_party_entry_size = 100
}

-- Construtor específico do FireRed
function PokemonFirered:new()
    local config = {
        name = "Pokemon FireRed",
        addresses = self.Addresses,
        detection_keywords = {"fire", "bpre"}
    }
    return BaseGame.new(self, config)
end

-- Implementação específica do FireRed (se necessário)
function PokemonFirered:getGameSpecificData()
    return "Dados específicos do Pokemon FireRed"
end

-- Método específico para FireRed (exemplo de extensão)
function PokemonFirered:getFireRedSpecialFeature()
    return "Funcionalidade especial do FireRed"
end

return PokemonFirered