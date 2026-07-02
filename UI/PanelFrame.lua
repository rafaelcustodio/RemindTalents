-------------------------------------------------------------------------------
--  RemindTalents / UI/PanelFrame.lua
--  Painel mestre-detalhe ancorado à árvore de talentos:
--   MESTRE  = catálogo da season (masmorras + bosses + Antigos), com ícones.
--   DETALHE = a LISTA de loadouts do slot selecionado (vários por dungeon/boss).
--  Importar / Salvar atual / Editar usam o mesmo diálogo (nome + ícone + código).
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI
local L = ns.L

local panel, master, detailList
local selectedKey, selectedSlot
local PANEL_WIDTH = 320

-- Título de um frame Basic/Portrait (cobre as duas formas).
function UI.SetTitle(frame, text)
    local t = frame.TitleText or (frame.TitleContainer and frame.TitleContainer.TitleText)
    if t then t:SetText(text) end
end

-- Fundo preto sólido no interior de um frame (abaixo da barra de título).
function UI.SolidBlack(frame)
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetColorTexture(0, 0, 0, 1)
    bg:SetPoint("TOPLEFT", 7, -22)
    bg:SetPoint("BOTTOMRIGHT", -6, 6)
    return bg
end

local function trim(s) return (s or ""):gsub("^%s+", ""):gsub("%s+$", "") end

-------------------------------------------------------------------------------
--  Widget de lista reutilizável (pool de linhas + rolagem por roda)
-------------------------------------------------------------------------------
-- opts = { rowHeight, width, pool (máx. de linhas criadas), build(row), fill(row,data,idx) }
-- As linhas visíveis são calculadas pela ALTURA do frame (que pode ser ancorada
-- dinamicamente). Excesso é recortado (SetClipsChildren).
function UI.CreateList(parent, opts)
    local rowHeight = opts.rowHeight or 34
    local pool      = opts.pool or opts.visible or 10
    local width     = opts.width or 280

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(width, rowHeight * pool)
    frame:SetClipsChildren(true)
    frame.rows = {}
    frame.data = {}
    frame.offset = 0

    for i = 1, pool do
        local row = CreateFrame("Button", nil, frame)
        row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(i - 1) * rowHeight)
        row:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
        row:SetHeight(rowHeight)
        opts.build(row)
        frame.rows[i] = row
    end

    local function VisibleCount()
        local h = frame:GetHeight() or 0
        local v = math.floor(h / rowHeight)
        if v < 1 then v = 1 end
        if v > #frame.rows then v = #frame.rows end
        return v
    end

    local function Render()
        local vis = VisibleCount()
        local total = #frame.data
        local maxOffset = math.max(0, total - vis)
        if frame.offset > maxOffset then frame.offset = maxOffset end
        if frame.offset < 0 then frame.offset = 0 end
        for i = 1, #frame.rows do
            local row = frame.rows[i]
            local idx = frame.offset + i
            local data = frame.data[idx]
            if i <= vis and data then
                opts.fill(row, data, idx)
                row:Show()
            else
                row:Hide()
            end
        end
    end
    frame.Render = Render

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        frame.offset = frame.offset - delta
        Render()
    end)
    frame:SetScript("OnSizeChanged", function() Render() end)

    function frame:Refresh(data)
        self.data = data or {}
        Render()
    end
    return frame
end

-------------------------------------------------------------------------------
--  Janela de talentos arrastável
-------------------------------------------------------------------------------
local madeMovable = false
local function MakeTalentsMovable()
    if madeMovable then return end
    local f = _G.PlayerSpellsFrame
    if not f then return end
    local handle = f.TitleContainer
    if not handle then return end
    madeMovable = true
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    handle:EnableMouse(true)
    handle:RegisterForDrag("LeftButton")
    handle:HookScript("OnDragStart", function() if not InCombatLockdown() then f:StartMoving() end end)
    handle:HookScript("OnDragStop", function() f:StopMovingOrSizing() end)
end

