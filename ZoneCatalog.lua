-------------------------------------------------------------------------------
--  RemindTalents / ZoneCatalog.lua
--  Catálogo estático de zonas conhecidas (raids/masmorras/arenas/pvp) e
--  detecção da zona atual. Masmorras casam por mapID; raids/arenas/pvp por
--  nome de instância (GetInstanceInfo). Portado de TALENT_REMINDER_ZONES
--  (EllesmereUI). Estender à vontade conforme novas zonas.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local Zones = {}
ns.Zones = Zones

-- type: "raid" | "dungeon" | "pvp"
Zones.entries = {
    { name = "The Voidspire",           type = "raid" },
    { name = "The Dreamrift",           type = "raid" },
    { name = "March on Quel'Danas",     type = "raid" },
    { name = "Sporefall",               type = "raid" },

    { name = "Magister's Terrace",      type = "dungeon", mapID = 2515 },
    { name = "Maisara Caverns",         type = "dungeon", mapID = 2501 },
    { name = "Nexus-Point Xenas",       type = "dungeon", mapID = 2556 },
    { name = "Windrunner Spire",        type = "dungeon", mapID = 2492 },
    { name = "Algeth'ar Academy",       type = "dungeon", mapID = 2097 },
    { name = "Seat of the Triumvirate", type = "dungeon", mapID = 8910 },
    { name = "Skyreach",                type = "dungeon", mapID = 601  },
    { name = "Pit of Saron",            type = "dungeon", mapID = 184  },
    { name = "The Rookery",             type = "dungeon", mapID = 2315 },

    { name = "Nagrand Arena",           type = "pvp" },
    { name = "Blade's Edge Arena",      type = "pvp" },
    { name = "Ruins of Lordaeron",      type = "pvp" },
    { name = "Dalaran Sewers",          type = "pvp" },
    { name = "The Ring of Valor",       type = "pvp" },
    { name = "Tol'viron Arena",         type = "pvp" },
    { name = "Tiger's Peak",            type = "pvp" },
    { name = "Black Rook Hold Arena",   type = "pvp" },
    { name = "Ashamane's Fall",         type = "pvp" },
    { name = "Mugambala",               type = "pvp" },
    { name = "Hook Point",              type = "pvp" },
    { name = "Empyrean Domain",         type = "pvp" },
    { name = "Warsong Gulch",           type = "pvp" },
    { name = "Arathi Basin",            type = "pvp" },
    { name = "Eye of the Storm",        type = "pvp" },
    { name = "Strand of the Ancients",  type = "pvp" },
    { name = "Isle of Conquest",        type = "pvp" },
    { name = "Twin Peaks",              type = "pvp" },
    { name = "Silvershard Mines",       type = "pvp" },
    { name = "Battle for Gilneas",      type = "pvp" },
    { name = "Temple of Kotmogu",       type = "pvp" },
    { name = "Deepwind Gorge",          type = "pvp" },
    { name = "Ashran",                  type = "pvp" },
    { name = "Seething Shore",          type = "pvp" },
    { name = "Wintergrasp",             type = "pvp" },
    { name = "Slayer's Rise",           type = "pvp" },
}

-- Índice por mapID para lookup rápido.
Zones.byMapID = {}
for _, z in ipairs(Zones.entries) do
    if z.mapID then Zones.byMapID[z.mapID] = z end
end

-- Descritor da zona atual: { iType, name, mapID }. iType vem do 2º retorno de
-- GetInstanceInfo (party/raid/scenario/arena/pvp/none).
function Zones.GetCurrent()
    local name, iType = GetInstanceInfo()
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    return { iType = iType, name = name, mapID = mapID }
end

-- É conteúdo instanciado relevante (onde faz sentido lembrar de loadout)?
function Zones.IsInstancedContent()
    if C_Garrison and C_Garrison.IsOnGarrisonMap and C_Garrison.IsOnGarrisonMap() then
        return false
    end
    local _, iType = GetInstanceInfo()
    return iType == "party" or iType == "raid" or iType == "scenario"
        or iType == "arena" or iType == "pvp"
end

-- Se a zona atual está no catálogo, retorna a entrada correspondente.
function Zones.MatchCatalog(zone)
    zone = zone or Zones.GetCurrent()
    if zone.mapID and Zones.byMapID[zone.mapID] then
        return Zones.byMapID[zone.mapID]
    end
    if zone.name then
        for _, z in ipairs(Zones.entries) do
            if z.name == zone.name then return z end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
--  Catálogo AUTOMÁTICO da season (dungeons via C_ChallengeMode, bosses via
--  Encounter Journal). Ícone + nome direto das APIs. Cache até /reload.
-------------------------------------------------------------------------------

