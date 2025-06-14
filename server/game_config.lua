-- Game selection and address configuration

local PokemonFirered = require("addresses.pokemon_firered")
local PokemonUnbound = require("addresses.pokemon_unbound")



GAME_CONFIGS = {
   firered = {
       name = "Pokemon FireRed",
       addresses = PokemonFirered.Addresses,
       detection_keywords = {"fire", "bpre"}
   },
   leafgreen = {
       name = "Pokemon LeafGreen", 
       addresses = PokemonFirered.Addresses, -- LeafGreen uses same addresses as FireRed
       detection_keywords = {"leaf", "bpge"}
   },
   unbound = {
       name = "Pokemon Unbound",
       addresses = PokemonUnbound.Addresses,
       detection_keywords = {"unbound"}
   }
}
return GAME_CONFIGS