-------------------------------------------------------------------------------
--  Diálogo unificado: nome + ícone + código  (importar / salvar / editar)
--  OpenLoadoutEditor({title,name,icon,text}, onSave(name, icon, text))
-------------------------------------------------------------------------------
local editor, editorIcon, editorOnSave, editorDifficulty
local function OpenLoadoutEditor(opts, onSave)
    opts = opts or {}
    editorOnSave = onSave
    editorIcon = opts.icon or ns.GetSpecIcon() or 134400
    editorDifficulty = opts.difficulty or "all"

    if not editor then
        local f = CreateFrame("Frame", "RemindTalentsEditor", UIParent, "BasicFrameTemplateWithInset")
        f:SetSize(470, 400)
        f:SetPoint("CENTER")
        f:SetFrameStrata("DIALOG")
        f:SetMovable(true); f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        UI.SolidBlack(f)
        tinsert(UISpecialFrames, "RemindTalentsEditor")

        local nameLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        nameLabel:SetPoint("TOPLEFT", 18, -38)
        nameLabel:SetText(L["Name:"])

        local nameBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
        nameBox:SetSize(300, 26)
        nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        nameBox:SetAutoFocus(false)
        nameBox:SetFontObject("GameFontHighlight")
        f.nameBox = nameBox

        -- Botão de ícone (com preview) → abre o IconPicker
        local iconBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        iconBtn:SetSize(40, 40)
        iconBtn:SetPoint("TOPRIGHT", -16, -34)
        local iconTex = iconBtn:CreateTexture(nil, "ARTWORK")
        iconTex:SetPoint("TOPLEFT", 2, -2); iconTex:SetPoint("BOTTOMRIGHT", -2, 2)
        iconTex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        f.iconTex = iconTex
        iconBtn:SetScript("OnClick", function()
            if UI.OpenIconPicker then
                UI.OpenIconPicker(editorIcon, function(fileID)
                    editorIcon = fileID
                    f.iconTex:SetTexture(fileID)
                end)
            end
        end)
        local iconHint = f:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
        iconHint:SetPoint("RIGHT", iconBtn, "LEFT", -6, 0)
        iconHint:SetText(L["Icon"])

        -- Linha de dificuldade (só aparece para bosses/raid)
        local diffLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        diffLabel:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 0, -16)
        diffLabel:SetText(L["Difficulty:"])
        f.diffLabel = diffLabel

        f.diffRadios = {}
        f.UpdateDiffChecks = function()
            for _, rb in ipairs(f.diffRadios) do rb:SetChecked(rb.value == editorDifficulty) end
        end
        local diffs = { { "all", L["All"] }, { "normal", L["Normal"] },
                        { "heroic", L["Heroic"] }, { "mythic", L["Mythic"] } }
        local prevLabel
        for i, dd in ipairs(diffs) do
            local rb = CreateFrame("CheckButton", nil, f, "UIRadioButtonTemplate")
            rb.value = dd[1]
            if i == 1 then rb:SetPoint("LEFT", diffLabel, "RIGHT", 8, 0)
            else rb:SetPoint("LEFT", prevLabel, "RIGHT", 10, 0) end
            local lbl = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
            lbl:SetPoint("LEFT", rb, "RIGHT", 2, 0); lbl:SetText(dd[2])
            rb.label = lbl
            rb:SetScript("OnClick", function() editorDifficulty = rb.value; f.UpdateDiffChecks() end)
            f.diffRadios[i] = rb
            prevLabel = lbl
        end

        f.SetDiffShown = function(shown)
            f.diffLabel:SetShown(shown)
            for _, rb in ipairs(f.diffRadios) do
                rb:SetShown(shown); rb.label:SetShown(shown)
            end
        end

        local codeLabel = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        codeLabel:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -108)
        codeLabel:SetText(L["Paste the talent code (empty = use current build):"])

        local scroll = CreateFrame("ScrollFrame", nil, f, "InputScrollFrameTemplate")
        scroll:SetSize(426, 170)
        scroll:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 4, -6)
        scroll.EditBox:SetWidth(406)
        scroll.EditBox:SetAutoFocus(false)
        scroll.EditBox:SetFontObject("GameFontHighlight")
        if scroll.CharCount then scroll.CharCount:Hide() end
        f.codeBox = scroll.EditBox

        local save = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        save:SetSize(110, 24)
        save:SetPoint("BOTTOMRIGHT", -16, 14)
        save:SetText(L["Save"])
        save:SetScript("OnClick", function()
            local name = trim(f.nameBox:GetText())
            if name == "" then ns.Warn(L["a name is required."]); return end
            local text = (f.codeBox:GetText() or ""):gsub("%s+$", "")
            if text == "" then
                -- Código vazio = capturar o build atual
                text = ns.Apply.ExportCurrent()
                if not text then ns.Warn(L["could not export the current build."]); return end
            end
            local ok, specID, err = ns.Apply.ValidateImport(text)
            if not ok then ns.Warn(err or L["invalid code."]); return end
            if specID ~= ns.GetSpecID() then
                ns.Warn(L["this loadout is for another specialization."]); return
            end
            f:Hide()
            if editorOnSave then editorOnSave(name, editorIcon, text, editorDifficulty) end
        end)

        local cancel = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        cancel:SetSize(110, 24)
        cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)
        cancel:SetText(L["Cancel"])
        cancel:SetScript("OnClick", function() f:Hide() end)

        editor = f
    end

    UI.SetTitle(editor, opts.title or L["Loadout"])
    editor.nameBox:SetText(opts.name or "")
    editor.codeBox:SetText(opts.text or "")
    editor.iconTex:SetTexture(editorIcon)
    editor.SetDiffShown(opts.isBoss and true or false)
    editor.UpdateDiffChecks()
    editor:Show()
    editor.nameBox:SetFocus()
