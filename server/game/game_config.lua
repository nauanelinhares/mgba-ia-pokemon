-- Configuração simples dos jogos disponíveis

local PokemonFirered = require("game.pokemon_firered")
local PokemonLeafgreen = require("game.pokemon_leafgreen")
local PokemonUnbound = require("game.pokemon_unbound")

-- Exporta as classes dos jogos
return {
    firered = PokemonFirered,
    leafgreen = PokemonLeafgreen,
    unbound = PokemonUnbound
}