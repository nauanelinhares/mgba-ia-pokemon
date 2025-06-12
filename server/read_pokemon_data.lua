-- Função para ler dados completos do Pokémon

-- Importa as dependências necessárias
local Utils = require("Utils.utils")
local GeneralData = require("structure.general_data")


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


    local success, data = pcall(function()
        return {
            type = emu:read8(base_address + 0x00),    -- Tipo do Pokémon
            species = pokemon_structure.species, -- ID do Pokémon
            hp_current = emu:read16(base_address + 0x56), -- HP atual
            hp_max = emu:read16(base_address + 0x58),     -- HP máximo
            level = emu:read8(base_address + 0x54)        -- Nível
        }
    end)

    if success and data.species > 0 then
        -- Adiciona as stats base ao resultado
        data.base_stats = readBaseStats(data.species)
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