end

-------------------------------------------------------------------------------
--  Catálogo (mestre)
-------------------------------------------------------------------------------
local function BuildCatalog()
    local items = {}
    local function header(label) items[#items + 1] = { kind = "header", label = label } end

    local dungeons = ns.Zones.GetSeasonDungeons()
    if #dungeons > 0 then
        header(L["Dungeons"])
        for _, d in ipairs(dungeons) do items[#items + 1] = d end
    end

    for _, raid in ipairs(ns.Zones.GetSeasonRaids()) do
        header((L["Raid: %s"]):format(raid.name))
        for _, b in ipairs(raid.bosses) do items[#items + 1] = b end
    end

    local olds = {}
    for _, e in pairs(ns.Storage.GetAllEntries()) do
        local s = e.slot
        if s and not ns.Zones.IsSlotCurrent(s) then
            olds[#olds + 1] = {
                kind = s.kind or "old", name = s.name or "?", encounterID = s.encounterID,
                challengeMapID = s.challengeMapID, mapID = s.mapID, _old = true,
            }
        end
    end
    if #olds > 0 then
        header(L["Old"])
        for _, o in ipairs(olds) do items[#items + 1] = o end
    end

    if #items == 0 then
        header(L["No season data yet. Open the Adventure Guide once, then /reload."])
    end
    return items
end

-------------------------------------------------------------------------------
--  Ações
-------------------------------------------------------------------------------
local function SlotIsBoss()
    return selectedSlot and selectedSlot.kind == "boss" or false
end

local function DoImport()
    if not selectedSlot then return end
    OpenLoadoutEditor({ title = L["Import loadout"], name = selectedSlot.name, isBoss = SlotIsBoss() },
        function(name, icon, text, difficulty)
            local lo = ns.Storage.AddLoadout(selectedSlot,
                { name = name, icon = icon, text = text, difficulty = difficulty })
            if lo then ns.SafePrint((L["loadout '%s' imported."]):format(lo.name)) end
            UI.RefreshList()
        end)
end

local function DoSaveCurrent()
    if not selectedSlot then return end
    local text = ns.Apply.ExportCurrent()
    if not text then ns.Warn(L["could not export the current build."]); return end
    OpenLoadoutEditor({ title = L["Save current loadout"], name = selectedSlot.name,
                        icon = ns.GetSpecIcon(), text = text, isBoss = SlotIsBoss() },
        function(name, icon, t, difficulty)
            local lo = ns.Storage.AddLoadout(selectedSlot,
                { name = name, icon = icon, text = t, difficulty = difficulty })
            if lo then ns.SafePrint((L["loadout '%s' saved."]):format(lo.name)) end
            UI.RefreshList()
        end)
end

local function DoEdit(lo)
    OpenLoadoutEditor({ title = L["Edit"], name = lo.name, icon = lo.icon, text = lo.text,
                        difficulty = lo.difficulty, isBoss = SlotIsBoss() },
        function(name, icon, text, difficulty)
            ns.Storage.UpdateLoadout(selectedKey, lo.id,
                { name = name, icon = icon, text = text, difficulty = difficulty })
            ns.SafePrint((L["loadout '%s' updated."]):format(name))
            UI.RefreshList()
        end)
end

local function DoDuplicate(lo)
    if not selectedSlot then return end
    ns.Storage.AddLoadout(selectedSlot, {
        name = (lo.name or "?") .. L[" (copy)"], icon = lo.icon,
        text = lo.text, difficulty = lo.difficulty,
    })
    UI.RefreshList()
end

-- Move o loadout do slot atual para outro slot (dungeon/boss).
local function DoMove(lo, targetSlot)
    if not (lo and targetSlot) then return end
    ns.Storage.AddLoadout(targetSlot, {
        name = lo.name, icon = lo.icon, text = lo.text, difficulty = lo.difficulty,
    })
    ns.Storage.DeleteLoadout(selectedKey, lo.id)
    UI.RefreshList()
end

-- Menu de contexto de um loadout (Editar / Duplicar / Mover / Excluir).
local function OpenLoadoutMenu(anchor, lo)
    if not (MenuUtil and MenuUtil.CreateContextMenu) then
        DoEdit(lo)   -- fallback simples
        return
    end
    MenuUtil.CreateContextMenu(anchor, function(_, root)
        root:CreateTitle(lo.name or "?")
        root:CreateButton(L["Edit"], function() DoEdit(lo) end)
        root:CreateButton(L["Duplicate"], function() DoDuplicate(lo) end)

        local move = root:CreateButton(L["Move to..."])
        local dungeons = ns.Zones.GetSeasonDungeons()
        if #dungeons > 0 then
            local ds = move:CreateButton(L["Dungeons"])
            for _, d in ipairs(dungeons) do
                ds:CreateButton(d.name, function() DoMove(lo, d) end)
            end
        end
        for _, raid in ipairs(ns.Zones.GetSeasonRaids()) do
            local rs = move:CreateButton(raid.name)
            for _, b in ipairs(raid.bosses) do
                rs:CreateButton(b.name, function() DoMove(lo, b) end)
            end
        end

        root:CreateDivider()
        root:CreateButton(L["Delete"], function()
            ns.Storage.DeleteLoadout(selectedKey, lo.id); UI.RefreshList()
        end)
    end)
end

-------------------------------------------------------------------------------
--  Linhas do detalhe (loadouts do slot)
-------------------------------------------------------------------------------
local function BuildLoadoutRow(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, 0.04)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWidth(140)

    -- "⋯" abre o menu (Editar / Duplicar / Mover / Excluir)
    row.more = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.more:SetSize(26, 22); row.more:SetPoint("RIGHT", -4, 0); row.more:SetText("...")
    row.apply = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.apply:SetSize(58, 22); row.apply:SetPoint("RIGHT", row.more, "LEFT", -3, 0); row.apply:SetText(L["Apply"])

    -- Marca de "ativo" (ocupa o lugar do Apply quando este é o build ativo)
    row.activeMark = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.activeMark:SetPoint("RIGHT", row.more, "LEFT", -6, 0)
    row.activeMark:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t |cff33ff99" .. L["Active"] .. "|r")
    row.activeMark:Hide()

    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local hl = row:GetHighlightTexture()
    if hl then hl:SetColorTexture(1, 1, 1, 0.06) end
end

local DIFF_ABBR = { normal = "N", heroic = "H", mythic = "M", lfr = "LFR" }
local function DiffTag(d)
    if not d or d == "all" then return "" end
    local ab = DIFF_ABBR[d]
    return ab and (" |cff88ccff[" .. ab .. "]|r") or ""
end

local function FillLoadoutRow(row, lo)
    row.icon:SetTexture(lo.icon or ns.GetSpecIcon() or 134400)
    row.name:SetText((lo.name or "?") .. DiffTag(lo.difficulty))

    -- Este loadout é o build ativo? Se sim, esconde "Aplicar" e mostra a marca.
    local active = ns.Codec.IsActive(lo.text)
    row.apply:SetShown(not active)
    row.activeMark:SetShown(active)
    if active then row.name:SetTextColor(0.2, 1, 0.4) else row.name:SetTextColor(1, 1, 1) end

    row.apply:SetScript("OnClick", function() ns.Apply.ApplyLoadout(lo.text, UI.RefreshList) end)
    row.more:SetScript("OnClick", function(self) OpenLoadoutMenu(self, lo) end)
end

-------------------------------------------------------------------------------
--  Detalhe
-------------------------------------------------------------------------------
local function UpdateDetail()
    if not panel then return end
    local d = panel.detail
    if not selectedSlot then
        d.title:SetText(L["Select a dungeon or boss"])
        d.icon:Hide()
        detailList:Refresh({})
        d.importBtn:Hide(); d.saveBtn:Hide()
        d.empty:Hide()
        return
    end

    d.icon:Show(); d.icon:SetTexture(selectedSlot.icon or 134400)
    d.title:SetText((L["Loadouts for: %s"]):format(selectedSlot.name or "?"))
    d.importBtn:Show(); d.saveBtn:Show()

    local list = ns.Storage.GetLoadouts(selectedKey)
    detailList:Refresh(list)
    d.empty:SetShown(#list == 0)
end

function UI.RefreshList()
    if not panel or not master then return end
    master:Refresh(BuildCatalog())
    UpdateDetail()
end

-------------------------------------------------------------------------------
--  Linhas do mestre
-------------------------------------------------------------------------------
local function BuildRow(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND"); row.bg:SetAllPoints()
    row.sel = row:CreateTexture(nil, "BORDER"); row.sel:SetAllPoints()
    row.sel:SetColorTexture(0.1, 0.6, 1, 0.25); row.sel:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(32, 32); row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightMedium")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 0); row.name:SetJustifyH("LEFT"); row.name:SetWidth(168)

    row.mark = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.mark:SetPoint("RIGHT", -6, 0); row.mark:SetJustifyH("RIGHT"); row.mark:SetWidth(36)

    row:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
    local hl = row:GetHighlightTexture()
    if hl then hl:SetColorTexture(1, 1, 1, 0.08) end

    row:SetScript("OnClick", function(self)
        if self.entry and self.entry.kind ~= "header" then
            selectedSlot = self.entry
            selectedKey = ns.Storage.SlotKey(self.entry)
            UI.RefreshList()
        end
    end)
end

local function FillRow(row, entry)
    row.entry = entry
    if entry.kind == "header" then
        row.bg:SetColorTexture(1, 1, 1, 0); row.sel:Hide(); row.icon:Hide(); row.mark:SetText("")
        row.name:ClearAllPoints(); row.name:SetPoint("LEFT", 6, 0)
        row.name:SetText("|cffffd200" .. (entry.label or "") .. "|r")
        row:EnableMouse(false)
        return
    end
    row:EnableMouse(true)
    row.bg:SetColorTexture(1, 1, 1, 0.04)
    row.icon:Show(); row.name:ClearAllPoints(); row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.icon:SetTexture(entry.icon or 134400)
    row.name:SetText((entry.name or "?") .. (entry._old and L[" (old)"] or ""))

    local key = ns.Storage.SlotKey(entry)
    local e = ns.Storage.GetSlotEntry(key)
    local n = e and e.loadouts and #e.loadouts or 0
    local activeHere = false
    if e and e.loadouts then
        for _, lo in ipairs(e.loadouts) do
            if ns.Codec.IsActive(lo.text) then activeHere = true; break end
        end
    end
    if activeHere then
        row.mark:SetText("|TInterface\\RaidFrame\\ReadyCheck-Ready:0:0|t")
    else
        row.mark:SetText(n > 0 and ("|cff33ff99" .. n .. "|r") or "—")
    end
    row.sel:SetShown(selectedKey == key)
end

-------------------------------------------------------------------------------
--  Construção do painel
-------------------------------------------------------------------------------
local function BuildPanel(talentsFrame)
    if panel then return end

    panel = CreateFrame("Frame", "RemindTalentsPanel", PlayerSpellsFrame, "BasicFrameTemplateWithInset")
    panel:SetWidth(PANEL_WIDTH)
    -- Altura acompanha a janela de talentos (topo e base ancorados nela).
    panel:SetPoint("TOPLEFT", talentsFrame, "TOPRIGHT", 8, 0)
    panel:SetPoint("BOTTOMLEFT", talentsFrame, "BOTTOMRIGHT", 8, 0)
    panel:SetFrameStrata("HIGH")
    UI.SetTitle(panel, "RemindTalents")
    UI.SolidBlack(panel)

    -- DETALHE (fixo na base, menor)
    local detailBox = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    detailBox:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 12, 12)
    detailBox:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -12, 12)
    detailBox:SetHeight(176)
    detailBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    detailBox:SetBackdropColor(0, 0, 0, 1)
    detailBox:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- MESTRE: catálogo (preenche o espaço entre a spec e o detalhe)
    master = UI.CreateList(panel, { rowHeight = 38, pool = 22, width = 288, build = BuildRow, fill = FillRow })
    master:SetPoint("TOPLEFT", 12, -34)
    master:SetPoint("TOPRIGHT", -12, -34)
    master:SetPoint("BOTTOM", detailBox, "TOP", 0, 8)

    local detail = {}
    panel.detail = detail

    detail.icon = detailBox:CreateTexture(nil, "ARTWORK")
    detail.icon:SetSize(24, 24); detail.icon:SetPoint("TOPLEFT", 8, -8)
    detail.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93); detail.icon:Hide()

    detail.title = detailBox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    detail.title:SetPoint("TOPLEFT", 34, -9); detail.title:SetJustifyH("LEFT"); detail.title:SetWidth(248)
    detail.title:SetText(L["Select a dungeon or boss"])

    detailList = UI.CreateList(detailBox, { rowHeight = 26, pool = 8, width = 268, build = BuildLoadoutRow, fill = FillLoadoutRow })
    detailList:SetPoint("TOPLEFT", 8, -38)
    detailList:SetPoint("BOTTOMRIGHT", detailBox, "BOTTOMRIGHT", -8, 38)

    detail.empty = detailBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    detail.empty:SetPoint("TOPLEFT", 10, -40)
    detail.empty:SetText(L["No loadouts here yet. Use Import or Save current."])
    detail.empty:Hide()

    detail.importBtn = CreateFrame("Button", nil, detailBox, "UIPanelButtonTemplate")
    detail.importBtn:SetSize(120, 24); detail.importBtn:SetPoint("BOTTOMLEFT", 8, 8)
    detail.importBtn:SetText(L["Import code"]); detail.importBtn:SetScript("OnClick", DoImport)
    detail.importBtn:Hide()

    detail.saveBtn = CreateFrame("Button", nil, detailBox, "UIPanelButtonTemplate")
    detail.saveBtn:SetSize(140, 24); detail.saveBtn:SetPoint("LEFT", detail.importBtn, "RIGHT", 6, 0)
    detail.saveBtn:SetText(L["Save current loadout"]); detail.saveBtn:SetScript("OnClick", DoSaveCurrent)
    detail.saveBtn:Hide()

    -- Segue a visibilidade da árvore de talentos.
    panel:SetShown(talentsFrame:IsShown())
    hooksecurefunc(talentsFrame, "SetShown", function(_, shown)
        panel:SetShown(shown); if shown then UI.RefreshList() end
    end)
    hooksecurefunc(talentsFrame, "Show", function() panel:Show(); UI.RefreshList() end)
    hooksecurefunc(talentsFrame, "Hide", function() panel:Hide() end)

    MakeTalentsMovable()
    UI.RefreshList()
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
local function TryBuild()
    local tf = (ns.Apply.GetTalentsFrame and ns.Apply.GetTalentsFrame())
        or (PlayerSpellsFrame and PlayerSpellsFrame.TalentsFrame)
    if tf then BuildPanel(tf); return true end
    return false
end

ns.RegisterInit(function()
    if C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_PlayerSpells") then
        TryBuild()
    else
        ns.On("ADDON_LOADED", function(_, addonName)
            if addonName == "Blizzard_PlayerSpells" then TryBuild() end
        end)
    end
    ns.On("PLAYER_SPECIALIZATION_CHANGED", function()
        selectedKey, selectedSlot = nil, nil
        ns.After(1.0, function() if panel and panel:IsShown() then UI.RefreshList() end end)
    end)
    -- Ao trocar talentos, atualiza as marcas de "ativo" enquanto o painel estiver aberto.
    local function refreshIfShown()
        if panel and panel:IsShown() then ns.After(0.3, UI.RefreshList) end
    end
    ns.On("TRAIT_CONFIG_UPDATED", refreshIfShown)
    ns.On("PLAYER_TALENT_UPDATE", refreshIfShown)
end)
