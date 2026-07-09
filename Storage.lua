-------------------------------------------------------------------------------
--  RemindTalents / Storage.lua
--  Cada slot (dungeon ou boss) pode ter VÁRIOS loadouts.
--  db.assignments[CLASS][specID][slotKey] = {
--      slotKey, slot = {kind,name,encounterID,challengeMapID,mapID},
--      loadouts = { { id, name, icon, text, created }, ... }
--  }
--  A export string (text) é a fonte de verdade do talento.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local Storage = {}
ns.Storage = Storage
local L = ns.L

local idCounter = 0
local function NewID()
    idCounter = idCounter + 1
    return ("l-%d-%d"):format(time(), idCounter)
end

-------------------------------------------------------------------------------
--  Chave estável de um slot
-------------------------------------------------------------------------------
local function SlotKey(slot)
    if not slot then return nil end
    if slot.kind == "boss" then
        return "b:" .. tostring(slot.encounterID or slot.name or "?")
    elseif slot.kind == "dungeon" then
        return "d:" .. tostring(slot.challengeMapID or slot.name or "?")
    elseif slot.kind == "other" then
        -- Bucket único "Others": chave fixa (independe de nome/idioma).
        return "o:others"
    end
    return "x:" .. tostring(slot.name or slot.mapID or "?")
end
Storage.SlotKey = SlotKey

-------------------------------------------------------------------------------
--  Container da classe/spec atual
-------------------------------------------------------------------------------
local function GetSpecTable(create)
    local db = ns.db
    local class, spec = ns.GetClassKey(), ns.GetSpecID()
    if not (db and class and spec) then return nil end
    db.assignments = db.assignments or {}
    local byClass = db.assignments[class]
    if not byClass then
        if not create then return nil end
        byClass = {}; db.assignments[class] = byClass
    end
    local t = byClass[spec]
    if not t then
        if not create then return nil end
        t = {}; byClass[spec] = t
    end
    return t
end

function Storage.GetAllEntries()
    return GetSpecTable(false) or {}
end

function Storage.GetSlotEntry(slotKey)
    local t = GetSpecTable(false)
    return (t and slotKey) and t[slotKey] or nil
end

-- Lista de loadouts de um slot (nunca nil).
function Storage.GetLoadouts(slotKey)
    local e = Storage.GetSlotEntry(slotKey)
    return e and e.loadouts or {}
end

