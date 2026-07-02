-------------------------------------------------------------------------------
--  RemindTalents / LoadoutApply.lua
--  Import/export/aplicação de loadouts via APIs públicas da Blizzard
--  (C_Traits / C_ClassTalents / ExportUtil) + os métodos-helper do mixin
--  nativo PlayerSpellsFrame.TalentsFrame (só para parsing/serialização).
--
--  Reimplementação dos mecanismos do TalentLoadoutsEx. O commit é feito via
--  C_Traits.CommitConfig(configID) — NUNCA TalentsFrame:CommitConfig() — para
--  não contaminar (taint) o frame protegido da Blizzard.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local Apply = {}
ns.Apply = Apply
local L = ns.L

-------------------------------------------------------------------------------
--  Garantir o TalentsFrame (mixin) carregado sem ABRIR a UI de talentos.
-------------------------------------------------------------------------------
-- Carrega Blizzard_PlayerSpells sob demanda. NÃO chama :Show() — só precisamos
-- dos métodos do mixin (ReadLoadoutHeader/Content, ConvertToImportLoadoutEntryInfo,
-- WriteLoadout*). Retorna o TalentsFrame ou nil.
function Apply.GetTalentsFrame()
    local psf = _G.PlayerSpellsFrame
    if psf and psf.TalentsFrame then return psf.TalentsFrame end
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_PlayerSpells")
    elseif _G.LoadAddOn then
        pcall(_G.LoadAddOn, "Blizzard_PlayerSpells")
    end
    psf = _G.PlayerSpellsFrame
    return psf and psf.TalentsFrame or nil
end

function Apply.EnsureTalentsFrame(cb)
    local tf = Apply.GetTalentsFrame()
    if tf then
        if cb then cb(tf) end
        return tf
    end
    ns.Warn(L["could not load the talent interface (Blizzard_PlayerSpells)."])
    return nil
end

-------------------------------------------------------------------------------
--  Classificação dos nós da árvore (por spec). Portado de TLX/node.lua.
--  NodeType usa os flags de moeda: Class=4, Spec=8, Hero=0.
-------------------------------------------------------------------------------
local NodeType = { Class = 4, Spec = 8, Hero = 0 }

-- cache por specID
local nodeDataCache = {}   -- [specID] = { order=[nodeID]=idx, typeOf=[nodeID]=flag,
                           --              apex=nodeID, subTreeIDs={}, subCurrencies={} }

