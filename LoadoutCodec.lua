-------------------------------------------------------------------------------
--  RemindTalents / LoadoutCodec.lua
--  Decodifica a export string de talentos (formato ImportExport da Blizzard) e
--  compara nó-a-nó contra a config viva. Portado do EllesmereUI
--  (EllesmereUIABR_TalentReminders.lua). Só depende de C_Traits — não precisa
--  do TalentsFrame. Fail-safe: quando não consegue decodificar, considera
--  "match" (não reclama), evitando lembretes falsos.
-------------------------------------------------------------------------------
local ADDON, ns = ...
local floor = math.floor

local Codec = {}
ns.Codec = Codec

-- charset base64, empacotamento LSB-first de 6 bits.
-- Header = version(8) + specID(16) + treeHash(128) = 152 bits, depois conteúdo
-- por nó na ordem de C_Traits.GetTreeNodes. Por nó:
--   isNodeSelected(1); se selecionado: isNodePurchased(1); se comprado:
--   isPartiallyRanked(1)[+ranks(6)], isChoiceNode(1)[+choiceIndex(2)].
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX
local SELECTION_START = 153  -- 1-indexed: primeiro bit de conteúdo, após 152 bits de header

local function DecodeLoadoutBits(str)
    if type(str) ~= "string" or str == "" then return nil end
    if not B64IDX then
        B64IDX = {}
        for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end
    end
    local bits = {}
    for i = 1, #str do
        local v = B64IDX[str:sub(i, i)]
        if v == nil then return nil end          -- char desconhecido → desiste
        for _ = 1, 6 do
            bits[#bits + 1] = v % 2
            v = floor(v / 2)
        end
    end
    return bits
end
Codec.DecodeLoadoutBits = DecodeLoadoutBits

-- Lê os campos de um nó a partir do cursor `cur`. Retorna
-- newCursor, selected(bool), purchased(bool), choiceIndex(0-based ou nil).
local function ReadLoadoutNode(bits, cur)
    if bits[cur] == nil then return cur, false, false, nil end
    local selected = bits[cur] == 1; cur = cur + 1
    if not selected then return cur, false, false, nil end
    local purchased = bits[cur] == 1; cur = cur + 1
    if not purchased then return cur, true, false, nil end   -- concedido, sem mais bits
    local partial = bits[cur] == 1; cur = cur + 1
    if partial then cur = cur + 6 end                        -- pula ranksPurchased (6 bits)
    local isChoice = bits[cur] == 1; cur = cur + 1
    local choiceIdx
    if isChoice then
        choiceIdx = (bits[cur] or 0) + (bits[cur + 1] or 0) * 2
        cur = cur + 2
    end
    return cur, true, true, choiceIdx
end
Codec.ReadLoadoutNode = ReadLoadoutNode

-- A config ativa corresponde à export string dada? Compara o estado selecionado
-- + entry escolhida de cada nó contra a config viva, pulando nós auto-concedidos
-- (idênticos para toda build da spec). Retorna (bool, reason).
local function ActiveMatchesLoadout(storedStr, treeID, configID)
    local bits = DecodeLoadoutBits(storedStr)
    if not bits then return true, "undecodable" end          -- não dá pra saber → não reclama
    local nodes = treeID and C_Traits and C_Traits.GetTreeNodes and C_Traits.GetTreeNodes(treeID)
    if not nodes then return true, "notree" end
    local cur = SELECTION_START
    for _, nodeID in ipairs(nodes) do
        local selected, choiceIdx
        cur, selected, _, choiceIdx = ReadLoadoutNode(bits, cur)
        if cur > #bits + 2 then return true, "desync" end    -- deriva de formato → não reclama
        local ni = C_Traits.GetNodeInfo(configID, nodeID)
        if ni then
            local liveRank = ni.activeRank or 0
            local liveGranted = liveRank > (ni.ranksPurchased or 0)
            if not liveGranted then
                -- compara estado selecionado
                if selected ~= (liveRank > 0) then
                    return false, "node:" .. tostring(nodeID)
                end
                -- compara entry escolhida em choice nodes
                if selected and choiceIdx ~= nil then
                    local wantEntry = ni.entryIDs and ni.entryIDs[choiceIdx + 1]
                    local liveEntry = ni.activeEntry and ni.activeEntry.entryID
                    if wantEntry and liveEntry and wantEntry ~= liveEntry then
                        return false, "choice:" .. tostring(nodeID)
                    end
                end
            end
        end
    end
    return true, "match"
end

-- Retorna true SÓ quando há correspondência real (reason == "match"), ou seja,
-- este loadout é exatamente o build ativo. Diferente de ActiveMatchesLoadout,
-- que retorna true também nos casos indecidíveis (fail-safe do lembrete).
function Codec.IsActive(text)
    if not text then return false end
    -- Enquanto houver mudanças não comitadas (cast de troca em andamento), não
    -- considera ativo — só marca depois que a troca assenta (como o LoadoutEx).
    if C_Traits and C_Traits.ConfigHasStagedChanges and C_ClassTalents and C_ClassTalents.GetActiveConfigID then
        local cfg = C_ClassTalents.GetActiveConfigID()
        if cfg and C_Traits.ConfigHasStagedChanges(cfg) then return false end
    end
    local ok, reason = Codec.ActiveMatchesLoadout(text)
    return ok and reason == "match"
end

-- Wrapper conveniente: resolve configID/treeID vivos da spec atual e compara.
-- Retorna true se a config ativa corresponde ao loadout (ou se não dá pra decidir).
function Codec.ActiveMatchesLoadout(storedStr, treeID, configID)
    if not (C_ClassTalents and C_Traits) then return true, "noapi" end
    configID = configID or (C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID())
    if not configID then return true, "nocfg" end
    if not treeID and C_Traits.GetConfigInfo then
        local ci = C_Traits.GetConfigInfo(configID)
        treeID = ci and ci.treeIDs and ci.treeIDs[1]
    end
    return ActiveMatchesLoadout(storedStr, treeID, configID)
end
