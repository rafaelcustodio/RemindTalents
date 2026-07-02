-------------------------------------------------------------------------------
--  RemindTalents / UI/IconPicker.lua
--  Seletor de ícone (grade + rolagem por roda) com BUSCA.
--  A busca casa pelo nome das magias do jogador (spellbook) → ícone, pois os
--  fileIDs de ícone do jogo não têm nome pesquisável. Sem busca, mostra a grade
--  completa de ícones (GetMacroIcons/GetMacroItemIcons).
--  API: ns.UI.OpenIconPicker(currentIcon, onPick)  →  onPick(fileID).
-------------------------------------------------------------------------------
local ADDON, ns = ...

ns.UI = ns.UI or {}
local UI = ns.UI
local L = ns.L

local COLS, ROWS = 10, 8
local ICON = 30
local GAP = 2

local picker, grid, searchBox
local onPickCb

-------------------------------------------------------------------------------
--  Fontes de ícones
-------------------------------------------------------------------------------
local iconList
local function BuildIcons()
    if iconList then return iconList end
    iconList = {}
    local seen = {}
    local function add(v)
        if v and not seen[v] then seen[v] = true; iconList[#iconList + 1] = v end
    end
    add(ns.GetSpecIcon())
    local t = {}
    if GetMacroIcons then GetMacroIcons(t) end
    if GetMacroItemIcons then GetMacroItemIcons(t) end
    for _, v in ipairs(t) do add(v) end
    return iconList
end

-- Índice nome→ícone das magias do jogador (para a busca). Guardado sob pcall.
local nameIndex
local function BuildNameIndex()
    if nameIndex then return nameIndex end
    nameIndex = {}
    pcall(function()
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
        if not (C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines and bank) then return end
        local numLines = C_SpellBook.GetNumSpellBookSkillLines() or 0
        for l = 1, numLines do
            local info = C_SpellBook.GetSpellBookSkillLineInfo(l)
            if info then
                local offset = info.itemIndexOffset or 0
                local count = info.numSpellBookItems or 0
                for s = offset + 1, offset + count do
                    local name = C_SpellBook.GetSpellBookItemName
                        and C_SpellBook.GetSpellBookItemName(s, bank)
                    local tex = C_SpellBook.GetSpellBookItemTexture
                        and C_SpellBook.GetSpellBookItemTexture(s, bank)
                    if name and tex then
                        nameIndex[#nameIndex + 1] = { name = name:lower(), icon = tex }
                    end
                end
            end
        end
    end)
    return nameIndex
end

-- Dados exibidos. Critério no MESMO campo:
--   • busca vazia            → grade completa
--   • só dígitos             → filtra por ID do ícone (fileID, substring)
--   • com letras             → filtra por nome (magias do jogador → ícone)
local function CurrentData()
    local q = (searchBox and searchBox:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if q == "" then return BuildIcons() end

    if q:match("^%d+$") then
        local out = {}
        for _, id in ipairs(BuildIcons()) do
            if type(id) == "number" and tostring(id):find(q, 1, true) then
                out[#out + 1] = id
            end
        end
        return out
    end

    local out, seen = {}, {}
    for _, e in ipairs(BuildNameIndex()) do
        if e.name:find(q, 1, true) and e.icon and not seen[e.icon] then
            seen[e.icon] = true
            out[#out + 1] = e.icon
        end
    end
    return out
end

-------------------------------------------------------------------------------
--  Grade
-------------------------------------------------------------------------------
local function Render()
    if not grid then return end
    local data = CurrentData()
    local total = #data
    local totalRows = math.ceil(total / COLS)
    local maxOffset = math.max(0, totalRows - ROWS)
    if grid.offset > maxOffset then grid.offset = maxOffset end
    if grid.offset < 0 then grid.offset = 0 end
    for i = 1, COLS * ROWS do
        local btn = grid.buttons[i]
        local idx = grid.offset * COLS + i
        local tex = data[idx]
        if tex then
            btn.tex:SetTexture(tex)
            btn.fileID = tex
            btn.selected:SetShown(grid.currentIcon and grid.currentIcon == tex)
            btn:Show()
        else
            btn.fileID = nil
            btn:Hide()
        end
    end
end

local function BuildPicker()
    local f = CreateFrame("Frame", "RemindTalentsIconPicker", UIParent, "BasicFrameTemplateWithInset")
    local w = COLS * (ICON + GAP) + 24
    f:SetSize(w, ROWS * (ICON + GAP) + 90)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:SetMovable(true); f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    UI.SetTitle(f, L["Choose an icon"])
    if UI.SolidBlack then UI.SolidBlack(f) end
    tinsert(UISpecialFrames, "RemindTalentsIconPicker")

    searchBox = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
    searchBox:SetSize(w - 40, 22)
    searchBox:SetPoint("TOP", 0, -30)
    if searchBox.Instructions then searchBox.Instructions:SetText(L["Search (name or id)"]) end
    searchBox:SetScript("OnTextChanged", function(self)
        if SearchBoxTemplate_OnTextChanged then SearchBoxTemplate_OnTextChanged(self) end
        grid.offset = 0
        Render()
    end)

    grid = CreateFrame("Frame", nil, f)
    grid:SetPoint("TOPLEFT", 12, -60)
    grid:SetSize(COLS * (ICON + GAP), ROWS * (ICON + GAP))
    grid.buttons = {}
    grid.offset = 0

    for i = 1, COLS * ROWS do
        local btn = CreateFrame("Button", nil, grid)
        btn:SetSize(ICON, ICON)
        local col = (i - 1) % COLS
        local rowN = math.floor((i - 1) / COLS)
        btn:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (ICON + GAP), -rowN * (ICON + GAP))

        btn.tex = btn:CreateTexture(nil, "ARTWORK")
        btn.tex:SetAllPoints()
        btn.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        btn.selected = btn:CreateTexture(nil, "OVERLAY")
        btn.selected:SetAllPoints()
        btn.selected:SetColorTexture(0.1, 0.6, 1, 0.35)
        btn.selected:Hide()

        btn:SetHighlightTexture("Interface\\Buttons\\WHITE8X8")
        local hl = btn:GetHighlightTexture()
        if hl then hl:SetColorTexture(1, 1, 1, 0.2) end

        btn:SetScript("OnClick", function(self)
            if self.fileID and onPickCb then onPickCb(self.fileID) end
            f:Hide()
        end)
        grid.buttons[i] = btn
    end

    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta)
        grid.offset = grid.offset - delta
        Render()
    end)

    picker = f
end

-------------------------------------------------------------------------------
--  API pública
-------------------------------------------------------------------------------
function UI.OpenIconPicker(currentIcon, onPick)
    if #BuildIcons() == 0 then
        ns.Warn(L["Icon selection is not available in this client."])
        return
    end
    onPickCb = onPick
    if not picker then BuildPicker() end
    grid.currentIcon = currentIcon
    grid.offset = 0
    if searchBox then searchBox:SetText("") end
    Render()
    picker:Show()
end