-- Adiciona um loadout ao slot (cria a entrada se necessário). Retorna o loadout.
function Storage.AddLoadout(slot, fields)
    local key = SlotKey(slot)
    if not key then return nil end
    local t = GetSpecTable(true)
    if not t then ns.Warn(L["could not save (class/spec unavailable)."]); return nil end

    local e = t[key]
    if not e then
        e = { slotKey = key, slot = {}, loadouts = {} }
        t[key] = e
    end
    e.slot = {
        kind = slot.kind, name = slot.name, encounterID = slot.encounterID,
        challengeMapID = slot.challengeMapID, mapID = slot.mapID,
    }
    fields = fields or {}
    local lo = {
        id = NewID(),
        name = fields.name or slot.name or "Loadout",
        icon = fields.icon,
        text = fields.text,
        difficulty = fields.difficulty,   -- "all"/"normal"/"heroic"/"mythic" (raid) ou nil
        created = time(),
    }
    e.loadouts[#e.loadouts + 1] = lo
    return lo
end

-- Localiza um loadout por (slotKey,id). Retorna loadout, entry, index.
local function FindLoadout(slotKey, id)
    local e = Storage.GetSlotEntry(slotKey)
    if not e then return nil end
    for i, lo in ipairs(e.loadouts) do
        if lo.id == id then return lo, e, i end
    end
    return nil
end

function Storage.UpdateLoadout(slotKey, id, fields)
    local lo = FindLoadout(slotKey, id)
    if not lo or not fields then return nil end
    for k, v in pairs(fields) do lo[k] = v end
    return lo
end

function Storage.DeleteLoadout(slotKey, id)
    local lo, e, idx = FindLoadout(slotKey, id)
    if not lo then return false end
    table.remove(e.loadouts, idx)
    if #e.loadouts == 0 then
        local t = GetSpecTable(false)
        if t then t[slotKey] = nil end
    end
    return true
end

-------------------------------------------------------------------------------
--  Lookups para o lembrete (retornam a ENTRADA do slot, com .loadouts)
-------------------------------------------------------------------------------
function Storage.FindForZone(zone)
    local t = GetSpecTable(false)
    if not (t and zone) then return nil end
    for _, e in pairs(t) do
        local s = e.slot
        if s and s.kind ~= "boss" then
            if (s.mapID and zone.mapID and s.mapID == zone.mapID)
                or (s.name and zone.name and s.name == zone.name) then
                return e
            end
        end
    end
    return nil
end

-------------------------------------------------------------------------------
--  Migração
--   1) modelo array antigo (db.loadouts[.].zones) → assignments 1:1
--   2) assignments 1:1 (com .text no topo) → lista (.loadouts)
-------------------------------------------------------------------------------
local function MigrateArray(db)
    if db._assignMigrated then return end
    db._assignMigrated = true
    if type(db.loadouts) ~= "table" then return end
    db.assignments = db.assignments or {}
    for class, byClass in pairs(db.loadouts) do
        for spec, list in pairs(byClass) do
            if type(list) == "table" then
                db.assignments[class] = db.assignments[class] or {}
                db.assignments[class][spec] = db.assignments[class][spec] or {}
                local dst = db.assignments[class][spec]
                for _, lo in ipairs(list) do
                    local zones = lo.zones or {}
                    local function put(slot)
                        local key = SlotKey(slot)
                        if not key then return end
                        dst[key] = dst[key] or { slotKey = key, slot = slot, loadouts = {} }
                        dst[key].loadouts[#dst[key].loadouts + 1] =
                            { id = NewID(), name = lo.name, icon = lo.icon, text = lo.text, created = lo.created }
                    end
                    if #zones == 0 then
                        put({ kind = "old", name = lo.name })
                    else
                        for _, z in ipairs(zones) do
                            put({ kind = z.kind or (z.encounterID and "boss") or "dungeon",
                                  name = z.name, encounterID = z.encounterID,
                                  challengeMapID = z.challengeMapID, mapID = z.mapID })
                        end
                    end
                end
            end
        end
    end
end

local function MigrateToList(db)
    if db._listMigrated then return end
    db._listMigrated = true
    if type(db.assignments) ~= "table" then return end
    for _, byClass in pairs(db.assignments) do
        for _, t in pairs(byClass) do
            for _, e in pairs(t) do
                if type(e) == "table" and e.loadouts == nil and e.text ~= nil then
                    e.loadouts = { { id = NewID(), name = e.name, icon = e.icon,
                                     text = e.text, created = e.created } }
                    e.name, e.icon, e.text, e.created = nil, nil, nil, nil
                end
            end
        end
    end
end

function Storage.Migrate()
    local db = ns.db
    if not db then return end
    MigrateArray(db)
    MigrateToList(db)
end

ns.RegisterInit(Storage.Migrate)

-------------------------------------------------------------------------------
--  Migração a partir do TalentLoadoutsEx (_G.TalentLoadoutEx)
--  Estrutura do TLX: TalentLoadoutEx[CLASS][specIndex] = { {name,icon,text}, ... }
--  (entradas sem `text` são grupos/pastas do TLX e são ignoradas).
--  Só é possível enquanto o TLX está ATIVO (a SV dele só carrega assim).
--  Importa os builds da CLASSE do jogador (todas as specs) para um slot
--  "Importados (TalentLoadoutsEx)" que aparece em "Antigos".
-------------------------------------------------------------------------------

-- Há dados do TLX para a classe do jogador?
function Storage.HasTLXData()
    local sv = _G.TalentLoadoutEx
    if type(sv) ~= "table" then return false end
    local _, class = UnitClass("player")
    local byClass = class and sv[class]
    if type(byClass) ~= "table" then return false end
    for specIndex, list in pairs(byClass) do
        if type(specIndex) == "number" and type(list) == "table" then
            for _, e in ipairs(list) do
                if type(e) == "table" and e.text then return true end
            end
        end
    end
    return false
end

-- Importa e retorna a quantidade importada.
function Storage.ImportFromTLX()
    local sv = _G.TalentLoadoutEx
    if type(sv) ~= "table" then return 0 end
    local _, class = UnitClass("player")
    local byClass = class and sv[class]
    if type(byClass) ~= "table" then return 0 end

    local db = ns.db
    if not db then return 0 end
    db.assignments = db.assignments or {}
    db.assignments[class] = db.assignments[class] or {}

    -- A chave DEVE ser SlotKey(slot) para a UI encontrar a entrada.
    local importSlot = { kind = "old", name = L["Imported (TalentLoadoutsEx)"] }
    local KEY = SlotKey(importSlot)
    local imported = 0

    for specIndex, list in pairs(byClass) do
        if type(specIndex) == "number" and type(list) == "table" then
            local specID = GetSpecializationInfo(specIndex)
            if specID then
                local t = db.assignments[class][specID]
                if not t then t = {}; db.assignments[class][specID] = t end
                local e = t[KEY]
                if not e then
                    e = { slotKey = KEY, slot = { kind = "old", name = L["Imported (TalentLoadoutsEx)"] }, loadouts = {} }
                    t[KEY] = e
                end
                for _, entry in ipairs(list) do
                    if type(entry) == "table" and entry.text then
                        local dup = false
                        for _, lo in ipairs(e.loadouts) do
                            if lo.text == entry.text then dup = true; break end
                        end
                        if not dup then
                            e.loadouts[#e.loadouts + 1] = {
                                id = NewID(),
                                name = entry.name or "Loadout",
                                icon = (type(entry.icon) == "number") and entry.icon or nil,
                                text = entry.text,
                                created = time(),
                            }
                            imported = imported + 1
                        end
                    end
                end
                -- remove o slot se nada foi importado nele
                if #e.loadouts == 0 then t[KEY] = nil end
            end
        end
    end
    return imported
end
