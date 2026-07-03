-------------------------------------------------------------------------------
--  RemindTalents / Reminder.lua
--  Mostra um ícone na tela quando o loadout ativo difere do esperado para a
--  zona atual. Clicar aplica o loadout. Standalone (sem dependências do
--  EllesmereUI). Lógica de visibilidade portada de EllesmereUIABR_TalentReminders.
-------------------------------------------------------------------------------
local ADDON, ns = ...

local Reminder = {}
ns.Reminder = Reminder
local L = ns.L

local ICON_SIZE = 40
local SPACING = 40

local anchor
local pool = {}          -- índice → Button
local active = {}        -- botões visíveis nesta passada
local applying = false   -- suprime refresh durante Apply.ApplyLoadout

-------------------------------------------------------------------------------
--  Supressão de contexto
-------------------------------------------------------------------------------
local function InCombat()
    return InCombatLockdown and InCombatLockdown()
end

local function InMythicPlusKey()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive
        and C_ChallengeMode.IsChallengeModeActive()
end

local function Suppressed()
    if UnitIsDeadOrGhost("player") or IsResting()
        or (IsMounted() and IsFlying()) or UnitInVehicle("player") then
        return true
    end
    return false
end

-------------------------------------------------------------------------------
--  Ícones
-------------------------------------------------------------------------------
local function StyleIcon(btn)
    -- Borda simples via BackdropTemplate.
    if BackdropTemplateMixin then
        Mixin(btn, BackdropTemplateMixin)
    end
    if btn.SetBackdrop then
        btn:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        btn:SetBackdropBorderColor(0, 0, 0, 1)
    end
end

-------------------------------------------------------------------------------
--  Glow (brilho ao aparecer o botão)
-------------------------------------------------------------------------------
-- Fallback próprio: textura de "proc alert" pulsando em alpha. Usado quando o
-- glow nativo (ActionButton_ShowOverlayGlow) não está disponível.
local function EnsureGlow(btn)
    if btn._glow then return btn._glow end
    local glow = btn:CreateTexture(nil, "OVERLAY", nil, 7)
    glow:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
    glow:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    glow:SetBlendMode("ADD")
    local pad = ICON_SIZE * 0.4
    glow:SetPoint("TOPLEFT", btn, "TOPLEFT", -pad, pad)
    glow:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", pad, -pad)
    glow:Hide()

    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(1); fade:SetToAlpha(0.35); fade:SetDuration(0.6); fade:SetOrder(1)
    local rise = ag:CreateAnimation("Alpha")
    rise:SetFromAlpha(0.35); rise:SetToAlpha(1); rise:SetDuration(0.6); rise:SetOrder(2)

    btn._glow = glow
    btn._glowAnim = ag
    return glow
end

local function StartGlow(btn)
    if btn._glowOn then return end
    btn._glowOn = true
    if ActionButton_ShowOverlayGlow then
        ActionButton_ShowOverlayGlow(btn)
    else
        EnsureGlow(btn)
        btn._glow:Show()
        btn._glowAnim:Play()
    end
end

local function StopGlow(btn)
    if not btn._glowOn then return end
    btn._glowOn = false
    if ActionButton_HideOverlayGlow then
        ActionButton_HideOverlayGlow(btn)
    end
    if btn._glowAnim then btn._glowAnim:Stop() end
    if btn._glow then btn._glow:Hide() end
end

local function ApplyEntry(btn)
    local e = btn._entry
    if not e or not e.text then return end
    if InCombat() then
        ns.Warn(L["cannot change talents in combat."])
        return
    end
    ns.Apply.ApplyLoadout(e.text, Reminder.RequestRefresh)
end

