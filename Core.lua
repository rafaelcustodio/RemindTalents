-------------------------------------------------------------------------------
--  RemindTalents / Core.lua
--  Namespace, DB init, roteador central de eventos, checagem de
--  incompatibilidade com o TalentLoadoutsEx, e slash command.
-------------------------------------------------------------------------------
local ADDON, ns = ...

_G.RemindTalents = ns          -- exposto p/ debug: /run RemindTalents.something
ns.name = ADDON
local L = ns.L

-------------------------------------------------------------------------------
--  Helpers
-------------------------------------------------------------------------------
local PREFIX = "|cff33ff99RemindTalents|r: "

function ns.SafePrint(msg)
    if msg then DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg)) end
end

function ns.Warn(msg)
    if msg then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555RemindTalents|r: " .. tostring(msg)) end
end

-- Wrapper de C_Timer.After (nome curto e à prova de nil).
function ns.After(sec, fn)
    if C_Timer and C_Timer.After and type(fn) == "function" then
        C_Timer.After(sec or 0, fn)
    end
end

-- Chave de classe (CLASS_FILENAME, ex. "MAGE").
function ns.GetClassKey()
    local _, classFile = UnitClass("player")
    return classFile
end

-- specID real (ex. 63 = Fire), estável entre patches. nil se indisponível.
function ns.GetSpecID()
    if PlayerUtil and PlayerUtil.GetCurrentSpecID then
        local id = PlayerUtil.GetCurrentSpecID()
        if id then return id end
    end
    local idx = GetSpecialization and GetSpecialization()
    if idx then
        local specID = GetSpecializationInfo(idx)
        return specID
    end
    return nil
end

-- Índice da spec (1..4) e o ícone da spec atual (fileID) para fallbacks.
function ns.GetSpecIndex()
    return GetSpecialization and GetSpecialization() or nil
end

function ns.GetSpecIcon()
    local specID = ns.GetSpecID()
    if specID and GetSpecializationInfoByID then
        local _, _, _, icon = GetSpecializationInfoByID(specID)
        return icon
    end
    return nil
end

-------------------------------------------------------------------------------
--  Roteador central de eventos (pub-sub sobre um único frame)
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
ns.eventFrame = eventFrame

local subscribers = {}   -- [event] = { fn, fn, ... }

-- Assina um evento do WoW. O evento só é registrado no frame na primeira
-- assinatura. Os callbacks recebem (event, ...).
function ns.On(event, fn)
    if type(fn) ~= "function" then return end
    local list = subscribers[event]
    if not list then
        list = {}
        subscribers[event] = list
        eventFrame:RegisterEvent(event)
    end
    list[#list + 1] = fn
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if ns.disabled then return end
    local list = subscribers[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], event, ...)
        if not ok then ns.Warn("erro em handler de " .. event .. ": " .. tostring(err)) end
    end
end)