-- Masmorras da temporada de M+ atual: { {kind="dungeon", name, icon, challengeMapID} }
function Zones.GetSeasonDungeons()
    if Zones._dungeons then return Zones._dungeons end
    local out = {}
    if C_ChallengeMode and C_ChallengeMode.GetMapTable then
        local maps = C_ChallengeMode.GetMapTable() or {}
        for _, mapID in ipairs(maps) do
            local name, _, _, texture = C_ChallengeMode.GetMapUIInfo(mapID)
            if name then
                out[#out + 1] = { kind = "dungeon", name = name, icon = texture, challengeMapID = mapID }
            end
        end
    end
    -- só cacheia se veio algo (evita travar num resultado vazio antes dos dados carregarem)
    if #out > 0 then Zones._dungeons = out end
    return out
end

-- Carrega o Encounter Journal sob demanda (sem abrir a UI).
function Zones.EnsureEJ()
    if EJ_GetCurrentTier and EJ_GetInstanceByIndex and EJ_GetEncounterInfoByIndex then return true end
    if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_EncounterJournal")
    elseif _G.LoadAddOn then pcall(_G.LoadAddOn, "Blizzard_EncounterJournal") end
    return EJ_GetCurrentTier ~= nil and EJ_GetInstanceByIndex ~= nil
end

-- Raids do tier atual: { {name=raidName, bosses={ {kind="boss", name, icon, encounterID} }} }
function Zones.GetSeasonRaids()
    if Zones._raids then return Zones._raids end
    local out = {}
    if not Zones.EnsureEJ() then return out end

    local savedTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    if EJ_SelectTier and savedTier then EJ_SelectTier(savedTier) end

    local i = 1
    while true do
        -- shouldDisplayDifficulty é o 10º retorno: false para o grupo de world
        -- bosses (que o journal lista como uma "raid" com o nome da expansão,
        -- ex.: "Midnight") e true para raids de verdade. ATENÇÃO à contagem de
        -- underscores: são 7 (posições 3-9) antes do 10º valor.
        local instanceID, name, _, _, _, _, _, _, _, shouldDisplayDifficulty =
            EJ_GetInstanceByIndex(i, true)
        if not instanceID then break end
        if shouldDisplayDifficulty == false then
            i = i + 1
        else
            EJ_SelectInstance(instanceID)
            local bosses = {}
            local b = 1
            while true do
                local bName, _, encID = EJ_GetEncounterInfoByIndex(b, instanceID)
                if not bName then break end
                local icon = encID and select(5, EJ_GetCreatureInfo(1, encID))  -- iconImage
                bosses[#bosses + 1] = { kind = "boss", name = bName, encounterID = encID, icon = icon }
                b = b + 1
            end
            if #bosses > 0 then out[#out + 1] = { name = name, bosses = bosses } end
            i = i + 1
        end
    end

    if EJ_SelectTier and savedTier then EJ_SelectTier(savedTier) end
    if #out > 0 then Zones._raids = out end
    return out
end

-- Dificuldade da raid atual como token: "normal"/"heroic"/"mythic"/"lfr" ou nil.
function Zones.GetRaidDifficulty()
    local _, _, difficultyID = GetInstanceInfo()
    if difficultyID == 16 then return "mythic"
    elseif difficultyID == 15 then return "heroic"
    elseif difficultyID == 14 then return "normal"
    elseif difficultyID == 17 then return "lfr"
    end
    return nil
end

-- Um slot armazenado (loadout.zones) ainda pertence ao catálogo atual?
function Zones.IsSlotCurrent(slot)
    if not slot then return false end
    if slot.kind == "boss" then
        for _, raid in ipairs(Zones.GetSeasonRaids()) do
            for _, b in ipairs(raid.bosses) do
                if (slot.encounterID and b.encounterID == slot.encounterID)
                    or (slot.name and b.name == slot.name) then return true end
            end
        end
        return false
    end
    -- Uma masmorra só é "atual" se casar pelo challengeMapID (a chave estável do
    -- catálogo). Slots legados só por nome caem em "Antigos" (recuperáveis).
    if slot.challengeMapID then
        for _, d in ipairs(Zones.GetSeasonDungeons()) do
            if d.challengeMapID == slot.challengeMapID then return true end
        end
    end
    return false
end

-------------------------------------------------------------------------------
--  Busca textual (legado; usada só se o catálogo automático estiver vazio)
-------------------------------------------------------------------------------
-- Busca textual (case-insensitive) por nome. query vazia retorna tudo.
function Zones.Search(query)
    query = (query or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return Zones.entries end
    local out = {}
    for _, z in ipairs(Zones.entries) do
        if z.name:lower():find(query, 1, true) then
            out[#out + 1] = z
        end
    end
    return out
end