local function GetIcon(index)
    if pool[index] then return pool[index] end
    local btn = CreateFrame("Button", "RemindTalentsIcon" .. index, anchor, "BackdropTemplate")
    btn:SetSize(ICON_SIZE, ICON_SIZE)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(100)
    btn:RegisterForClicks("LeftButtonUp")
    btn:Hide()

    local tex = btn:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    btn._icon = tex

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOP", btn, "BOTTOM", 0, -2)
    label:SetTextColor(1, 1, 1, 1)
    btn._label = label

    StyleIcon(btn)

    btn:SetScript("OnClick", ApplyEntry)
    btn:SetScript("OnEnter", function(self)
        local e = self._entry
        if not e then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(e.tooltip or e.name or "", 1, 1, 1)
        GameTooltip:AddLine(L["Click to apply this loadout"], 0.05, 0.82, 0.62)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", GameTooltip_Hide or function() GameTooltip:Hide() end)

    pool[index] = btn
    return btn
end

local function SetIconTexture(btn, icon)
    local tex = icon or 134400
    if type(tex) == "string" and not tex:find("\\", 1, true) then
        btn._icon:SetAtlas(tex)
    else
        btn._icon:SetTexture(tex)
    end
end

local function ShowIcon(index, entry)
    local btn = GetIcon(index)
    btn._entry = entry
    SetIconTexture(btn, entry.icon)
    btn._label:SetText(entry.name or "")
    btn:Show()
    StartGlow(btn)
    active[#active + 1] = btn
end

local function LayoutIcons()
    local count = #active
    if count == 0 then return end
    local totalW = (count * ICON_SIZE) + ((count - 1) * SPACING)
    local startX = -totalW / 2
    for i, btn in ipairs(active) do
        btn:ClearAllPoints()
        btn:SetPoint("TOPLEFT", anchor, "TOP", startX + (i - 1) * (ICON_SIZE + SPACING), 0)
    end
end

local function HideIcons()
    if InCombat() then return end
    for _, btn in ipairs(active) do
        StopGlow(btn)
        btn._label:SetText("")
        btn:Hide()
    end
    wipe(active)
    if anchor then anchor:Hide() end
end

-------------------------------------------------------------------------------
--  Coleta / decisão
-------------------------------------------------------------------------------
local function Collect(out)
    if applying then return end
    if InMythicPlusKey() or InCombat() or not ns.Zones.IsInstancedContent() then return end

    local specIcon = ns.GetSpecIcon()
    local seen = {}

    -- Considera a entrada de um slot (com vários loadouts). Para bosses, filtra
    -- pela dificuldade atual da raid (loadout "all"/nil vale para todas). Se o
    -- build ativo já corresponde a ALGUM loadout aplicável, nada a lembrar.
    -- Senão, mostra um ícone por loadout aplicável (clique aplica).
    local function considerEntry(e)
        if not e or not e.loadouts or #e.loadouts == 0 then return end

        local isBoss = e.slot and e.slot.kind == "boss"
        local raidDiff = isBoss and ns.Zones.GetRaidDifficulty() or nil
        local function applies(lo)
            if not isBoss then return true end
            local d = lo.difficulty
            if not d or d == "all" then return true end
            if not raidDiff then return true end  -- dificuldade desconhecida → não filtra
            return d == raidDiff
        end

        local list = {}
        for _, lo in ipairs(e.loadouts) do
            if lo.text and applies(lo) then list[#list + 1] = lo end
        end
        if #list == 0 then return end

        for _, lo in ipairs(list) do
            if ns.Codec.ActiveMatchesLoadout(lo.text) then return end
        end
        for _, lo in ipairs(list) do
            if not seen[lo.id] then
                seen[lo.id] = true
                out[#out + 1] = {
                    text    = lo.text,
                    icon    = lo.icon or specIcon or 134400,
                    name    = lo.name,
                    tooltip = (L["Apply: %s"]):format(lo.name or ""),
                }
            end
        end
    end

    -- Masmorra / zona atual (por nome/mapID)
    local zone = ns.Zones.GetCurrent()
    if zone and zone.name then
        considerEntry(ns.Storage.FindForZone(zone))
    end

    -- Boss: quando o jogador mira o boss (fora de combate — já garantido acima)
    if UnitExists("target") and not UnitIsDeadOrGhost("target") then
        local tname = UnitName("target")
        if tname then
            considerEntry(ns.Storage.FindForBoss(tname))
        end
    end
end

-------------------------------------------------------------------------------
--  Refresh (com debounce)
-------------------------------------------------------------------------------
local refreshQueued = false
local lastRefresh = 0
local collected = {}

local function Refresh()
    refreshQueued = false
    lastRefresh = GetTime()
    if not ns.db or not anchor then return end

    if Suppressed() then HideIcons(); return end

    HideIcons()
    wipe(collected)
    Collect(collected)

    if #collected > 0 then
        for i, e in ipairs(collected) do ShowIcon(i, e) end
        LayoutIcons()
        anchor:Show()
    end
end

function Reminder.RequestRefresh()
    if refreshQueued then return end
    refreshQueued = true
    local elapsed = GetTime() - lastRefresh
    local delay = (elapsed >= 0.5) and 0 or (0.5 - elapsed)
    ns.After(delay, function() refreshQueued = false; Refresh() end)
end

function Reminder.SetApplying(v)
    applying = v and true or false
    if applying then HideIcons() end
end

function Reminder.HideIcons() HideIcons() end

-- Reposiciona o ícone para o centro-superior padrão.
function Reminder.ResetIconPosition()
    ns.db.settings.iconPoint = { "CENTER", nil, "CENTER", 0, 120 }
    if anchor then
        anchor:ClearAllPoints()
        anchor:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    end
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
ns.RegisterInit(function()
    anchor = CreateFrame("Frame", "RemindTalentsAnchor", UIParent)
    anchor:SetSize(1, 1)
    anchor:SetFrameStrata("MEDIUM")
    anchor:SetFrameLevel(100)
    anchor:EnableMouse(false)
    local p = ns.db.settings.iconPoint
    anchor:SetPoint(p[1] or "CENTER", UIParent, p[3] or "CENTER", p[4] or 0, p[5] or 120)
    anchor:Hide()

    local events = {
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED",
        "PLAYER_TALENT_UPDATE", "PLAYER_SPECIALIZATION_CHANGED",
        "SPELLS_CHANGED", "PLAYER_DEAD", "PLAYER_ALIVE",
        "PLAYER_TARGET_CHANGED",
    }
    for _, ev in ipairs(events) do
        ns.On(ev, function(event)
            if event == "PLAYER_REGEN_DISABLED" then
                HideIcons()
                return
            end
            -- Mudanças de spec/talento assentam async → refresh extra em +1s.
            if event == "PLAYER_SPECIALIZATION_CHANGED" or event == "PLAYER_TALENT_UPDATE"
                or event == "TRAIT_CONFIG_UPDATED" then
                ns.After(1.0, Reminder.RequestRefresh)
            end
            Reminder.RequestRefresh()
        end)
    end

    ns.After(1.0, Reminder.RequestRefresh)
end)