local function BuildNodeData(specID, configID, treeID)
    if nodeDataCache[specID] then return nodeDataCache[specID] end
    if not (C_Traits and C_Traits.GetTreeNodes) then return nil end

    -- Ordena os nós visíveis por (posY, posX).
    local ordered = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni and ni.isVisible then
            ordered[#ordered + 1] = { ni.posY or 0, ni.posX or 0, nodeID }
        end
    end
    table.sort(ordered, function(a, b)
        if a[1] ~= b[1] then return a[1] < b[1] end
        return a[2] < b[2]
    end)

    local data = { order = {}, typeOf = {}, apex = nil, subTreeIDs = {}, subCurrencies = {} }
    for idx, node in ipairs(ordered) do
        local nodeID = node[3]
        data.order[nodeID] = idx

        local costs = C_Traits.GetNodeCost(configID, nodeID)
        local currencyID = costs and costs[1] and costs[1].ID
        data.typeOf[nodeID] = currencyID and C_Traits.GetTraitCurrencyInfo(currencyID) or nil

        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni and (ni.maxRanks or 0) >= 4 then
            data.apex = nodeID
        end
    end

    -- Hero sub-trees: os selection nodes contam como Hero(0).
    if C_ClassTalents and C_ClassTalents.GetHeroTalentSpecsForClassSpec then
        local subTreeIDs = C_ClassTalents.GetHeroTalentSpecsForClassSpec() or {}
        data.subTreeIDs = subTreeIDs
        for _, subTreeID in ipairs(subTreeIDs) do
            local sti = C_Traits.GetSubTreeInfo and C_Traits.GetSubTreeInfo(configID, subTreeID)
            if sti then
                if sti.traitCurrencyID then
                    data.subCurrencies[#data.subCurrencies + 1] = sti.traitCurrencyID
                end
                if sti.subTreeSelectionNodeIDs then
                    for _, nodeID in ipairs(sti.subTreeSelectionNodeIDs) do
                        data.typeOf[nodeID] = NodeType.Hero
                    end
                end
            end
        end
    end

    nodeDataCache[specID] = data
    return data
end

-- Invalida o cache quando a árvore pode ter mudado (subir de nível, etc.).
function Apply.ResetNodeData()
    wipe(nodeDataCache)
end

-------------------------------------------------------------------------------
--  Export do estado atual (para "salvar loadout atual").
-------------------------------------------------------------------------------
-- Retorna a export string nativa do build ativo, ou nil.
function Apply.ExportCurrent()
    local tf = Apply.EnsureTalentsFrame()
    if not tf then return nil end
    if not (ExportUtil and C_ClassTalents and C_Traits) then return nil end

    local configID = C_ClassTalents.GetActiveConfigID()
    local specID   = ns.GetSpecID()
    if not configID or not specID then return nil end

    local ci = C_Traits.GetConfigInfo(configID)
    local treeID = ci and ci.treeIDs and ci.treeIDs[1]
    if not treeID then return nil end

    local treeHash = C_Traits.GetTreeHash(treeID)
    local serVer   = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or 1

    local ok, str = pcall(function()
        local stream = ExportUtil.MakeExportDataStream()
        tf:WriteLoadoutHeader(stream, serVer, specID, treeHash)
        tf:WriteLoadoutContent(stream, configID, treeID)
        return stream:GetExportString()
    end)
    if ok then return str end
    return nil
end

-- /rt save: no modelo 1:1 o loadout pertence a um slot; oriente a usar o painel.
function Apply.ExportCurrentToNew()
    ns.SafePrint(L["use the panel: pick a dungeon/boss, then Save current."])
end

-------------------------------------------------------------------------------
--  Validação do header da import string.
-------------------------------------------------------------------------------
-- Retorna (loadoutContent, treeID, configID) em sucesso, ou (nil, mensagemErro).
local function ParseImport(tf, text)
    if not (ExportUtil and C_ClassTalents and C_Traits) then return nil, L["APIs unavailable."] end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, L["talent config unavailable."] end

    local ci = C_Traits.GetConfigInfo(configID)
    local treeID = ci and ci.treeIDs and ci.treeIDs[1]
    if not treeID then return nil, L["talent tree unavailable."] end

    local stream = ExportUtil.MakeImportDataStream(text)
    if not stream then return nil, L["invalid string."] end

    local headerValid, serVer, specID = tf:ReadLoadoutHeader(stream)
    if not headerValid then return nil, L["invalid loadout string."] end
    local wantVer = C_Traits.GetLoadoutSerializationVersion and C_Traits.GetLoadoutSerializationVersion() or serVer
    if serVer ~= wantVer then return nil, L["loadout from a different version (recreate the string)."] end
    if specID ~= ns.GetSpecID() then return nil, L["this loadout is for another specialization."] end

    local ok, content = pcall(tf.ReadLoadoutContent, tf, stream, treeID)
    if not ok or not content then return nil, L["could not read the loadout content."] end

    return content, treeID, configID
end

-- Só valida e retorna o header (usado no import da UI para saber a specID).
-- Retorna (ok, specID, mensagemErro).
function Apply.ValidateImport(text)
    local tf = Apply.EnsureTalentsFrame()
    if not tf then return false, nil, L["talent interface unavailable."] end
    local stream = ExportUtil and ExportUtil.MakeImportDataStream(text)
    if not stream then return false, nil, L["invalid string."] end
    local headerValid, _, specID = tf:ReadLoadoutHeader(stream)
    if not headerValid then return false, nil, L["invalid loadout string."] end
    return true, specID, nil
end

-------------------------------------------------------------------------------
--  Aplicação nó-a-nó (Class → Spec → Hero). Portado de TLX/import.lua.
-------------------------------------------------------------------------------
local RankNodeTypes = {
    [Enum.TraitNodeType.Single] = true,
    [Enum.TraitNodeType.Tiered] = true,
}

local function RefundNode(configID, nodeInfo)
    if (nodeInfo.ranksPurchased or 0) == 0 then return end
    C_Traits.RefundAllRanks(configID, nodeInfo.ID)
    for _ = 1, (nodeInfo.maxRanks or 0) do
        C_Traits.RefundRank(configID, nodeInfo.ID)
    end
end

local function TryPurchaseNode(configID, entry, apexNodeID, apexRank)
    local nodeID = entry.nodeID
    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
    if not nodeInfo then return false end

    if RankNodeTypes[nodeInfo.type] then
        local target = (nodeID == apexNodeID) and apexRank or entry.ranksPurchased
        if nodeInfo.activeRank == target then return true end
        local hadError = false
        for _ = 1, target do
            if not C_Traits.PurchaseRank(configID, nodeID) then hadError = true end
        end
        if hadError then
            local newRank = C_Traits.GetNodeInfo(configID, nodeID).activeRank
            if newRank ~= target then return false end
        end
    else
        local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID
        if activeEntryID == entry.selectionEntryID then return true end
        if not C_Traits.SetSelection(configID, nodeID, entry.selectionEntryID, false) then
            return false
        end
    end
    return true
end

local function ImportByNodeType(configID, treeID, entries, nodeType, data)
    local apexNodeID = data.apex
    local apexRank = 0

    local targetByNode = {}
    for _, entry in ipairs(entries) do
        if data.typeOf[entry.nodeID] == nodeType then
            targetByNode[entry.nodeID] = entry
            if entry.nodeID == apexNodeID then
                apexRank = apexRank + (entry.ranksPurchased or 0)
            end
        end
    end

    -- Fase Hero: se a hero spec escolhida mudou, reseta a sub-tree por moeda.
    local heroResetted = false
    if nodeType == NodeType.Hero then
        for _, subTreeID in ipairs(data.subTreeIDs) do
            local sti = C_Traits.GetSubTreeInfo(configID, subTreeID)
            if sti and sti.subTreeSelectionNodeIDs then
                for _, nodeID in ipairs(sti.subTreeSelectionNodeIDs) do
                    local ni = C_Traits.GetNodeInfo(configID, nodeID)
                    local activeEntryID = ni and ni.activeEntry and ni.activeEntry.entryID
                    if activeEntryID then
                        local entry = targetByNode[nodeID]
                        if activeEntryID ~= (entry and entry.selectionEntryID) then
                            heroResetted = true
                            C_Traits.RefundRank(configID, nodeID)
                            break
                        end
                    end
                end
            end
            if heroResetted then break end
        end
    end

    if heroResetted then
        for _, currencyID in ipairs(data.subCurrencies) do
            C_Traits.ResetTreeByCurrency(configID, treeID, currencyID)
        end
    else
        -- Refund dos nós deste tipo que precisam mudar.
        for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
            if data.typeOf[nodeID] == nodeType then
                local entry = targetByNode[nodeID]
                local ni = C_Traits.GetNodeInfo(configID, nodeID)
                if ni then
                    if ni.activeRank > (ni.ranksPurchased or 0) then
                        -- concedido; nada a fazer
                    elseif not entry then
                        RefundNode(configID, ni)
                    elseif nodeID == apexNodeID then
                        if apexRank ~= ni.ranksPurchased then RefundNode(configID, ni) end
                    elseif RankNodeTypes[ni.type] then
                        if ni.ranksPurchased ~= entry.ranksPurchased and ni.ranksPurchased > 0 then
                            RefundNode(configID, ni)
                        end
                    else
                        local activeEntryID = ni.activeEntry and ni.activeEntry.entryID
                        if activeEntryID ~= entry.selectionEntryID and entry.selectionEntryID == 0 then
                            RefundNode(configID, ni)
                        end
                    end
                end
            end
        end
    end

    -- Compra dos nós deste tipo.
    for _, entry in ipairs(entries) do
        if data.typeOf[entry.nodeID] == nodeType then
            if not TryPurchaseNode(configID, entry, apexNodeID, apexRank) then
                -- Abaixo do nível máximo pode não ter pontos para tudo — não trata como erro fatal.
                return UnitLevel("player") < GetMaxPlayerLevel()
            end
        end
    end
    return true
end

-------------------------------------------------------------------------------
--  ApplyLoadout — orquestra tudo.
-------------------------------------------------------------------------------
local starterFrame = CreateFrame("Frame")

function Apply.ApplyLoadout(text, onDone)
    if not text then return end

    -- Guardas de contexto
    if InCombatLockdown() then
        ns.Warn(L["cannot change talents in combat."])
        return
    end
    if C_ClassTalents.CanChangeTalents then
        local can = C_ClassTalents.CanChangeTalents()
        if not can then
            ns.Warn(L["cannot change talents here (instance/combat). Change them manually."])
            return
        end
    end

    local tf = Apply.EnsureTalentsFrame()
    if not tf then return end

    -- Starter build ativo: desativar e reagendar (a API assenta 1 frame depois).
    if C_ClassTalents.GetStarterBuildActive and C_ClassTalents.GetStarterBuildActive() then
        local configID = C_ClassTalents.GetActiveConfigID()
        starterFrame:RegisterEvent("TRAIT_CONFIG_UPDATED")
        starterFrame:SetScript("OnEvent", function(_, evt, updatedID)
            if evt == "TRAIT_CONFIG_UPDATED" and updatedID == configID then
                starterFrame:UnregisterAllEvents()
                Apply.ApplyLoadout(text, onDone)
            end
        end)
        C_ClassTalents.SetStarterBuildActive(false)
        return
    end

    local content, treeIDorErr, configID = ParseImport(tf, text)
    if not content then
        ns.Warn(treeIDorErr or "falha ao ler o loadout.")
        return
    end
    local treeID = treeIDorErr
    local specID = ns.GetSpecID()

    -- Entries ordenados por posição do nó.
    local data = BuildNodeData(specID, configID, treeID)
    if not data then ns.Warn(L["tree data unavailable."]); return end

    local entries = tf:ConvertToImportLoadoutEntryInfo(configID, treeID, content)
    if not entries then ns.Warn(L["failed to convert the loadout."]); return end
    table.sort(entries, function(a, b)
        return (data.order[a.nodeID] or 0) < (data.order[b.nodeID] or 0)
    end)

    -- Evita flood de refresh do reminder durante a compra.
    if ns.Reminder and ns.Reminder.SetApplying then ns.Reminder.SetApplying(true) end

    local ok = pcall(function()
        local a = ImportByNodeType(configID, treeID, entries, NodeType.Class, data)
        local b = a and ImportByNodeType(configID, treeID, entries, NodeType.Spec, data)
        local c = b and ImportByNodeType(configID, treeID, entries, NodeType.Hero, data)
        return c
    end)

    if not ok then
        if C_Traits.RollbackConfig then C_Traits.RollbackConfig(configID) end
        if ns.Reminder and ns.Reminder.SetApplying then ns.Reminder.SetApplying(false) end
        ns.Warn(L["error applying the loadout; changes reverted."])
        return
    end

    -- Commit SEM taint.
    local committed = C_Traits.CommitConfig(configID)
    if ns.Reminder and ns.Reminder.SetApplying then ns.Reminder.SetApplying(false) end

    if committed == false then
        ns.Warn(L["could not confirm the talent change."])
    end

    -- TRAIT_CONFIG_UPDATED chega async; agenda um refresh e chama onDone.
    ns.After(1.0, function()
        if type(onDone) == "function" then onDone() end
        if ns.Reminder and ns.Reminder.RequestRefresh then ns.Reminder.RequestRefresh() end
    end)
end

-------------------------------------------------------------------------------
--  Init: invalida o cache de nós ao subir de nível.
-------------------------------------------------------------------------------
ns.RegisterInit(function()
    ns.On("PLAYER_LEVEL_UP", Apply.ResetNodeData)
    ns.On("PLAYER_SPECIALIZATION_CHANGED", Apply.ResetNodeData)
end)