-------------------------------------------------------------------------------
--  Módulos: cada módulo registra uma função de init chamada no PLAYER_LOGIN
--  (somente se o addon não estiver desabilitado por incompatibilidade).
-------------------------------------------------------------------------------
ns.initFns = {}
function ns.RegisterInit(fn)
    if type(fn) == "function" then ns.initFns[#ns.initFns + 1] = fn end
end

-------------------------------------------------------------------------------
--  DB
-------------------------------------------------------------------------------
local DB_DEFAULTS = {
    version  = 1,
    loadouts = {},   -- [CLASS][specID] = { loadout, ... }
    minimap  = { hide = false, minimapPos = 215 },
    settings = {
        iconScale = 1.0,
        lockIcon  = false,
        iconPoint = { "CENTER", nil, "CENTER", 0, 120 },
    },
}

local function ApplyDefaults(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            ApplyDefaults(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local function InitDB()
    if type(_G.RemindTalentsDB) ~= "table" then _G.RemindTalentsDB = {} end
    ApplyDefaults(_G.RemindTalentsDB, DB_DEFAULTS)
    ns.db = _G.RemindTalentsDB
end

-------------------------------------------------------------------------------
--  Incompatibilidade com o TalentLoadoutsEx
-------------------------------------------------------------------------------
local function TLXActive()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        return C_AddOns.IsAddOnLoaded("TalentLoadoutsEx")
    end
    if _G.IsAddOnLoaded then return _G.IsAddOnLoaded("TalentLoadoutsEx") end
    return false
end

-------------------------------------------------------------------------------
--  Bootstrap
-------------------------------------------------------------------------------
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:HookScript("OnEvent", function(_, event, ...)
    -- Roda ANTES da checagem de ns.disabled do dispatcher acima? Não — este é um
    -- segundo handler via HookScript. Tratamos só o bootstrap aqui.
    if event ~= "PLAYER_LOGIN" then return end

    InitDB()

    if TLXActive() then
        ns.disabled = true
        ns.Warn(L["Disable TalentLoadoutsEx to use RemindTalents (they are incompatible), then type /reload."])
        -- Oferece migrar os loadouts do TLX (a SV dele só está disponível enquanto ativo).
        if ns.Storage and ns.Storage.HasTLXData and ns.Storage.HasTLXData() then
            ns.After(1.5, function() StaticPopup_Show("REMINDTALENTS_TLX_MIGRATE") end)
        end
        return
    end

    for i = 1, #ns.initFns do
        local ok, err = pcall(ns.initFns[i])
        if not ok then ns.Warn("init error: " .. tostring(err)) end
    end
    ns.SafePrint(L["loaded. Open the talent tree to manage loadouts. /rtl for help."])
end)

-------------------------------------------------------------------------------
--  Slash command
-------------------------------------------------------------------------------
-- Executa a migração do TalentLoadoutsEx e informa o resultado.
function ns.RunTLXMigration()
    if not (ns.Storage and ns.Storage.ImportFromTLX) then return end
    local n = ns.Storage.ImportFromTLX()
    if n and n > 0 then
        ns.SafePrint((L["Imported %d loadout(s) from TalentLoadoutsEx. Now disable it and use /reload."]):format(n))
        if not ns.disabled and ns.UI and ns.UI.RefreshList then ns.UI.RefreshList() end
    else
        ns.SafePrint(L["No TalentLoadoutsEx loadouts found for your class (is it enabled?)."])
    end
end

StaticPopupDialogs["REMINDTALENTS_TLX_MIGRATE"] = {
    text = L["TalentLoadoutsEx is enabled and is incompatible with RemindTalents.\n\nDo you want to import your loadouts from it now?"],
    button1 = L["Migrate"],
    button2 = L["Not now"],
    OnAccept = function() ns.RunTLXMigration() end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

-- /rt é usado pelo Method Raid Tools; usamos /rtl para não conflitar.
SLASH_REMINDTALENTS1 = "/rtl"
SLASH_REMINDTALENTS2 = "/remindtalents"
SlashCmdList["REMINDTALENTS"] = function(msg)
    msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower()

    -- Migração do TalentLoadoutsEx (funciona mesmo com o addon inerte, pois
    -- precisa que o TLX esteja ativo para ler a SavedVariable dele).
    if msg == "migrate" or msg == "import" or msg == "tlx" then
        ns.RunTLXMigration()
        return
    end

    if ns.disabled then
        ns.Warn(L["inactive: disable TalentLoadoutsEx and use /reload."])
        return
    end

    if msg == "save" then
        if ns.Apply and ns.Apply.ExportCurrentToNew then
            ns.Apply.ExportCurrentToNew()
        else
            ns.Warn(L["export module unavailable."])
        end
        return
    elseif msg == "talents" or msg == "" then
        -- Abre a arvore de talentos nativa; o painel do RemindTalents vem junto.
        if _G.PlayerSpellsUtil and PlayerSpellsUtil.OpenToTalentsTab then
            PlayerSpellsUtil.OpenToTalentsTab()
        elseif _G.ToggleTalentFrame then
            ToggleTalentFrame()
        end
        if msg == "" then
            ns.SafePrint(L["commands: /rtl (talents), /rtl save (save current), /rtl migrate (import from TalentLoadoutsEx)."])
        end
        return
    else
        ns.SafePrint(L["commands: /rtl (talents), /rtl save (save current), /rtl migrate (import from TalentLoadoutsEx)."])
    end
end
